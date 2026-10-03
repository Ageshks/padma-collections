import 'package:flutter/material.dart';

import 'app_colors.dart';

/// App-wide spacing, radius and elevation scale.
///
/// Keeping these in one place is what stops a UI from drifting into
/// "crowded" — every gap, radius and card in the app comes from here.
class AppSpacing {
  AppSpacing._();

  static const double xxs = 2;
  static const double xs = 4;
  static const double sm = 8;
  static const double md = 12;
  static const double lg = 16;
  static const double xl = 20;
  static const double xxl = 24;
  static const double xxxl = 32;
  static const double huge = 40;

  /// Standard horizontal page gutter.
  static const double gutter = 20;

  /// Bottom padding that clears the home indicator / bottom nav bar.
  static const double bottomBarClearance = 96;
}

class AppRadius {
  AppRadius._();

  static const double sm = 8;
  static const double md = 12;
  static const double lg = 16;
  static const double xl = 22;
  static const double pill = 999;

  static const BorderRadius cardRadius = BorderRadius.all(Radius.circular(lg));
  static const BorderRadius tileRadius = BorderRadius.all(Radius.circular(md));
  static const BorderRadius pillRadius = BorderRadius.all(
    Radius.circular(pill),
  );
}

/// Responsive breakpoints.
class AppBreakpoints {
  AppBreakpoints._();

  static const double mobile = 600;
  static const double tablet = 900;
  static const double desktop = 1240;

  static bool isMobile(BuildContext context) =>
      MediaQuery.sizeOf(context).width < mobile;

  static bool isTablet(BuildContext context) {
    final double w = MediaQuery.sizeOf(context).width;
    return w >= mobile && w < tablet;
  }

  static bool isDesktop(BuildContext context) =>
      MediaQuery.sizeOf(context).width >= tablet;

  /// Number of columns for a product grid at the current width.
  static int productGridColumns(BuildContext context) {
    final double w = MediaQuery.sizeOf(context).width;
    if (w >= 1500) return 5;
    if (w >= tablet) return 4;
    if (w >= mobile) return 3;
    return 2;
  }

  /// Admin stat cards per row.
  static int adminStatColumns(BuildContext context) {
    final double w = MediaQuery.sizeOf(context).width;
    if (w >= 1100) return 4;
    if (w >= 700) return 3;
    return 2;
  }

  /// Max readable content width, so the UI never stretches on tablets.
  static double contentMaxWidth(BuildContext context) =>
      isDesktop(context) ? 1200 : double.infinity;

  /// Centres and constrains page content on wide screens.
  static Widget constrainContent(
    BuildContext context,
    Widget child, {
    double maxWidth = 1200,
  }) {
    return Center(
      child: ConstrainedBox(
        constraints: BoxConstraints(maxWidth: maxWidth),
        child: child,
      ),
    );
  }
}

/// Motion tokens. One place to tune the feel of the whole app.
class AppDurations {
  AppDurations._();

  static const Duration fast = Duration(milliseconds: 180);
  static const Duration normal = Duration(milliseconds: 300);
  static const Duration slow = Duration(milliseconds: 550);
  static const Duration splash = Duration(milliseconds: 2200);

  static const Curve ease = Curves.easeOutCubic;
  static const Curve standard = Curves.easeInOutCubic;
}

/// Reusable gradients built from the brand ramp.
class AppGradients {
  AppGradients._();

  static const LinearGradient goldSheen = LinearGradient(
    begin: Alignment.topLeft,
    end: Alignment.bottomRight,
    colors: [AppColors.goldLight, AppColors.gold, AppColors.goldDark],
  );

  static const LinearGradient burgundy = LinearGradient(
    begin: Alignment.topLeft,
    end: Alignment.bottomRight,
    colors: [
      AppColors.burgundyLight,
      AppColors.burgundy,
      AppColors.burgundyDark,
    ],
  );

  /// Overlay placed on top of hero imagery so white text stays legible.
  static const LinearGradient heroScrim = LinearGradient(
    begin: Alignment.topCenter,
    end: Alignment.bottomCenter,
    colors: [Color(0x33000000), Color(0x22000000), Color(0xB3000000)],
  );
}
