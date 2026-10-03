// Regression tests for two controller-lifecycle bugs found in an audit of every
// controller in the app.
//
// 1. CartController / WishlistController subscribed to Firestore once, in
//    onInit, and are registered `permanent: true` so they are never recreated
//    on sign-in. That left them bound to whoever was signed in at launch: a
//    customer signing in later saw a permanently empty cart, and signing out
//    left the previous customer's items on screen.
//
// 2. HomeController.load() appended to its subscription list without clearing
//    it, so every pull-to-refresh left seven more live subscriptions behind.
import 'dart:async';

import 'package:firebase_auth/firebase_auth.dart';

import 'package:flutter_test/flutter_test.dart';
import 'package:padma/core/services/google_sign_in_service.dart';
import 'package:padma/core/services/whatsapp_service.dart';
import 'package:padma/data/models/models.dart';
import 'package:padma/data/repositories/auth_repository.dart';
import 'package:padma/data/repositories/banner_repository.dart';
import 'package:padma/data/repositories/cart_repository.dart';
import 'package:padma/data/repositories/category_repository.dart';
import 'package:padma/data/repositories/notification_repository.dart';
import 'package:padma/data/repositories/product_repository.dart';
import 'package:padma/data/repositories/settings_repository.dart';
import 'package:padma/data/repositories/wishlist_repository.dart';
import 'package:padma/modules/cart/cart_controller.dart';
import 'package:padma/modules/common/controllers/app_controller.dart';
import 'package:padma/modules/home/home_controller.dart';

CartItem _item(String id) => CartItem(
  productId: id,
  name: 'Ring $id',
  price: 1000,
  quantity: 1,
  addedAt: DateTime(2026),
);

/// Cart repository that records which uid was asked for and how many streams
/// are still open, so a test can prove the controller re-reads for the *new*
/// user rather than staying bound to the first.
class _RecordingCartRepository extends CartRepository {
  final List<String> requestedUids = <String>[];
  final Map<String, List<CartItem>> cartsByUid = <String, List<CartItem>>{};

  int liveSubscriptions = 0;
  int cancelledSubscriptions = 0;

  @override
  Stream<List<CartItem>> watchCart(String uid) {
    requestedUids.add(uid);
    liveSubscriptions++;
    late StreamController<List<CartItem>> controller;
    controller = StreamController<List<CartItem>>(
      onCancel: () {
        cancelledSubscriptions++;
        liveSubscriptions--;
      },
    );
    controller.add(cartsByUid[uid] ?? const <CartItem>[]);
    return controller.stream;
  }
}

/// Stands in for the signed-in session so the uid can be changed mid-test.
///
/// Every dependency is passed explicitly: `AppController` falls back to
/// `Get.find` for anything omitted, which would make these lifecycle tests
/// depend on whatever happens to be registered globally.
class _FakeAppController extends AppController {
  _FakeAppController({required super.authRepository})
    : super(
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

  String fakeUid = '';

  @override
  String get currentUid => fakeUid;

  @override
  void onInit() {}
}

/// A repository stub with no Firebase app behind it.
///
/// Reports "signed out" rather than reaching for `FirebaseAuth.instance`,
/// which throws `[core/no-app]` under `flutter test`.
class _NoopAuthRepository extends AuthRepository {
  @override
  String? get currentUid => null;

  @override
  bool get isSignedIn => false;

