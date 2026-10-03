import 'package:flutter/material.dart';

/// Padma Collections brand palette.
///
/// Gold is deliberately used as an *accent* only — for icons, borders,
/// highlights and CTAs — rather than flooding surfaces with gold.
class AppColors {
  AppColors._();

  // Core brand colours.
  static const Color burgundy = Color(0xFF7A1F3D);
  static const Color gold = Color(0xFFD4AF37);
  static const Color cream = Color(0xFFFFF9F0);
  static const Color darkBrown = Color(0xFF2B2118);
  static const Color white = Color(0xFFFFFFFF);

  // Derived burgundy ramp.
  static const Color burgundyDark = Color(0xFF5A1530);
  static const Color burgundyLight = Color(0xFF9B2F55);
  static const Color burgundySoft = Color(0xFFF6E7EC);

  // Derived gold ramp.
  static const Color goldDark = Color(0xFFA98A22);
  static const Color goldLight = Color(0xFFEDD98C);
  static const Color goldSoft = Color(0xFFFBF3DC);

  // Neutrals tuned to the warm cream background.
  static const Color background = cream;
  static const Color surface = white;
  static const Color surfaceMuted = Color(0xFFFDF6EC);
  static const Color border = Color(0xFFEFE3D2);
  static const Color divider = Color(0xFFF2E8DA);
  static const Color textPrimary = darkBrown;
  static const Color textSecondary = Color(0xFF7A6A5C);
  static const Color textHint = Color(0xFFAFA093);

  // Semantic colours.
  static const Color success = Color(0xFF2E7D52);
  static const Color successSoft = Color(0xFFE4F2EA);
  static const Color warning = Color(0xFFC77700);
  static const Color warningSoft = Color(0xFFFDF1DC);
  static const Color danger = Color(0xFFC0392B);
  static const Color dangerSoft = Color(0xFFFBE7E4);
  static const Color info = Color(0xFF2C5F8A);
  static const Color infoSoft = Color(0xFFE4EEF6);

  /// Warm terracotta used sparingly for the third colour-scheme slot.
  static const Color accent = Color(0xFFC08A4E);
  static const Color accentSoft = Color(0xFFF7EBE0);

  // WhatsApp brand green (only for WhatsApp surfaces).
  static const Color whatsapp = Color(0xFF25D366);
  static const Color whatsappDark = Color(0xFF128C7E);

  // Admin surface — deliberately cooler/greyer so the two apps feel distinct.
  static const Color adminBackground = Color(0xFFF4F5F7);
  static const Color adminSurface = white;
  static const Color adminSidebar = Color(0xFF1F2230);
  static const Color adminSidebarActive = Color(0xFF2E3348);

  /// Elevation shadow used by cards. Warm-tinted rather than pure black.
  static List<BoxShadow> get cardShadow => const <BoxShadow>[
    BoxShadow(color: Color(0x0F2B2118), blurRadius: 18, offset: Offset(0, 6)),
    BoxShadow(color: Color(0x082B2118), blurRadius: 4, offset: Offset(0, 1)),
  ];

  static List<BoxShadow> get elevatedShadow => const <BoxShadow>[
    BoxShadow(color: Color(0x1A2B2118), blurRadius: 30, offset: Offset(0, 12)),
  ];

  /// Subtle gold hairline used to frame premium cards.
  static const BorderSide goldBorder = BorderSide(color: goldLight, width: 1);
}
