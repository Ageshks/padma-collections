import 'firestore_map.dart';

/// Admin-controlled pricing rules. Stored at `settings/rates`.
///
/// Products still support manually defined prices; these settings drive the
/// *suggested* price and the extra charges applied at checkout.
class RateSettings {
  const RateSettings({
    this.baseRate = 0,
    this.makingChargePercent = 0,
    this.makingChargeFlat = 0,
    this.defaultDiscountPercent = 0,
    this.taxPercent = 0,
    this.shippingCharge = 0,
    this.freeShippingAbove = 0,
    this.applyMakingCharge = true,
    this.applyDiscount = false,
    this.applyTax = false,
    this.applyShipping = true,
    this.updatedAt,
  });

  /// Baseline price used when the admin has not entered a manual price.
  final double baseRate;

  /// Making charge can be a percentage, a flat amount, or both.
  final double makingChargePercent;
  final double makingChargeFlat;

  /// Store-wide discount, applied only when [applyDiscount] is on.
  final double defaultDiscountPercent;

  final double taxPercent;
  final double shippingCharge;

  /// Orders at or above this subtotal ship free (when shipping is enabled).
  final double freeShippingAbove;

  final bool applyMakingCharge;
  final bool applyDiscount;
  final bool applyTax;
  final bool applyShipping;

  final DateTime? updatedAt;

  /// Working copy used by the Rate Settings form.
  RateSettings copyWith({
    double? baseRate,
    double? makingChargePercent,
    double? makingChargeFlat,
    double? defaultDiscountPercent,
    double? taxPercent,
    double? shippingCharge,
    double? freeShippingAbove,
    bool? applyMakingCharge,
    bool? applyDiscount,
    bool? applyTax,
    bool? applyShipping,
    DateTime? updatedAt,
  }) {
    return RateSettings(
      baseRate: baseRate ?? this.baseRate,
      makingChargePercent: makingChargePercent ?? this.makingChargePercent,
      makingChargeFlat: makingChargeFlat ?? this.makingChargeFlat,
      defaultDiscountPercent:
          defaultDiscountPercent ?? this.defaultDiscountPercent,
      taxPercent: taxPercent ?? this.taxPercent,
      shippingCharge: shippingCharge ?? this.shippingCharge,
      freeShippingAbove: freeShippingAbove ?? this.freeShippingAbove,
      applyMakingCharge: applyMakingCharge ?? this.applyMakingCharge,
      applyDiscount: applyDiscount ?? this.applyDiscount,
      applyTax: applyTax ?? this.applyTax,
      applyShipping: applyShipping ?? this.applyShipping,
      updatedAt: updatedAt ?? this.updatedAt,
    );
  }

  /// Computes the itemised breakdown for a given subtotal.
  ///
  /// Returns a [PriceBreakdown] so the checkout UI can show the customer
  /// exactly how the total was reached instead of just a number.
  PriceBreakdown compute(double subtotal) {
    final double safeSubtotal = subtotal < 0 ? 0 : subtotal;

    double making = 0;
    if (applyMakingCharge) {
      making = (safeSubtotal * makingChargePercent / 100) + makingChargeFlat;
    }

    final double afterMaking = safeSubtotal + making;

    double discount = 0;
    if (applyDiscount && defaultDiscountPercent > 0) {
      discount = afterMaking * defaultDiscountPercent / 100;
    }

    final double afterDiscount = afterMaking - discount;

    double tax = 0;
    if (applyTax && taxPercent > 0) {
      tax = afterDiscount * taxPercent / 100;
    }

    double shipping = 0;
    if (applyShipping) {
      final bool qualifies =
          freeShippingAbove > 0 && afterDiscount >= freeShippingAbove;
      shipping = qualifies ? 0 : shippingCharge;
    }

    return PriceBreakdown(
      subtotal: safeSubtotal,
      makingCharge: making,
      discount: discount,
      tax: tax,
      shipping: shipping,
    );
  }

  /// Suggested selling price for a base cost, used to prefill the product form.
  double suggestedPrice(double baseCost) {
    if (baseCost <= 0) return baseRate;
    if (baseRate > 0) return baseRate;
    if (!applyMakingCharge) return baseCost;
    return baseCost + (baseCost * makingChargePercent / 100) + makingChargeFlat;
  }

  factory RateSettings.fromMap(Map<String, dynamic> map) {
    return RateSettings(
      baseRate: FirestoreMap.num2(map, 'baseRate'),
      makingChargePercent: FirestoreMap.num2(map, 'makingChargePercent'),
      makingChargeFlat: FirestoreMap.num2(map, 'makingChargeFlat'),
      defaultDiscountPercent: FirestoreMap.num2(map, 'defaultDiscountPercent'),
      taxPercent: FirestoreMap.num2(map, 'taxPercent'),
      shippingCharge: FirestoreMap.num2(map, 'shippingCharge'),
      freeShippingAbove: FirestoreMap.num2(map, 'freeShippingAbove'),
      applyMakingCharge: FirestoreMap.boolean(map, 'applyMakingCharge', true),
      applyDiscount: FirestoreMap.boolean(map, 'applyDiscount'),
      applyTax: FirestoreMap.boolean(map, 'applyTax'),
      applyShipping: FirestoreMap.boolean(map, 'applyShipping', true),
      updatedAt: FirestoreMap.dateTime(map, 'updatedAt'),
    );
  }

  Map<String, dynamic> toMap() {
    return FirestoreMap.clean(<String, dynamic>{
      'baseRate': baseRate,
      'makingChargePercent': makingChargePercent,
      'makingChargeFlat': makingChargeFlat,
      'defaultDiscountPercent': defaultDiscountPercent,
      'taxPercent': taxPercent,
      'shippingCharge': shippingCharge,
      'freeShippingAbove': freeShippingAbove,
      'applyMakingCharge': applyMakingCharge,
      'applyDiscount': applyDiscount,
      'applyTax': applyTax,
      'applyShipping': applyShipping,
      'updatedAt': DateTime.now(),
    });
  }

  @override
  String toString() => 'RateSettings(base: $baseRate, tax: $taxPercent%)';
}

/// The itemised result of applying [RateSettings] to a subtotal.
class PriceBreakdown {
  const PriceBreakdown({
    required this.subtotal,
    this.makingCharge = 0,
    this.discount = 0,
    this.tax = 0,
    this.shipping = 0,
  });

  final double subtotal;
  final double makingCharge;
  final double discount;
  final double tax;
  final double shipping;

  double get total => subtotal + makingCharge - discount + tax + shipping;

  /// True when at least one extra charge is actually being applied.
  bool get hasAdjustments =>
      makingCharge > 0 || discount > 0 || tax > 0 || shipping > 0;

  @override
  String toString() => 'PriceBreakdown($subtotal -> $total)';
}
