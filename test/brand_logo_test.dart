import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:padma/core/constants/app_constants.dart';
import 'package:padma/core/widgets/brand_widgets.dart';

void main() {
  group('AppAssets', () {
    test('every branded asset ships in the bundle', () {
      for (final String path in <String>[
        AppAssets.logoMark,
        AppAssets.logoWordmark,
        AppAssets.logoFull,
        AppAssets.appIcon,
      ]) {
        expect(
          File(path).existsSync(),
          isTrue,
          reason: '$path is declared but missing from assets/images/',
        );
      }
    });

    test('each BrandLogoVariant maps to a distinct asset', () {
      expect(BrandLogoVariant.full.asset, AppAssets.logoFull);
      expect(BrandLogoVariant.wordmark.asset, AppAssets.logoWordmark);
      expect(BrandLogoVariant.mark.asset, AppAssets.logoMark);
    });
  });

  group('BrandLogo', () {
    Future<void> pump(WidgetTester tester, BrandLogo logo) async {
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(body: Center(child: logo)),
        ),
      );
    }

    testWidgets('renders the bundled artwork, never stretched', (
      WidgetTester tester,
    ) async {
      await pump(tester, const BrandLogo(height: 40));

      final Finder image = find.byType(Image);
      expect(image, findsOneWidget);

      final Image widget = tester.widget<Image>(image);
      expect(widget.fit, BoxFit.contain);
      expect(widget.height, 40);
      expect((widget.image as AssetImage).assetName, AppAssets.logoWordmark);
    });

    testWidgets('each variant loads its own asset', (
      WidgetTester tester,
    ) async {
      for (final BrandLogoVariant variant in BrandLogoVariant.values) {
        await pump(tester, BrandLogo(height: 40, variant: variant));
        final Image widget = tester.widget<Image>(find.byType(Image));
        expect((widget.image as AssetImage).assetName, variant.asset);
      }
    });

    testWidgets('showTagline keeps the artwork and adds the subtitle', (
      WidgetTester tester,
    ) async {
      await pump(tester, const BrandLogo(height: 40, showTagline: true));

      expect(find.byType(Image), findsOneWidget);
      expect(find.text(AppConstants.appSubtitle), findsOneWidget);
    });

    testWidgets('an unresolvable asset falls back to the text lockup', (
      WidgetTester tester,
    ) async {
      // Guards the brand from ever rendering blank.
      final List<FlutterErrorDetails> errors = <FlutterErrorDetails>[];
      final void Function(FlutterErrorDetails)? previous = FlutterError.onError;
      FlutterError.onError = errors.add;
      addTearDown(() => FlutterError.onError = previous);

      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: Center(
              // Only the logo sees the broken bundle; the app chrome is fine.
              child: DefaultAssetBundle(
                bundle: _FailingAssetBundle(),
                child: const BrandLogo(height: 40),
              ),
            ),
          ),
        ),
      );
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 100));

      expect(find.byType(Image), findsOneWidget);
      expect(find.text('PADMA'), findsOneWidget);
      expect(find.text('COLLECTIONS'), findsOneWidget);
    });

    testWidgets('an admin logoUrl takes precedence over bundled artwork', (
      WidgetTester tester,
    ) async {
      await pump(
        tester,
        const BrandLogo(height: 40, logoUrl: 'https://example.com/logo.png'),
      );

      // The network image is used instead of the local asset.
      expect(
        find.byWidgetPredicate(
          (Widget w) => w is Image && w.image is AssetImage,
        ),
        findsNothing,
      );
    });
  });
}

/// An asset bundle in which every load fails, standing in for a corrupt or
/// missing bundled image.
class _FailingAssetBundle extends CachingAssetBundle {
  @override
  Future<ByteData> load(String key) =>
      Future<ByteData>.error(StateError('cannot load $key'));
}
