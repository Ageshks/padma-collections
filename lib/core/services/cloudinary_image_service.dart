import 'dart:async';
import 'dart:convert';
import 'dart:io' show SocketException;
import 'dart:typed_data';

import 'package:flutter/foundation.dart' show visibleForTesting;
import 'package:flutter_image_compress/flutter_image_compress.dart';
import 'package:http/http.dart' as http;

import '../constants/cloudinary_config.dart';
import '../utils/error_handler.dart';
import '../../data/models/cloudinary_image.dart';

/// Progress of a single image within a batch upload.
///
/// Drives the per-file rows in the admin UI:
/// ```text
/// Uploading 2 of 4
/// Image 1   ✓
/// Image 2   ███████████░░ 80%
/// Image 3   Waiting
/// ```
enum ImageUploadState { waiting, uploading, uploaded, failed }

/// Per-image upload status, reported as a batch progresses.
class ImageUploadStatus {
  const ImageUploadStatus({
    required this.index,
    required this.fileName,
    required this.state,
    this.progress = 0,
  });

  /// Position in the batch, zero-based.
  final int index;
  final String fileName;
  final ImageUploadState state;

  /// 0.0 – 1.0. Only meaningful while [state] is uploading or uploaded.
  final double progress;

  /// 1-based position, for copy like "Image 2".
  String get label => 'Image ${index + 1}';

  ImageUploadStatus copyWith({ImageUploadState? state, double? progress}) {
    return ImageUploadStatus(
      index: index,
      fileName: fileName,
      state: state ?? this.state,
      progress: progress ?? this.progress,
    );
  }
}

/// Progress of a batch upload, for the admin's progress indicator.
class ImageUploadProgress {
  const ImageUploadProgress({
    required this.completed,
    required this.total,
    this.currentFileName = '',
    this.statuses = const <ImageUploadStatus>[],
  });

  /// Images finished (successfully or not).
  final int completed;
  final int total;

  /// Name of the image currently being sent.
  final String currentFileName;

  /// Per-image rows, so the UI can tick each one off individually.
  final List<ImageUploadStatus> statuses;

  /// 0.0 – 1.0. Zero when nothing has started, 1.0 when all are done.
  double get fraction => total <= 0 ? 0 : (completed / total).clamp(0.0, 1.0);

  /// Copy for the admin UI, e.g. "Uploading 2 of 4".
  String get label => 'Uploading $completed of $total';

  /// Fraction rendered as a whole percentage, e.g. "75%".
  String get percentLabel => '${(fraction * 100).round()}%';
}

/// Outcome of uploading one batch of images.
class ImageUploadResult {
  const ImageUploadResult({
    required this.uploaded,
    required this.failures,
    this.failedFileNames = const <String>[],
    this.failureMessages = const <String>[],
  });

  /// Images that reached Cloudinary, in the order supplied.
  final List<CloudinaryImage> uploaded;

  /// Number of images that did not make it.
  final int failures;

  /// Names of the failed images, so the admin can retry exactly those.
  final List<String> failedFileNames;

  /// Friendly reasons for failed uploads, in the same order as their files.
  final List<String> failureMessages;

  bool get allSucceeded => failures == 0;

  bool get isEmpty => uploaded.isEmpty;
}

/// Uploads images to Cloudinary and reports their progress.
///
/// ### Why this talks to Cloudinary directly
///
/// This service POSTs image bytes straight to
/// `https://api.cloudinary.com/v1_1/{cloud}/image/upload` using an **unsigned
/// upload preset**. It does not call a Cloud Function, for one concrete reason:
/// this Firebase project is on the Spark plan, which cannot deploy Cloud
/// Functions at all. The signed-upload function in `functions/` is still
/// correct and remains the right thing to deploy once the plan is upgraded to
/// Blaze — see `docs/cloudinary-images.md` for the path back.
///
/// ### The security trade-off, stated plainly
///
/// An unsigned preset means uploads are **unauthenticated**: the preset name is
/// public (it ships inside the APK), so anyone who extracts it can push
/// arbitrary files into this Cloudinary account. That is accepted deliberately
/// and contained by locking the preset down in the Cloudinary dashboard — a
/// fixed `folder`, an `allowed_formats` allowlist, and a `max_file_size` cap.
/// Those dashboard settings, not this code, are the real security boundary.
///
/// The alternative (a signing backend) is strictly stronger. This class is
/// deliberately shaped so that swapping back is a contained change: only
/// [uploadOne] would need to become a signed call.
///
/// ### Deletion is not possible
///
/// Cloudinary's Admin API `destroy` endpoint always requires the API secret and
/// has no unsigned equivalent. The delete helpers below are therefore no-ops
/// that resolve successfully (see [deleteImage]) instead of pretending to work.
/// Images the admin removes remain in the Media Library until cleaned up by hand.
class CloudinaryImageService {
  /// Accepts every asset type the store uses. Mirrors `ASSET_TYPES` in
  /// `functions/index.js`.
  static const String typeProducts = 'products';
  static const String typeCategories = 'categories';
  static const String typeBanners = 'banners';
  static const String typeStore = 'store';

