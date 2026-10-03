import '../../core/constants/app_constants.dart';
import 'firestore_map.dart';

/// Where a notification came from.
enum NotificationType {
  orderUpdate,
  promotion,
  newArrival,
  system,
  enquiry,
  account,
}

extension NotificationTypeX on NotificationType {
  String get label {
    switch (this) {
      case NotificationType.orderUpdate:
        return 'Order Update';
      case NotificationType.promotion:
        return 'Offer';
      case NotificationType.newArrival:
        return 'New Arrival';
      case NotificationType.system:
        return 'Store Update';
      case NotificationType.enquiry:
        return 'Enquiry';
      case NotificationType.account:
        return 'Account';
    }
  }

  static NotificationType fromString(String value) {
    for (final NotificationType t in NotificationType.values) {
      if (t.name == value) return t;
    }
    return NotificationType.system;
  }
}

/// An in-app notification. Stored at `notifications/{notificationId}`.
///
/// Carries both `userId` (single recipient) and `audience`, so a broadcast is
/// stored once and matched by rules instead of being duplicated per user.
class NotificationModel {
  const NotificationModel({
    required this.notificationId,
    required this.title,
    required this.message,
    this.type = NotificationType.system,
    this.userId = '',
    this.audience = 'all',
    this.isRead = false,
    this.imageUrl = '',
    this.actionRoute = '',
    this.actionValue = '',
    required this.createdAt,
  });

  final String notificationId;
  final String title;
  final String message;
  final NotificationType type;

  /// Specific recipient. Empty means the whole audience receives it.
  final String userId;

  /// `all`, `customers`, `admins`, or a specific uid.
  final String audience;

  final bool isRead;
  final String imageUrl;

  /// Optional deep link, e.g. an order id to open on tap.
  final String actionRoute;
  final String actionValue;

  final DateTime createdAt;

  bool get isBroadcast => userId.isEmpty;

  /// Role-aware match, used when streaming a user's notification list.
  bool matches({required String uid, required bool isAdmin}) {
    if (isAdmin) return true;
    if (userId.isNotEmpty) return userId == uid;
    switch (audience) {
      case 'all':
        return true;
      case 'customers':
      case 'admins':
        return false;
      default:
        return audience == uid;
    }
  }

  NotificationModel copyWith({
    String? title,
    String? message,
    NotificationType? type,
    String? userId,
    String? audience,
    bool? isRead,
    String? imageUrl,
    String? actionRoute,
    String? actionValue,
  }) {
    return NotificationModel(
      notificationId: notificationId,
      title: title ?? this.title,
      message: message ?? this.message,
      type: type ?? this.type,
      userId: userId ?? this.userId,
      audience: audience ?? this.audience,
      isRead: isRead ?? this.isRead,
      imageUrl: imageUrl ?? this.imageUrl,
      actionRoute: actionRoute ?? this.actionRoute,
      actionValue: actionValue ?? this.actionValue,
      createdAt: createdAt,
    );
  }

  factory NotificationModel.fromMap(
    Map<String, dynamic> map, {
    String? notificationId,
  }) {
    return NotificationModel(
      notificationId: FirestoreMap.str(
        map,
        'notificationId',
        notificationId ?? '',
      ),
      title: FirestoreMap.str(map, 'title'),
      message: FirestoreMap.str(map, 'message'),
      type: NotificationTypeX.fromString(FirestoreMap.str(map, 'type')),
      userId: FirestoreMap.str(map, 'userId'),
      audience: FirestoreMap.str(map, 'audience', 'all'),
      isRead: FirestoreMap.boolean(map, 'isRead'),
      imageUrl: FirestoreMap.str(map, 'imageUrl'),
      actionRoute: FirestoreMap.str(map, 'actionRoute'),
      actionValue: FirestoreMap.str(map, 'actionValue'),
      createdAt: FirestoreMap.dateTime(map, 'createdAt') ?? DateTime.now(),
    );
  }

  Map<String, dynamic> toMap() {
    return FirestoreMap.clean(<String, dynamic>{
      'notificationId': notificationId,
      'title': title,
      'message': message,
      'type': type.name,
      'userId': userId,
      'audience': audience,
      'isRead': isRead,
      'imageUrl': imageUrl,
      'actionRoute': actionRoute,
      'actionValue': actionValue,
      'createdAt': createdAt,
    });
  }

  @override
  String toString() => 'NotificationModel($notificationId, $title)';
}

/// Order statuses that generate an automatic customer notification.
class OrderNotificationCopy {
  OrderNotificationCopy._();

  static String titleFor(String status) {
    switch (status) {
      case OrderStatus.pending:
        return 'Order received';
      case OrderStatus.confirmed:
        return 'Order confirmed';
      case OrderStatus.processing:
        return 'Order processing';
      case OrderStatus.readyToShip:
        return 'Ready to ship';
      case OrderStatus.shipped:
        return 'Order shipped';
      case OrderStatus.delivered:
        return 'Order delivered';
      case OrderStatus.cancelled:
        return 'Order cancelled';
      default:
        return 'Order update';
    }
  }

  static String messageFor(String status, String orderNumber) {
    switch (status) {
      case OrderStatus.pending:
        return 'We have received your order $orderNumber and will confirm it '
            'shortly.';
      case OrderStatus.confirmed:
        return 'Your order $orderNumber has been confirmed. We are preparing it '
            'for you.';
      case OrderStatus.processing:
        return 'Your order $orderNumber is being prepared with care.';
      case OrderStatus.readyToShip:
        return 'Your order $orderNumber is packed and ready to ship.';
      case OrderStatus.shipped:
        return 'Your order $orderNumber is on its way.';
      case OrderStatus.delivered:
        return 'Your order $orderNumber has been delivered. Thank you for '
            'shopping with us!';
      case OrderStatus.cancelled:
        return 'Your order $orderNumber has been cancelled. Please contact us '
            'if you need help.';
      default:
        return 'Your order $orderNumber has been updated.';
    }
  }
}
