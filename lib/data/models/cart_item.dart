import '../../core/constants/app_constants.dart';
import 'firestore_map.dart';

/// A line in a customer's cart.
///
/// Stored at `users/{userId}/cart/{productId}` — keyed by product so adding
/// the same product twice merges quantities instead of creating a duplicate.
class CartItem {
  const CartItem({
    required this.productId,
    required this.name,
    this.image = '',
    this.price = 0,
    this.quantity = 1,
    this.sku = '',
    this.stock = 0,
    this.isAvailable = true,
    required this.addedAt,
  });

  final String productId;
  final String name;
  final String image;

  /// Unit price at the time it was added; refreshed on join.
  final double price;
  final int quantity;
  final String sku;

  /// Stock snapshot, so the cart can warn before checkout.
  final int stock;
  final bool isAvailable;

  final DateTime addedAt;

  double get subtotal => price * quantity;

  /// True when the product is gone or the cart quantity exceeds stock.
  bool get exceedsStock => stock > 0 && quantity > stock;

  /// Quantity is capped so a customer cannot request 500 of one item.
  bool get canIncrease =>
      quantity <
      stock.clamp(AppConstants.cartQuantityMin, AppConstants.cartQuantityMax);

  bool get canDecrease => quantity > AppConstants.cartQuantityMin;

  CartItem copyWith({
    String? name,
    String? image,
    double? price,
    int? quantity,
    String? sku,
    int? stock,
    bool? isAvailable,
  }) {
    return CartItem(
      productId: productId,
      name: name ?? this.name,
      image: image ?? this.image,
      price: price ?? this.price,
      quantity: quantity ?? this.quantity,
      sku: sku ?? this.sku,
      stock: stock ?? this.stock,
      isAvailable: isAvailable ?? this.isAvailable,
      addedAt: addedAt,
    );
  }

  factory CartItem.fromMap(Map<String, dynamic> map, {String? productId}) {
    return CartItem(
      productId: FirestoreMap.str(map, 'productId', productId ?? ''),
      name: FirestoreMap.str(map, 'name'),
      image: FirestoreMap.str(map, 'image'),
      price: FirestoreMap.num2(map, 'price'),
      quantity: FirestoreMap.int2(
        map,
        'quantity',
        1,
      ).clamp(AppConstants.cartQuantityMin, AppConstants.cartQuantityMax),
      sku: FirestoreMap.str(map, 'sku'),
      stock: FirestoreMap.int2(map, 'stock'),
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
      'quantity': quantity,
      'subtotal': subtotal,
      'sku': sku,
      'stock': stock,
      'isAvailable': isAvailable,
      'addedAt': addedAt,
    });
  }

  @override
  String toString() => 'CartItem($productId x$quantity)';
}