  CloudinaryImageService({
    http.Client? client,
    this.cloudName = '',
    this.uploadPreset = '',
  }) : _client = client ?? http.Client();

  final http.Client _client;

  /// The Cloudinary cloud name used to build upload and delivery URLs.
  ///
  /// Public value, but supplied at runtime from `settings/app` so the account
  /// can be swapped without shipping an app release.
  String cloudName = '';

  /// Unsigned upload preset name.
  ///
  /// **Not a secret** — it ships inside the app and is extractable by anyone.
  /// It is loaded at runtime from `settings/app`
  /// ([CloudinaryConfig.uploadPresetField]) purely so the preset can be rotated
  /// without an app release, which is the one remediation available if it ever
  /// leaks.
  String uploadPreset = '';

  /// True when both the cloud name and a preset are known, i.e. an upload can
  /// actually be attempted.
  ///
  /// Checked before uploading so an unconfigured build reports a clear
  /// configuration error rather than failing with an opaque HTTP error.
  bool get isConfigured => cloudName.isNotEmpty && uploadPreset.isNotEmpty;

  // -------------------------------------------------------------------------
  // URL construction
  // -------------------------------------------------------------------------

  /// Builds a delivery URL for [publicId] at [transform].
  ///
  /// Returns an empty string when no cloud name is configured, which renders as
  /// the standard "no image" placeholder rather than a broken request.
  String getImageUrl(
    String publicId,
    CloudinaryTransform transform, {
    String? format,
  }) {
    if (publicId.isEmpty || cloudName.isEmpty) return '';
    return CloudinaryDelivery.build(
      publicId,
      transform,
      format: format,
      cloudName: cloudName,
    );
  }

  /// Arbitrary optimised URL — the general entry point the others delegate to.
  String getOptimizedUrl(
    String publicId,
    CloudinaryTransform transform, {
    String? format,
  }) => getImageUrl(publicId, transform, format: format);

  /// Convenience overload taking a whole image.
  String urlForImage(CloudinaryImage image, CloudinaryTransform transform) =>
      image.urlFor(transform, cloudName: cloudName);

  /// Wishlist/cart sized URL.
  String getThumbnailUrl(CloudinaryImage image) =>
      urlForImage(image, CloudinaryTransform.thumbnail);

  /// Product card sized URL — what grids and rails should request.
  String getProductImageUrl(CloudinaryImage image) =>
      urlForImage(image, CloudinaryTransform.productCard);

  /// Full gallery sized URL.
  String getProductDetailUrl(CloudinaryImage image) =>
      urlForImage(image, CloudinaryTransform.productDetail);

  /// Home carousel sized URL.
  String getBannerImageUrl(CloudinaryImage image) =>
      urlForImage(image, CloudinaryTransform.banner);

  // -------------------------------------------------------------------------
  // Upload
  // -------------------------------------------------------------------------

  /// Compresses, validates and uploads one image to Cloudinary.
  ///
  /// POSTs the compressed bytes to Cloudinary's upload endpoint with an
  /// unsigned preset. Only the fields Cloudinary permits on an unsigned upload
  /// are sent — `file`, `upload_preset`, `folder`, `public_id`, `tags` — because
  /// passing anything else (a `transformation`, say) is rejected outright.
  ///
  /// The returned [CloudinaryImage] carries the public id and the stored
  /// original's URL; the admin form decides which image is primary and what
  /// `sortOrder` it takes.
  Future<CloudinaryImage> uploadImage(
    XFile file, {
    String type = typeProducts,
    String? entityId,
  }) async {
    _validateFile(file);

    final Uint8List bytes = await prepareBytes(file);
    final Map<String, dynamic> data = await uploadOne(
      file: file,
      bytes: bytes,
      type: type,
      entityId: entityId,
    );

    final String publicId = (data['publicId'] as String?) ?? '';
    if (publicId.isEmpty) {
      throw const AppException(
        'The image service returned an unexpected response. Please try again.',
        code: 'format',
      );
    }

    return CloudinaryImage(
      publicId: publicId,
      secureUrl: (data['secureUrl'] as String?) ?? '',
      resourceType: (data['resourceType'] as String?) ?? 'image',
      format: (data['format'] as String?) ?? '',
      width: (data['width'] as num?)?.toInt() ?? 0,
      height: (data['height'] as num?)?.toInt() ?? 0,
      createdAt: DateTime.now(),
    );
  }

