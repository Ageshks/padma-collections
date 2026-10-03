// ignore_for_file: must_call_super

import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:get/get.dart';
import 'package:padma/core/routes/app_pages.dart';
import 'package:padma/core/routes/app_routes.dart';
import 'package:padma/core/services/google_sign_in_service.dart';
import 'package:padma/core/services/whatsapp_service.dart';
import 'package:padma/data/repositories/auth_repository.dart';
import 'package:padma/data/repositories/banner_repository.dart';
import 'package:padma/data/repositories/cart_repository.dart';
import 'package:padma/data/repositories/category_repository.dart';
import 'package:padma/data/repositories/notification_repository.dart';
import 'package:padma/data/repositories/order_repository.dart';
import 'package:padma/data/repositories/product_repository.dart';
import 'package:padma/data/repositories/settings_repository.dart';
import 'package:padma/data/repositories/wishlist_repository.dart';
import 'package:padma/modules/auth/auth_controller.dart';
import 'package:padma/modules/cart/cart_controller.dart';
import 'package:padma/modules/common/controllers/app_controller.dart';
import 'package:padma/data/models/models.dart';

void main() {
  setUp(() {
    final _LayoutAuthRepository auth = _LayoutAuthRepository();
    final _LayoutAppController app = _LayoutAppController(authRepository: auth);
    Get.put<AppController>(app);
    Get.put<AuthController>(
      AuthController(authRepository: auth, appController: app),
    );
  });
  tearDown(() {
    Get.reset();
  });

  testWidgets('auth routes render and navigate on a compact phone', (
    WidgetTester tester,
  ) async {
    tester.view.physicalSize = const Size(320, 568);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);

    await tester.pumpWidget(
      MediaQuery(
        data: const MediaQueryData(
          size: Size(320, 568),
          textScaler: TextScaler.linear(1.3),
        ),
        child: GetMaterialApp(
          initialRoute: Routes.login,
          getPages: AppPages.pages,
        ),
      ),
    );
    await tester.pumpAndSettle();
    final Object? loginLayoutError = tester.takeException();
    if (loginLayoutError != null) {
      debugPrint('$loginLayoutError');
      debugDumpRenderTree();
    }
    expect(loginLayoutError, isNull);

    await tester.ensureVisible(find.text('Create an account'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Create an account'));
    await tester.pumpAndSettle();
    expect(find.text('Full name'), findsOneWidget);
    expect(tester.takeException(), isNull);

    await tester.ensureVisible(find.text('Already have an account? Sign in'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Already have an account? Sign in'));
    await tester.pumpAndSettle();
    expect(find.text('Welcome back'), findsOneWidget);

    await tester.ensureVisible(find.text('Forgot Password?'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Forgot Password?'));
    await tester.pumpAndSettle();
    expect(find.text('Send reset link'), findsOneWidget);
    expect(tester.takeException(), isNull);

    await tester.ensureVisible(find.text('Back to sign in'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Back to sign in'));
    await tester.pumpAndSettle();
    await tester.ensureVisible(find.text('Admin Sign In'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Admin Sign In'));
    await tester.pumpAndSettle();
    expect(find.text('Sign In to Admin'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });

  testWidgets('auth controller survives bouncing between auth screens', (
    WidgetTester tester,
  ) async {
    // Regression: AuthController owns the TextEditingControllers behind these
    // fields. It used to be a lazyPut with `fenix`, so GetX disposed (and
    // recreated) it while a mounted TextField still referenced the old
    // instance, producing "A TextEditingController was used after being
    // disposed" on the login screen.
    tester.view.physicalSize = const Size(320, 568);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);

    await tester.pumpWidget(
      GetMaterialApp(initialRoute: Routes.login, getPages: AppPages.pages),
    );
    await tester.pumpAndSettle();
    expect(tester.takeException(), isNull);

    final AuthController controller = Get.find<AuthController>();
    await tester.enterText(find.byType(TextField).first, 'shopper@example.com');
    await tester.pumpAndSettle();

    // Round-trip through the other auth screens, the way a person does when
    // they realise they need to register. `offNamed` replaces rather than
    // stacks, matching how the app actually switches auth screens — register
    // and forgot-password use Get.back, and the admin screen uses offAllNamed.
    // Pushing a second login on top of the first would instead duplicate the
    // form GlobalKey shared through AuthController.
    for (final String route in <String>[
      Routes.register,
      Routes.login,
      Routes.adminLogin,
      Routes.login,
    ]) {
      Get.offNamed<void>(route);
      await tester.pumpAndSettle();
      expect(tester.takeException(), isNull, reason: 'navigating to $route');
    }

    // The controller must still be the same live instance, with working
    // text fields — not a stale or recreated copy.
    expect(Get.find<AuthController>(), same(controller));
    expect(tester.takeException(), isNull);

    await tester.enterText(
      find.byType(TextField).first,
      'still-usable@example.com',
    );
    await tester.pumpAndSettle();
    expect(tester.takeException(), isNull);
    expect(find.text('still-usable@example.com'), findsOneWidget);
  });

  testWidgets('customer workflow screens fit a compact phone', (
    WidgetTester tester,
  ) async {
    tester.view.physicalSize = const Size(320, 568);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);

    final _LayoutCartRepository cart = _LayoutCartRepository();
    Get.put<CartRepository>(cart);
    Get.put<CartController>(
      CartController(
        repository: cart,
        appController: Get.find<AppController>(),
      ),
    );
    Get.put<OrderRepository>(_LayoutOrderRepository());
    Get.put<NotificationRepository>(_LayoutNotificationRepository());

    await tester.pumpWidget(
      GetMaterialApp(initialRoute: Routes.myOrders, getPages: AppPages.pages),
    );
    await tester.pumpAndSettle();
    expect(find.text('No orders yet.'), findsOneWidget);
    expect(tester.takeException(), isNull);

    const List<String> routes = <String>[
      Routes.notifications,
      Routes.editProfile,
      Routes.aboutUs,
      Routes.privacyPolicy,
      Routes.termsConditions,
      Routes.checkout,
      Routes.orderSuccess,
    ];
    for (final String route in routes) {
      Get.toNamed<void>(route);
      await tester.pumpAndSettle();
      expect(tester.takeException(), isNull, reason: 'Route $route');
    }
  });
}

class _LayoutAppController extends AppController {
  _LayoutAppController({required AuthRepository authRepository})
    : super(
        authRepository: authRepository,
        settingsRepository: SettingsRepository(),
        productRepository: ProductRepository(),
        categoryRepository: CategoryRepository(),
        bannerRepository: BannerRepository(),
        notificationRepository: NotificationRepository(),
        whatsappService: WhatsappService(),
        cartRepository: CartRepository(),
        wishlistRepository: WishlistRepository(),
        googleSignInService: GoogleSignInService(),
      );

  @override
  void onInit() {}
}

/// A repository stub with no Firebase app behind it.
///
/// The repositories deliberately resolve `FirebaseAuth.instance` lazily, so an
/// otherwise-empty subclass still throws `[core/no-app]` the moment anything
/// reads the session. Overriding the two accessors the controllers actually
/// consult keeps the stub honest — it reports "signed out" rather than
/// pretending to be in demo mode, which the app no longer has.
class _LayoutAuthRepository extends AuthRepository {
  @override
  String? get currentUid => null;

  @override
  bool get isSignedIn => false;

  @override
  Stream<User?> get authStateChanges => const Stream<User?>.empty();
}

class _LayoutCartRepository extends CartRepository {
  @override
  Stream<List<CartItem>> watchCart(String uid) =>
      Stream<List<CartItem>>.value(const <CartItem>[]);
}

class _LayoutOrderRepository extends OrderRepository {
  @override
  Stream<List<OrderModel>> watchUserOrders(String userId) =>
      Stream<List<OrderModel>>.value(const <OrderModel>[]);
}

class _LayoutNotificationRepository extends NotificationRepository {
  @override
  Stream<List<NotificationModel>> watchForUser({
    required String uid,
    required bool isAdmin,
  }) => Stream<List<NotificationModel>>.value(const <NotificationModel>[]);
}
