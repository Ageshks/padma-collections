// Regression tests for the product card layout contract.
//
// The card is laid out into a height the parent chooses, and the image absorbs
// whatever is left over. An earlier version derived the image height from an
// AspectRatio, which made the card's natural height depend on its width and
// overflowed the "Add to Cart" button at the bottom of every grid cell and
// horizontal rail.
//
// These tests render the card at the real sizes the app uses and fail if the
// layout reports an overflow, which is the only reliable way to catch this
// class of regression — it looks fine in a screenshot on one screen.
import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:padma/core/widgets/product_card.dart';
import 'package:padma/data/models/models.dart';

ProductModel _product({String name = 'Temple Jewellery Ring'}) {
  return ProductModel(
    productId: 'p1',
    name: name,
    description: 'A handcrafted piece.',
    categoryId: 'cat-rings',
    categoryName: 'Rings',
    price: 2499,
    compareAtPrice: 3499,
    stock: 4,
    isActive: true,
    createdAt: DateTime(2026),
  );
}

/// Fails the test if anything inside [pump] reported a RenderFlex overflow.
Future<void> pumpCard(
  WidgetTester tester, {
  required Widget child,
  required Size surface,
}) async {
  tester.view.physicalSize = surface;
  tester.view.devicePixelRatio = 1.0;
  addTearDown(tester.view.resetPhysicalSize);
  addTearDown(tester.view.resetDevicePixelRatio);

  await tester.pumpWidget(
    MaterialApp(
      home: Scaffold(body: Center(child: child)),
    ),
  );
  await tester.pump();
}

void main() {
  final ProductModel product = _product();

  testWidgets('grid cell does not overflow at 2-up phone width', (
    WidgetTester tester,
  ) async {
    // Matches ProductListView: 220 max extent, 320 extent, on a 360dp screen
    // gives a cell roughly 164 wide.
    await pumpCard(
      tester,
      surface: const Size(360, 640),
      child: SizedBox(
        width: 164,
        height: 320,
        child: ProductCard(
          product: product,
          onTap: () {},
          onAddToCart: () {},
          onToggleWishlist: () {},
        ),
      ),
    );
    expect(tester.takeException(), isNull);
  });

  testWidgets('narrow cell still fits, including the button', (
    WidgetTester tester,
  ) async {
    // A small phone is the tightest case: the details block is a fixed height,
    // so the image must shrink rather than push the button off the card.
    await pumpCard(
      tester,
      surface: const Size(320, 640),
      child: SizedBox(
        width: 130,
        height: 320,
        child: ProductCard(
          product: product,
          onTap: () {},
          onAddToCart: () {},
          onToggleWishlist: () {},
        ),
      ),
    );
    expect(tester.takeException(), isNull);
    expect(find.text('Add to Cart'), findsOneWidget);
  });

  testWidgets('home rail card does not overflow', (WidgetTester tester) async {
    // Matches home_view: width 162 inside a 344-tall rail.
    await pumpCard(
      tester,
      surface: const Size(360, 640),
      child: SizedBox(
        width: 162,
        height: 344,
        child: ProductCard(product: product, onTap: () {}, onAddToCart: () {}),
      ),
    );
    expect(tester.takeException(), isNull);
  });

  testWidgets('related-products card does not overflow', (
    WidgetTester tester,
  ) async {
    // Matches product_details_view: width 148 inside a 310-tall rail.
    await pumpCard(
      tester,
      surface: const Size(360, 640),
      child: SizedBox(
        width: 148,
        height: 310,
        child: ProductCard(product: product, onTap: () {}, onAddToCart: () {}),
      ),
    );
    expect(tester.takeException(), isNull);
  });

  testWidgets('the overflow check actually detects overflow', (
    WidgetTester tester,
  ) async {
    // Negative control. If this ever stops failing, the assertions above are
    // vacuous and the suite is no longer protecting the layout at all.
    //
    // A Column with fixed-size children, given less height than it needs, is
    // exactly the shape of the original bug.
    await pumpCard(
      tester,
      surface: const Size(360, 640),
      child: SizedBox(
        width: 164,
        height: 120,
        child: Column(
          children: <Widget>[
            Container(height: 164, color: Colors.red),
            const Text('overflows'),
          ],
        ),
      ),
    );
    expect(
      tester.takeException(),
      isNotNull,
      reason: 'a RenderFlex overflow must surface as a test exception',
    );
  });

  testWidgets('a long name is truncated, not grown', (
    WidgetTester tester,
  ) async {
    // The name box is a fixed two-line height so every card in a row matches,
    // however long the product name is.
    await pumpCard(
      tester,
      surface: const Size(360, 640),
      child: SizedBox(
        width: 164,
        height: 320,
        child: ProductCard(
          product: _product(
            name: 'Handcrafted Bridal Diamond Ring with Matching Nose Stud Set',
          ),
          onTap: () {},
          onAddToCart: () {},
        ),
      ),
    );
    expect(tester.takeException(), isNull);

    final RenderParagraph paragraph = tester.renderObject<RenderParagraph>(
      find.textContaining('Handcrafted Bridal'),
    );
    // `didExceedMaxLines` being true means the name was ellipsised, which is
    // the point: the card keeps its height instead of growing with the text.
    expect(
      paragraph.didExceedMaxLines,
      isTrue,
      reason: 'a long name must be ellipsised, not allowed to expand the card',
    );
    expect(tester.takeException(), isNull);
  });
}
