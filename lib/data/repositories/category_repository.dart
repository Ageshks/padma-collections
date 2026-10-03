import 'dart:async';

import 'package:cloud_firestore/cloud_firestore.dart';

import '../../core/constants/app_constants.dart';
import '../models/models.dart';
import 'base_repository.dart';

/// Reads and writes jewellery categories.
class CategoryRepository extends BaseRepository {
  CategoryRepository({super.firestore});

  CollectionReference<Map<String, dynamic>> get _collection =>
      firestore.collection(AppConstants.categoriesCollection);

  /// Active categories for the customer, ordered for display.
  Stream<List<CategoryModel>> watchActiveCategories() {
    return _collection
        .where('isActive', isEqualTo: true)
        .orderBy('sortOrder')
        .snapshots()
        .map(_mapList);
  }

  /// Every category, including disabled ones (admin only).
  Stream<List<CategoryModel>> watchAllCategories() {
    return _collection.orderBy('sortOrder').snapshots().map(_mapList);
  }

  Future<CategoryModel?> getById(String categoryId) async {
    final DocumentSnapshot<Map<String, dynamic>> doc = await _collection
        .doc(categoryId)
        .get();
    if (!doc.exists) return null;
    return CategoryModel.fromMap(
      FirestoreMap.fromDocument(doc),
      categoryId: doc.id,
    );
  }

  /// Resolves category ids to display names.
  Future<Map<String, String>> namesFor(List<String> ids) async {
    final Map<String, String> result = <String, String>{};
    for (final String id in ids) {
      final CategoryModel? c = await getById(id);
      if (c != null) result[id] = c.name;
    }
    return result;
  }

  /// Creates a category and returns its id.
  Future<String> create(CategoryModel category) async {
    final DocumentReference<Map<String, dynamic>> ref = _collection.doc();
    final Map<String, dynamic> data = category.toMap()..['categoryId'] = ref.id;
    await ref.set(data);
    return ref.id;
  }

  Future<void> update(String categoryId, CategoryModel category) async {
    final Map<String, dynamic> data = category.toMap()
      ..['categoryId'] = categoryId
      ..['updatedAt'] = DateTime.now();
    await _collection.doc(categoryId).update(data);
  }

  Future<void> delete(String categoryId) async {
    await _collection.doc(categoryId).delete();
  }

  Future<void> setActive(String categoryId, bool isActive) async {
    await _collection.doc(categoryId).update(<String, dynamic>{
      'isActive': isActive,
      'updatedAt': DateTime.now(),
    });
  }

  /// Renumbers categories to match the given order.
  Future<void> reorder(List<String> orderedIds) async {
    final WriteBatch batch = firestore.batch();
    for (int i = 0; i < orderedIds.length; i++) {
      batch.update(_collection.doc(orderedIds[i]), <String, dynamic>{
        'sortOrder': i + 1,
        'updatedAt': DateTime.now(),
      });
    }
    await batch.commit();
  }

  /// Recomputes the denormalised product count on each category card.
  Future<void> refreshCounts(List<ProductModel> products) async {
    final Map<String, int> counts = <String, int>{};
    for (final ProductModel p in products) {
      if (!p.isActive) continue;
      counts[p.categoryId] = (counts[p.categoryId] ?? 0) + 1;
    }

    // Read the categories that actually exist rather than iterating a local
    // list, so a category with no products still gets its count reset to zero.
    final QuerySnapshot<Map<String, dynamic>> snap = await _collection.get();
    final WriteBatch batch = firestore.batch();
    for (final QueryDocumentSnapshot<Map<String, dynamic>> d in snap.docs) {
      final CategoryModel c = CategoryModel.fromMap(
        FirestoreMap.fromDocument(d),
      );
      final int count = counts[c.categoryId] ?? 0;
      if (count != c.productCount) {
        batch.update(d.reference, <String, dynamic>{'productCount': count});
      }
    }
    await batch.commit();
  }

  List<CategoryModel> _mapList(QuerySnapshot<Map<String, dynamic>> snap) {
    return snap.docs
        .map(
          (QueryDocumentSnapshot<Map<String, dynamic>> d) =>
              CategoryModel.fromMap(
                FirestoreMap.fromDocument(d),
                categoryId: d.id,
              ),
        )
        .toList();
  }
}

/// Shared demo category store.
