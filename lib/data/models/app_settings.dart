import '../../core/constants/app_constants.dart';
import '../../core/constants/cloudinary_config.dart';
import 'cloudinary_image.dart';
import 'firestore_map.dart';

/// Store branding and public contact details.
///
/// Stored at `settings/app`. Nothing in here is hardcoded in the Flutter app —
/// the owner edits these in the admin **App Settings** screen and the change
/// propagates to every customer device on next launch.
class AppSettings {
  const AppSettings({
    this.storeName = AppConstants.fallbackStoreName,
    this.tagline = AppConstants.appTagline,
    this.subtitle = AppConstants.appSubtitle,
    this.description = '',
    this.logoImage,
    this.cloudinaryCloudName = '',
    this.cloudinaryUploadPreset = '',
    this.phone = '',
    this.email = '',
    this.address = '',
    this.whatsappNumber = '',
    this.instagramUrl = '',
    this.facebookUrl = '',
    this.websiteUrl = '',
    this.shippingInformation = '',
    this.termsAndConditions = '',
    this.privacyPolicy = '',
    this.aboutUs = '',
    this.currencySymbol = AppConstants.currencySymbol,
    this.supportHours = '',
    this.fcmEnabled = true,
    this.maintenanceMode = false,
    this.updatedAt,
  });

  final String storeName;
  final String tagline;
  final String subtitle;
  final String description;

  /// Store logo stored in Cloudinary, or null to use the bundled
  /// wordmark from `assets/images/`.
  final CloudinaryImage? logoImage;

  /// The Cloudinary cloud name used to build every delivery URL.
  ///
  /// Public — it is already visible in each URL the app loads — but kept here
  /// rather than compiled into the binary so the account can be changed from
  /// the admin UI without shipping an app update. Empty means "not configured",
  /// which degrades delivery to the stored snapshot URLs instead of breaking.
  ///
  /// The Cloudinary **API secret** is deliberately absent here and must never
  /// be added: it belongs only in the Cloud Function environment.
  final String cloudinaryCloudName;

  /// The Cloudinary **unsigned upload preset** name the app uploads with.
  ///
  /// Public — it is compiled into the app and extractable by anyone — so it is
  /// not treated as a secret. It is read at runtime so the preset can be
  /// rotated in the Cloudinary dashboard without shipping an app release.
  ///
  /// Empty means uploads are unconfigured and the admin form reports a
  /// configuration error rather than failing obscurely.
  final String cloudinaryUploadPreset;

  /// Logo delivery URL. Null when no logo has been uploaded.
  String? get logoUrl {
    final CloudinaryImage? logo = logoImage;
    if (logo == null || !logo.hasImage) return null;
    return logo.urlFor(
      CloudinaryTransform.original,
      cloudName: cloudinaryCloudName,
    );
  }

  final String phone;
  final String email;
  final String address;

  /// Kept here as well as in `settings/whatsapp` for display purposes.
  final String whatsappNumber;

  final String instagramUrl;
  final String facebookUrl;
  final String websiteUrl;
  final String shippingInformation;
  final String termsAndConditions;
  final String privacyPolicy;
  final String aboutUs;
  final String currencySymbol;
  final String supportHours;

  /// Master switch for push notifications.
  final bool fcmEnabled;

  /// When on, customers see a "store closed" notice instead of the catalogue.
  final bool maintenanceMode;

  final DateTime? updatedAt;

  bool get hasSocialLinks =>
      instagramUrl.isNotEmpty ||
      facebookUrl.isNotEmpty ||
      websiteUrl.isNotEmpty;

  AppSettings copyWith({
    String? storeName,
    String? tagline,
    String? subtitle,
    String? description,
    CloudinaryImage? logoImage,
    String? cloudinaryCloudName,
    String? cloudinaryUploadPreset,
    String? phone,
    String? email,
    String? address,
    String? whatsappNumber,
    String? instagramUrl,
    String? facebookUrl,
    String? websiteUrl,
    String? shippingInformation,
    String? termsAndConditions,
    String? privacyPolicy,
    String? aboutUs,
    String? currencySymbol,
    String? supportHours,
    bool? fcmEnabled,
    bool? maintenanceMode,
    DateTime? updatedAt,
  }) {
    return AppSettings(
      storeName: storeName ?? this.storeName,
      tagline: tagline ?? this.tagline,
      subtitle: subtitle ?? this.subtitle,
      description: description ?? this.description,
      logoImage: logoImage ?? this.logoImage,
      cloudinaryCloudName: cloudinaryCloudName ?? this.cloudinaryCloudName,
        cloudinaryUploadPreset:
          cloudinaryUploadPreset ?? this.cloudinaryUploadPreset,
      phone: phone ?? this.phone,
      email: email ?? this.email,
      address: address ?? this.address,
      whatsappNumber: whatsappNumber ?? this.whatsappNumber,
      instagramUrl: instagramUrl ?? this.instagramUrl,
      facebookUrl: facebookUrl ?? this.facebookUrl,
      websiteUrl: websiteUrl ?? this.websiteUrl,
      shippingInformation: shippingInformation ?? this.shippingInformation,
      termsAndConditions: termsAndConditions ?? this.termsAndConditions,
      privacyPolicy: privacyPolicy ?? this.privacyPolicy,
      aboutUs: aboutUs ?? this.aboutUs,
      currencySymbol: currencySymbol ?? this.currencySymbol,
      supportHours: supportHours ?? this.supportHours,
      fcmEnabled: fcmEnabled ?? this.fcmEnabled,
      maintenanceMode: maintenanceMode ?? this.maintenanceMode,
      updatedAt: updatedAt ?? this.updatedAt,
    );
  }

