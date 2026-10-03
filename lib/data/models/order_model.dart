import '../../core/constants/app_constants.dart';
import 'firestore_map.dart';

/// A single line in an order. Stored as a nested map inside the order
/// document — deliberately denormalised so an order never breaks when a
/// product is later renamed, repriced or deleted.
class OrderItem {
  const OrderItem({
    required this.productId,
    required this.name,
    this.image = '',
    this.price = 0,
    this.quantity = 1,
    this.sku = '',
    this.categoryName = '',
  });

  final String productId;
  final String name;
  final String image;

  /// Unit price captured at the time of ordering.
  final double price;

  final int quantity;
  final String sku;
  final String categoryName;

  double get subtotal => price * quantity;

  OrderItem copyWith({
    String? name,
    String? image,
    double? price,
    int? quantity,
  }) {
    return OrderItem(
      productId: productId,
      name: name ?? this.name,
      image: image ?? this.image,
      price: price ?? this.price,
      quantity: quantity ?? this.quantity,
      sku: sku,
      categoryName: categoryName,
    );
  }

  factory OrderItem.fromMap(Map<String, dynamic> map) {
    return OrderItem(
      productId: FirestoreMap.str(map, 'productId'),
      name: FirestoreMap.str(map, 'name'),
      image: FirestoreMap.str(map, 'image'),
      price: FirestoreMap.num2(map, 'price'),
      quantity: FirestoreMap.int2(map, 'quantity', 1),
      sku: FirestoreMap.str(map, 'sku'),
      categoryName: FirestoreMap.str(map, 'categoryName'),
    );
  }

  Map<String, dynamic> toMap() {
    return FirestoreMap.clean(<String, dynamic>{
      'productId': productId,
      'name': name,
      'image': image,
      'price': price,
      'quantity': quantity,
      'sku': sku,
      'categoryName': categoryName,
    });
  }
}

/// A customer order / enquiry. Stored at `orders/{orderId}`.
///
/// There is intentionally **no payment gateway**: the customer submits this
/// request and then confirms it over WhatsApp with the seller.
class OrderModel {
  const OrderModel({
    required this.orderId,
    required this.userId,
    this.orderNumber = '',
    this.customerName = '',
    this.phone = '',
    this.address = '',
    this.items = const <OrderItem>[],
    this.subtotal = 0,
    this.makingCharge = 0,
    this.discount = 0,
    this.tax = 0,
    this.shippingCharge = 0,
    this.total = 0,
    this.customerNote = '',
    this.status = OrderStatus.pending,
    this.statusHistory = const <OrderStatusEntry>[],
    this.isWhatsappSent = false,
    required this.createdAt,
    this.updatedAt,
  });

  final String orderId;
  final String userId;

  /// Human-friendly reference shown to the customer, e.g. "PC-2417".
  final String orderNumber;

  final String customerName;
  final String phone;
  final String address;
  final List<OrderItem> items;

  final double subtotal;
  final double makingCharge;
  final double discount;
  final double tax;
  final double shippingCharge;
  final double total;

  final String customerNote;
  final String status;
  final List<OrderStatusEntry> statusHistory;

  /// Tracks whether the customer followed through on the WhatsApp handoff.
  final bool isWhatsappSent;

  final DateTime createdAt;
  final DateTime? updatedAt;

  int get itemCount =>
      items.fold<int>(0, (int s, OrderItem i) => s + i.quantity);

  bool get isCancelled => status == OrderStatus.cancelled;
  bool get isDelivered => status == OrderStatus.delivered;
  bool get isActive => OrderStatus.active.contains(status);

  /// Next status the admin is most likely to pick.
  String? get nextStatus => OrderStatus.next(status);

  OrderModel copyWith({
    String? orderId,
    String? orderNumber,
    String? customerName,
    String? phone,
    String? address,
    List<OrderItem>? items,
    double? subtotal,
    double? makingCharge,
    double? discount,
    double? tax,
    double? shippingCharge,
    double? total,
    String? customerNote,
    String? status,
    List<OrderStatusEntry>? statusHistory,
    bool? isWhatsappSent,
    DateTime? updatedAt,
  }) {
    return OrderModel(
      orderId: orderId ?? this.orderId,
      userId: userId,
      orderNumber: orderNumber ?? this.orderNumber,
      customerName: customerName ?? this.customerName,
      phone: phone ?? this.phone,
      address: address ?? this.address,
      items: items ?? this.items,
      subtotal: subtotal ?? this.subtotal,
      makingCharge: makingCharge ?? this.makingCharge,
      discount: discount ?? this.discount,
      tax: tax ?? this.tax,
      shippingCharge: shippingCharge ?? this.shippingCharge,
      total: total ?? this.total,
      customerNote: customerNote ?? this.customerNote,
      status: status ?? this.status,
      statusHistory: statusHistory ?? this.statusHistory,
      isWhatsappSent: isWhatsappSent ?? this.isWhatsappSent,
      createdAt: createdAt,
      updatedAt: updatedAt ?? this.updatedAt,
    );
  }

