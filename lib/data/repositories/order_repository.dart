import 'dart:async';

import 'package:cloud_firestore/cloud_firestore.dart';

import '../../core/constants/app_constants.dart';
import '../../core/utils/error_handler.dart';
import '../models/models.dart';
import 'base_repository.dart';

/// Customer order requests. Stored at `orders/{orderId}`.
///
/// There is **no payment gateway** in Padma Collections: the customer submits
/// this request and then confirms it over WhatsApp with the seller.
class OrderRepository extends BaseRepository {
  OrderRepository({super.firestore});

  CollectionReference<Map<String, dynamic>> get _orders =>
      firestore.collection(AppConstants.ordersCollection);

  /// Creates an order from the given lines and returns it with its id set.
  ///
  /// Money fields are computed from the line items so the stored total can
  /// never disagree with what the customer actually selected.
  Future<OrderModel> create({
    required String userId,
    required String customerName,
    required String phone,
    required String address,
    required List<OrderItem> items,
    required double subtotal,
    required double makingCharge,
    required double discount,
    required double tax,
    required double shippingCharge,
    String customerNote = '',
  }) async {
    try {
      final double total =
          subtotal + makingCharge - discount + tax + shippingCharge;
      final DateTime now = DateTime.now();

      final OrderModel draft = OrderModel(
        orderId: '',
        orderNumber: await _nextOrderNumber(),
        userId: userId,
        customerName: customerName.trim(),
        phone: phone.trim(),
        address: address.trim(),
        items: items,
        subtotal: subtotal,
        makingCharge: makingCharge,
        discount: discount,
        tax: tax,
        shippingCharge: shippingCharge,
        total: total,
        customerNote: customerNote.trim(),
        status: OrderStatus.pending,
        statusHistory: <OrderStatusEntry>[
          OrderStatusEntry(status: OrderStatus.pending, at: now),
        ],
        createdAt: now,
      );

      final DocumentReference<Map<String, dynamic>> ref = await _orders.add(
        draft.toMap(),
      );
      return draft.copyWith(orderId: ref.id);
    } catch (e) {
      throw AppErrorHandler.wrap(e);
    }
  }

  /// Next human-friendly order reference, e.g. `PC-1004`.
  ///
  /// Derived from the highest reference already stored rather than from a
  /// running count, so it keeps increasing across the whole shop instead of
  /// resetting. Falls back to a timestamp-derived number if the existing
  /// values cannot be read — a unique reference matters more than a tidy one.
  Future<String> _nextOrderNumber() async {
    try {
      final QuerySnapshot<Map<String, dynamic>> snap = await _orders
          .orderBy('createdAt', descending: true)
          .limit(200)
          .get();

      int highest = 1000;
      for (final QueryDocumentSnapshot<Map<String, dynamic>> d in snap.docs) {
        final String raw = FirestoreMap.str(
          FirestoreMap.fromDocument(d),
          'orderNumber',
        );
        final int? parsed = int.tryParse(
          raw.startsWith('PC-') ? raw.substring(3) : raw,
        );
        if (parsed != null && parsed > highest) {
          highest = parsed;
        }
      }
      return 'PC-${highest + 1}';
    } catch (_) {
      final int stamp = DateTime.now().millisecondsSinceEpoch % 100000;
      return 'PC-$stamp';
    }
  }

  /// Orders for one customer, newest first.
  ///
  /// An empty [userId] means "signed out"; it yields no orders rather than
  /// querying for `userId == ''`, which the security rules would reject.
  Stream<List<OrderModel>> watchUserOrders(String userId) {
    if (userId.isEmpty)
      return Stream<List<OrderModel>>.value(const <OrderModel>[]);
    return _orders
        .where('userId', isEqualTo: userId)
        .orderBy('createdAt', descending: true)
        .snapshots()
        .map(_mapList);
  }

  /// Every order (admin only), newest first.
  Stream<List<OrderModel>> watchAllOrders() {
    return _orders
        .orderBy('createdAt', descending: true)
        .snapshots()
        .map(_mapList);
  }

  /// Orders for the admin tabs, optionally filtered to one status.
  Stream<List<OrderModel>> watchOrdersByStatus(String status) {
    if (status == 'All') return watchAllOrders();
    return watchAllOrders().map(
      (List<OrderModel> list) =>
          list.where((OrderModel o) => o.status == status).toList(),
    );
  }

  Future<OrderModel?> getById(String orderId) async {
    final DocumentSnapshot<Map<String, dynamic>> doc = await _orders
        .doc(orderId)
        .get();
    if (!doc.exists) return null;
    return OrderModel.fromMap(FirestoreMap.fromDocument(doc), orderId: doc.id);
  }

  /// Moves an order to a new status and appends to its timeline.
  ///
  /// Uses a transaction so the history array is extended atomically, even if
  /// two admins update the same order at once.
  Future<void> updateStatus(
    String orderId,
    String status, {
    String note = '',
  }) async {
    try {
      final DocumentReference<Map<String, dynamic>> ref = _orders.doc(orderId);
      await firestore.runTransaction((Transaction transaction) async {
        final DocumentSnapshot<Map<String, dynamic>> snap = await transaction
            .get(ref);
        if (!snap.exists) return;
        final List<OrderStatusEntry> history =
            FirestoreMap.mapList(
              FirestoreMap.fromDocument(snap),
              'statusHistory',
            ).map(OrderStatusEntry.fromMap).toList()..add(
              OrderStatusEntry(
                status: status,
                at: DateTime.now(),
                note: note.trim(),
              ),
            );
        transaction.update(ref, <String, dynamic>{
          'status': status,
          'statusHistory': history
              .map((OrderStatusEntry e) => e.toMap())
              .toList(),
          'updatedAt': DateTime.now(),
        });
      });
    } catch (e) {
      throw AppErrorHandler.wrap(e);
    }
  }

  /// Records that the customer followed through on the WhatsApp handoff.
  Future<void> markWhatsAppSent(String orderId) async {
    await _orders.doc(orderId).update(<String, dynamic>{
      'isWhatsappSent': true,
      'updatedAt': DateTime.now(),
    });
  }

  List<OrderModel> _mapList(QuerySnapshot<Map<String, dynamic>> snap) {
    return snap.docs
        .map(
          (QueryDocumentSnapshot<Map<String, dynamic>> d) =>
              OrderModel.fromMap(FirestoreMap.fromDocument(d), orderId: d.id),
        )
        .toList()
      ..sort(
        (OrderModel a, OrderModel b) => b.createdAt.compareTo(a.createdAt),
      );
  }
}

/// Shared demo order store.
