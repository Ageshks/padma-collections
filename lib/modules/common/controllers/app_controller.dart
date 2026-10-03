import 'dart:async';

import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:get/get.dart';

import '../../../core/constants/app_colors.dart';
import '../../../core/constants/cloudinary_config.dart';
import '../../../core/services/cloudinary_image_service.dart';
import '../../../core/services/google_sign_in_service.dart';
import '../../../core/services/whatsapp_service.dart';
import '../../../core/utils/error_handler.dart';
import '../../../data/models/models.dart';
import '../../../data/repositories/auth_repository.dart';
import '../../../data/repositories/banner_repository.dart';
import '../../../data/repositories/cart_repository.dart';
import '../../../data/repositories/category_repository.dart';
import '../../../data/repositories/notification_repository.dart';
import '../../../data/repositories/product_repository.dart';
import '../../../data/repositories/settings_repository.dart';
import '../../../data/repositories/wishlist_repository.dart';
import '../../cart/cart_controller.dart';
import '../../wishlist/wishlist_controller.dart';

/// App-wide session and configuration.
///
/// Holds the signed-in user, live store settings and notification counters.
/// Registered permanently so every screen reads from the same source of truth.
class AppController extends GetxController {
  AppController({
    AuthRepository? authRepository,
    SettingsRepository? settingsRepository,
    ProductRepository? productRepository,
    CategoryRepository? categoryRepository,
    BannerRepository? bannerRepository,
    NotificationRepository? notificationRepository,
    WhatsappService? whatsappService,
    CartRepository? cartRepository,
    WishlistRepository? wishlistRepository,
    GoogleSignInService? googleSignInService,
  }) : _auth = authRepository ?? Get.find<AuthRepository>(),
       _settings = settingsRepository ?? Get.find<SettingsRepository>(),
       _products = productRepository ?? Get.find<ProductRepository>(),
       _categories = categoryRepository ?? Get.find<CategoryRepository>(),
       _banners = bannerRepository ?? Get.find<BannerRepository>(),
       _notifications =
           notificationRepository ?? Get.find<NotificationRepository>(),
       _whatsapp = whatsappService ?? Get.find<WhatsappService>(),
       _cart = cartRepository ?? Get.find<CartRepository>(),
       _wishlist = wishlistRepository ?? Get.find<WishlistRepository>(),
       _google = googleSignInService ?? Get.find<GoogleSignInService>();

  final AuthRepository _auth;
  final SettingsRepository _settings;
  final ProductRepository _products;
  final CategoryRepository _categories;
  final BannerRepository _banners;
  final NotificationRepository _notifications;
  final WhatsappService _whatsapp;
  final CartRepository _cart;
  final WishlistRepository _wishlist;
  final GoogleSignInService _google;

  // ---------------------------------------------------------------------------
  // Observable state
  // ---------------------------------------------------------------------------

  final Rxn<UserModel> currentUser = Rxn<UserModel>();
  final RxBool isLoading = false.obs;

  /// True until the initial session restore finishes — drives the splash.
  final RxBool isInitialising = true.obs;

  final Rx<AppSettings> settings = const AppSettings().obs;
  final Rx<WhatsAppSettings> whatsappSettings = const WhatsAppSettings().obs;
  final Rx<RateSettings> rateSettings = const RateSettings().obs;

  final RxInt unreadNotifications = 0.obs;

  /// Total number of distinct lines in the cart, shown on the tab badge.
  final RxInt cartCount = 0.obs;

  /// Total number of saved wishlist items, shown on the wishlist badge.
  final RxInt wishlistCount = 0.obs;

  StreamSubscription<User?>? _authSub;
  StreamSubscription<List<CartItem>>? _cartSub;
  StreamSubscription<List<WishlistItem>>? _wishlistSub;

  // ---------------------------------------------------------------------------
  // Derived getters
  // ---------------------------------------------------------------------------

  UserModel? get user => currentUser.value;

  String get uid => currentUser.value?.uid ?? _auth.currentUid ?? '';

  bool get isSignedIn => currentUser.value != null || _auth.isSignedIn;

  bool get isAdmin =>
      currentUser.value?.isAdmin == true && currentUser.value?.isActive == true;

  /// Store name, falling back to the brand default until settings load.
  String get storeName => settings.value.storeName;

  String get tagline => settings.value.tagline;

  /// True when the admin has put the store into maintenance mode.
  bool get isMaintenance => settings.value.maintenanceMode;

  // ---------------------------------------------------------------------------
  // Lifecycle
  // ---------------------------------------------------------------------------

  @override
  void onInit() {
    super.onInit();
    _watchSettings();
    _watchCartAndWishlist();
    _restoreSession();
  }

  @override
  void onClose() {
    _authSub?.cancel();
    _cartSub?.cancel();
    _wishlistSub?.cancel();
    super.onClose();
  }

