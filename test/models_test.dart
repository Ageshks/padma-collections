import 'package:flutter_test/flutter_test.dart';
import 'package:padma/core/constants/app_constants.dart';
import 'package:padma/data/models/models.dart';

void main() {
  group('ProductModel', () {
    test('derives discount percentage and clamps bad compare price', () {
      final ProductModel p = ProductModel.fromMap(<String, dynamic>{
        'productId': 'p1',
        'name': 'Gold Plated Necklace',
        'price': 1299.0,
        'compareAtPrice': 2599.0,
        'stock': 10,
        'sku': 'PC-NK-001',
      });

      expect(p.discountPercentage, 50);
      expect(p.hasDiscount, isTrue);
      expect(p.badgeLabel, '50% OFF');
      expect(p.inStock, isTrue);
      expect(p.isPurchasable, isTrue);
    });

    test('clears compare price when it is not above the sale price', () {
      final ProductModel p = ProductModel.fromMap(<String, dynamic>{
        'productId': 'p2',
        'price': 999.0,
        'compareAtPrice': 500.0,
        'stock': 4,
      });

      expect(p.hasDiscount, isFalse);
      expect(p.compareAtPrice, 0);
      expect(p.badgeLabel, '');
    });

    test('flags out-of-stock products as not purchasable', () {
      final ProductModel p = ProductModel.fromMap(<String, dynamic>{
        'productId': 'p3',
        'price': 100.0,
        'stock': 0,
      });

      expect(p.inStock, isFalse);
      expect(p.isPurchasable, isFalse);
      expect(p.badgeLabel, 'Out of Stock');
    });

    test('matches query on name, sku and category', () {
      final ProductModel p = ProductModel.fromMap(<String, dynamic>{
        'productId': 'p4',
        'name': 'Pearl Earrings',
        'sku': 'PC-ER-001',
        'categoryName': 'Earrings',
        'price': 599.0,
      });

      expect(p.matchesQuery('pearl'), isTrue);
      expect(p.matchesQuery('PC-ER'), isTrue);
      expect(p.matchesQuery('earring'), isTrue);
      expect(p.matchesQuery('necklace'), isFalse);
      expect(p.matchesQuery(''), isTrue);
    });

    test('round-trips through toMap/fromMap', () {
      final ProductModel original = ProductModel(
        productId: 'p5',
        name: 'Bridal Set',
        categoryId: 'c1',
        categoryName: 'Bridal Jewellery',
        images: const <CloudinaryImage>[
          CloudinaryImage(publicId: 'img-a', isPrimary: true, sortOrder: 0),
          CloudinaryImage(publicId: 'img-b', sortOrder: 1),
        ],
        price: 4999,
        compareAtPrice: 7999,
        stock: 5,
        sku: 'PC-BD-001',
        material: 'Gold Plated',
        color: 'Gold',
        weight: '85 g',
        isFeatured: true,
        createdAt: DateTime(2026, 1, 1),
      );

      final ProductModel copy = ProductModel.fromMap(
        original.toMap(),
        productId: 'p5',
      );

      expect(copy.name, original.name);
      expect(copy.images, original.images);
      expect(copy.isFeatured, isTrue);
      expect(copy.price, 4999);
    });
  });

  group('OrderModel', () {
    test('recalculates totals from line items', () {
      final OrderModel order = OrderModel(
        orderId: 'o1',
        userId: 'u1',
        items: const <OrderItem>[
          OrderItem(
            productId: 'p1',
            name: 'Necklace',
            price: 1299,
            quantity: 1,
          ),
          OrderItem(productId: 'p2', name: 'Earrings', price: 599, quantity: 2),
        ],
        shippingCharge: 50,
        createdAt: DateTime(2026, 1, 1),
      ).recalculated();

      // 1299 + (599 * 2) = 2497, plus 50 shipping.
      expect(order.subtotal, 2497);
      expect(order.total, 2547);
      expect(order.itemCount, 3);
    });

    test('unknown status falls back to Pending', () {
      final OrderModel order = OrderModel.fromMap(<String, dynamic>{
        'orderId': 'o2',
        'status': 'Teleported',
      });

      expect(order.status, OrderStatus.pending);
    });
  });

  group('UserModel', () {
    test('coerces unknown roles to customer', () {
      final UserModel u = UserModel.fromMap(<String, dynamic>{
        'uid': 'u1',
        'role': 'superadmin',
      });

      expect(u.role, UserRole.customer);
      expect(u.isAdmin, isFalse);
    });

    test('exposes the first name for greetings', () {
      final UserModel u = UserModel.fromMap(<String, dynamic>{
        'uid': 'u1',
        'name': 'Aarav Mehta',
      });

      expect(u.firstName, 'Aarav');
    });
  });
}
