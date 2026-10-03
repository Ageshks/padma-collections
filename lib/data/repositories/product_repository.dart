import 'dart:async';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:get/get.dart';
import 'package:image_picker/image_picker.dart';

import '../../core/constants/app_constants.dart';
import '../../core/services/cloudinary_image_service.dart';
import '../models/models.dart';
import 'base_repository.dart';

/// Reads and writes jewellery products.
///
/// The repository is the **only** place that talks to Firestore for products —
/// UI code never issues a query directly, which keeps indexing requirements
/// visible in one place.
class ProductRepository extends BaseRepository {
  ProductRepository({super.firestore});

  CollectionReference<Map<String, dynamic>> get _collection =>
      firestore.collection(AppConstants.productsCollection);

  /// Live, mutable demo catalogue shared across repository instances.

  // ---------------------------------------------------------------------------
  // Reads
  // ---------------------------------------------------------------------------

  /// Streams active products for the customer catalogue.
  Stream<List<ProductModel>> watchActiveProducts({String? categoryId}) {
    Query<Map<String, dynamic>> query = _collection.where(
      'isActive',
      isEqualTo: true,
    );

    if (categoryId != null && categoryId.isNotEmpty) {
      query = query.where('categoryId', isEqualTo: categoryId);
    }

    return query.snapshots().map(_mapList);
  }

  /// Streams every product including deactivated ones (admin only).
  Stream<List<ProductModel>> watchAllProducts() {
    return _collection.snapshots().map(_mapList);
  }

  /// Streams the subset flagged as featured.
  Stream<List<ProductModel>> watchFeatured({int limit = 10}) {
    return _collection
        .where('isActive', isEqualTo: true)
        .where('isFeatured', isEqualTo: true)
        .limit(limit)
        .snapshots()
        .map(_mapList);
  }

  /// Streams the subset flagged as fast moving.
  Stream<List<ProductModel>> watchFastMoving({int limit = 10}) {
    return _collection
        .where('isActive', isEqualTo: true)
        .where('isFastMoving', isEqualTo: true)
        .limit(limit)
        .snapshots()
        .map(_mapList);
  }

  /// Streams new arrivals, newest first.
  ///
  /// Combines the admin's explicit `isNewArrival` flag with an optional
  /// automatic window, so freshly added products surface without extra work.
  Stream<List<ProductModel>> watchNewArrivals({int limit = 20}) {
    return _collection
        .where('isActive', isEqualTo: true)
        .snapshots()
        .map(
          (QuerySnapshot<Map<String, dynamic>> snap) =>
              applyNewArrivalWindow(_mapList(snap), limit),
        );
  }

  /// Most-sold products, used for the "Popular" rail.
  Stream<List<ProductModel>> watchPopular({int limit = 10}) {
    return _collection
        .where('isActive', isEqualTo: true)
        .orderBy('soldCount', descending: true)
        .limit(limit)
        .snapshots()
        .map(_mapList);
  }

  /// Recent products for the "Recently Added" section.
  Stream<List<ProductModel>> watchRecentlyAdded({int limit = 10}) {
    return _collection
        .where('isActive', isEqualTo: true)
        .orderBy('createdAt', descending: true)
        .limit(limit)
        .snapshots()
        .map(_mapList);
  }

  /// Fetches a single product, or null when it no longer exists.
  Future<ProductModel?> getById(String productId) async {
    final DocumentSnapshot<Map<String, dynamic>> doc = await _collection
        .doc(productId)
        .get();
    if (!doc.exists) return null;
    return ProductModel.fromMap(
      FirestoreMap.fromDocument(doc),
      productId: doc.id,
    );
  }

  /// Streams a specific set of products (wishlist and cart hydration).
  Stream<List<ProductModel>> watchByIds(List<String> ids) {
    if (ids.isEmpty) {
      return Stream<List<ProductModel>>.value(const <ProductModel>[]);
    }
    return _collection
        .where('productId', whereIn: ids)
        .snapshots()
        .map(_mapList);
  }

  /// Products in a category, for the category detail screen.
  Stream<List<ProductModel>> watchByCategory(
    String categoryId, {
    int limit = 50,
  }) {
    return watchActiveProducts(
      categoryId: categoryId,
    ).map((List<ProductModel> list) => list.take(limit).toList());
  }