  factory AppSettings.fromMap(Map<String, dynamic> map) {
    return AppSettings(
      storeName: _orDefault(
        FirestoreMap.str(map, 'storeName'),
        AppConstants.fallbackStoreName,
      ),
      tagline: _orDefault(
        FirestoreMap.str(map, 'tagline'),
        AppConstants.appTagline,
      ),
      subtitle: _orDefault(
        FirestoreMap.str(map, 'subtitle'),
        AppConstants.appSubtitle,
      ),
      description: FirestoreMap.str(map, 'description'),
      logoImage: _logoFrom(map),
      cloudinaryCloudName: FirestoreMap.str(
        map,
        CloudinaryConfig.cloudNameField,
      ),
      cloudinaryUploadPreset: FirestoreMap.str(
        map,
        CloudinaryConfig.uploadPresetField,
      ),
      phone: FirestoreMap.str(map, 'phone'),
      email: FirestoreMap.str(map, 'email'),
      address: FirestoreMap.str(map, 'address'),
      whatsappNumber: FirestoreMap.str(map, 'whatsappNumber'),
      instagramUrl: FirestoreMap.str(map, 'instagramUrl'),
      facebookUrl: FirestoreMap.str(map, 'facebookUrl'),
      websiteUrl: FirestoreMap.str(map, 'websiteUrl'),
      shippingInformation: FirestoreMap.str(map, 'shippingInformation'),
      termsAndConditions: FirestoreMap.str(map, 'termsAndConditions'),
      privacyPolicy: FirestoreMap.str(map, 'privacyPolicy'),
      aboutUs: FirestoreMap.str(map, 'aboutUs'),
      currencySymbol: _orDefault(
        FirestoreMap.str(map, 'currencySymbol'),
        AppConstants.currencySymbol,
      ),
      supportHours: FirestoreMap.str(map, 'supportHours'),
      fcmEnabled: FirestoreMap.boolean(map, 'fcmEnabled', true),
      maintenanceMode: FirestoreMap.boolean(map, 'maintenanceMode'),
      updatedAt: FirestoreMap.dateTime(map, 'updatedAt'),
    );
  }

  static String _orDefault(String value, String fallback) =>
      value.trim().isEmpty ? fallback : value;

  /// Reads the store logo, preferring the nested Cloudinary metadata and
  /// falling back to the legacy `logoUrl` string written before migration.
  static CloudinaryImage? _logoFrom(Map<String, dynamic> map) {
    final Object? nested = map['logoImage'];
    if (nested != null) {
      final CloudinaryImage parsed = CloudinaryImage.fromEntry(nested);
      if (parsed.hasImage) return parsed;
    }
    final String legacy = FirestoreMap.str(map, 'logoUrl');
    if (legacy.isEmpty) return null;
    return CloudinaryImage(publicId: '', secureUrl: legacy, isPrimary: true);
  }

  Map<String, dynamic> toMap() {
    return FirestoreMap.clean(<String, dynamic>{
      'storeName': storeName,
      'tagline': tagline,
      'subtitle': subtitle,
      'description': description,
      'logoImage': logoImage?.toMap(),
      CloudinaryConfig.cloudNameField: cloudinaryCloudName,
      CloudinaryConfig.uploadPresetField: cloudinaryUploadPreset,
      'phone': phone,
      'email': email,
      'address': address,
      'whatsappNumber': whatsappNumber,
      'instagramUrl': instagramUrl,
      'facebookUrl': facebookUrl,
      'websiteUrl': websiteUrl,
      'shippingInformation': shippingInformation,
      'termsAndConditions': termsAndConditions,
      'privacyPolicy': privacyPolicy,
      'aboutUs': aboutUs,
      'currencySymbol': currencySymbol,
      'supportHours': supportHours,
      'fcmEnabled': fcmEnabled,
      'maintenanceMode': maintenanceMode,
      'updatedAt': DateTime.now(),
    });
  }

  @override
  String toString() => 'AppSettings($storeName)';
}
