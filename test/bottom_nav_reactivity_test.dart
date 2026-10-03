// Regression test: the bottom navigation highlight must follow *programmatic*
// tab changes, not just taps on the bar itself.
//
// Tabs are rarely switched only by tapping. "See all" on Home, the empty-cart
// CTA, and the profile shortcuts all call `changeTab()` directly. The shell
// wrapped only the `IndexedStack` in an `Obx`, so those switched the body while
// the bar kept highlighting the previous tab — the body and the bar disagreed.

import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:get/get.dart';
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
import 'package:padma/modules/customer/customer_bindings.dart';
import 'package:padma/modules/customer/customer_shell_view.dart';
import 'package:padma/modules/common/controllers/app_controller.dart';

/// The label the bar shows as selected, read from the bar's own widget rather
/// than from the controller, so the assertion is about the UI.
String? _selectedBarLabel(WidgetTester tester) {
  final NavigationBar bar = tester.widget<NavigationBar>(
    find.byType(NavigationBar),
  );
  const List<String> labels = <String>[
    'Home',
    'Categories',
    'Wishlist',
    'Cart',
    'Profile',
  ];
  return (bar.selectedIndex >= 0 && bar.selectedIndex < labels.length)
      ? labels[bar.selectedIndex]
      : null;
}

void main() {
  setUp(() {
    final AuthRepository auth = _NavAuthRepository();
    Get.put<AppController>(_NavAppController(authRepository: auth));
    Get.put<AuthRepository>(auth);
    Get.put<CartRepository>(_NavCartRepository());
    Get.put<WishlistRepository>(WishlistRepository());
    Get.put<OrderRepository>(OrderRepository());
    Get.put<NotificationRepository>(NotificationRepository());
    Get.put<WhatsappService>(WhatsappService());
    Get.put<CustomerShellController>(_NavShellController());
  });

  tearDown(Get.reset);

  Future<void> pumpShell(WidgetTester tester) async {
    tester.view.physicalSize = const Size(400, 800);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);

    await tester.pumpWidget(const GetMaterialApp(home: CustomerShellView()));
    await tester.pumpAndSettle();
  }

  testWidgets('bar starts on the first tab', (WidgetTester tester) async {
    await pumpShell(tester);
    expect(_selectedBarLabel(tester), 'Home');
  });

  testWidgets('bar follows a programmatic changeTab', (
    WidgetTester tester,
  ) async {
    await pumpShell(tester);
    final CustomerShellController controller =
        Get.find<CustomerShellController>();

    // This is what "See all" on Home and the empty-cart CTA do.
    controller.changeTab(1);
    await tester.pumpAndSettle();
    expect(_selectedBarLabel(tester), 'Categories');

    controller.changeTab(3);
    await tester.pumpAndSettle();
    expect(_selectedBarLabel(tester), 'Cart');

    controller.changeTab(4);
    await tester.pumpAndSettle();
    expect(_selectedBarLabel(tester), 'Profile');
  });

  testWidgets('bar follows selectRoute by name', (WidgetTester tester) async {
    await pumpShell(tester);
    final CustomerShellController controller =
        Get.find<CustomerShellController>();

    // selectRoute() matches full route names, not bare tab labels.
    controller.selectRoute(Routes.wishlist);
    await tester.pumpAndSettle();
    expect(_selectedBarLabel(tester), 'Wishlist');

    controller.selectRoute(Routes.home);
    await tester.pumpAndSettle();
    expect(_selectedBarLabel(tester), 'Home');

    // An unknown route is ignored rather than resetting the selection.
    controller.selectRoute('/not-a-tab');
    await tester.pumpAndSettle();
    expect(_selectedBarLabel(tester), 'Home');
  });

  testWidgets('tapping the bar also moves the selection', (
    WidgetTester tester,
  ) async {
    await pumpShell(tester);

    await tester.tap(find.text('Wishlist'));
    await tester.pumpAndSettle();
    expect(_selectedBarLabel(tester), 'Wishlist');
  });
}

/// Renders the real shell view and the real bottom bar, with trivial tab
/// bodies. The test is about the shell's own reactivity, so the five real tabs
/// (and the Firestore subscriptions they pull in) are stubbed out.
class _NavShellController extends CustomerShellController {
  @override
  List<Widget> get tabs => const <Widget>[
    _StubTab(label: 'Home'),
    _StubTab(label: 'Categories'),
    _StubTab(label: 'Wishlist'),
    _StubTab(label: 'Cart'),
    _StubTab(label: 'Profile'),
  ];
}

class _StubTab extends StatelessWidget {
  const _StubTab({required this.label});

  final String label;

  @override
  Widget build(BuildContext context) => Center(child: Text(label));
}

class _NavAppController extends AppController {
  _NavAppController({required AuthRepository authRepository})
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

  // The real controller subscribes to Firestore on init; the shell under test
  // only needs `cartCount`, so the wiring is skipped.
  @override
  void onInit() {}
}

/// A repository stub with no Firebase app behind it.
///
/// Reports "signed out" rather than reaching for `FirebaseAuth.instance`,
/// which throws `[core/no-app]` under `flutter test`.
class _NavAuthRepository extends AuthRepository {
  @override
  String? get currentUid => null;

  @override
  bool get isSignedIn => false;

  @override
  Stream<User?> get authStateChanges => const Stream<User?>.empty();
}

class _NavCartRepository extends CartRepository {}
