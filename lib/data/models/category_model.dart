import '../../core/constants/cloudinary_config.dart';
import 'cloudinary_image.dart';
import 'firestore_map.dart';

/// A jewellery category. Stored at `categories/{categoryId}`.
class CategoryModel {
  const CategoryModel({
    required this.categoryId,
    required this.name,
    this.description = '',
    this.image,
    this.icon = '',
    this.isActive = true,
    this.sortOrder = 0,
    this.productCount = 0,
    required this.createdAt,
    this.updatedAt,
  });

  final String categoryId;
  final String name;
  final String description;

  /// Cloudinary metadata for the category photo, or null when the
  /// category uses its Material [icon] instead.
  final CloudinaryImage? image;

  /// Optional Material icon key, used when no image has been uploaded.
  final String icon;
  final bool isActive;

  /// Lower numbers appear first on the categories screen.
  final int sortOrder;

  /// Denormalised count so the category grid avoids N+1 reads.
  final int productCount;

  final DateTime createdAt;
  final DateTime? updatedAt;

  bool get hasImage => image?.hasImage ?? false;

  /// Delivery URL for the category photo at [variant].
  ///
  /// Defaults to the `category` variant — a category tile never needs more.
  String imageUrl({
    CloudinaryTransform variant = CloudinaryTransform.category,
    String? cloudName,
  }) => image?.urlFor(variant, cloudName: cloudName) ?? '';

  CategoryModel copyWith({
    String? name,
    String? description,
    CloudinaryImage? image,
    String? icon,
    bool? isActive,
    int? sortOrder,
    int? productCount,
    DateTime? updatedAt,
  }) {
    return CategoryModel(
      categoryId: categoryId,
      name: name ?? this.name,
      description: description ?? this.description,
      image: image ?? this.image,
      icon: icon ?? this.icon,
      isActive: isActive ?? this.isActive,
      sortOrder: sortOrder ?? this.sortOrder,
      productCount: productCount ?? this.productCount,
      createdAt: createdAt,
      updatedAt: updatedAt ?? this.updatedAt,
    );
  }

  factory CategoryModel.fromMap(
    Map<String, dynamic> map, {
    String? categoryId,
  }) {
    return CategoryModel(
      categoryId: FirestoreMap.str(map, 'categoryId', categoryId ?? ''),
      name: FirestoreMap.str(map, 'name'),
      description: FirestoreMap.str(map, 'description'),
      // Tolerates both the nested metadata object and a bare legacy URL.
      image: _imageFrom(map['image']),
      icon: FirestoreMap.str(map, 'icon'),
      isActive: FirestoreMap.boolean(map, 'isActive', true),
      sortOrder: FirestoreMap.int2(map, 'sortOrder'),
      productCount: FirestoreMap.int2(map, 'productCount'),
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

  Map<String, dynamic> toMap() {
    return FirestoreMap.clean(<String, dynamic>{
      'categoryId': categoryId,
      'name': name,
      'description': description,
      'image': image?.toMap(),
      'icon': icon,
      'isActive': isActive,
      'sortOrder': sortOrder,
      'productCount': productCount,
      'createdAt': createdAt,
      'updatedAt': updatedAt ?? DateTime.now(),
    });
  }

  @override
  String toString() => 'CategoryModel($categoryId, $name)';

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      (other is CategoryModel && other.categoryId == categoryId);

  @override
  int get hashCode => categoryId.hashCode;
}
