/// Cloudinary configuration that is safe to ship in the app binary.
///
/// ## Where the credentials live — read this before "simplifying" it
///
/// This file contains **no API secret**, and neither does any other file in
/// the app. The Cloudinary API secret is never compiled into the Flutter app,
/// never written to a committed `.env`, and never stored in Firestore.
///
/// ### Uploads go direct to Cloudinary with an unsigned preset
///
/// The app uploads by POSTing the file straight to
/// `https://api.cloudinary.com/v1_1/{cloud}/image/upload` with an **unsigned
/// upload preset** name. This is deliberately the opposite of the usual
/// "route every upload through a backend" advice, and the reason is
/// operational rather than stylistic:
///
///   * Cloud Functions require the **Blaze (pay-as-you-go) plan**. On the
///     Spark plan this project cannot deploy a function at all, so the
///     previously built signed-upload function was undeployable.
///   * An unsigned preset needs no server and no billing plan.
///
/// Two consequences of unsigned uploads are load-bearing and must not be
/// "tidied away":
///
///   1. **The preset name is public.** It ships inside the APK, so anyone who
///      unzips the app can upload arbitrary files to this Cloudinary account.
///      The blast radius is bounded entirely by the *preset configuration*
///      (`folder`, `allowed_formats`, `max_file_size`, `tags`), which lives in
///      the Cloudinary dashboard — not in this file. Keep it locked down, and
///      see `docs/cloudinary-images.md`.
///   2. **Unsigned uploads cannot delete.** Cloudinary's Admin API `destroy`
///      endpoint always requires the API secret, and there is no unsigned
///      delete. Deletion therefore happens manually in the Cloudinary Media
///      Library until this project is upgraded to Blaze and the signed
///      function is deployed. See [CloudinaryConfig.canDeleteRemotely].
///
/// ### What is safe to put in this file
///
/// The *cloud name* appears in every delivery URL and the *preset name* appears
/// in every upload request, so both are public by definition. Neither is
/// treated as a secret. The cloud name is read at runtime from `settings/app`
/// so the Cloudinary account can be swapped without shipping an app update —
/// see [CloudinaryDelivery].
class CloudinaryConfig {
  CloudinaryConfig._();

  /// Cloudinary delivery host.
  static const String deliveryHost = 'res.cloudinary.com';

  /// Cloudinary upload API host, used for unsigned uploads.
  static const String uploadHost = 'api.cloudinary.com';

  /// Base of every delivery URL:
  /// `https://res.cloudinary.com/{cloud}/{type}/upload/{transform}/{publicId}`.
  static const String deliveryBase = 'https://$deliveryHost';

  /// Firestore field on `settings/app` holding the Cloudinary cloud name.
  static const String cloudNameField = 'cloudinaryCloudName';

  /// Firestore field on `settings/app` holding the unsigned upload preset name.
  ///
  /// Read at runtime for the same reason as [cloudNameField]: the preset can be
  /// rotated in the Cloudinary dashboard without shipping an app update. This
  /// matters more than usual for the preset name, because it is the one value
  /// that would ever need rotating after a leak — anyone holding it can upload.
  static const String uploadPresetField = 'cloudinaryUploadPreset';

  /// True when the app can delete assets from Cloudinary by itself.
  ///
  /// Currently **false**, and the code paths that would need it are written to
  /// degrade gracefully rather than throw. See the class documentation for why.
  ///
  /// Flipping this to `true` is only correct once the Blaze plan is enabled
  /// and `functions/lib/cloudinary.js` is deployed — at that point the delete
  /// helpers should be switched back to the signed Admin API. Do not set it
  /// optimistically.
  static const bool canDeleteRemotely = false;

  /// Endpoint an unsigned upload is POSTed to.
  ///
  /// Empty when [cloudName] is unknown, so a misconfigured build fails fast
  /// with a clear message instead of posting to a malformed URL.
  static String uploadEndpoint(String cloudName) =>
      cloudName.isEmpty ? '' : 'https://$uploadHost/v1_1/$cloudName/image/upload';