  /// Best sellers ranked by units actually ordered.
  ///
  /// Drives the optional automatic fast-moving detection in the admin UI.
  Future<List<ProductModel>> topSellers({int limit = 10}) async {
    final List<ProductModel> source = await watchAllProducts().first;
    final List<ProductModel> sorted =
        source.where((ProductModel p) => p.isActive && p.soldCount > 0).toList()
          ..sort(
            (ProductModel a, ProductModel b) =>
                b.soldCount.compareTo(a.soldCount),
          );
    return sorted.take(limit).toList();
  }

  // ---------------------------------------------------------------------------
  // Search, filtering and sorting
  // ---------------------------------------------------------------------------

  /// Applies a query, filters and sort order to an in-memory product list.
  ///
  /// Filtering happens client-side so the customer gets instant results and
  /// so every filter dimension (category, price, badges) can be combined.
  static List<ProductModel> search({
    required List<ProductModel> products,
    String query = '',
    List<String> categoryIds = const <String>[],
    double? minPrice,
    double? maxPrice,
    bool newArrivalsOnly = false,
    bool fastMovingOnly = false,
    bool featuredOnly = false,
    bool inStockOnly = false,
    ProductSortOption sort = ProductSortOption.newest,
    int newArrivalDays = 30,
    bool autoNewArrivals = true,
  }) {
    final DateTime cutoff = DateTime.now().subtract(
      Duration(days: newArrivalDays),
    );
    final String q = query.trim().toLowerCase();

    final List<ProductModel> results = products.where((ProductModel p) {
      if (!p.isActive) return false;
      if (q.isNotEmpty && !p.matchesQuery(q)) return false;

      if (categoryIds.isNotEmpty && !categoryIds.contains(p.categoryId)) {
        return false;
      }
      if (minPrice != null && p.price < minPrice) return false;
      if (maxPrice != null && p.price > maxPrice) return false;

      final bool isRecent = p.createdAt.isAfter(cutoff);
      final bool countsAsNew = p.isNewArrival || (autoNewArrivals && isRecent);
      if (newArrivalsOnly && !countsAsNew) return false;
      if (fastMovingOnly && !p.isFastMoving) return false;
      if (featuredOnly && !p.isFeatured) return false;
      if (inStockOnly && !p.inStock) return false;

      return true;
    }).toList();

    return sortProducts(results, sort);
  }

  /// Sorts a list in place-safe fashion, returning a new list.
  static List<ProductModel> sortProducts(
    List<ProductModel> products,
    ProductSortOption sort,
  ) {
    final List<ProductModel> sorted = List<ProductModel>.of(products);
    switch (sort) {
      case ProductSortOption.newest:
        sorted.sort(
          (ProductModel a, ProductModel b) =>
              b.createdAt.compareTo(a.createdAt),
        );
      case ProductSortOption.priceLowToHigh:
        sorted.sort(
          (ProductModel a, ProductModel b) => a.price.compareTo(b.price),
        );
      case ProductSortOption.priceHighToLow:
        sorted.sort(
          (ProductModel a, ProductModel b) => b.price.compareTo(a.price),
        );
      case ProductSortOption.popular:
        sorted.sort((ProductModel a, ProductModel b) {
          final int bySales = b.soldCount.compareTo(a.soldCount);
          if (bySales != 0) return bySales;
          return b.views.compareTo(a.views);
        });
    }
    return sorted;
  }

  /// Filters a list down to new arrivals, newest first.
  static List<ProductModel> applyNewArrivalWindow(
    List<ProductModel> products,
    int limit,
  ) {
    final DateTime cutoff = DateTime.now().subtract(
      Duration(days: AppConstants.defaultNewArrivalDays),
    );
    final List<ProductModel> list =
        products
            .where(
              (ProductModel p) => p.isNewArrival || p.createdAt.isAfter(cutoff),
            )
            .toList()
          ..sort(
            (ProductModel a, ProductModel b) =>
                b.createdAt.compareTo(a.createdAt),
          );
    return list.take(limit).toList();
  }
  // ---------------------------------------------------------------------------
  // Writes (admin)
  // ---------------------------------------------------------------------------

  /// Creates a product and returns its generated id.
  Future<String> create(ProductModel product) async {
    final ProductModel normalised = product.normalised();
    final DocumentReference<Map<String, dynamic>> ref = _collection.doc();
    final Map<String, dynamic> data = normalised.toMap()
      ..['productId'] = ref.id;
    await ref.set(data);
    return ref.id;
  }