  /// Performs the actual unsigned upload and normalises Cloudinary's response.
  ///
  /// This is the one method that would change if the project moves to a signed
  /// upload (i.e. once the Blaze plan is enabled and `functions/` is deployed) —
  /// everything else works off the returned map.
  ///
  /// Public only so tests can drive it against a stub HTTP client and assert on
  /// the exact multipart fields sent. Callers should use [uploadImage] instead.
  @visibleForTesting
  Future<Map<String, dynamic>> uploadOne({
    required XFile file,
    required Uint8List bytes,
    required String type,
    String? entityId,
  }) async {
    if (!isConfigured) {
      throw const AppException(
        'Cloudinary uploads are not configured. Enter the cloud name and '
            'unsigned upload preset in Admin > Store Settings, then save.',
        code: 'not-configured',
      );
    }

    // Fail before streaming rather than after.
    if (bytes.length > CloudinaryConfig.maxUploadBytes) {
      throw AppException(
        'That image is too large. Please choose one under '
        '${CloudinaryConfig.maxUploadBytes ~/ (1024 * 1024)} MB.',
        code: 'file-too-large',
      );
    }

    final String endpoint = CloudinaryConfig.uploadEndpoint(cloudName);
    final String folder = CloudinaryConfig.publicFolderFor(type, entityId);

    final http.MultipartRequest request = http.MultipartRequest(
      'POST',
      Uri.parse(endpoint),
    )
      // An unsigned upload must NOT carry api_key/signature/timestamp: the
      // preset alone authenticates, and an incomplete signature is rejected.
      ..fields['upload_preset'] = uploadPreset
      ..fields['folder'] = folder
      ..fields['public_id'] = _publicIdFor(folder, file.name)
      // Tagging makes the Media Library auditable, which is now the only
      // practical way to identify orphans for manual cleanup.
      ..fields['tags'] = 'padma,$type'
      ..files.add(
        http.MultipartFile.fromBytes('file', bytes, filename: file.name),
      );

    final http.StreamedResponse streamed;
    try {
      streamed = await _client.send(request);
    } on SocketException {
      // No connectivity, DNS failure, or the request was cut off mid-flight.
      // Surfaced as an AppException so the admin form's retry path handles it
      // like any other upload failure instead of crashing the batch.
      throw const AppException(
        'No connection. Please check your internet and try again.',
        code: 'offline',
      );
    } on http.ClientException {
      throw const AppException(
        'Could not reach the image service. Please try again.',
        code: 'network',
      );
    }

    final String body = await streamed.stream.bytesToString();
    final Map<String, dynamic> payload = _decode(body);

    // Cloudinary reports failures as a 4xx carrying an `error` object.
    if (streamed.statusCode >= 400 || payload['error'] != null) {
      throw AppException(
        _cloudinaryErrorMessage(payload, streamed.statusCode),
        code: 'upload-failed',
      );
    }

    final String publicId = payload['public_id'] as String? ?? '';
    if (publicId.isEmpty) {
      throw const AppException(
        'The image service returned an unexpected response. Please try again.',
        code: 'format',
      );
    }

    return <String, dynamic>{
      'publicId': publicId,
      'secureUrl': payload['secure_url'] as String? ?? '',
      'resourceType': payload['resource_type'] as String? ?? 'image',
      'format': payload['format'] as String? ?? '',
      'width': (payload['width'] as num?)?.toInt() ?? 0,
      'height': (payload['height'] as num?)?.toInt() ?? 0,
      'bytes': (payload['bytes'] as num?)?.toInt() ?? bytes.length,
      // There is no server to resolve this now, so it is simply our own value.
      // Kept in the map because the signed path still populates it.
      'cloudName': cloudName,
    };
  }

  /// Parses a Cloudinary response body, tolerating a non-JSON payload.
  Map<String, dynamic> _decode(String body) {
    try {
      final dynamic decoded = jsonDecode(body);
      if (decoded is Map<String, dynamic>) return decoded;
    } on FormatException {
      // Fall through to the generic message below rather than leaking a raw
      // HTML error page (often an edge 502) into the admin UI.
    }
    return <String, dynamic>{};
  }

