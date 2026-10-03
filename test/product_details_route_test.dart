import 'package:flutter_test/flutter_test.dart';
import 'package:padma/core/routes/app_pages.dart';
import 'package:padma/data/models/models.dart';
import 'package:padma/data/repositories/product_repository.dart';
import 'package:padma/modules/products/product_list_controller.dart';

/// Pins the argument contract of [Routes.productDetails] and [Routes.categoryProducts].
///
/// Regression cover for two real bugs found together.
///
/// **1. The home rails rendered an error page.** They passed a whole
/// [ProductModel] to the route instead of its id. The route resolved anything
/// that was not a `String` to an empty id, so the mismatch never threw at the
/// call site — it surfaced much later as a blank error page after a pointless
/// `getById('')` round trip, with nothing pointing back at the actual mistake.
/// The product list, cart, wishlist and related-products paths all passed an id
/// correctly, which is why only the home rails appeared broken.
///
/// **2. "See all" and category tiles showed the whole catalogue.** The five
/// catalogue routes built `const ProductListView()` and ignored `Get.arguments`
/// entirely, so New Arrivals, Fast Moving and every category tile rendered the
/// complete catalogue — and because the controller is a permanent service, its
/// filters leaked between those screens too.
///
/// ### What these tests do and do not prove
///
/// They pin the *contract* — which argument shapes each route accepts, and that
/// each entry point applies exactly its own scope. They do **not** inspect the
/// call sites; the `productDetailsId` assertion is what stops a future caller
/// from repeating bug 1, firing at the point of the mistake with the offending
/// type named, rather than surfacing as a blank page three layers later.
void main() {
  ProductModel model(String id) => ProductModel(
    productId: id,
    name: 'Temple Necklace',
    createdAt: DateTime(2026, 1, 1),
  );

  group('productDetailsId | accepts a product id', () {
    test('passes a plain id straight through', () {
      expect(productDetailsId('PC-NK-001'), 'PC-NK-001');
    });

    test('preserves ids containing separators', () {
      expect(productDetailsId('a_b-c.1'), 'a_b-c.1');
    });
  });

  group('productDetailsId | rejects everything else', () {
    // Each of these used to be silently swallowed into an empty id.
    test('a product model fails loudly and names the fix', () {
      expect(
        () => productDetailsId(model('PC-NK-001')),
        throwsA(
          isA<AssertionError>().having(
            (AssertionError e) => e.message.toString(),
            'message',
            allOf(
              contains('expects a product id String'),
              contains('product.productId'),
            ),
          ),
        ),
      );
    });

    test('null, ints and lists are equally rejected', () {
      for (final Object? bad in <Object?>[null, 42, <String>['PC-NK-001']]) {
        expect(
          () => productDetailsId(bad),
          throwsA(isA<AssertionError>()),
          reason: 'argument of type ${bad.runtimeType} must not be accepted',
        );
      }
    });

    test('a category model is rejected just like a product model', () {
      expect(
        () => productDetailsId(
          CategoryModel(
            categoryId: 'cat-1',
            name: 'Necklaces',
            createdAt: DateTime(2026, 1, 1),
          ),
        ),
        throwsA(isA<AssertionError>()),
      );
    });
  });

  group('categoryProductsId | accepts both legitimate shapes', () {
    test('a category model resolves to its id', () {
      expect(
        categoryProductsId(
          CategoryModel(
            categoryId: 'cat-necklaces',
            name: 'Necklaces',
            createdAt: DateTime(2026, 1, 1),
          ),
        ),
        'cat-necklaces',
      );
    });

    test('a bare string passes through, as sent by a banner', () {
      expect(categoryProductsId('cat-bangles'), 'cat-bangles');
    });

    test('an empty or missing value means "whole catalogue"', () {
      // A banner with no actionValue is guarded by its caller, and an empty
      // category id should degrade to the full list rather than an empty one.
      expect(categoryProductsId(''), isNull);
      expect(categoryProductsId(null), isNull);
    });

    test('an unrelated object resolves to no filter rather than throwing', () {
      expect(categoryProductsId(42), isNull);
    });
  });

  group('ProductListController | catalogue scope', () {
    // Regression cover for the second bug this same investigation found: the
    // five catalogue routes passed no arguments at all, so "See all" on New
    // Arrivals, Fast Moving and every category tile all rendered the entire
    // catalogue. Worse, because the controller is a permanent service, its
    // filters also leaked between those screens.
    late ProductListController controller;

    setUp(() {
      // Never registered with Get and never subscribed, so `onInit` does not
      // run and no Firestore read is attempted — these tests exercise the scope
      // flags only.
      controller = ProductListController(repository: ProductRepository());
    });

    // Lazy closure: `tearDown(controller.onClose)` would read `controller`
    // while the group is still being declared, before setUp has run.
    tearDown(() => controller.onClose());

    test('showCategory filters by category and clears everything else', () {
      controller
        ..showNewArrivals()
        ..showCategory('cat-necklaces');

      expect(controller.categoryId.value, 'cat-necklaces');
      expect(controller.onlyNewArrival.value, isFalse);
      expect(controller.onlyFastMoving.value, isFalse);
    });

    test('showNewArrivals does not inherit a previously chosen category', () {
      // The exact leak reported: browse a category, then tap New Arrivals.
      controller
        ..showCategory('cat-necklaces')
        ..showNewArrivals();

      expect(controller.onlyNewArrival.value, isTrue);
      expect(controller.categoryId.value, isEmpty);
    });

    test('showFastMoving replaces a new-arrivals scope', () {
      controller
        ..showNewArrivals()
        ..showFastMoving();

      expect(controller.onlyFastMoving.value, isTrue);
      expect(controller.onlyNewArrival.value, isFalse);
      expect(controller.categoryId.value, isEmpty);
    });

    test('showAllProducts clears every scope', () {
      controller
        ..showFastMoving()
        ..showAllProducts();

      expect(controller.onlyFastMoving.value, isFalse);
      expect(controller.onlyNewArrival.value, isFalse);
      expect(controller.categoryId.value, isEmpty);
    });

    test('a scoped entry point also clears a stale search query', () {
      controller.query.value = 'gold';
      controller.showCategory('cat-necklaces');

      expect(controller.query.value, isEmpty);
    });

    test('showSearchResults keeps the query but drops other scopes', () {
      // The search screen's own filter is the text, so it survives; everything
      // else is scope that should not leak into a search.
      controller
        ..showCategory('cat-necklaces')
        ..query.value = 'bangles'
        ..showSearchResults();

      expect(controller.query.value, 'bangles');
      expect(controller.categoryId.value, isEmpty);
    });

    test('an empty category id falls back to the whole catalogue', () {
      controller
        ..showNewArrivals()
        ..showCategory('');

      expect(controller.onlyNewArrival.value, isFalse);
      expect(controller.categoryId.value, isEmpty);
    });
  });
}