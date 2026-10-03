import 'package:intl/intl.dart';

import '../constants/app_constants.dart';

/// Currency / number / date formatting shared by the whole app.
///
/// Indian numbering (₹1,29,999) is used throughout because Padma Collections
/// is an Indian jewellery retailer.
class AppFormatter {
  AppFormatter._();

  static final NumberFormat _currency = NumberFormat.currency(
    locale: 'en_IN',
    symbol: AppConstants.currencySymbol,
    decimalDigits: 0,
  );

  static final NumberFormat _currencyPrecise = NumberFormat.currency(
    locale: 'en_IN',
    symbol: AppConstants.currencySymbol,
    decimalDigits: 2,
  );

  static final NumberFormat _integer = NumberFormat.decimalPattern('en_IN');
  static final NumberFormat _decimal = NumberFormat('#,##0.##', 'en_IN');

  static final DateFormat _date = DateFormat('dd MMM yyyy');
  static final DateFormat _dateTime = DateFormat('dd MMM yyyy, h:mm a');
  static final DateFormat _shortDate = DateFormat('dd MMM');
  static final DateFormat _time = DateFormat('h:mm a');
  static final DateFormat _monthYear = DateFormat('MMMM yyyy');

  /// ₹1,299
  static String currency(num value) => _currency.format(value);

  /// ₹1,299.00 — used where paise matter (order totals, rate settings).
  static String currencyPrecise(num value) => _currencyPrecise.format(value);

  /// 1,280
  static String count(num value) => _integer.format(value);

  /// 12.5
  static String decimal(num value) => _decimal.format(value);

  /// ₹1.3L / ₹25K — compact form for dashboard stat tiles.
  static String compactCurrency(num value) {
    final double v = value.toDouble();
    if (v >= 10000000) {
      return '${AppConstants.currencySymbol}${_decimal.format(v / 10000000)}Cr';
    }
    if (v >= 100000) {
      return '${AppConstants.currencySymbol}${_decimal.format(v / 100000)}L';
    }
    if (v >= 1000) {
      return '${AppConstants.currencySymbol}${_integer.format(v / 1000)}K';
    }
    return _currency.format(v);
  }

  /// "45% OFF", or "SAVE ₹500" when the saving is large enough that the
  /// percentage reads oddly.
  static String discountLabel(num price, num compareAtPrice) {
    if (compareAtPrice <= price || compareAtPrice <= 0) return '';
    final num off = compareAtPrice - price;
    final int pct = discountPercent(price, compareAtPrice);
    if (pct >= 90) return 'SAVE ${currency(off)}';
    return '$pct% OFF';
  }

  /// Discount percentage, or 0 when there is no meaningful saving.
  static int discountPercent(num price, num compareAtPrice) {
    if (compareAtPrice <= price || compareAtPrice <= 0) return 0;
    return (((compareAtPrice - price) / compareAtPrice) * 100).round();
  }

  static String date(DateTime? value) =>
      value == null ? '—' : _date.format(value.toLocal());

  static String dateTime(DateTime? value) =>
      value == null ? '—' : _dateTime.format(value.toLocal());

  static String shortDate(DateTime? value) =>
      value == null ? '—' : _shortDate.format(value.toLocal());

  static String time(DateTime? value) =>
      value == null ? '—' : _time.format(value.toLocal());

  static String monthYear(DateTime? value) =>
      value == null ? '—' : _monthYear.format(value.toLocal());

  /// "just now", "2h ago", "3d ago", then an absolute date.
  static String relative(DateTime? value) {
    if (value == null) return '—';
    final Duration diff = DateTime.now().difference(value.toLocal());
    if (diff.inSeconds < 60) return 'just now';
    if (diff.inMinutes < 60) return '${diff.inMinutes}m ago';
    if (diff.inHours < 24) return '${diff.inHours}h ago';
    if (diff.inDays < 7) return '${diff.inDays}d ago';
    return _date.format(value.toLocal());
  }

  /// Longer-form phrasing for order timelines.
  static String ago(DateTime? value) {
    if (value == null) return '—';
    final Duration diff = DateTime.now().difference(value.toLocal());
    if (diff.inSeconds < 60) return 'just now';
    if (diff.inMinutes < 60) return '${diff.inMinutes} minutes ago';
    if (diff.inHours < 24) return '${diff.inHours} hours ago';
    if (diff.inDays == 1) return 'yesterday';
    if (diff.inDays < 30) return '${diff.inDays} days ago';
    return _date.format(value.toLocal());
  }
}

/// String helpers used across forms, search and copy generation.
class StringUtils {
  StringUtils._();

  /// Strips the country code so a stored "919812345678" becomes "9812345678".
  static String toLocalNumber(String raw) {
    final String digits = raw.replaceAll(RegExp(r'[^0-9]'), '');
    if (digits.length > 10 && digits.startsWith('91')) {
      return digits.substring(2);
    }
    if (digits.length > 10) return digits.substring(digits.length - 10);
    return digits;
  }

  /// Normalises to the international format required by wa.me links.
  static String toWhatsappNumber(String raw, {String defaultCode = '91'}) {
    final String digits = raw.replaceAll(RegExp(r'[^0-9]'), '');
    if (digits.isEmpty) return '';
    if (digits.length == 10) return '$defaultCode$digits';
    return digits;
  }

  /// Pretty display form: +91 98123 45678
  static String formatPhone(String raw) {
    final String local = toLocalNumber(raw);
    if (local.length != 10) return raw;
    return '+91 ${local.substring(0, 5)} ${local.substring(5)}';
  }

  /// First letters of a name, e.g. "Aarav Mehta" → "AM".
  static String initials(String? name) {
    final List<String> parts = (name ?? '')
        .trim()
        .split(RegExp(r'\s+'))
        .where((String p) => p.isNotEmpty)
        .toList();
    if (parts.isEmpty) return '?';
    if (parts.length == 1) return parts.first.substring(0, 1).toUpperCase();
    return (parts.first.substring(0, 1) + parts.last.substring(0, 1))
        .toUpperCase();
  }

  static String titleCase(String value) {
    if (value.isEmpty) return value;
    return value
        .split(RegExp(r'\s+'))
        .map(
          (String w) => w.isEmpty
              ? w
              : '${w[0].toUpperCase()}${w.substring(1).toLowerCase()}',
        )
        .join(' ');
  }

  /// Collapses whitespace and trims — used for notes and addresses.
  static String squish(String? value) =>
      (value ?? '').replaceAll(RegExp(r'\s+'), ' ').trim();

  /// Truncates with an ellipsis for list previews.
  static String truncate(String value, int max) {
    if (value.length <= max) return value;
    return '${value.substring(0, max).trimRight()}…';
  }

  /// Lower-cased haystack for case-insensitive search matching.
  static String normalise(String? value) => (value ?? '').toLowerCase().trim();

  /// Splits a description into paragraphs for rich rendering.
  static List<String> paragraphs(String? value) {
    if (value == null || value.trim().isEmpty) return const <String>[];
    return value
        .split(RegExp(r'\n{2,}'))
        .map((String p) => p.trim())
        .where((String p) => p.isNotEmpty)
        .toList();
  }
}
