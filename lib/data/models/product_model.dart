import '../../core/constants/cloudinary_config.dart';
import '../../core/utils/app_formatter.dart';
import 'cloudinary_image.dart';
import 'firestore_map.dart';

/// A jewellery product. Stored at `products/{productId}`.
class ProductModel {
  const ProductModel({
    required this.productId,
    required this.name,
    this.description = '',
    this.categoryId = '',
    this.categoryName = '',
    this.images = const <CloudinaryImage>[],
    this.price = 0,
    this.compareAtPrice = 0,
    this.discountPercentage = 0,
    this.stock = 0,
    this.sku = '',
    this.material = '',
    this.color = '',
    this.size = '',
    this.weight = '',
    this.isAvailable = true,
    this.isFeatured = false,
    this.isFastMoving = false,
    this.isNewArrival = false,
    this.isActive = true,
    this.views = 0,
    this.soldCount = 0,
    required this.createdAt,
    this.updatedAt,
  });

  final String productId;
  final String name;
  final String description;
  final String categoryId;
  final String categoryName;

  /// Cloudinary metadata, ordered by `sortOrder`. Exactly one entry is
  /// flagged primary; the rest are additional angles of the same piece.
  ///
  /// Only ids and URLs are stored — never image bytes.
  final List<CloudinaryImage> images;

  final double price;

  /// "Was" price. 0 means there is no discount to display.
  final double compareAtPrice;
  final int discountPercentage;
  final int stock;
  final String sku;
  final String material;
  final String color;

  /// Free-text size/dimension, e.g. "2.5 inch" or "Free size".
  final String size;
  final String weight;

  /// In-stock flag. Kept separate from [isActive] (which is an admin
  /// visibility switch) so a sold-out item can stay visible.
  final bool isAvailable;
  final bool isFeatured;
  final bool isFastMoving;
  final bool isNewArrival;

  /// Admin visibility switch — deactivated products vanish from the store.
  final bool isActive;

  final int views;
  final int soldCount;
  final DateTime createdAt;
  final DateTime? updatedAt;

  /// The image flagged `isPrimary`, or null when the product has none.
  CloudinaryImage? get primaryImageRef => images.isEmpty
      ? null
      : images.firstWhere(
          (CloudinaryImage image) => image.isPrimary,
          // normalised() guarantees a primary exists, but a hand-edited
          // document might not have one; falling back keeps the UI rendering.
          orElse: () => images.first,
        );

  /// Primary image URL at [variant] — `product_card` unless stated otherwise.
  ///
  /// This is what every card, cart row and wishlist row should ask for: it
  /// never downloads the full-size original.
  String primaryImage({
    CloudinaryTransform variant = CloudinaryTransform.productCard,
    String? cloudName,
  }) => primaryImageRef?.urlFor(variant, cloudName: cloudName) ?? '';

  /// Delivery URLs for the whole gallery at [variant].
  ///
  /// Used by the product detail page, which is the only place the larger
  /// `product_detail` transformation is worth the bandwidth.
  List<String> imageUrls({
    CloudinaryTransform variant = CloudinaryTransform.productDetail,
    String? cloudName,
  }) => <String>[
    for (final CloudinaryImage image in images)
      image.urlFor(variant, cloudName: cloudName),
  ];

  bool get hasImages => images.isNotEmpty;

  /// Cloudinary public ids only — what image deletion operates on.
  ///
  /// External images (legacy bare URLs) have no public id, so they are skipped:
  /// there is nothing in Cloudinary to delete for them.
  List<String> get imageIds => <String>[
    for (final CloudinaryImage image in images)
      if (image.publicId.isNotEmpty) image.publicId,
  ];

  bool get hasDiscount => compareAtPrice > price && compareAtPrice > 0;

  bool get inStock => stock > 0;

  /// Effective availability: visible, in stock, and not out of stock.
  bool get isPurchasable => isActive && isAvailable && stock > 0;

  /// Badge text for the card corner, e.g. "45% OFF" or "OUT OF STOCK".
  String get badgeLabel {
    if (hasDiscount) {
      return AppFormatter.discountLabel(price, compareAtPrice);
    }
    if (!isAvailable || stock == 0) return 'Out of Stock';
    return '';
  }

  /// Recomputes [discountPercentage] and clamps the compare-at price.
  ///
  /// Prices are manually defined by the admin; these derivations keep the
  /// displayed discount consistent without a second source of truth.
  ///
  /// Images are normalised too — a document is never written with two primary
  /// images or a gap in `sortOrder`, because the gallery and every card depend
  /// on that ordering being unambiguous.
  ProductModel normalised() {
    final double priceSafe = price < 0 ? 0 : price;
    final double compareSafe = compareAtPrice > priceSafe ? compareAtPrice : 0;
    return copyWith(
      price: priceSafe,
      compareAtPrice: compareSafe,
      discountPercentage: AppFormatter.discountPercent(priceSafe, compareSafe),
      images: CloudinaryImage.normalised(images),
    );
  }