  /// Builds a safe, unique public id for a new upload.
  ///
  /// Mirrors `publicIdFor` in `functions/lib/cloudinary.js` so both upload paths
  /// produce identically-shaped ids. Strips the extension (Cloudinary stores the
  /// format separately and re-attaches it at delivery time) and replaces every
  /// character outside `[A-Za-z0-9_-]` with an underscore, which stops a
  /// crafted filename from injecting folder segments.
  ///
  /// A short random suffix is appended so re-uploading a same-named file creates
  /// a *new* asset rather than silently overwriting one a product may still
  /// reference — the same intent as `overwrite: false, unique_filename: true` in
  /// the function, neither of which may be sent on an unsigned upload.
  String _publicIdFor(String folder, String fileName) {
    String base = fileName.replaceFirst(RegExp(r'\.[A-Za-z0-9]+$'), '');
    base = base.replaceAll(RegExp(r'[^A-Za-z0-9_-]'), '_');
    base = base.replaceAll(RegExp(r'_+'), '_');
    base = base.replaceAll(RegExp(r'^_|_$'), '');
    if (base.length > 40) base = base.substring(0, 40);
    if (base.isEmpty) base = 'image';

    final String suffix = DateTime.now()
        .microsecondsSinceEpoch
        .toRadixString(36)
        .substring(5);
    return '$folder/$base-$suffix';
  }

  /// Turns a Cloudinary error payload into something worth showing an admin.
  ///
  /// Cloudinary's own messages are specific and useful ("File size too large",
  /// "Unsupported image format"), so the real text is surfaced rather than
  /// hidden behind something generic. Falls back to a safe generic string when
  /// the body is unparseable, so no raw HTML ever reaches the UI.
  String _cloudinaryErrorMessage(Map<String, dynamic> payload, int status) {
    final Object? error = payload['error'];
    if (error is Map && error['message'] is String) {
      final String message = (error['message'] as String).trim();
      if (message.isNotEmpty) return message;
    }
    if (error is String && error.trim().isNotEmpty) return error.trim();
    return 'Upload failed (HTTP $status). Please try a different image.';
  }

  /// Uploads several images in order, reporting per-image progress.
  ///
  /// A failure never aborts the batch: one bad photo must not strand the
  /// admin's other four. The failed file names come back in
  /// [ImageUploadResult] so a retry uploads exactly what is missing and
  /// nothing already stored.
  Future<ImageUploadResult> uploadImages(
    List<XFile> files, {
    String type = typeProducts,
    String? entityId,
    void Function(ImageUploadProgress progress)? onProgress,
  }) async {
    final List<CloudinaryImage> uploaded = <CloudinaryImage>[];
    final List<String> failed = <String>[];
    final List<String> failureMessages = <String>[];
    final List<ImageUploadStatus> statuses = <ImageUploadStatus>[
      for (int i = 0; i < files.length; i++)
        ImageUploadStatus(
          index: i,
          fileName: files[i].name,
          state: ImageUploadState.waiting,
        ),
    ];

    void report(int completed, int currentIndex) {
      onProgress?.call(
        ImageUploadProgress(
          completed: completed,
          total: files.length,
          currentFileName: files[currentIndex].name,
          statuses: List<ImageUploadStatus>.unmodifiable(statuses),
        ),
      );
    }

    for (int i = 0; i < files.length; i++) {
      statuses[i] = statuses[i].copyWith(state: ImageUploadState.uploading);
      report(i, i);

      try {
        uploaded.add(
          await uploadImage(files[i], type: type, entityId: entityId),
        );
        statuses[i] = statuses[i].copyWith(
          state: ImageUploadState.uploaded,
          progress: 1,
        );
      } catch (error) {
        failed.add(files[i].name);
        failureMessages.add(
          error is AppException
              ? error.message
              : AppErrorHandler.wrap(error).message,
        );
        statuses[i] = statuses[i].copyWith(state: ImageUploadState.failed);
      }
      report(i + 1, i);
    }

    onProgress?.call(
      ImageUploadProgress(
        completed: files.length,
        total: files.length,
        statuses: List<ImageUploadStatus>.unmodifiable(statuses),
      ),
    );

    return ImageUploadResult(
      uploaded: uploaded,
      failures: failed.length,
      failedFileNames: failed,
      failureMessages: failureMessages,
    );
  }

