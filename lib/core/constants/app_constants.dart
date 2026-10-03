/// Static, non-business app configuration.
///
/// IMPORTANT: business contact details (store name, phone, WhatsApp number,
/// address, social links…) are **never** hardcoded here. They live in
/// Firestore under `settings/app` and `settings/whatsapp` so the owner can
/// change them without shipping an app update. See `AppSettings`.
class AppConstants {
  AppConstants._();

  static const String appName = 'Padma Collections';
  static const String appSubtitle = 'Imitation Jewellery';
  static const String appTagline = 'Elegance That Belongs to You';

  /// Shown in the store when Firestore has no branding configured yet.
  static const String fallbackStoreName = 'Padma Collections';

  static const String currencySymbol = '₹';
  static const String defaultCountryCode = '+91';

  /// Firestore collection names (single source of truth for queries + rules).
  static const String usersCollection = 'users';
  static const String productsCollection = 'products';
  static const String categoriesCollection = 'categories';
  static const String bannersCollection = 'banners';
  static const String ordersCollection = 'orders';
  static const String settingsCollection = 'settings';
  static const String notificationsCollection = 'notifications';
  static const String wishlistCollection = 'wishlist';
  static const String cartCollection = 'cart';
  static const String fcmTokensCollection = 'fcmTokens';

  /// Documents inside the `settings` collection.
  static const String settingsApp = 'app';
  static const String settingsRates = 'rates';
  static const String settingsWhatsapp = 'whatsapp';

  /// Storage paths.
  static const String storageProducts = 'products';
  static const String storageCategories = 'categories';
  static const String storageBanners = 'banners';
  static const String storageUsers = 'users';

  /// How long a product stays "new" when automatic new-arrival detection is on.
  static const int defaultNewArrivalDays = 30;

  /// Default WhatsApp copy used until the admin customises it.
  static const String defaultWhatsappMessage =
      'Hello Padma Collections, I would like to know more about your jewellery products.';

  /// Fallback used only if the admin has not set a number yet.
  static const String fallbackWhatsappNumber = '919999999999';

  static const int cartQuantityMin = 1;
  static const int cartQuantityMax = 20;
}

/// User roles. Registration is always [customer]; only an existing admin can
/// create or promote an [admin] account (enforced by Firestore rules).
class UserRole {
  UserRole._();

  static const String customer = 'customer';
  static const String admin = 'admin';

  static bool isValid(String? role) => role == customer || role == admin;
}

/// Firestore-backed order lifecycle.
class OrderStatus {
  OrderStatus._();

  static const String pending = 'Pending';
  static const String confirmed = 'Confirmed';
  static const String processing = 'Processing';
  static const String readyToShip = 'Ready to Ship';
  static const String shipped = 'Shipped';
  static const String delivered = 'Delivered';
  static const String cancelled = 'Cancelled';

  static const List<String> all = <String>[
    pending,
    confirmed,
    processing,
    readyToShip,
    shipped,
    delivered,
    cancelled,
  ];

  /// Statuses that still count as "open work" for the admin dashboard.
  static const List<String> active = <String>[
    pending,
    confirmed,
    processing,
    readyToShip,
    shipped,
  ];

  /// Next status an admin is most likely to pick, used for the quick action.
  static String? next(String status) {
    final int i = all.indexOf(status);
    if (i == -1 || i == all.length - 2) return null;
    return all[i + 1];
  }

  static bool isTerminal(String status) =>
      status == delivered || status == cancelled;
}

/// Product sort options exposed on the search/listing screen.
enum ProductSort {
  newest('Newest'),
  priceLowToHigh('Price: Low to High'),
  priceHighToLow('Price: High to Low'),
  popular('Popular');

  const ProductSort(this.label);
  final String label;
}

/// Bundled brand artwork.
///
/// Every path here is a transparent PNG derived from the uploaded
/// `assets/images/logo.png` by `tool/generate_logo_assets.py`, which strips the
/// photographic navy backdrop that would otherwise render as a hard rectangle
/// on the app's cream surfaces.
class AppAssets {
  AppAssets._();

  /// The crest alone — compact headers, avatars and chips.
  static const String logoMark = 'assets/images/logo_mark.png';

  /// The "PADMA COLLECTIONS" lettering — light and cream surfaces.
  static const String logoWordmark = 'assets/images/logo_wordmark.png';

  /// Crest above the wordmark — the full lockup for splash and sign-in.
  static const String logoFull = 'assets/images/logo_full.png';

  /// 1024x1024 launcher icon source (navy plate + centred crest).
  static const String appIcon = 'assets/images/icon.png';
}

/// Bundle keys for SharedPreferences.
class StorageKeys {
  StorageKeys._();

  static const String fcmEnabled = 'padma_fcm_enabled';
}
