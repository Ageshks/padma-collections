import 'package:flutter_test/flutter_test.dart';
import 'package:padma/core/constants/app_constants.dart';
import 'package:padma/core/utils/app_formatter.dart';
import 'package:padma/data/models/models.dart';

void main() {
  group('RateSettings', () {
    test('computes an itemised breakdown', () {
      const RateSettings rates = RateSettings(
        makingChargePercent: 10,
        defaultDiscountPercent: 5,
        taxPercent: 3,
        shippingCharge: 60,
        applyDiscount: true,
        applyTax: true,
      );

      final PriceBreakdown b = rates.compute(1000);

      // 1000 subtotal + 100 making (10%) = 1100
      //   - 55 discount (5% of 1100)  = 1045
      //   + 31.35 tax (3% of 1045)   = 1076.35
      //   + 60 shipping              = 1136.35
      expect(b.makingCharge, 100);
      expect(b.discount, 55);
      expect(b.tax, closeTo(31.35, 0.01));
      expect(b.shipping, 60);
      expect(b.hasAdjustments, isTrue);
      expect(b.total, closeTo(1136.35, 0.01));
    });

    test('respects the free shipping threshold', () {
      const RateSettings rates = RateSettings(
        shippingCharge: 60,
        freeShippingAbove: 500,
      );

      expect(rates.compute(499).shipping, 60);
      expect(rates.compute(600).shipping, 0);
    });

    test('disabled charges are not applied', () {
      const RateSettings rates = RateSettings(
        makingChargePercent: 20,
        taxPercent: 5,
        shippingCharge: 50,
        applyMakingCharge: false,
        applyTax: false,
        applyShipping: false,
      );

      final PriceBreakdown b = rates.compute(1000);
      expect(b.total, 1000);
      expect(b.hasAdjustments, isFalse);
    });
  });

  group('AppSettings', () {
    test('falls back to the Padma Collections brand defaults', () {
      final AppSettings s = AppSettings.fromMap(<String, dynamic>{});

      expect(s.storeName, 'Padma Collections');
      expect(s.tagline, 'Elegance That Belongs to You');
    });

    test('round-trips through Firestore maps', () {
      const AppSettings original = AppSettings(
        storeName: 'Padma Collections',
        phone: '9876543210',
        instagramUrl: 'https://instagram.com/padmacollections',
        cloudinaryCloudName: 'demo-cloud',
        cloudinaryUploadPreset: 'padma_unsigned',
      );

      final AppSettings copy = AppSettings.fromMap(original.toMap());
      expect(copy.storeName, original.storeName);
      expect(copy.phone, original.phone);
      expect(copy.cloudinaryCloudName, original.cloudinaryCloudName);
      expect(copy.cloudinaryUploadPreset, original.cloudinaryUploadPreset);
      expect(copy.hasSocialLinks, isTrue);
    });

    test('copyWith keeps Cloudinary credentials when saving settings', () {
      const AppSettings original = AppSettings(
        cloudinaryCloudName: 'demo-cloud',
        cloudinaryUploadPreset: 'padma_unsigned',
      );

      final AppSettings copy = original.copyWith(
        storeName: 'Padma Collections',
        cloudinaryCloudName: 'demo-cloud-2',
        cloudinaryUploadPreset: 'padma_unsigned_2',
      );

      expect(copy.cloudinaryCloudName, 'demo-cloud-2');
      expect(copy.cloudinaryUploadPreset, 'padma_unsigned_2');
    });
  });

  group('WhatsAppSettings', () {
    test('normalises the number for wa.me links', () {
      final WhatsAppSettings s = WhatsAppSettings.fromMap(<String, dynamic>{
        'phoneNumber': '+91 98765 43210',
      });

      expect(s.normalisedNumber, '919876543210');
      expect(s.greeting, 'Hello Padma Collections,');
    });
  });

  group('AppFormatter', () {
    test('formats currency in the Indian style', () {
      expect(AppFormatter.currency(1299), '₹1,299');
      expect(AppFormatter.currency(129999), '₹1,29,999');
    });

    test('formats relative times', () {
      final DateTime now = DateTime.now();
      expect(
        AppFormatter.relative(now.subtract(const Duration(minutes: 5))),
        '5m ago',
      );
      expect(
        AppFormatter.relative(now.subtract(const Duration(days: 2))),
        '2d ago',
      );
    });

    test('computes discount labels', () {
      expect(AppFormatter.discountLabel(100, 200), '50% OFF');
      expect(AppFormatter.discountLabel(100, 100), '');
      expect(AppFormatter.discountLabel(100, 50), '');
    });
  });

  group('StringUtils', () {
    test('formats phones and initials', () {
      expect(StringUtils.toWhatsappNumber('9876543210'), '919876543210');
      expect(StringUtils.formatPhone('919876543210'), '+91 98765 43210');
      expect(StringUtils.initials('Aarav Mehta'), 'AM');
      expect(StringUtils.initials(null), '?');
    });
  });

  group('CartItem', () {
    test('clamps quantity into the allowed range', () {
      final CartItem item = CartItem.fromMap(<String, dynamic>{
        'productId': 'p1',
        'name': 'Ring',
        'price': 499,
        'quantity': 999,
      });

      expect(item.quantity, AppConstants.cartQuantityMax);
    });

    test('computes subtotal', () {
      final CartItem item = CartItem.fromMap(<String, dynamic>{
        'productId': 'p1',
        'price': 499,
        'quantity': 3,
      });

      expect(item.subtotal, 1497);
    });
  });
}