  /// Recomputes every money field from [items], so totals can never drift
  /// out of sync with the line items.
  OrderModel recalculated() {
    final double newSubtotal = items.fold<double>(
      0,
      (double s, OrderItem i) => s + i.subtotal,
    );
    return copyWith(
      subtotal: newSubtotal,
      total: newSubtotal + makingCharge - discount + tax + shippingCharge,
    );
  }

  factory OrderModel.fromMap(Map<String, dynamic> map, {String? orderId}) {
    return OrderModel(
      orderId: FirestoreMap.str(map, 'orderId', orderId ?? ''),
      userId: FirestoreMap.str(map, 'userId'),
      orderNumber: FirestoreMap.str(map, 'orderNumber'),
      customerName: FirestoreMap.str(map, 'customerName'),
      phone: FirestoreMap.str(map, 'phone'),
      address: FirestoreMap.str(map, 'address'),
      items: FirestoreMap.mapList(
        map,
        'items',
      ).map(OrderItem.fromMap).toList(growable: false),
      subtotal: FirestoreMap.num2(map, 'subtotal'),
      makingCharge: FirestoreMap.num2(map, 'makingCharge'),
      discount: FirestoreMap.num2(map, 'discount'),
      tax: FirestoreMap.num2(map, 'tax'),
      shippingCharge: FirestoreMap.num2(map, 'shippingCharge'),
      total: FirestoreMap.num2(map, 'total'),
      customerNote: FirestoreMap.str(map, 'customerNote'),
      status: _statusOrDefault(FirestoreMap.str(map, 'status')),
      statusHistory: FirestoreMap.mapList(
        map,
        'statusHistory',
      ).map(OrderStatusEntry.fromMap).toList(growable: false),
      isWhatsappSent: FirestoreMap.boolean(map, 'isWhatsappSent'),
      createdAt: FirestoreMap.dateTime(map, 'createdAt') ?? DateTime.now(),
      updatedAt: FirestoreMap.dateTime(map, 'updatedAt'),
    );
  }

  /// Unknown statuses collapse to Pending rather than breaking the UI.
  static String _statusOrDefault(String value) =>
      OrderStatus.all.contains(value) ? value : OrderStatus.pending;

  Map<String, dynamic> toMap() {
    return FirestoreMap.clean(<String, dynamic>{
      'orderId': orderId,
      'userId': userId,
      'orderNumber': orderNumber,
      'customerName': customerName,
      'phone': phone,
      'address': address,
      'items': items.map((OrderItem i) => i.toMap()).toList(),
      'subtotal': subtotal,
      'makingCharge': makingCharge,
      'discount': discount,
      'tax': tax,
      'shippingCharge': shippingCharge,
      'total': total,
      'customerNote': customerNote,
      'status': status,
      'statusHistory': statusHistory
          .map((OrderStatusEntry e) => e.toMap())
          .toList(),
      'isWhatsappSent': isWhatsappSent,
      'createdAt': createdAt,
      'updatedAt': updatedAt ?? DateTime.now(),
    });
  }

  @override
  String toString() => 'OrderModel($orderId, $orderNumber, $status)';
}

/// One entry in an order's status timeline.
class OrderStatusEntry {
  const OrderStatusEntry({
    required this.status,
    required this.at,
    this.note = '',
  });

  final String status;
  final DateTime at;
  final String note;

  factory OrderStatusEntry.fromMap(Map<String, dynamic> map) {
    return OrderStatusEntry(
      status: FirestoreMap.str(map, 'status'),
      at: FirestoreMap.dateTime(map, 'at') ?? DateTime.now(),
      note: FirestoreMap.str(map, 'note'),
    );
  }

  Map<String, dynamic> toMap() {
    return FirestoreMap.clean(<String, dynamic>{
      'status': status,
      'at': at,
      'note': note,
    });
  }
}