  /// Rejects an unsupported file before any work is done.
  void _validateFile(XFile file) {
    if (!CloudinaryConfig.isSupportedExtension(file.name)) {
      throw const AppException(
        'Unsupported image format.\nPlease select JPG, PNG, or WEBP.',
        code: 'unsupported-format',
      );
    }
  }

  /// Validates, downscales and re-encodes an image before upload.
  ///
  /// Catalogue photography from a modern phone is routinely 4–8 MB; the largest
  /// transformation the app requests is 1200px. Compressing here is what keeps
  /// the upload fast and the bill small, without visibly degrading the
  /// jewellery — 1600px at quality 82 is visually near-lossless.
  ///
  /// Falls back to the original bytes when the native codec is unavailable
  /// (some emulators, desktop).
  Future<Uint8List> prepareBytes(XFile file) async {
    final Uint8List original = await file.readAsBytes();

    if (original.isEmpty) {
      throw const AppException(
        'That image is empty. Please choose another.',
        code: 'invalid-file',
      );
    }
    if (original.length > CloudinaryConfig.maxUploadBytes) {
      throw AppException(
        'That image is too large. Please choose one under '
        '${CloudinaryConfig.maxUploadBytes ~/ (1024 * 1024)} MB.',
        code: 'file-too-large',
      );
    }

    try {
      // Explicitly nullable: the native codec returns null when it cannot
      // compress, and that case must fall through to the original bytes.
      // ignore: unnecessary_nullable_for_final_variable_declarations
      final Uint8List? compressed = await FlutterImageCompress.compressWithList(
        original,
        minWidth: CloudinaryConfig.maxDimension,
        minHeight: CloudinaryConfig.maxDimension,
        quality: CloudinaryConfig.jpegQuality,
        format: CompressFormat.jpeg,
      );
      // Never let compression make the file bigger — a small PNG can re-encode
      // to a *larger* JPEG, and uploading the bigger one helps nobody.
      if (compressed != null && compressed.length < original.length) {
        return compressed;
      }
    } catch (_) {
      // Fall through to the original bytes.
    }
    return original;
  }

  // -------------------------------------------------------------------------
  // Deletion
  //
  // NOTHING IN THIS SECTION ACTUALLY DELETES ANYTHING.
  //
  // Cloudinary's Admin API `destroy` endpoint requires the API secret on every
  // call, and there is no unsigned equivalent — an upload preset authorises
  // uploads only. So while the app uploads unsigned, deletion is impossible
  // from the client by construction, not by oversight.
  //
  // These helpers deliberately RESOLVE SUCCESSFULLY instead of throwing:
  //
  //   * Throwing would block admins from removing a photo at all, leaving them
  //     unable to fix a mistake — far worse than a stale file in the library.
  //   * Callers use these to decide whether it is safe to drop Firestore
  //     metadata. A "failure" here would therefore block the metadata write and
  //     strand the admin in a state where the image still shows in the product
  //     even though they removed it.
  //
  // The Firestore document is still updated, so the storefront never shows a
  // removed image; only the underlying asset lingers, costing storage until
  // swept from the Cloudinary Media Library by hand.
  //
  // See `docs/cloudinary-images.md` for the manual cleanup routine and the
  // conditions under which these should be reinstated against the signed
  // function.
  // -------------------------------------------------------------------------

  /// Reports whether Cloudinary assets can actually be deleted remotely.
  ///
  /// Always false today. Exposed so callers and UI can avoid implying to an
  /// admin that a removal reclaimed storage, rather than each call site
  /// hardcoding the answer.
  bool get canDeleteRemotely => CloudinaryConfig.canDeleteRemotely;

  /// A no-op stand-in for a real delete.
  ///
  /// Returns `false` rather than throwing: the asset was not deleted, and a
  /// truthful `false` lets [deleteImages] and the repository's "is it safe to
  /// drop the metadata?" checks read the current behaviour correctly.
  Future<bool> deleteImage(String publicId) async => false;

  /// A no-op stand-in for a bulk delete. Never throws.
  Future<void> deleteImages(Iterable<String> publicIds) async {}

  /// A no-op stand-in for a product's prefix delete.
  ///
  /// Returns 0, never throws. Products still live under their own
  /// `padma_collections/products/{productId}/` folder, so once signed deletes
  /// are available this remains a single prefix operation rather than a walk
  /// over ids — the folder layout was kept for exactly that reason.
  Future<int> deleteProductImages(String productId) async => 0;
}
