import 'dart:async';

import 'package:cloud_firestore/cloud_firestore.dart';

import '../../core/constants/app_constants.dart';
import '../models/models.dart';
import 'base_repository.dart';

/// Reads and writes home promotional banners.
class BannerRepository extends BaseRepository {
  BannerRepository({super.firestore});

  CollectionReference<Map<String, dynamic>> get _collection =>
      firestore.collection(AppConstants.bannersCollection);

  /// Active banners for the home carousel, in display order.
  Stream<List<BannerModel>> watchActiveBanners() {
    return _collection
        .where('isActive', isEqualTo: true)
        .orderBy('sortOrder')
        .snapshots()
        .map(_mapList);
  }

  /// Every banner, including disabled ones (admin only).
  Stream<List<BannerModel>> watchAllBanners() {
    return _collection.orderBy('sortOrder').snapshots().map(_mapList);
  }

  Future<String> create(BannerModel banner) async {
    final DocumentReference<Map<String, dynamic>> ref = _collection.doc();
    final Map<String, dynamic> data = banner.toMap()..['bannerId'] = ref.id;
    await ref.set(data);
    return ref.id;
  }

  Future<void> update(String bannerId, BannerModel banner) async {
    final Map<String, dynamic> data = banner.toMap()
      ..['bannerId'] = bannerId
      ..['updatedAt'] = DateTime.now();
    await _collection.doc(bannerId).update(data);
  }

  Future<void> delete(String bannerId) async {
    await _collection.doc(bannerId).delete();
  }

  Future<void> setActive(String bannerId, bool isActive) async {
    await _collection.doc(bannerId).update(<String, dynamic>{
      'isActive': isActive,
      'updatedAt': DateTime.now(),
    });
  }

  /// Persists a new banner order.
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

  List<BannerModel> _mapList(QuerySnapshot<Map<String, dynamic>> snap) {
    return snap.docs
        .map(
          (QueryDocumentSnapshot<Map<String, dynamic>> d) =>
              BannerModel.fromMap(FirestoreMap.fromDocument(d), bannerId: d.id),
        )
        .toList();
  }
}

/// Shared demo banner store.
