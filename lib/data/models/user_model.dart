import '../../core/constants/app_constants.dart';
import 'firestore_map.dart';

/// A Padma Collections account.
///
/// Stored at `users/{userId}`. Passwords are never stored here — Firebase
/// Authentication owns credentials; this document holds the profile only.
class UserModel {
  const UserModel({
    required this.uid,
    required this.name,
    required this.email,
    this.phone = '',
    this.profileImage = '',
    this.role = UserRole.customer,
    required this.createdAt,
    this.updatedAt,
    this.isActive = true,
    this.fcmToken,
    this.unreadNotifications = 0,
  });

  final String uid;
  final String name;
  final String email;
  final String phone;
  final String profileImage;

  /// Either [UserRole.customer] or [UserRole.admin].
  final String role;
  final DateTime createdAt;
  final DateTime? updatedAt;

  /// Deactivated accounts are blocked by Firestore rules, not just hidden.
  final bool isActive;

  /// Latest device token, used for targeted push notifications.
  final String? fcmToken;

  /// Denormalised unread count so the bell can show a badge cheaply.
  final int unreadNotifications;

  bool get isAdmin => role == UserRole.admin;
  bool get isCustomer => role == UserRole.customer;

  /// First name only — used for greetings like "Hi, Aarav".
  String get firstName => name.trim().split(RegExp(r'\s+')).first;

  UserModel copyWith({
    String? name,
    String? email,
    String? phone,
    String? profileImage,
    String? role,
    DateTime? updatedAt,
    bool? isActive,
    String? fcmToken,
    int? unreadNotifications,
  }) {
    return UserModel(
      uid: uid,
      name: name ?? this.name,
      email: email ?? this.email,
      phone: phone ?? this.phone,
      profileImage: profileImage ?? this.profileImage,
      role: role ?? this.role,
      createdAt: createdAt,
      updatedAt: updatedAt ?? this.updatedAt,
      isActive: isActive ?? this.isActive,
      fcmToken: fcmToken ?? this.fcmToken,
      unreadNotifications: unreadNotifications ?? this.unreadNotifications,
    );
  }

  factory UserModel.fromMap(Map<String, dynamic> map, {String? uid}) {
    return UserModel(
      uid: FirestoreMap.str(map, 'uid', uid ?? ''),
      name: FirestoreMap.str(map, 'name'),
      email: FirestoreMap.str(map, 'email'),
      phone: FirestoreMap.str(map, 'phone'),
      profileImage: FirestoreMap.str(map, 'profileImage'),
      role: _normaliseRole(FirestoreMap.str(map, 'role')),
      createdAt: FirestoreMap.dateTime(map, 'createdAt') ?? DateTime.now(),
      updatedAt: FirestoreMap.dateTime(map, 'updatedAt'),
      isActive: FirestoreMap.boolean(map, 'isActive', true),
      fcmToken: FirestoreMap.strOrNull(map, 'fcmToken'),
      unreadNotifications: FirestoreMap.int2(map, 'unreadNotifications'),
    );
  }

  /// Any unknown/missing role is coerced to `customer` — the app must never
  /// treat an unrecognised value as elevated.
  static String _normaliseRole(String role) =>
      UserRole.isValid(role) ? role : UserRole.customer;

  Map<String, dynamic> toMap() {
    return FirestoreMap.clean(<String, dynamic>{
      'uid': uid,
      'name': name,
      'email': email,
      'phone': phone,
      'profileImage': profileImage,
      'role': role,
      'createdAt': createdAt,
      'updatedAt': updatedAt ?? DateTime.now(),
      'isActive': isActive,
      'fcmToken': fcmToken,
      'unreadNotifications': unreadNotifications,
    });
  }

  @override
  String toString() => 'UserModel($uid, $email, $role)';

  @override
  bool operator ==(Object other) =>
      identical(this, other) || (other is UserModel && other.uid == uid);

  @override
  int get hashCode => uid.hashCode;
}
