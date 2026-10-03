import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../constants/app_colors.dart';
import '../constants/app_sizes.dart';
import 'app_typography.dart';

/// The neutral, dense theme used by the **admin** dashboard.
///
/// Deliberately different from the boutique customer UI: more structure,
/// tighter spacing, cooler surfaces — it should feel like a back office.
class AdminTheme {
  AdminTheme._();

  static const ColorScheme scheme = ColorScheme.light(
    primary: Color(0xFF7A1F3D),
    onPrimary: Colors.white,
    primaryContainer: Color(0xFFF6E7EC),
    onPrimaryContainer: Color(0xFF5A1530),
    secondary: Color(0xFF9A7B18),
    onSecondary: Colors.white,
    secondaryContainer: Color(0xFFFBF3DC),
    onSecondaryContainer: Color(0xFF6B5510),
    surface: Colors.white,
    onSurface: Color(0xFF1F2230),
    surfaceContainerHighest: Color(0xFFF4F5F7),
    error: Color(0xFFC0392B),
    onError: Colors.white,
    outline: Color(0xFFDFE1E6),
    outlineVariant: Color(0xFFECEEF2),
  );

  // Admin-specific greys, kept out of the global palette on purpose.
  static const Color ink = Color(0xFF1F2230);
  static const Color inkMuted = Color(0xFF6B7185);
  static const Color inkHint = Color(0xFFA9AEBF);
  static const Color line = Color(0xFFDFE1E6);
  static const Color lineSoft = Color(0xFFECEEF2);
  static const Color surfaceMuted = Color(0xFFF7F8FA);