  /// Updates an existing product.
  Future<void> update(String productId, ProductModel product) async {
    final ProductModel normalised = product.normalised();
    final Map<String, dynamic> data = normalised.toMap()
      ..['productId'] = productId
      ..['updatedAt'] = DateTime.now();
    await _collection.doc(productId).update(data);
  }

  /// Permanently removes a product.
  Future<void> delete(String productId) async {
    await _collection.doc(productId).delete();
  }

  // ---------------------------------------------------------------------------
  // Images (Cloudinary + Firestore metadata)
  //
  // These coordinate the two systems: the bytes live in Cloudinary, the
  // metadata lives in Firestore. Ordering matters everywhere — see the notes on
  // each method.
  // ---------------------------------------------------------------------------

  /// Uploads photos for a product and returns the new image metadata.
  ///
  /// Nothing is written to Firestore here: the caller decides when to persist,
  /// which is what guarantees a product is never saved referencing an image
  /// that failed to upload.
  Future<ImageUploadResult> uploadProductImages(
    String productId,
    List<XFile> files, {
    void Function(ImageUploadProgress progress)? onProgress,
  }) async {
    return _images.uploadImages(
      files,
      type: CloudinaryImageService.typeProducts,
      // Photos land under padma_collections/products/{productId}/, which is
      // what makes bulk cleanup a prefix delete rather than a list walk.
      entityId: productId,
      onProgress: onProgress,
    );
  }

  /// Persists an updated image list for a product.
  ///
  /// The list is normalised first, so the stored document always has exactly
  /// one primary image and contiguous `sortOrder` values.
  Future<void> saveProductImages(
    String productId,
    List<CloudinaryImage> images,
  ) async {
    await _collection.doc(productId).update(<String, dynamic>{
      'images': <Map<String, dynamic>>[
        for (final CloudinaryImage image in CloudinaryImage.normalised(images))
          image.toMap(),
      ],
      'updatedAt': DateTime.now(),
    });
  }

  /// Reorders a product's images.
  ///
  /// [from] and [to] are positions in the current list.
  Future<void> reorderProductImages(String productId, int from, int to) async {
    final List<CloudinaryImage> images = await _currentImages(productId);
    if (images.isEmpty) return;
    await saveProductImages(
      productId,
      CloudinaryImage.reordered(images, from, to),
    );
  }

  /// Promotes one of a product's images to primary.
  Future<void> setPrimaryImage(String productId, int index) async {
    final List<CloudinaryImage> images = await _currentImages(productId);
    if (images.isEmpty) return;
    await saveProductImages(
      productId,
      CloudinaryImage.withPrimary(images, index),
    );
  }

  /// Removes one image from a product.
  ///
  /// Removes an image from a product.
  ///
  /// Only the Firestore metadata is removed — see the note on
  /// [deleteProductWithImages] for why the Cloudinary asset is not deleted.
  ///
  /// An external image (legacy bare URL) has no Cloudinary asset at all.
  Future<void> deleteProductImage(
    String productId,
    CloudinaryImage image,
  ) async {
    if (!image.isExternal) {
      await _images.deleteImage(image.publicId);
    }

    final List<CloudinaryImage> images = await _currentImages(productId);
    if (images.isEmpty) return;

    await saveProductImages(productId, <CloudinaryImage>[
      for (final CloudinaryImage existing in images)
        if (existing.publicId != image.publicId ||
            existing.secureUrl != image.secureUrl)
          existing,
    ]);
  }

  /// Replaces an image on a product.
  ///
  /// [replacement] must already be uploaded. The swap is upload → persist →
  /// delete old, so an interrupted replacement can never lose the product's
  /// picture.
  Future<void> replaceProductImage(
    String productId,
    CloudinaryImage existing,
    CloudinaryImage replacement,
  ) async {
    final List<CloudinaryImage> images = await _currentImages(productId);
    if (images.isEmpty) return;

    // Keep the position and primary flag of the image being replaced, so a
    // swap does not silently reorder the gallery.
    await saveProductImages(productId, <CloudinaryImage>[
      for (final CloudinaryImage image in images)
        if (image.publicId == existing.publicId &&
            image.secureUrl == existing.secureUrl)
          replacement.copyWith(
            isPrimary: image.isPrimary,
            sortOrder: image.sortOrder,
          )
        else
          image,
    ]);

    // Only now is the old asset unreferenced and safe to release.
    if (!existing.isExternal) await _images.deleteImage(existing.publicId);
  }

