import '../../core/constants/app_constants.dart';
import 'firestore_map.dart';
import 'user_model.dart';

/// A product saved to a customer's wishlist.
///
/// Stored at `users/{userId}/wishlist/{productId}`. A snapshot of the product
/// is kept alongside the id so the wishlist still renders if the underlying
/// product is deactivated or removed.
class WishlistItem {
  const WishlistItem({
    required this.productId,
    this.name = '',
    this.image = '',
    this.price = 0,
    this.compareAtPrice = 0,
    this.isAvailable = true,
    required this.addedAt,
  });

  final String productId;
  final String name;
  final String image;
  final double price;
  final double compareAtPrice;
  final bool isAvailable;
  final DateTime addedAt;

  bool get hasDiscount => compareAtPrice > price && compareAtPrice > 0;

  WishlistItem copyWith({
    String? name,
    String? image,
    double? price,
    double? compareAtPrice,
    bool? isAvailable,
  }) {
    return WishlistItem(
      productId: productId,
      name: name ?? this.name,
      image: image ?? this.image,
      price: price ?? this.price,
      compareAtPrice: compareAtPrice ?? this.compareAtPrice,
      isAvailable: isAvailable ?? this.isAvailable,
      addedAt: addedAt,
    );
  }

  factory WishlistItem.fromMap(Map<String, dynamic> map, {String? productId}) {
    return WishlistItem(
      productId: FirestoreMap.str(map, 'productId', productId ?? ''),
      name: FirestoreMap.str(map, 'name'),
      image: FirestoreMap.str(map, 'image'),
      price: FirestoreMap.num2(map, 'price'),
      compareAtPrice: FirestoreMap.num2(map, 'compareAtPrice'),
      isAvailable: FirestoreMap.boolean(map, 'isAvailable', true),
      addedAt: FirestoreMap.dateTime(map, 'addedAt') ?? DateTime.now(),
    );
  }

  Map<String, dynamic> toMap() {
    return FirestoreMap.clean(<String, dynamic>{
      'productId': productId,
      'name': name,
      'image': image,
      'price': price,
      'compareAtPrice': compareAtPrice,
      'isAvailable': isAvailable,
      'addedAt': addedAt,
    });
  }

  @override
  String toString() => 'WishlistItem($productId)';
}

/// Per-customer figures shown in the admin customer list.
class CustomerStats {
  const CustomerStats({
    required this.userId,
    required this.name,
    required this.email,
    this.phone = '',
    this.profileImage = '',
    this.isActive = true,
    required this.joinedAt,
    this.orderCount = 0,
    this.totalSpent = 0,
    this.lastOrderAt,
  });

  final String userId;
  final String name;
  final String email;
  final String phone;
  final String profileImage;
  final bool isActive;
  final DateTime joinedAt;
  final int orderCount;
  final double totalSpent;
  final DateTime? lastOrderAt;

  /// A customer who has signed up but never ordered.
  bool get isNew => orderCount == 0;

  factory CustomerStats.fromUser(
    UserModel user, {
    int orderCount = 0,
    double totalSpent = 0,
    DateTime? lastOrderAt,
  }) {
    return CustomerStats(
      userId: user.uid,
      name: user.name,
      email: user.email,
      phone: user.phone,
      profileImage: user.profileImage,
      isActive: user.isActive,
      joinedAt: user.createdAt,
      orderCount: orderCount,
      totalSpent: totalSpent,
      lastOrderAt: lastOrderAt,
    );
  }
}

/// Aggregate figures for the admin dashboard.
///
/// Built client-side from the products/users/orders collections. At the scale
/// of a single boutique store this is cheap; if the catalogue grows into the
/// thousands, these should move to a Cloud Function or counter documents.
class DashboardStats {
  const DashboardStats({
    this.totalProducts = 0,
    this.activeProducts = 0,
    this.outOfStockProducts = 0,
    this.totalCustomers = 0,
    this.newCustomersThisMonth = 0,
    this.totalOrders = 0,
    this.pendingOrders = 0,
    this.confirmedOrders = 0,
    this.processingOrders = 0,
    this.shippedOrders = 0,
    this.deliveredOrders = 0,
    this.cancelledOrders = 0,
    this.totalOrderValue = 0,
    this.revenueDelivered = 0,
    this.newArrivals = 0,
    this.fastMoving = 0,
    this.featured = 0,
    this.totalCategories = 0,
    this.monthlyRevenue = const <double>[],
    this.statusBreakdown = const <String, int>{},
  });

