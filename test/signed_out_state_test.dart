import 'package:flutter_test/flutter_test.dart';
import 'package:padma/core/utils/error_handler.dart';
import 'package:padma/data/models/models.dart';
import 'package:padma/data/repositories/cart_repository.dart';
import 'package:padma/data/repositories/order_repository.dart';
import 'package:padma/data/repositories/wishlist_repository.dart';

/// Regression tests for the signed-out state.
///
/// Before Firebase was wired to a live project, an empty uid was harmless
/// because the repositories served demo data. Against the real backend it
/// builds the document path `users//cart`, which Firestore rejects with
/// "A document path must be a non-empty string" and crashed the app on launch.
///
/// Signed out is a normal state, not an error, so reads must degrade to empty
/// and writes must fail with a message a customer can act on.
void main() {
  // A repository in live mode: the injected Firestore is never touched for the
  // signed-out cases, which is the point — no Firebase call happens at all.
  final CartRepository cart = CartRepository();
  final WishlistControllerless wishlist = WishlistControllerless();

  group('signed out reads are empty, not fatal', () {
    test('watchCart("") yields an empty list', () async {
      await expectLater(cart.watchCart(''), emits(const <CartItem>[]));
    });

    test('watchWishlist("") yields an empty list', () async {
      await expectLater(
        wishlist.repo.watchWishlist(''),
        emits(const <WishlistItem>[]),
      );
    });

    test('watchUserOrders("") yields an empty list', () async {
      await expectLater(
        OrderRepository().watchUserOrders(''),
        emits(const <OrderModel>[]),
      );
    });
  });

  group('signed out writes fail with an actionable message', () {
    test('adding to the cart explains the sign-in requirement', () async {
      await expectLater(
        cart.add(
          '',
          CartItem(
            productId: 'p1',
            name: 'Ring',
            price: 100,
            addedAt: DateTime(2026),
          ),
        ),
        throwsA(
          isA<AppException>().having(
            (AppException e) => e.message,
            'message',
            contains('sign in'),
          ),
        ),
      );
    });

    test('clearing the cart explains the sign-in requirement', () async {
      await expectLater(
        cart.clear(''),
        throwsA(
          isA<AppException>().having(
            (AppException e) => e.message,
            'message',
            contains('sign in'),
          ),
        ),
      );
    });

    test('removing a wishlist item explains the sign-in requirement', () async {
      await expectLater(
        wishlist.repo.remove('', 'p1'),
        throwsA(
          isA<AppException>().having(
            (AppException e) => e.message,
            'message',
            contains('sign in'),
          ),
        ),
      );
    });
  });
}

/// Thin holder so the wishlist repository is constructed once for the group.
class WishlistControllerless {
  final WishlistRepository repo = WishlistRepository();
}