  /// Keeps the cart and wishlist badge counts in sync for the current user.
  ///
  /// This also re-binds [CartController] and [WishlistController]. Both are
  /// registered `permanent: true` and hold the *actual* cart and wishlist
  /// items, so without this they stayed bound to whoever was signed in at
  /// launch — a customer signing in later saw an empty cart, and signing out
  /// left the previous customer's items on screen.
  void _watchCartAndWishlist() {
    _cartSub?.cancel();
    _wishlistSub?.cancel();

    // The shared controllers read `currentUser` themselves, so rebind them
    // after it has been updated for this auth event.
    _rebindAuthScoped();

    final String uid = currentUid;
    if (uid.isEmpty) {
      cartCount.value = 0;
      wishlistCount.value = 0;
      return;
    }

    _cartSub = _cart
        .watchCart(uid)
        .listen(
          (List<CartItem> items) {
            cartCount.value = items.length;
          },
          onError: (Object _) {
            cartCount.value = 0;
          },
        );
    _wishlistSub = _wishlist
        .watchWishlist(uid)
        .listen(
          (List<WishlistItem> items) {
            wishlistCount.value = items.length;
          },
          onError: (Object _) {
            wishlistCount.value = 0;
          },
        );
  }

  /// uid of the signed-in user, or empty when signed out.
  String get currentUid => currentUser.value?.uid ?? _auth.currentUid ?? '';

  /// Rebinds the cart and wishlist controllers to whoever is signed in now.
  ///
  /// Both are registered `permanent: true` and own the *actual* cart and
  /// wishlist items, so they are not recreated on sign-in. Without this they
  /// stayed bound to whoever was signed in at launch: a customer signing in
  /// later saw an empty cart, and after a sign-out the previous customer's
  /// items stayed on screen.
  ///
  /// Resolved lazily because the customer shell — and therefore these
  /// controllers — does not exist on the admin side.
  void _rebindAuthScoped() {
    if (Get.isRegistered<CartController>()) {
      Get.find<CartController>().bindToUser();
    }
    if (Get.isRegistered<WishlistController>()) {
      Get.find<WishlistController>().bindToUser();
    }
  }

  /// Restores the previous session, if any.
  void _restoreSession() {
    _authSub = _auth.authStateChanges.listen((User? firebaseUser) async {
      if (firebaseUser == null) {
        currentUser.value = null;
        _watchCartAndWishlist();
        isInitialising.value = false;
        return;
      }
      try {
        final UserModel profile = await _auth.fetchProfile(firebaseUser.uid);
        if (profile.isActive) {
          currentUser.value = profile;
        } else {
          await _auth.logout();
          currentUser.value = null;
        }
      } catch (e) {
        currentUser.value = null;
      } finally {
        _watchCartAndWishlist();
        isInitialising.value = false;
      }
      unawaited(refreshUnreadCount());
    }, onError: (_) => isInitialising.value = false);
  }

  void _watchSettings() {
    _settings.watchAppSettings().listen((AppSettings v) {
      settings.value = v;
      _applyCloudinaryAccount(v);
    });
    _settings.watchWhatsAppSettings().listen(
      (WhatsAppSettings v) => whatsappSettings.value = v,
    );
    _settings.watchRateSettings().listen(
      (RateSettings v) => rateSettings.value = v,
    );
  }

  /// Publishes the Cloudinary cloud name to the image layer.
  ///
  /// Delivery URLs are built as
  /// `https://res.cloudinary.com/{cloud}/image/upload/{transform}/{publicId}`,
  /// so every image widget needs this value. Keeping it in `settings/app` means
  /// the owner can move the Cloudinary account without shipping an app update.
  ///
  /// This is a public identifier — it is already visible in every URL the app
  /// loads. The Cloudinary API secret is never handled here; it lives only in
  /// the Cloud Function environment.
  void _applyCloudinaryAccount(AppSettings value) {
    CloudinaryDelivery.cloudName = value.cloudinaryCloudName;

    // Keep the upload service in step so it can build the URLs it stores.
    if (Get.isRegistered<CloudinaryImageService>()) {
      final CloudinaryImageService images = Get.find<CloudinaryImageService>();
      images.cloudName = value.cloudinaryCloudName;
      // The preset is public (it ships in the app), but it is loaded at runtime
      // so it can be rotated in the dashboard without an app release.
      images.uploadPreset = value.cloudinaryUploadPreset;
    }
  }

  // ---------------------------------------------------------------------------
  // Session actions
  // ---------------------------------------------------------------------------

  /// Signs in and stores the resulting profile.
  Future<UserModel> signIn({
    required String email,
    required String password,
  }) async {
    isLoading.value = true;
    try {
      final UserModel user = await _auth.login(
        email: email,
        password: password,
      );
      currentUser.value = user;
      _watchCartAndWishlist();
      unawaited(refreshUnreadCount());
      return user;
    } finally {
      isLoading.value = false;
    }
  }

  /// Signs in with Google, creating the profile on first use.
  ///
  /// Returns the signed-in user so the caller can route to the right app —
  /// admins land on the dashboard, customers in the shop.
  Future<UserModel> signInWithGoogle() async {
    isLoading.value = true;
    try {
      final GoogleAuthResult result = await _google.signIn();
      final UserModel user = await _auth.loginWithGoogle(
        idToken: result.idToken,
        fallbackName: result.displayName,
        fallbackEmail: result.email,
        photoUrl: result.photoUrl,
      );
      currentUser.value = user;
      _watchCartAndWishlist();
      unawaited(refreshUnreadCount());
      return user;
    } finally {
      isLoading.value = false;
    }
  }

