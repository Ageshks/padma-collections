import 'package:flutter/material.dart';

import '../constants/app_colors.dart';

/// Typography for Padma Collections.
///
/// Playfair Display carries the boutique feel in headings while Inter keeps
/// body text, forms and tables crisp and highly legible.
class AppTypography {
  AppTypography._();

  static const String heading = 'PlayfairDisplay';
  static const String body = 'Inter';

  static const TextStyle splashBrand = TextStyle(
    fontFamily: heading,
    fontSize: 34,
    fontWeight: FontWeight.w700,
    letterSpacing: 4,
    height: 1.15,
    color: AppColors.white,
  );

  static const TextStyle displayLarge = TextStyle(
    fontFamily: heading,
    fontSize: 32,
    fontWeight: FontWeight.w700,
    height: 1.2,
    letterSpacing: -0.2,
    color: AppColors.textPrimary,
  );

  static const TextStyle displayMedium = TextStyle(
    fontFamily: heading,
    fontSize: 26,
    fontWeight: FontWeight.w600,
    height: 1.25,
    color: AppColors.textPrimary,
  );

  static const TextStyle headlineMedium = TextStyle(
    fontFamily: heading,
    fontSize: 21,
    fontWeight: FontWeight.w600,
    height: 1.3,
    color: AppColors.textPrimary,
  );

  static const TextStyle titleLarge = TextStyle(
    fontFamily: body,
    fontSize: 18,
    fontWeight: FontWeight.w600,
    height: 1.35,
    color: AppColors.textPrimary,
  );

  static const TextStyle titleMedium = TextStyle(
    fontFamily: body,
    fontSize: 15.5,
    fontWeight: FontWeight.w600,
    height: 1.35,
    color: AppColors.textPrimary,
  );

  static const TextStyle bodyLarge = TextStyle(
    fontFamily: body,
    fontSize: 15,
    fontWeight: FontWeight.w400,
    height: 1.5,
    color: AppColors.textPrimary,
  );

  static const TextStyle bodyMedium = TextStyle(
    fontFamily: body,
    fontSize: 13.5,
    fontWeight: FontWeight.w400,
    height: 1.5,
    color: AppColors.textSecondary,
  );

  static const TextStyle bodySmall = TextStyle(
    fontFamily: body,
    fontSize: 12,
    fontWeight: FontWeight.w400,
    height: 1.45,
    color: AppColors.textSecondary,
  );

  /// Small all-caps label used for section eyebrows and badges.
  static const TextStyle overline = TextStyle(
    fontFamily: body,
    fontSize: 11,
    fontWeight: FontWeight.w600,
    letterSpacing: 1.6,
    height: 1.2,
    color: AppColors.goldDark,
  );

  static const TextStyle button = TextStyle(
    fontFamily: body,
    fontSize: 15,
    fontWeight: FontWeight.w600,
    letterSpacing: 0.3,
    height: 1.2,
  );

  static const TextStyle price = TextStyle(
    fontFamily: body,
    fontSize: 16,
    fontWeight: FontWeight.w700,
    color: AppColors.textPrimary,
  );

  static const TextStyle priceSmall = TextStyle(
    fontFamily: body,
    fontSize: 13.5,
    fontWeight: FontWeight.w700,
    color: AppColors.textPrimary,
  );

  /// Tabular figures stop currency columns jittering as values change.
  static const TextStyle numeric = TextStyle(
    fontFamily: body,
    fontSize: 14,
    fontWeight: FontWeight.w600,
    color: AppColors.textPrimary,
    fontFeatures: [FontFeature.tabularFigures()],
  );
}
