import 'package:flutter_test/flutter_test.dart';
import 'package:padma/core/constants/app_constants.dart';
import 'package:padma/data/models/models.dart';

/// A couple of products built inline, so the aggregation assertions below do
/// not depend on any seeded catalogue.
List<ProductModel> _products() => <ProductModel>[
  ProductModel(
    productId: 'p1',
    name: 'Ruby Studs',
    categoryId: 'earrings',
    price: 1200,
    isActive: true,
    createdAt: DateTime.now(),
  ),
  ProductModel(
    productId: 'p2',
    name: 'Pearl Necklace',
    categoryId: 'necklaces',
    price: 3400,
    isActive: true,
    createdAt: DateTime.now(),
  ),
  ProductModel(
    productId: 'p3',
    name: 'Retired Bangle',
    categoryId: 'bangles',
    price: 900,
    isActive: false,
    createdAt: DateTime.now(),
  ),
];

/// Verifies the aggregation logic behind the admin dashboard.
void main() {
  group('DashboardStats aggregation', () {
    test('counts products, orders and revenue from raw maps', () {
      final DashboardStats stats = DashboardStats.fromMaps(
        products: _products().map((ProductModel p) => p.toMap()).toList(),
        users: <Map<String, dynamic>>[
          UserModel.fromMap(<String, dynamic>{
            'uid': 'a',
            'createdAt': DateTime.now().toIso8601String(),
          }).toMap(),
          UserModel.fromMap(<String, dynamic>{
            'uid': 'b',
            'createdAt': DateTime(2020).toIso8601String(),
          }).toMap(),
        ],
        orders: <Map<String, dynamic>>[
          OrderModel(
            orderId: 'o1',
            userId: 'a',
            total: 2000,
            status: OrderStatus.delivered,
            createdAt: DateTime.now(),
          ).toMap(),
          OrderModel(
            orderId: 'o2',
            userId: 'a',
            total: 1000,
            status: OrderStatus.pending,
            createdAt: DateTime.now(),
          ).toMap(),
          OrderModel(
            orderId: 'o3',
            userId: 'b',
            total: 500,
            status: OrderStatus.cancelled,
            createdAt: DateTime.now(),
          ).toMap(),
        ],
      );

      expect(stats.totalProducts, _products().length);
      expect(stats.totalCustomers, 2);
      expect(stats.newCustomersThisMonth, 1);
      expect(stats.totalOrders, 3);
      expect(stats.deliveredOrders, 1);
      expect(stats.pendingOrders, 1);
      expect(stats.cancelledOrders, 1);
      // Cancelled orders are excluded from revenue.
      expect(stats.totalOrderValue, 3000);
      expect(stats.revenueDelivered, 2000);
      expect(stats.activeOrders, 1);
    });

    test('monthly revenue buckets into the trailing window', () {
      final DateTime now = DateTime.now();
      final DateTime lastMonth = DateTime(now.year, now.month - 1, 15);

      final DashboardStats stats = DashboardStats.fromMaps(
        products: const <Map<String, dynamic>>[],
        users: const <Map<String, dynamic>>[],
        orders: <Map<String, dynamic>>[
          OrderModel(
            orderId: 'o1',
            userId: 'a',
            total: 300,
            createdAt: now,
          ).toMap(),
          OrderModel(
            orderId: 'o2',
            userId: 'a',
            total: 700,
            createdAt: lastMonth,
          ).toMap(),
        ],
        monthsOfHistory: 6,
      );

      expect(stats.monthlyRevenue.length, 6);
      expect(stats.monthlyRevenue.last, 300);
      expect(stats.monthlyRevenue[4], 700);
      expect(
        stats.monthlyRevenue.fold<double>(0, (double a, double b) => a + b),
        1000,
      );
    });

    test('handles an empty store without dividing by zero', () {
      final DashboardStats stats = DashboardStats.fromMaps(
        products: const <Map<String, dynamic>>[],
        users: const <Map<String, dynamic>>[],
        orders: const <Map<String, dynamic>>[],
      );

      expect(stats.isEmpty, isTrue);
      expect(stats.totalProducts, 0);
      expect(stats.totalOrderValue, 0);
      expect(stats.monthlyRevenue.every((double v) => v == 0), isTrue);
    });
  });

  group('CustomerStats', () {
    test('flags a customer who has never ordered as new', () {
      final CustomerStats fresh = CustomerStats.fromUser(
        UserModel.fromMap(<String, dynamic>{
          'uid': 'u1',
          'name': 'Asha',
          'email': 'a@b.com',
        }),
      );
      final CustomerStats returning = CustomerStats.fromUser(
        UserModel.fromMap(<String, dynamic>{
          'uid': 'u2',
          'name': 'Riya',
          'email': 'r@b.com',
        }),
        orderCount: 3,
        totalSpent: 4200,
      );

      expect(fresh.isNew, isTrue);
      expect(returning.isNew, isFalse);
      expect(returning.orderCount, 3);
      expect(returning.totalSpent, 4200);
    });
  });

  group('BannerModel', () {
    test('falls back to a safe action for unknown button actions', () {
      final BannerModel banner = BannerModel.fromMap(<String, dynamic>{
        'bannerId': 'b1',
        'buttonAction': 'launch_missiles',
      });

      expect(banner.action, BannerAction.openCategory);
    });

    test('round-trips its action', () {
      final BannerModel banner = BannerModel(
        bannerId: 'b1',
        title: 'Test',
        action: BannerAction.openWhatsapp,
        createdAt: DateTime(2026, 1, 1),
      );
      final BannerModel copy = BannerModel.fromMap(banner.toMap());

      expect(copy.action, BannerAction.openWhatsapp);
    });
  });
}