  /// Deletes every Cloudinary image belonging to a product.
  ///
  /// One Cloudinary call, because products are scoped to their own folder.
  Future<int> deleteProductImages(String productId) =>
      _images.deleteProductImages(productId);

  /// Deletes a product and all of its Cloudinary images.
  ///
  /// Only the Firestore document is deleted. The underlying Cloudinary assets
  /// are **not** removed, because unsigned uploads cannot delete: Cloudinary's
  /// `destroy` endpoint always requires the API secret.
  ///
  /// That leaves the assets orphaned in the Media Library, still costing
  /// storage. They are easy to identify, though — every upload is tagged
  /// `padma,products` and each product owns its own folder, so a manual sweep
  /// can find them by folder. See `docs/cloudinary-images.md` for the cleanup
  /// routine and for how to reinstate real deletes by upgrading to Blaze.
  Future<void> deleteProductWithImages(String productId) async {
    await delete(productId);
  }

  /// Reads a product's current images, or an empty list when it is gone.
  Future<List<CloudinaryImage>> _currentImages(String productId) async {
    final DocumentSnapshot<Map<String, dynamic>> doc = await _collection
        .doc(productId)
        .get();
    if (!doc.exists) return const <CloudinaryImage>[];
    return ProductModel.fromMap(
      FirestoreMap.fromDocument(doc),
      productId: productId,
    ).images;
  }

  /// The Cloudinary service used for uploads and deletions.
  CloudinaryImageService get _images {
    if (!Get.isRegistered<CloudinaryImageService>()) {
      throw StateError('Image service is not available.');
    }
    return Get.find<CloudinaryImageService>();
  }

  /// Shows or hides a product in the storefront without deleting it.
  Future<void> setActive(String productId, bool isActive) =>
      _setFlag(productId, 'isActive', isActive);

  /// Flags or unflags a product as a new arrival.
  Future<void> setNewArrival(String productId, bool isNewArrival) =>
      _setFlag(productId, 'isNewArrival', isNewArrival);

  /// Flags or unflags a product as fast moving.
  Future<void> setFastMoving(String productId, bool isFastMoving) =>
      _setFlag(productId, 'isFastMoving', isFastMoving);

  /// Flags or unflags a product as featured.
  Future<void> setFeatured(String productId, bool isFeatured) =>
      _setFlag(productId, 'isFeatured', isFeatured);

  /// Marks a product in or out of stock.
  Future<void> setStock(String productId, int stock) {
    return _collection.doc(productId).update(<String, dynamic>{
      'stock': stock,
      'updatedAt': DateTime.now(),
    });
  }

  /// Increments the view counter for a product detail page.
  Future<void> incrementViews(String productId) async {
    await _collection.doc(productId).update(<String, dynamic>{
      'views': FieldValue.increment(1),
    });
  }

  /// Applies the automatic fast-moving rule to the top N best sellers.
  ///
  /// Only ever called when the admin explicitly enables automatic detection.
  Future<int> applyAutoFastMoving({int limit = 10}) async {
    final List<ProductModel> top = await topSellers(limit: limit);
    final WriteBatch batch = firestore.batch();
    for (final ProductModel p in top) {
      batch.update(_collection.doc(p.productId), <String, dynamic>{
        'isFastMoving': true,
        'updatedAt': DateTime.now(),
      });
    }
    await batch.commit();
    return top.length;
  }

  Future<void> _setFlag(String productId, String field, bool value) async {
    await _collection.doc(productId).update(<String, dynamic>{
      field: value,
      'updatedAt': DateTime.now(),
    });
  }

  /// Maps a Firestore snapshot to models.
  List<ProductModel> _mapList(QuerySnapshot<Map<String, dynamic>> snap) {
    return snap.docs
        .map(
          (QueryDocumentSnapshot<Map<String, dynamic>> d) =>
              ProductModel.fromMap(
                FirestoreMap.fromDocument(d),
                productId: d.id,
              ),
        )
        .toList();
  }
}
