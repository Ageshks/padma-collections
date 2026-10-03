import 'dart:async';

import 'package:cloud_firestore/cloud_firestore.dart';

import '../../core/constants/app_constants.dart';
import '../../core/utils/error_handler.dart';
import '../models/models.dart';
import 'base_repository.dart';

/// A customer's saved products, stored at
/// `users/{userId}/wishlist/{productId}` so the wishlist syncs across devices
/// once the customer signs in.
class WishlistRepository extends BaseRepository {
  WishlistRepository({super.firestore});

  /// Resolves the customer's wishlist collection.
  ///
  /// Throws a friendly [AppException] when signed out, rather than letting
  /// Firestore reject the malformed path `users//wishlist`.
  CollectionReference<Map<String, dynamic>> _wishlistFor(String uid) {
    if (uid.isEmpty) {
      throw const AppException(
        'Please sign in to update your wishlist.',
        code: 'not-signed-in',
      );
    }
    return firestore
        .collection(AppConstants.usersCollection)
        .doc(uid)
        .collection(AppConstants.wishlistCollection);
  }

  /// Streams the customer's wishlist, newest first.
  ///
  /// An empty [uid] means "signed out", which yields an empty wishlist instead
  /// of the invalid path `users//wishlist`.
  Stream<List<WishlistItem>> watchWishlist(String uid) {
    if (uid.isEmpty) {
      return Stream<List<WishlistItem>>.value(const <WishlistItem>[]);
    }
    return _wishlistFor(uid).snapshots().map(_mapList);
  }

  /// Adds a product to the wishlist. Adding twice is a no-op.
  Future<void> add(String uid, WishlistItem item) async {
    try {
      await _wishlistFor(
        uid,
      ).doc(item.productId).set(item.toMap(), SetOptions(merge: true));
    } catch (e) {
      throw AppErrorHandler.wrap(e);
    }
  }

  Future<void> remove(String uid, String productId) async {
    await _wishlistFor(uid).doc(productId).delete();
  }

  /// Toggles membership and returns the resulting state.
  ///
  /// Returning the new state lets the caller show the right confirmation
  /// ("Added to wishlist" vs "Removed from wishlist") without a second read.
  Future<bool> toggle(String uid, WishlistItem item) async {
    final bool exists = await contains(uid, item.productId);
    if (exists) {
      await remove(uid, item.productId);
      return false;
    }
    await add(uid, item);
    return true;
  }

  /// Whether a product is currently saved.
  Future<bool> contains(String uid, String productId) async {
    final DocumentSnapshot<Map<String, dynamic>> doc = await _wishlistFor(
      uid,
    ).doc(productId).get();
    return doc.exists;
  }

  /// Current saved product ids — used to paint hearts across listings.
  Future<Set<String>> productIds(String uid) async {
    final QuerySnapshot<Map<String, dynamic>> snap = await _wishlistFor(
      uid,
    ).get();
    return snap.docs
        .map((QueryDocumentSnapshot<Map<String, dynamic>> d) => d.id)
        .toSet();
  }

  List<WishlistItem> _mapList(QuerySnapshot<Map<String, dynamic>> snap) {
    final List<WishlistItem> list =
        snap.docs
            .map(
              (QueryDocumentSnapshot<Map<String, dynamic>> d) =>
                  WishlistItem.fromMap(
                    FirestoreMap.fromDocument(d),
                    productId: d.id,
                  ),
            )
            .toList()
          ..sort(
            (WishlistItem a, WishlistItem b) => b.addedAt.compareTo(a.addedAt),
          );
    return list;
  }
}

/// Shared demo wishlist store.