  final int totalProducts;
  final int activeProducts;
  final int outOfStockProducts;
  final int totalCustomers;
  final int newCustomersThisMonth;
  final int totalOrders;
  final int pendingOrders;
  final int confirmedOrders;
  final int processingOrders;
  final int shippedOrders;
  final int deliveredOrders;
  final int cancelledOrders;

  /// Sum of all non-cancelled order totals.
  final double totalOrderValue;

  /// Sum of delivered order totals only.
  final double revenueDelivered;

  final int newArrivals;
  final int fastMoving;
  final int featured;
  final int totalCategories;

  /// Revenue for the last 6 months, oldest first — feeds the dashboard chart.
  final List<double> monthlyRevenue;

  /// Order counts keyed by status.
  final Map<String, int> statusBreakdown;

  /// Orders still being worked on (not delivered, not cancelled).
  int get activeOrders => totalOrders - deliveredOrders - cancelledOrders;

  bool get isEmpty => totalOrders == 0 && totalProducts == 0;

  /// Aggregates raw Firestore maps into dashboard figures.
  factory DashboardStats.fromMaps({
    required List<Map<String, dynamic>> products,
    required List<Map<String, dynamic>> users,
    required List<Map<String, dynamic>> orders,
    int totalCategories = 0,
    int monthsOfHistory = 6,
  }) {
    int active = 0, outOfStock = 0, newArrivals = 0, fastMoving = 0;
    int featured = 0;
    for (final Map<String, dynamic> p in products) {
      if (FirestoreMap.boolean(p, 'isActive', true)) active++;
      if (FirestoreMap.int2(p, 'stock') <= 0) outOfStock++;
      if (FirestoreMap.boolean(p, 'isNewArrival')) newArrivals++;
      if (FirestoreMap.boolean(p, 'isFastMoving')) fastMoving++;
      if (FirestoreMap.boolean(p, 'isFeatured')) featured++;
    }

    final DateTime now = DateTime.now();
    final DateTime monthStart = DateTime(now.year, now.month);
    int newCustomers = 0;
    for (final Map<String, dynamic> u in users) {
      final DateTime? created = FirestoreMap.dateTime(u, 'createdAt');
      if (created != null && created.isAfter(monthStart)) newCustomers++;
    }

    int pending = 0, confirmed = 0, processing = 0, shipped = 0;
    int delivered = 0, cancelled = 0;
    double totalValue = 0, deliveredValue = 0;
    final Map<String, int> breakdown = <String, int>{};
    final List<double> monthly = List<double>.filled(monthsOfHistory, 0);

    for (final Map<String, dynamic> o in orders) {
      final String status = FirestoreMap.str(o, 'status');
      // Cancelled orders are excluded from revenue entirely.
      if (status == OrderStatus.cancelled) {
        cancelled++;
        continue;
      }
      final double value = FirestoreMap.num2(o, 'total');
      totalValue += value;
      breakdown[status] = (breakdown[status] ?? 0) + 1;

      switch (status) {
        case OrderStatus.pending:
          pending++;
          break;
        case OrderStatus.confirmed:
          confirmed++;
          break;
        case OrderStatus.processing:
          processing++;
          break;
        case OrderStatus.shipped:
          shipped++;
          break;
        case OrderStatus.delivered:
          delivered++;
          deliveredValue += value;
          break;
      }

      // Bucket into the trailing-months array, oldest bucket first.
      final DateTime? created = FirestoreMap.dateTime(o, 'createdAt');
      if (created != null) {
        final int monthsAgo =
            (now.year - created.year) * 12 + (now.month - created.month);
        if (monthsAgo >= 0 && monthsAgo < monthsOfHistory) {
          monthly[monthsOfHistory - 1 - monthsAgo] += value;
        }
      }
    }

    return DashboardStats(
      totalProducts: products.length,
      activeProducts: active,
      outOfStockProducts: outOfStock,
      totalCustomers: users.length,
      newCustomersThisMonth: newCustomers,
      totalOrders: orders.length,
      pendingOrders: pending,
      confirmedOrders: confirmed,
      processingOrders: processing,
      shippedOrders: shipped,
      deliveredOrders: delivered,
      cancelledOrders: cancelled,
      totalOrderValue: totalValue,
      revenueDelivered: deliveredValue,
      newArrivals: newArrivals,
      fastMoving: fastMoving,
      featured: featured,
      totalCategories: totalCategories,
      monthlyRevenue: monthly,
      statusBreakdown: breakdown,
    );
  }
}
