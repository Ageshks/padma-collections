import '../../core/constants/app_constants.dart';
import '../../core/utils/app_formatter.dart';
import 'firestore_map.dart';

/// WhatsApp configuration. Stored at `settings/whatsapp`.
///
/// The admin can change the business number and default message here without
/// shipping an app update — every WhatsApp button in the app reads from this.
class WhatsAppSettings {
  const WhatsAppSettings({
    this.phoneNumber = AppConstants.fallbackWhatsappNumber,
    this.businessName = AppConstants.fallbackStoreName,
    this.defaultMessage = AppConstants.defaultWhatsappMessage,
    this.orderTemplate = '',
    this.autoOpenOnCheckout = true,
    this.updatedAt,
  });

  /// International format, digits only (e.g. 919812345678).
  final String phoneNumber;
  final String businessName;
  final String defaultMessage;

  /// Optional custom order wording. Empty means use the built-in template.
  final String orderTemplate;

  /// When on, placing an order automatically opens WhatsApp.
  final bool autoOpenOnCheckout;

  final DateTime? updatedAt;

  /// The number actually used for `wa.me` links.
  String get normalisedNumber => StringUtils.toWhatsappNumber(phoneNumber);

  /// Name used to open the conversation; falls back to the brand name.
  String get contactName => businessName.trim().isEmpty
      ? AppConstants.fallbackStoreName
      : businessName;

  /// Greeting used by every generated message.
  String get greeting => 'Hello $contactName,';

  /// Default copy when the admin has not written one.
  String get effectiveDefaultMessage => defaultMessage.trim().isEmpty
      ? AppConstants.defaultWhatsappMessage
      : defaultMessage;

  WhatsAppSettings copyWith({
    String? phoneNumber,
    String? businessName,
    String? defaultMessage,
    String? orderTemplate,
    bool? autoOpenOnCheckout,
    DateTime? updatedAt,
  }) {
    return WhatsAppSettings(
      phoneNumber: phoneNumber ?? this.phoneNumber,
      businessName: businessName ?? this.businessName,
      defaultMessage: defaultMessage ?? this.defaultMessage,
      orderTemplate: orderTemplate ?? this.orderTemplate,
      autoOpenOnCheckout: autoOpenOnCheckout ?? this.autoOpenOnCheckout,
      updatedAt: updatedAt ?? this.updatedAt,
    );
  }

  factory WhatsAppSettings.fromMap(Map<String, dynamic> map) {
    return WhatsAppSettings(
      phoneNumber: _orDefault(
        FirestoreMap.str(map, 'phoneNumber'),
        AppConstants.fallbackWhatsappNumber,
      ),
      businessName: _orDefault(
        FirestoreMap.str(map, 'businessName'),
        AppConstants.fallbackStoreName,
      ),
      defaultMessage: _orDefault(
        FirestoreMap.str(map, 'defaultMessage'),
        AppConstants.defaultWhatsappMessage,
      ),
      orderTemplate: FirestoreMap.str(map, 'orderTemplate'),
      autoOpenOnCheckout: FirestoreMap.boolean(map, 'autoOpenOnCheckout', true),
      updatedAt: FirestoreMap.dateTime(map, 'updatedAt'),
    );
  }

  static String _orDefault(String value, String fallback) =>
      value.trim().isEmpty ? fallback : value;

  Map<String, dynamic> toMap() {
    return FirestoreMap.clean(<String, dynamic>{
      'phoneNumber': normalisedNumber,
      'businessName': contactName,
      'defaultMessage': defaultMessage,
      'orderTemplate': orderTemplate,
      'autoOpenOnCheckout': autoOpenOnCheckout,
      'updatedAt': DateTime.now(),
    });
  }

  @override
  String toString() => 'WhatsAppSettings($contactName, $normalisedNumber)';
}