  /// Folder the store's media lives under, mirroring `ROOT_FOLDER` in
  /// `functions/lib/cloudinary.js`.
  static const String rootFolder = 'padma_collections';

  /// Sub-folder per asset type. Mirrors `FOLDERS` in the Cloud Function.
  ///
  /// Keys are the asset type strings the upload service accepts.
  static const Map<String, String> folders = <String, String>{
    'products': '$rootFolder/products',
    'categories': '$rootFolder/categories',
    'banners': '$rootFolder/banners',
    'store': '$rootFolder/store',
  };

  /// The target folder for [type], falling back to [rootFolder].
  static String folderFor(String type) => folders[type] ?? rootFolder;

  /// The target folder for [type], nested under [entityId] where meaningful.
  ///
  /// Mirrors `publicFolderFor` in `functions/lib/cloudinary.js`, including its
  /// sanitisation, so the folder a client uploads to is identical to the one
  /// the signed function would have chosen. That matters while both paths
  /// coexist: assets uploaded either way stay grouped together.
  ///
  /// Only products and categories get a per-entity sub-folder; banners and the
  /// store logo are flat.
  static String publicFolderFor(String type, String? entityId) {
    final String base = folderFor(type);
    if (entityId == null || entityId.isEmpty) return base;
    if (type != 'products' && type != 'categories') return base;
    // Anything outside this set becomes an underscore, which stops a crafted
    // id from escaping the folder or injecting path segments.
    final String safe = entityId.replaceAll(RegExp(r'[^A-Za-z0-9_-]'), '_');
    if (safe.isEmpty) return base;
    return '$base/$safe';
  }

  /// Largest file the client will attempt to upload.
  ///
  /// Mirrors `MAX_UPLOAD_BYTES` in `functions/lib/cloudinary.js`. The client
  /// checks this first so an oversized photo is rejected instantly instead of
  /// after a slow round trip; the function re-checks it because the client
  /// cannot be trusted.
  static const int maxUploadBytes = 10 * 1024 * 1024;

  /// Longest edge after compression, in pixels.
  ///
  /// Comfortably larger than the largest transformation the app requests
  /// (`product_detail` at 1200px), so a customer can still zoom in without the
  /// stored original being the bottleneck.
  static const int maxDimension = 1600;

  /// JPEG quality used when re-encoding. Visually near-lossless, far smaller.
  static const int jpegQuality = 82;

  /// Product images per product. Matches the admin form's cap.
  static const int maxProductImages = 8;

  /// Most product images one batch upload will attempt.
  static const int maxImagesPerUpload = 8;

  /// Formats Cloudinary will accept from this app.
  static const List<String> allowedExtensions = <String>[
    'jpg',
    'jpeg',
    'png',
    'webp',
  ];

  /// MIME types the client may declare to the upload function.
  static const List<String> allowedContentTypes = <String>[
    'image/jpeg',
    'image/jpg',
    'image/png',
    'image/webp',
  ];

  /// MIME type for a filename extension, falling back to JPEG.
  static String contentTypeFor(String fileName) {
    switch (extensionOf(fileName)) {
      case 'jpg':
      case 'jpeg':
        return 'image/jpeg';
      case 'png':
        return 'image/png';
      case 'webp':
        return 'image/webp';
      default:
        // Anything unrecognised is rejected by [isSupportedExtension] before it
        // reaches here; JPEG is only a last-resort default.
        return 'image/jpeg';
    }
  }

  /// Lower-cased extension of [fileName], without the dot. Empty when absent.
  static String extensionOf(String fileName) {
    final int dot = fileName.lastIndexOf('.');
    if (dot < 0 || dot == fileName.length - 1) return '';
    return fileName.substring(dot + 1).toLowerCase();
  }

  /// True when the extension is one Cloudinary will accept.
  static bool isSupportedExtension(String fileName) =>
      allowedExtensions.contains(extensionOf(fileName));
}