  @override
  Stream<User?> get authStateChanges => const Stream<User?>.empty();
}

void main() {
  CartController buildCart(
    _RecordingCartRepository repo,
    _FakeAppController app,
  ) {
    return CartController(repository: repo, appController: app);
  }

  group('CartController rebinds to whoever is signed in', () {
    test('a later sign-in is picked up, not stuck on the first', () async {
      final _RecordingCartRepository repo = _RecordingCartRepository();
      final _FakeAppController app = _FakeAppController(
        authRepository: _NoopAuthRepository(),
      );
      final CartController controller = buildCart(repo, app);
      controller.onInit();

      // Signed out at launch: the first bind is for nobody.
      expect(repo.requestedUids, <String>['']);

      app.fakeUid = 'user-a';
      repo.cartsByUid['user-a'] = <CartItem>[_item('a1')];
      controller.bindToUser();
      await Future<void>.delayed(Duration.zero);

      expect(repo.requestedUids, <String>['', 'user-a']);
      expect(controller.items.single.productId, 'a1');

      // A different customer signs in on the same device.
      app.fakeUid = 'user-b';
      repo.cartsByUid['user-b'] = <CartItem>[_item('b1'), _item('b2')];
      controller.bindToUser();
      await Future<void>.delayed(Duration.zero);

      expect(
        controller.items.map((CartItem i) => i.productId).toSet(),
        <String>{'b1', 'b2'},
        reason: "the previous customer's items must not linger",
      );
    });

    test('releases the previous stream on every re-bind', () async {
      final _RecordingCartRepository repo = _RecordingCartRepository();
      final _FakeAppController app = _FakeAppController(
        authRepository: _NoopAuthRepository(),
      );
      final CartController controller = buildCart(repo, app);
      controller.onInit();

      for (int i = 0; i < 3; i++) {
        app.fakeUid = 'user-$i';
        controller.bindToUser();
      }
      await Future<void>.delayed(Duration.zero);

      expect(repo.liveSubscriptions, 1, reason: 'only the newest stays open');
      expect(repo.cancelledSubscriptions, 3);
    });

    test('onClose releases the stream', () async {
      final _RecordingCartRepository repo = _RecordingCartRepository();
      final _FakeAppController app = _FakeAppController(
        authRepository: _NoopAuthRepository(),
      );
      final CartController controller = buildCart(repo, app);
      controller.onInit();
      await Future<void>.delayed(Duration.zero);
      expect(repo.liveSubscriptions, 1);

      controller.onClose();
      await Future<void>.delayed(Duration.zero);
      expect(repo.liveSubscriptions, 0);
    });
  });

  group('HomeController.load does not stack subscriptions', () {
    test('three refreshes leave seven streams, not twenty-eight', () async {
      final _FakeAppController app = _FakeAppController(
        authRepository: _NoopAuthRepository(),
      );

      int live = 0;
      int cancelled = 0;
      Stream<List<T>> counting<T>() {
        late StreamController<List<T>> controller;
        controller = StreamController<List<T>>(
          onCancel: () {
            cancelled++;
            live--;
          },
        );
        live++;
        return controller.stream;
      }

      final HomeController controller = HomeController(
        bannerRepository: _StreamBannerRepository(counting),
        categoryRepository: _StreamCategoryRepository(counting),
        productRepository: _StreamProductRepository(counting),
        appController: app,
      );
      controller.onInit();
      await Future<void>.delayed(Duration.zero);
      expect(live, 7, reason: 'seven independent home sections');

      // What pull-to-refresh does.
      for (int i = 0; i < 3; i++) {
        controller.load();
        await Future<void>.delayed(Duration.zero);
      }

      expect(
        live,
        7,
        reason: 'a refresh must replace the streams, not add to them',
      );
      expect(cancelled, 21, reason: 'three refreshes x seven sections');

      controller.onClose();
      await Future<void>.delayed(Duration.zero);
      expect(live, 0);
    });
  });
}

/// Repositories handing out counting streams so a test can observe the leak.
class _StreamBannerRepository extends BannerRepository {
  _StreamBannerRepository(this._make);

  final Stream<List<BannerModel>> Function() _make;

  @override
  Stream<List<BannerModel>> watchActiveBanners() => _make();
}

class _StreamCategoryRepository extends CategoryRepository {
  _StreamCategoryRepository(this._make);

  final Stream<List<CategoryModel>> Function() _make;

  @override
  Stream<List<CategoryModel>> watchActiveCategories() => _make();
}

class _StreamProductRepository extends ProductRepository {
  _StreamProductRepository(this._make);

  final Stream<List<ProductModel>> Function() _make;

  @override
  Stream<List<ProductModel>> watchNewArrivals({int limit = 10}) => _make();

  @override
  Stream<List<ProductModel>> watchFastMoving({int limit = 10}) => _make();

  @override
  Stream<List<ProductModel>> watchFeatured({int limit = 10}) => _make();

  @override
  Stream<List<ProductModel>> watchPopular({int limit = 10}) => _make();

  @override
  Stream<List<ProductModel>> watchRecentlyAdded({int limit = 10}) => _make();
}
