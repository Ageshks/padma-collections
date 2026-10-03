import 'dart:async';

import 'package:cloud_firestore/cloud_firestore.dart';

import '../../core/constants/app_constants.dart';
import '../../core/utils/error_handler.dart';
import '../models/models.dart';
import 'base_repository.dart';

/// The customer's cart, stored at `users/{userId}/cart/{productId}`.
///
/// Keying by product id means adding the same item twice merges quantities
/// instead of creating a duplicate line.
class CartRepository extends BaseRepository {
  CartRepository({super.firestore});

  /// Resolves the customer's cart collection.
  ///
  /// Throws a friendly [AppException] when signed out: every write funnels
  /// through here, and without the guard Firestore would reject the malformed
  /// path `users//cart` with an error no customer can act on.
  CollectionReference<Map<String, dynamic>> _cartFor(String uid) {
    if (uid.isEmpty) {
      throw const AppException(
        'Please sign in to update your cart.',
        code: 'not-signed-in',
      );
    }
    return firestore
        .collection(AppConstants.usersCollection)
        .doc(uid)
        .collection(AppConstants.cartCollection);
  }

  /// Streams the current cart, newest items first.
  ///
  /// An empty [uid] means "signed out". That is a normal state, not an error,
  /// so it yields an empty cart rather than building the invalid document path
  /// `users//cart`, which Firestore rejects outright.
  Stream<List<CartItem>> watchCart(String uid) {
    if (uid.isEmpty) return Stream<List<CartItem>>.value(const <CartItem>[]);
    return _cartFor(uid).snapshots().map(_mapList);
  }

  /// Adds a product, merging quantity when it is already in the cart.
  ///
  /// The quantity is capped by available stock and the global maximum so a
  /// customer cannot request more than exists.
  Future<void> add(String uid, CartItem item) async {
    try {
      // Merge server-side so two devices cannot double-add the same product.
      final DocumentReference<Map<String, dynamic>> ref = _cartFor(
        uid,
      ).doc(item.productId);
      await firestore.runTransaction((Transaction transaction) async {
        final DocumentSnapshot<Map<String, dynamic>> snap = await transaction
            .get(ref);
        if (!snap.exists) {
          transaction.set(ref, item.toMap());
          return;
        }
        final CartItem existing = CartItem.fromMap(
          FirestoreMap.fromDocument(snap),
          productId: ref.id,
        );
        final int merged = (existing.quantity + item.quantity).clamp(
          AppConstants.cartQuantityMin,
          _maxFor(existing.stock),
        );
        transaction.update(ref, <String, dynamic>{
          'quantity': merged,
          'subtotal': merged * existing.price,
        });
      });
    } catch (e) {
      throw AppErrorHandler.wrap(e);
    }
  }

  /// Upper bound for a line's quantity, given the available stock.
  static int _maxFor(int stock) => stock > 0
      ? stock.clamp(AppConstants.cartQuantityMin, AppConstants.cartQuantityMax)
      : AppConstants.cartQuantityMax;

  /// Sets an exact quantity. Passing 0 removes the line.
  Future<void> updateQuantity(
    String uid,
    String productId,
    int quantity,
  ) async {
    try {
      if (quantity <= 0) {
        await remove(uid, productId);
        return;
      }
      await _cartFor(
        uid,
      ).doc(productId).update(<String, dynamic>{'quantity': quantity});
    } catch (e) {
      throw AppErrorHandler.wrap(e);
    }
  }

  /// Increments a line by one, respecting the stock ceiling.
  ///
  /// Reads the line back from Firestore rather than from any in-memory cache:
  /// the quantity that matters is the one on the server, and a local copy would
  /// silently no-op whenever it was stale or absent.
  Future<void> increase(String uid, String productId) async {
    final CartItem? item = await _readLine(uid, productId);
    if (item == null) return;
    await updateQuantity(uid, productId, item.quantity + 1);
  }

  /// Decrements a line by one, removing it when it reaches zero.
  Future<void> decrease(String uid, String productId) async {
    final CartItem? item = await _readLine(uid, productId);
    if (item == null) return;
    if (item.quantity <= 1) {
      await remove(uid, productId);
      return;
    }
    await updateQuantity(uid, productId, item.quantity - 1);
  }

  /// Loads one line from the cart, or null when it is not there.
  Future<CartItem?> _readLine(String uid, String productId) async {
    try {
      final DocumentSnapshot<Map<String, dynamic>> snap = await _cartFor(
        uid,
      ).doc(productId).get();
      if (!snap.exists) return null;
      return CartItem.fromMap(FirestoreMap.fromDocument(snap));
    } catch (e) {
      throw AppErrorHandler.wrap(e);
    }
  }

  Future<void> remove(String uid, String productId) async {
    await _cartFor(uid).doc(productId).delete();
  }

  Future<void> clear(String uid) async {
    final QuerySnapshot<Map<String, dynamic>> snap = await _cartFor(uid).get();
    final WriteBatch batch = firestore.batch();
    for (final QueryDocumentSnapshot<Map<String, dynamic>> d in snap.docs) {
      batch.delete(d.reference);
    }
    await batch.commit();
  }

  List<CartItem> _mapList(QuerySnapshot<Map<String, dynamic>> snap) {
    final List<CartItem> list =
        snap.docs
            .map(
              (QueryDocumentSnapshot<Map<String, dynamic>> d) =>
                  CartItem.fromMap(
                    FirestoreMap.fromDocument(d),
                    productId: d.id,
                  ),
            )
            .toList()
          ..sort((CartItem a, CartItem b) => b.addedAt.compareTo(a.addedAt));
    return list;
  }
}

/// Shared demo cart store.
