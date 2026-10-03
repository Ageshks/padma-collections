import '../../core/constants/cloudinary_config.dart';
import 'firestore_map.dart';

/// A single image stored in Cloudinary, as saved in Firestore.
///
/// Firestore holds **metadata only** — never the image bytes:
///
/// ```json
/// {
///   "publicId": "padma_collections/products/PC-NK-001/necklace",
///   "secureUrl": "https://res.cloudinary.com/demo/image/upload/.../necklace.jpg",
///   "resourceType": "image",
///   "format": "jpg",
///   "width": 1600,
///   "height": 1600,
///   "isPrimary": true,
///   "sortOrder": 0,
///   "createdAt": "Timestamp"
/// }
/// ```
///
/// Only [publicId] is the source of truth. [secureUrl] is the stored original
/// and is kept as a fallback for rendering; every sized variant is generated on
/// demand from the public id, which is why there is no point storing four URLs
/// per image when a cloud name and a transformation are all that is needed.
///
/// ### Backward compatibility
///
/// [fromEntry] accepts a bare URL string as well as a map. Documents written
/// before any migration stored `"images": ["https://…"]`, and those still have
/// to render. A string is read as an *external* image: [publicId] stays empty,
/// [isExternal] is true, and [urlFor] returns the stored URL unchanged.
class CloudinaryImage {
  const CloudinaryImage({
    required this.publicId,
    this.secureUrl = '',
    this.resourceType = 'image',
    this.format = '',
    this.width = 0,
    this.height = 0,
    this.isPrimary = false,
    this.sortOrder = 0,
    this.createdAt,
  });

  /// Cloudinary public id, e.g.
  /// `padma_collections/products/PC-NK-001/necklace`.
  final String publicId;

  /// The stored original's HTTPS URL. Used verbatim when [publicId] is empty.
  final String secureUrl;

  /// Cloudinary resource type — always `image` for this app.
  final String resourceType;

  /// Stored format (`jpg`, `png`, `webp`). Empty when unknown.
  final String format;

  /// Intrinsic dimensions of the stored original, for layout hints.
  final int width;
  final int height;

  final bool isPrimary;
  final int sortOrder;
  final DateTime? createdAt;

  /// True when this is a plain URL with no Cloudinary asset behind it.
  ///
  /// Such an image cannot be re-transformed or deleted through Cloudinary, so
  /// the admin UI must not offer those actions for it.
  bool get isExternal => publicId.isEmpty;

  /// True when the image actually renders something.
  bool get hasImage => publicId.isNotEmpty || secureUrl.isNotEmpty;

  /// The delivery URL for [transform].
  ///
  /// With a public id the URL is always rebuilt, so switching size is free and
  /// never requires another network round trip. Without one, the stored URL is
  /// returned as-is.
  String urlFor(CloudinaryTransform transform, {String? cloudName}) {
    if (isExternal) return secureUrl;

    // Falls back to the app-wide cloud name set from `settings/app`, so callers
    // that do not care about the account can just ask for a transformation.
    final String cloud = (cloudName != null && cloudName.isNotEmpty)
        ? cloudName
        : CloudinaryDelivery.cloudName;

    // No cloud name anywhere (settings have not loaded yet): the stored
    // original is still a valid URL and far better than showing a placeholder.
    if (cloud.isEmpty) return secureUrl;

    return CloudinaryDelivery.build(
      publicId,
      transform,
      format: format,
      cloudName: cloud,
    );
  }

  /// Parses one entry of a Firestore `images` array.
  ///
  /// [index] is used to derive `sortOrder` when the stored value has none, so
  /// an unordered array still renders in a stable, meaningful order.
  factory CloudinaryImage.fromEntry(Object? entry, {int index = 0}) {
    // Legacy: the whole entry is a URL string.
    if (entry is String) {
      return CloudinaryImage(
        publicId: '',
        secureUrl: entry,
        // The first legacy entry is the primary image, matching how the old
        // `primaryImage => images.first` getter behaved.
        isPrimary: index == 0,
        sortOrder: index,
      );
    }

    if (entry is Map) {
      final Map<String, dynamic> map = entry.map(
        (Object? key, Object? value) =>
            MapEntry<String, dynamic>(key.toString(), value),
      );
      return CloudinaryImage.fromMap(map, index: index);
    }

    return CloudinaryImage(publicId: '', sortOrder: index);
  }

  factory CloudinaryImage.fromMap(Map<String, dynamic> map, {int index = 0}) {
    return CloudinaryImage(
      publicId: FirestoreMap.str(map, 'publicId'),
      secureUrl: FirestoreMap.str(map, 'secureUrl'),
      resourceType: FirestoreMap.str(map, 'resourceType', 'image'),
      format: FirestoreMap.str(map, 'format'),
      width: FirestoreMap.int2(map, 'width'),
      height: FirestoreMap.int2(map, 'height'),
      isPrimary: FirestoreMap.boolean(map, 'isPrimary', index == 0),
      sortOrder: FirestoreMap.int2(map, 'sortOrder', index),
      createdAt: FirestoreMap.dateTime(map, 'createdAt'),
    );
  }

