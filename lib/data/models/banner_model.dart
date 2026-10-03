import '../../core/constants/cloudinary_config.dart';
import 'cloudinary_image.dart';
import 'firestore_map.dart';

/// What a home banner's CTA should do when tapped.
enum BannerAction {
  /// Open the product listing, optionally pre-filtered to a category.
  openCategory,

  /// Open a single product's details page.
  openProduct,

  /// Open the product listing sorted as New Arrivals.
  openNewArrivals,

  /// Just scroll the home page to the given section.
  scrollToSection,

  /// Open WhatsApp with the banner's own message.
  openWhatsapp,
}

/// A promotional banner on the home screen. Stored at `banners/{bannerId}`.
class BannerModel {
  const BannerModel({
    required this.bannerId,
    required this.title,
    this.subtitle = '',
    this.image,
    this.buttonText = 'Shop Now',
    this.action = BannerAction.openCategory,
    this.actionValue = '',
    this.isActive = true,
    this.sortOrder = 0,
    required this.createdAt,
    this.updatedAt,
  });

  final String bannerId;
  final String title;
  final String subtitle;

  /// Cloudinary metadata for the banner artwork, or null to fall back
  /// to the branded gradient slide.
  final CloudinaryImage? image;

  final String buttonText;

  /// What happens on tap — [action] plus an argument in [actionValue].
  final BannerAction action;

  /// Category id, product id or section key, depending on [action].
  final String actionValue;

  final bool isActive;
  final int sortOrder;
  final DateTime createdAt;
  final DateTime? updatedAt;

  bool get hasImage => image?.hasImage ?? false;

  /// Delivery URL for the banner artwork.
  ///
  /// Always the `banner` variant (1600 × 700): the home carousel is the one
  /// place a wide, high-resolution image is actually needed.
  String imageUrl({
    CloudinaryTransform variant = CloudinaryTransform.banner,
    String? cloudName,
  }) => image?.urlFor(variant, cloudName: cloudName) ?? '';

  BannerModel copyWith({
    String? title,
    String? subtitle,
    CloudinaryImage? image,
    String? buttonText,
    BannerAction? action,
    String? actionValue,
    bool? isActive,
    int? sortOrder,
    DateTime? updatedAt,
  }) {
    return BannerModel(
      bannerId: bannerId,
      title: title ?? this.title,
      subtitle: subtitle ?? this.subtitle,
      image: image ?? this.image,
      buttonText: buttonText ?? this.buttonText,
      action: action ?? this.action,
      actionValue: actionValue ?? this.actionValue,
      isActive: isActive ?? this.isActive,
      sortOrder: sortOrder ?? this.sortOrder,
      createdAt: createdAt,
      updatedAt: updatedAt ?? this.updatedAt,
    );
  }

  factory BannerModel.fromMap(Map<String, dynamic> map, {String? bannerId}) {
    return BannerModel(
      bannerId: FirestoreMap.str(map, 'bannerId', bannerId ?? ''),
      title: FirestoreMap.str(map, 'title'),
      subtitle: FirestoreMap.str(map, 'subtitle'),
      image: _imageFrom(map['image'] ?? map['imageId']),
      buttonText: FirestoreMap.str(map, 'buttonText', 'Shop Now'),
      action: _actionFromString(FirestoreMap.str(map, 'buttonAction')),
      actionValue: FirestoreMap.str(map, 'actionValue'),
      isActive: FirestoreMap.boolean(map, 'isActive', true),
      sortOrder: FirestoreMap.int2(map, 'sortOrder'),
      createdAt: FirestoreMap.dateTime(map, 'createdAt') ?? DateTime.now(),
      updatedAt: FirestoreMap.dateTime(map, 'updatedAt'),
    );
  }

  /// Reads the `image` field, which may be a metadata map or a bare URL
  /// string written before the Cloudinary migration.
  static CloudinaryImage? _imageFrom(Object? raw) {
    if (raw == null) return null;
    if (raw is String && raw.isEmpty) return null;
    final CloudinaryImage parsed = CloudinaryImage.fromEntry(raw);
    return parsed.hasImage ? parsed : null;
  }

  /// Unrecognised or missing values fall back to the safest action.
  static BannerAction _actionFromString(String value) {
    for (final BannerAction a in BannerAction.values) {
      if (a.name == value) return a;
    }
    switch (value) {
      case 'category':
        return BannerAction.openCategory;
      case 'product':
        return BannerAction.openProduct;
      case 'whatsapp':
        return BannerAction.openWhatsapp;
      default:
        return BannerAction.openCategory;
    }
  }

  Map<String, dynamic> toMap() {
    return FirestoreMap.clean(<String, dynamic>{
      'bannerId': bannerId,
      'title': title,
      'subtitle': subtitle,
      'image': image?.toMap(),
      'buttonText': buttonText,
      'buttonAction': action.name,
      'actionValue': actionValue,
      'isActive': isActive,
      'sortOrder': sortOrder,
      'createdAt': createdAt,
      'updatedAt': updatedAt ?? DateTime.now(),
    });
  }

  @override
  String toString() => 'BannerModel($bannerId, $title)';

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      (other is BannerModel && other.bannerId == bannerId);

  @override
  int get hashCode => bannerId.hashCode;
}

/// Section keys a banner can scroll the home page to.
class HomeSection {
  HomeSection._();

  static const String newArrivals = 'newArrivals';
  static const String fastMoving = 'fastMoving';
  static const String featured = 'featured';
  static const String categories = 'categories';
}

/// Sort options used across the product listing screens.
enum ProductSortOption {
  newest('Newest'),
  priceLowToHigh('Price: Low to High'),
  priceHighToLow('Price: High to Low'),
  popular('Popular');

  const ProductSortOption(this.label);
  final String label;

  String get storageValue => name;
}