  static ThemeData get theme {
    final ThemeData base = ThemeData(
      useMaterial3: true,
      colorScheme: scheme,
      scaffoldBackgroundColor: AppColors.adminBackground,
      fontFamily: AppTypography.body,
    );

    return base.copyWith(
      textTheme: base.textTheme.apply(bodyColor: ink, displayColor: ink),
      appBarTheme: const AppBarTheme(
        backgroundColor: AppColors.adminSurface,
        foregroundColor: ink,
        surfaceTintColor: Colors.transparent,
        elevation: 0,
        centerTitle: false,
        titleTextStyle: TextStyle(
          fontFamily: AppTypography.body,
          fontSize: 17,
          fontWeight: FontWeight.w600,
          color: ink,
        ),
        systemOverlayStyle: SystemUiOverlayStyle(
          statusBarColor: Colors.transparent,
          statusBarIconBrightness: Brightness.dark,
        ),
      ),
      cardTheme: CardThemeData(
        color: AppColors.adminSurface,
        surfaceTintColor: Colors.transparent,
        elevation: 0,
        margin: EdgeInsets.zero,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(AppRadius.md),
          side: const BorderSide(color: lineSoft),
        ),
      ),
      dividerTheme: const DividerThemeData(
        color: lineSoft,
        thickness: 1,
        space: 1,
      ),
      elevatedButtonTheme: ElevatedButtonThemeData(
        style: ElevatedButton.styleFrom(
          backgroundColor: scheme.primary,
          foregroundColor: Colors.white,
          minimumSize: const Size(0, 46),
          padding: const EdgeInsets.symmetric(horizontal: AppSpacing.xl),
          textStyle: const TextStyle(
            fontFamily: AppTypography.body,
            fontSize: 14,
            fontWeight: FontWeight.w600,
          ),
          elevation: 0,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(AppRadius.sm + 2),
          ),
        ),
      ),
      outlinedButtonTheme: OutlinedButtonThemeData(
        style: OutlinedButton.styleFrom(
          foregroundColor: const Color(0xFF3A3F52),
          minimumSize: const Size(0, 44),
          side: const BorderSide(color: line, width: 1.2),
          textStyle: const TextStyle(
            fontFamily: AppTypography.body,
            fontSize: 14,
            fontWeight: FontWeight.w600,
          ),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(AppRadius.sm + 2),
          ),
        ),
      ),
      textButtonTheme: TextButtonThemeData(
        style: TextButton.styleFrom(
          foregroundColor: scheme.primary,
          textStyle: const TextStyle(
            fontFamily: AppTypography.body,
            fontSize: 14,
            fontWeight: FontWeight.w600,
          ),
        ),
      ),
      inputDecorationTheme: InputDecorationTheme(
        filled: true,
        fillColor: Colors.white,
        isDense: true,
        contentPadding: const EdgeInsets.symmetric(
          horizontal: AppSpacing.md,
          vertical: AppSpacing.md,
        ),
        labelStyle: const TextStyle(
          fontFamily: AppTypography.body,
          fontSize: 13.5,
          color: inkMuted,
        ),
        floatingLabelStyle: const TextStyle(
          fontFamily: AppTypography.body,
          fontSize: 13.5,
          color: Color(0xFF7A1F3D),
          fontWeight: FontWeight.w600,
        ),
        hintStyle: const TextStyle(
          fontFamily: AppTypography.body,
          fontSize: 13.5,
          color: inkHint,
        ),
        border: _fieldBorder(line),
        enabledBorder: _fieldBorder(line),
        focusedBorder: _fieldBorder(const Color(0xFF7A1F3D), width: 1.4),
        errorBorder: _fieldBorder(AppColors.danger),
        focusedErrorBorder: _fieldBorder(AppColors.danger, width: 1.4),
      ),
      tabBarTheme: const TabBarThemeData(
        labelColor: Color(0xFF7A1F3D),
        unselectedLabelColor: inkMuted,
        labelStyle: TextStyle(
          fontFamily: AppTypography.body,
          fontSize: 13,
          fontWeight: FontWeight.w600,
        ),
        unselectedLabelStyle: TextStyle(
          fontFamily: AppTypography.body,
          fontSize: 13,
          fontWeight: FontWeight.w500,
        ),
        indicatorColor: AppColors.gold,
        indicatorSize: TabBarIndicatorSize.tab,
        dividerColor: lineSoft,
      ),
      dataTableTheme: const DataTableThemeData(
        headingRowColor: WidgetStatePropertyAll<Color>(surfaceMuted),
        headingTextStyle: TextStyle(
          fontFamily: AppTypography.body,
          fontSize: 12,
          fontWeight: FontWeight.w700,
          letterSpacing: 0.4,
          color: Color(0xFF4A5062),
        ),
        dataTextStyle: TextStyle(
          fontFamily: AppTypography.body,
          fontSize: 13,
          color: ink,
        ),
        dividerThickness: 1,
      ),
      snackBarTheme: SnackBarThemeData(
        backgroundColor: ink,
        contentTextStyle: const TextStyle(
          fontFamily: AppTypography.body,
          fontSize: 13.5,
          color: Colors.white,
        ),
        behavior: SnackBarBehavior.floating,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(AppRadius.sm + 2),
        ),
      ),
      dialogTheme: DialogThemeData(
        backgroundColor: Colors.white,
        surfaceTintColor: Colors.transparent,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(AppRadius.lg),
        ),
        titleTextStyle: const TextStyle(
          fontFamily: AppTypography.body,
          fontSize: 17,
          fontWeight: FontWeight.w600,
          color: ink,
        ),
        contentTextStyle: const TextStyle(
          fontFamily: AppTypography.body,
          fontSize: 14,
          color: Color(0xFF4A5062),
        ),
      ),
      bottomSheetTheme: const BottomSheetThemeData(
        backgroundColor: Colors.white,
        surfaceTintColor: Colors.transparent,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.vertical(
            top: Radius.circular(AppRadius.lg),
          ),
        ),
        showDragHandle: true,
        dragHandleColor: line,
      ),
      chipTheme: ChipThemeData(
        backgroundColor: const Color(0xFFF4F5F7),
        selectedColor: AppColors.burgundySoft,
        side: const BorderSide(color: Color(0xFFE4E6EB)),
        labelStyle: const TextStyle(
          fontFamily: AppTypography.body,
          fontSize: 12.5,
          fontWeight: FontWeight.w500,
          color: Color(0xFF3A3F52),
        ),
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
        shape: const StadiumBorder(),
        showCheckmark: false,
      ),
      switchTheme: SwitchThemeData(
        thumbColor: const WidgetStatePropertyAll<Color>(Colors.white),
        trackColor: WidgetStateProperty.resolveWith(
          (Set<WidgetState> s) =>
              s.contains(WidgetState.selected) ? const Color(0xFF7A1F3D) : line,
        ),
        trackOutlineColor: const WidgetStatePropertyAll<Color>(
          Colors.transparent,
        ),
      ),
      progressIndicatorTheme: const ProgressIndicatorThemeData(
        color: Color(0xFF7A1F3D),
        linearTrackColor: lineSoft,
        circularTrackColor: lineSoft,
      ),
      listTileTheme: const ListTileThemeData(
        contentPadding: EdgeInsets.symmetric(horizontal: AppSpacing.lg),
        iconColor: inkMuted,
        titleTextStyle: TextStyle(
          fontFamily: AppTypography.body,
          fontSize: 14.5,
          fontWeight: FontWeight.w500,
          color: ink,
        ),
        subtitleTextStyle: TextStyle(
          fontFamily: AppTypography.body,
          fontSize: 12.5,
          color: inkMuted,
        ),
      ),
    );
  }

  static OutlineInputBorder _fieldBorder(Color color, {double width = 1.2}) {
    return OutlineInputBorder(
      borderRadius: BorderRadius.circular(AppRadius.sm + 2),
      borderSide: BorderSide(color: color, width: width),
    );
  }
}