  /// Whether the Google button should be shown at all.
  /// Whether the Google sign-in button should be offered.
  ///
  /// Reactive on purpose: initialisation completes after the first frame, so
  /// the login screen has to be able to rebuild once it succeeds.
  RxBool get isGoogleSignInAvailable => _google.isReady;

  /// Registers a new customer. The role is always `customer`.
  Future<UserModel> register({
    required String name,
    required String email,
    required String password,
    String phone = '',
  }) async {
    isLoading.value = true;
    try {
      final UserModel user = await _auth.register(
        name: name,
        email: email,
        password: password,
        phone: phone,
      );
      currentUser.value = user;
      _watchCartAndWishlist();
      unawaited(refreshUnreadCount());
      return user;
    } finally {
      isLoading.value = false;
    }
  }

  Future<void> signOut() async {
    await _auth.logout();
    currentUser.value = null;
    _watchCartAndWishlist();
    unreadNotifications.value = 0;
  }

  Future<void> refreshProfile() async {
    final String id = uid;
    if (id.isEmpty) return;
    try {
      currentUser.value = await _auth.fetchProfile(id);
    } catch (_) {
      // Keep the existing profile if the refresh fails.
    }
  }

  Future<void> updateProfile({
    String? name,
    String? phone,
    String? profileImage,
  }) async {
    await _auth.updateProfile(
      name: name,
      phone: phone,
      profileImage: profileImage,
    );
    await refreshProfile();
  }

  // ---------------------------------------------------------------------------
  // Catalogue access, shared with feature controllers
  // ---------------------------------------------------------------------------

  ProductRepository get products => _products;

  CategoryRepository get categories => _categories;

  BannerRepository get banners => _banners;

  // ---------------------------------------------------------------------------
  // Notifications
  // ---------------------------------------------------------------------------

  Future<void> refreshUnreadCount() async {
    final String id = uid;
    if (id.isEmpty) {
      unreadNotifications.value = 0;
      return;
    }
    try {
      unreadNotifications.value = await _notifications.unreadCount(
        uid: id,
        isAdmin: isAdmin,
      );
    } catch (e) {
      // A badge is not worth surfacing an error for.
      if (AppErrorHandler.isRetryable(e)) unreadNotifications.value = 0;
    }
  }

  // ---------------------------------------------------------------------------
  // WhatsApp helpers
  // ---------------------------------------------------------------------------

  /// Opens WhatsApp with the store's default greeting.
  Future<bool> openWhatsAppGeneral() async {
    final WhatsAppSettings config = whatsappSettings.value;
    final bool opened = await _whatsapp.open(
      number: config.normalisedNumber,
      message: _whatsapp.generalMessage(config),
    );
    if (!opened) _showWhatsAppUnavailable();
    return opened;
  }

  /// Opens WhatsApp with a product-specific enquiry.
  Future<bool> openWhatsAppProduct(ProductModel product, int quantity) async {
    final WhatsAppSettings config = whatsappSettings.value;
    final bool opened = await _whatsapp.open(
      number: config.normalisedNumber,
      message: _whatsapp.productMessage(
        product: product,
        quantity: quantity,
        settings: config,
      ),
    );
    if (!opened) _showWhatsAppUnavailable();
    return opened;
  }

  /// Opens WhatsApp with a full order enquiry.
  Future<bool> openWhatsAppOrder({
    required List<CartItem> items,
    required double subtotal,
    required double total,
    String customerName = '',
    String phone = '',
    String address = '',
    String customerNote = '',
  }) async {
    final WhatsAppSettings config = whatsappSettings.value;
    final bool opened = await _whatsapp.open(
      number: config.normalisedNumber,
      message: _whatsapp.orderMessage(
        items: items,
        subtotal: subtotal,
        total: total,
        settings: config,
        customerName: customerName,
        phone: phone,
        address: address,
        customerNote: customerNote,
      ),
    );
    if (!opened) _showWhatsAppUnavailable();
    return opened;
  }

  /// Follow-up message for an existing order.
  Future<bool> openWhatsAppOrderFollowUp(OrderModel order) async {
    final WhatsAppSettings config = whatsappSettings.value;
    final bool opened = await _whatsapp.open(
      number: config.normalisedNumber,
      message: _whatsapp.orderFollowUpMessage(order: order, settings: config),
    );
    if (!opened) _showWhatsAppUnavailable();
    return opened;
  }

  void _showWhatsAppUnavailable() {
    Get.rawSnackbar(
      message: 'WhatsApp could not be opened. Please try again.',
      snackPosition: SnackPosition.BOTTOM,
      backgroundColor: AppColors.danger,
      margin: const EdgeInsets.all(12),
      borderRadius: 8,
      duration: const Duration(seconds: 3),
    );
  }
}
