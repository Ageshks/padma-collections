import 'dart:async';

import 'package:cloud_firestore/cloud_firestore.dart';

import '../../core/constants/app_constants.dart';
import '../../core/utils/error_handler.dart';
import '../models/models.dart';
import 'base_repository.dart';

/// Admin-side user management and dashboard aggregation.
///
/// Passwords are never stored in Firestore — Firebase Authentication owns
/// credentials, so nothing sensitive is exposed here.
class UserRepository extends BaseRepository {
  UserRepository({super.firestore});

  CollectionReference<Map<String, dynamic>> get _users =>
      firestore.collection(AppConstants.usersCollection);

  /// Every customer account (admin only), newest first.
  Stream<List<UserModel>> watchCustomers({bool includeAdmins = false}) {
    Query<Map<String, dynamic>> query = _users;
    if (!includeAdmins) {
      query = query.where('role', isEqualTo: UserRole.customer);
    }
    return query
        .orderBy('createdAt', descending: true)
        .snapshots()
        .map(
          (QuerySnapshot<Map<String, dynamic>> snap) => snap.docs
              .map(
                (QueryDocumentSnapshot<Map<String, dynamic>> d) =>
                    UserModel.fromMap(FirestoreMap.fromDocument(d), uid: d.id),
              )
              .toList(),
        );
  }

  /// Streams a single customer by id.
  ///
  /// An empty [uid] means "not signed in yet", so it emits null rather than
  /// building the invalid path `users/`.
  Stream<UserModel?> watchUser(String uid) {
    if (uid.isEmpty) return Stream<UserModel?>.value(null);
    return _users
        .doc(uid)
        .snapshots()
        .map(
          (DocumentSnapshot<Map<String, dynamic>> d) =>
              d.exists ? UserModel.fromMap(FirestoreMap.fromDocument(d)) : null,
        );
  }

  /// Activates or deactivates a customer.
  ///
  /// A deactivated account is blocked at the rules level, not merely hidden.
  Future<void> setActive(String uid, bool isActive) async {
    try {
      await _users.doc(uid).update(<String, dynamic>{
        'isActive': isActive,
        'updatedAt': DateTime.now(),
      });
    } catch (e) {
      throw AppErrorHandler.wrap(e);
    }
  }

  /// Promotes or demotes an account.
  ///
  /// Guarded twice: the UI hides this behind an admin-only action, and
  /// `firestore.rules` rejects any role change made by a non-admin.
  Future<void> setRole(String uid, String role) async {
    if (!UserRole.isValid(role)) {
      throw const AppException('That role is not valid.');
    }
    try {
      await _users.doc(uid).update(<String, dynamic>{
        'role': role,
        'updatedAt': DateTime.now(),
      });
    } catch (e) {
      throw AppErrorHandler.wrap(e);
    }
  }

  /// Creates an admin account (admin-only).
  ///
  /// The account is created with the customer role first and promoted by the
  /// caller, which matches how the security rules expect this to happen.
  Future<void> promoteToAdmin(String uid) => setRole(uid, UserRole.admin);

  /// Per-customer order statistics for the admin customer list.
  Future<List<CustomerStats>> customerStats({
    List<OrderModel> orders = const <OrderModel>[],
  }) async {
    final List<UserModel> customers = await watchCustomers().first;

    final Map<String, List<OrderModel>> byUser = <String, List<OrderModel>>{};
    for (final OrderModel order in orders) {
      byUser.putIfAbsent(order.userId, () => <OrderModel>[]).add(order);
    }

    return customers.map((UserModel user) {
      final List<OrderModel> userOrders =
          byUser[user.uid] ?? const <OrderModel>[];
      final List<OrderModel> valid = userOrders
          .where((OrderModel o) => !o.isCancelled)
          .toList();
      return CustomerStats.fromUser(
        user,
        orderCount: userOrders.length,
        totalSpent: valid.fold<double>(
          0,
          (double sum, OrderModel o) => sum + o.total,
        ),
        lastOrderAt: userOrders.isEmpty
            ? null
            : userOrders
                  .map((OrderModel o) => o.createdAt)
                  .reduce((DateTime a, DateTime b) => a.isAfter(b) ? a : b),
      );
    }).toList();
  }

  /// Aggregates everything the admin dashboard needs in one pass.
  Future<DashboardStats> dashboardStats({
    required List<ProductModel> products,
    required List<OrderModel> orders,
    int totalCategories = 0,
  }) async {
    final List<UserModel> customers = await watchCustomers().first;
    return DashboardStats.fromMaps(
      products: products.map((ProductModel p) => p.toMap()).toList(),
      users: customers.map((UserModel u) => u.toMap()).toList(),
      orders: orders.map((OrderModel o) => o.toMap()).toList(),
      totalCategories: totalCategories,
    );
  }
}
