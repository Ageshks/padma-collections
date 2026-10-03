import 'dart:async';

import 'package:get/get.dart';

import '../../modules/common/controllers/app_controller.dart';
import '../../modules/auth/auth_controller.dart';
import '../../data/firebase/firebase_options.dart';
import '../../data/firebase/firebase_bootstrap.dart';
import '../../data/repositories/auth_repository.dart';
import '../../data/repositories/banner_repository.dart';
import '../../data/repositories/cart_repository.dart';
import '../../data/repositories/category_repository.dart';
import '../../data/repositories/notification_repository.dart';
import '../../data/repositories/order_repository.dart';
import '../../data/repositories/product_repository.dart';
import '../../data/repositories/settings_repository.dart';
import '../../data/repositories/user_repository.dart';
import '../../data/repositories/wishlist_repository.dart';
import '../services/cloudinary_image_service.dart';
import '../services/connectivity_service.dart';
import '../services/google_sign_in_service.dart';
import '../services/whatsapp_service.dart';

/// Registers every long-lived dependency exactly once, and seeds the demo
/// dataset when the app is running without a Firebase project.
///
/// Registered permanently so repositories (and therefore streams) survive
/// navigation — a controller that created its own repository on dispose would
/// tear down live Firestore listeners.
class InitialBinding extends Bindings {
  @override
  void dependencies() {
    Get.put<ProductRepository>(ProductRepository(), permanent: true);
    Get.put<CategoryRepository>(CategoryRepository(), permanent: true);
    Get.put<BannerRepository>(BannerRepository(), permanent: true);
    Get.put<SettingsRepository>(SettingsRepository(), permanent: true);
    Get.put<AuthRepository>(AuthRepository(), permanent: true);
    Get.put<CartRepository>(CartRepository(), permanent: true);
    Get.put<WishlistRepository>(WishlistRepository(), permanent: true);
    Get.put<OrderRepository>(OrderRepository(), permanent: true);
    Get.put<NotificationRepository>(NotificationRepository(), permanent: true);
    Get.put<UserRepository>(UserRepository(), permanent: true);

    Get.put<WhatsappService>(WhatsappService(), permanent: true);
    Get.put<ConnectivityService>(ConnectivityService(), permanent: true);

    // Google Sign-In needs the Web client id from firebase_options before it
    // can initialise, so the id is handed over here rather than hardcoded.
    GoogleSignInService.webClientId = DefaultFirebaseOptions.hasWebClientId
        ? DefaultFirebaseOptions.webClientId
        : null;
    final GoogleSignInService google = GoogleSignInService();
    Get.put<GoogleSignInService>(google, permanent: true);

    // Register before AppController starts watching settings, so the initial
    // Firestore snapshot can configure uploads instead of being missed.
    if (FirebaseBootstrap.isReady) {
      try {
        Get.put<CloudinaryImageService>(
          CloudinaryImageService(),
          permanent: true,
        );
      } catch (_) {
        // Upload features degrade gracefully; the rest of the app is fine.
      }
    }

    Get.put<AppController>(AppController(), permanent: true);

    // Keep the form controller alive across auth-route transitions so its
    // TextEditingControllers are not disposed while fields remain mounted.
    Get.put<AuthController>(AuthController(), permanent: true);

    // Initialise off the critical path; failures are non-fatal because email
    // and password sign-in remains available.
    unawaited(google.initialize());
  }
}