  CloudinaryImage copyWith({
    String? publicId,
    String? secureUrl,
    String? resourceType,
    String? format,
    int? width,
    int? height,
    bool? isPrimary,
    int? sortOrder,
    DateTime? createdAt,
  }) {
    return CloudinaryImage(
      publicId: publicId ?? this.publicId,
      secureUrl: secureUrl ?? this.secureUrl,
      resourceType: resourceType ?? this.resourceType,
      format: format ?? this.format,
      width: width ?? this.width,
      height: height ?? this.height,
      isPrimary: isPrimary ?? this.isPrimary,
      sortOrder: sortOrder ?? this.sortOrder,
      createdAt: createdAt ?? this.createdAt,
    );
  }

  Map<String, dynamic> toMap() {
    return FirestoreMap.clean(<String, dynamic>{
      'publicId': publicId,
      'secureUrl': secureUrl,
      'resourceType': resourceType,
      'format': format,
      'width': width,
      'height': height,
      'isPrimary': isPrimary,
      'sortOrder': sortOrder,
      'createdAt': createdAt,
    });
  }

  /// Parses a whole `images` array, tolerating legacy string entries.
  static List<CloudinaryImage> listFrom(Object? value) {
    if (value is! List) return const <CloudinaryImage>[];
    final List<CloudinaryImage> images = value
        .asMap()
        .entries
        .map(
          (MapEntry<int, Object?> e) =>
              CloudinaryImage.fromEntry(e.value, index: e.key),
        )
        .where((CloudinaryImage image) => image.hasImage)
        .toList();
    return normalised(images);
  }

  /// Sorts by `sortOrder` and guarantees exactly one primary image.
  ///
  /// A product with no primary would break every card and gallery, so the
  /// first image is promoted rather than leaving the document ambiguous. The
  /// returned list is also renumbered from zero, so `sortOrder` always matches
  /// list position.
  static List<CloudinaryImage> normalised(List<CloudinaryImage> images) {
    final List<CloudinaryImage> sorted = List<CloudinaryImage>.of(images)
      ..sort(
        (CloudinaryImage a, CloudinaryImage b) =>
            a.sortOrder.compareTo(b.sortOrder),
      );

    final List<CloudinaryImage> result = <CloudinaryImage>[];
    for (int i = 0; i < sorted.length; i++) {
      result.add(sorted[i].copyWith(sortOrder: i));
    }

    if (result.isEmpty) return result;

    final int primary = result.indexWhere(
      (CloudinaryImage image) => image.isPrimary,
    );
    // No primary anywhere: promote the first so a card always has something.
    final int primaryIndex = primary < 0 ? 0 : primary;
    return <CloudinaryImage>[
      for (int i = 0; i < result.length; i++)
        result[i].copyWith(isPrimary: i == primaryIndex),
    ];
  }

  /// Moves the image at [from] to [to], keeping `sortOrder` contiguous.
  static List<CloudinaryImage> reordered(
    List<CloudinaryImage> images,
    int from,
    int to,
  ) {
    if (from < 0 || from >= images.length) return images;
    final List<CloudinaryImage> next = List<CloudinaryImage>.of(images);
    final CloudinaryImage moved = next.removeAt(from);
    next.insert(to.clamp(0, next.length), moved);

    // Renumber to the new positions *before* normalising. Otherwise normalised
    // would sort back by the stale `sortOrder` values and silently undo the
    // move — the admin would drag a photo and nothing would happen.
    final List<CloudinaryImage> renumbered = <CloudinaryImage>[
      for (int i = 0; i < next.length; i++) next[i].copyWith(sortOrder: i),
    ];
    return normalised(renumbered);
  }

  /// Promotes the image at [index] to primary, demoting the previous one.
  static List<CloudinaryImage> withPrimary(
    List<CloudinaryImage> images,
    int index,
  ) {
    if (index < 0 || index >= images.length) return images;
    return normalised(<CloudinaryImage>[
      for (int i = 0; i < images.length; i++)
        images[i].copyWith(isPrimary: i == index),
    ]);
  }

  @override
  String toString() => 'CloudinaryImage($publicId, primary: $isPrimary)';

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      (other is CloudinaryImage &&
          other.publicId == publicId &&
          other.secureUrl == secureUrl &&
          other.isPrimary == isPrimary &&
          other.sortOrder == sortOrder);

  @override
  int get hashCode => Object.hash(publicId, secureUrl, isPrimary, sortOrder);
}