/// App-wide resolver for the Cloudinary cloud name.
///
/// Delivery URLs are
/// `https://res.cloudinary.com/{CLOUD}/{type}/upload/{transform}/{PUBLIC_ID}`,
/// so every image widget needs the cloud name. Threading it through every
/// widget as a constructor argument would be noise, and hardcoding it would put
/// a value in the APK that the owner may need to change.
///
/// Instead `AppController` pushes it here once `settings/app` loads, and
/// `CloudinaryImage.urlFor` falls back to it when no cloud name is passed
/// explicitly. That keeps one source of truth for the whole app.
///
/// This holds a *public* identifier, never the API key or secret.
class CloudinaryDelivery {
  CloudinaryDelivery._();

  /// The Cloudinary cloud name, set by `AppController` when settings load.
  ///
  /// Publicly readable so image URLs can be built anywhere. Never a credential.
  static String cloudName = '';

  static bool get isConfigured => cloudName.isNotEmpty;

  /// Builds a delivery URL, or returns an empty string when unconfigured.
  ///
  /// [cloudName] defaults to the app-wide value set by `AppController`; pass
  /// it explicitly only when building a URL for an account other than the
  /// current one (which the app does not currently do, but the parameter keeps
  /// [CloudinaryImage.urlFor] honest rather than reaching into a global).
  ///
  /// An empty string is deliberate: it makes the image widgets fall back to
  /// their "no image" placeholder instead of requesting a malformed URL.
  static String build(
    String publicId,
    CloudinaryTransform transform, {
    String? format,
    String? cloudName,
  }) {
    final String cloud = (cloudName != null && cloudName.isNotEmpty)
        ? cloudName
        : CloudinaryDelivery.cloudName;
    if (publicId.isEmpty || cloud.isEmpty) return '';
    final String extension = (format == null || format.isEmpty)
        ? ''
        : '.${format.toLowerCase()}';
    return '${CloudinaryConfig.deliveryBase}/$cloud/image/upload/'
        '${transform.segment}/$publicId$extension';
  }
}

/// The delivery transformations the app requests from Cloudinary.
///
/// Cloudinary transformations are part of the **delivery URL** rather than a
/// server-side configuration, so nothing here needs to be created in the
/// dashboard first — so nothing has to be created up front, unlike provider-side variants
/// app could request them. Each is an on-the-fly resize, so one stored original
/// serves every size.
///
/// The names match the sizes the UI needs, and `f_auto` lets Cloudinary serve
/// AVIF or WebP to clients that support them and fall back to the stored format
/// otherwise.
enum CloudinaryTransform {
  /// Wishlist and cart rows. Smallest possible payload.
  thumbnail('c_fill,w_200,h_200,q_auto,f_auto', '200 × 200', 200),

  /// Home rails, category listings, search results, admin product grid.
  productCard('c_fill,w_500,h_500,q_auto,f_auto', '500 × 500', 500),

  /// Product detail gallery, where a customer may zoom.
  productDetail('c_fill,w_1200,h_1200,q_auto,f_auto', '1200 × 1200', 1200),

  /// Home and promotional carousel imagery.
  banner('c_fill,w_1600,h_700,q_auto,f_auto', '1600 × 700', 1200),

  /// Category tiles.
  category('c_fill,w_500,h_500,q_auto,f_auto', '500 × 500', 500),

  /// The stored original, only quality-optimised. Used for the store logo,
  /// which must keep its aspect ratio and cannot be cropped to a fixed box.
  original('q_auto,f_auto', 'original', 800);

  const CloudinaryTransform(this.segment, this.targetSize, this.decodeWidth);

  /// The comma-separated transformation placed in the delivery URL.
  final String segment;

  /// Human-readable target dimensions, shown in the admin UI only.
  final String targetSize;

  /// Decoded pixel width a list should decode at, for memory efficiency.
  ///
  /// Roughly the transform's width at a typical device pixel ratio. Passing
  /// this to `CloudinaryImage.memCacheWidth` stops a 1200px bitmap being
  /// decoded into a 160px list row.
  final int decodeWidth;
}