  ProductModel copyWith({
    String? name,
    String? description,
    String? categoryId,
    String? categoryName,
    List<CloudinaryImage>? images,
    double? price,
    double? compareAtPrice,
    int? discountPercentage,
    int? stock,
    String? sku,
    String? material,
    String? color,
    String? size,
    String? weight,
    bool? isAvailable,
    bool? isFeatured,
    bool? isFastMoving,
    bool? isNewArrival,
    bool? isActive,
    int? views,
    int? soldCount,
    DateTime? updatedAt,
  }) {
    return ProductModel(
      productId: productId,
      name: name ?? this.name,
      description: description ?? this.description,
      categoryId: categoryId ?? this.categoryId,
      categoryName: categoryName ?? this.categoryName,
      images: images ?? this.images,
      price: price ?? this.price,
      compareAtPrice: compareAtPrice ?? this.compareAtPrice,
      discountPercentage: discountPercentage ?? this.discountPercentage,
      stock: stock ?? this.stock,
      sku: sku ?? this.sku,
      material: material ?? this.material,
      color: color ?? this.color,
      size: size ?? this.size,
      weight: weight ?? this.weight,
      isAvailable: isAvailable ?? this.isAvailable,
      isFeatured: isFeatured ?? this.isFeatured,
      isFastMoving: isFastMoving ?? this.isFastMoving,
      isNewArrival: isNewArrival ?? this.isNewArrival,
      isActive: isActive ?? this.isActive,
      views: views ?? this.views,
      soldCount: soldCount ?? this.soldCount,
      createdAt: createdAt,
      updatedAt: updatedAt ?? this.updatedAt,
    );
  }

  factory ProductModel.fromMap(Map<String, dynamic> map, {String? productId}) {
    final double price = FirestoreMap.num2(map, 'price');
    final double compareAt = FirestoreMap.num2(map, 'compareAtPrice');
    // Trust the stored percentage only when it is still consistent.
    final int storedPct = FirestoreMap.int2(map, 'discountPercentage');
    final int derivedPct = AppFormatter.discountPercent(price, compareAt);

    return ProductModel(
      productId: FirestoreMap.str(map, 'productId', productId ?? ''),
      name: FirestoreMap.str(map, 'name'),
      description: FirestoreMap.str(map, 'description'),
      categoryId: FirestoreMap.str(map, 'categoryId'),
      categoryName: FirestoreMap.str(map, 'categoryName'),
      images: CloudinaryImage.listFrom(map['images']),
      price: price,
      compareAtPrice: compareAt > price ? compareAt : 0,
      discountPercentage: derivedPct > 0 ? derivedPct : storedPct,
      stock: FirestoreMap.int2(map, 'stock'),
      sku: FirestoreMap.str(map, 'sku'),
      material: FirestoreMap.str(map, 'material'),
      color: FirestoreMap.str(map, 'color'),
      size: FirestoreMap.str(map, 'size'),
      weight: FirestoreMap.str(map, 'weight'),
      isAvailable: FirestoreMap.boolean(map, 'isAvailable', true),
      isFeatured: FirestoreMap.boolean(map, 'isFeatured'),
      isFastMoving: FirestoreMap.boolean(map, 'isFastMoving'),
      isNewArrival: FirestoreMap.boolean(map, 'isNewArrival'),
      isActive: FirestoreMap.boolean(map, 'isActive', true),
      views: FirestoreMap.int2(map, 'views'),
      soldCount: FirestoreMap.int2(map, 'soldCount'),
      createdAt: FirestoreMap.dateTime(map, 'createdAt') ?? DateTime.now(),
      updatedAt: FirestoreMap.dateTime(map, 'updatedAt'),
    );
  }

  Map<String, dynamic> toMap() {
    return FirestoreMap.clean(<String, dynamic>{
      'productId': productId,
      'name': name,
      'description': description,
      'categoryId': categoryId,
      'categoryName': categoryName,
      'images': <Map<String, dynamic>>[
        for (final CloudinaryImage image in images) image.toMap(),
      ],
      'price': price,
      'compareAtPrice': compareAtPrice,
      'discountPercentage': discountPercentage,
      'stock': stock,
      'sku': sku,
      'material': material,
      'color': color,
      'size': size,
      'weight': weight,
      'isAvailable': isAvailable,
      'isFeatured': isFeatured,
      'isFastMoving': isFastMoving,
      'isNewArrival': isNewArrival,
      'isActive': isActive,
      'views': views,
      'soldCount': soldCount,
      'createdAt': createdAt,
      'updatedAt': updatedAt ?? DateTime.now(),
    });
  }

  /// Matches a free-text query against name, SKU and category.
  bool matchesQuery(String query) {
    final String q = StringUtils.normalise(query);
    if (q.isEmpty) return true;
    return StringUtils.normalise(name).contains(q) ||
        StringUtils.normalise(sku).contains(q) ||
        StringUtils.normalise(categoryName).contains(q) ||
        StringUtils.normalise(material).contains(q) ||
        StringUtils.normalise(description).contains(q);
  }

  @override
  String toString() => 'ProductModel($productId, $name)';

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      (other is ProductModel && other.productId == productId);

  @override
  int get hashCode => productId.hashCode;
}
