import 'package:flutter/material.dart';

import '../constants/app_colors.dart';
import '../constants/app_constants.dart';
import '../constants/app_sizes.dart';
import '../theme/app_typography.dart';
import 'app_network_image.dart';

/// Which part of the brand artwork a [BrandLogo] should show.
enum BrandLogoVariant {
  /// Crest above the wordmark. For splash and sign-in, where there is room.
  full(AppAssets.logoFull),

  /// The "PADMA COLLECTIONS" lettering alone. For light and cream surfaces.
  wordmark(AppAssets.logoWordmark),

  /// The crest alone. For compact headers, avatars and chips.
  mark(AppAssets.logoMark);

  const BrandLogoVariant(this.asset);

  /// Bundled transparent PNG backing this variant.
  final String asset;
}

/// The Padma Collections wordmark.
///
/// Prefers the brand artwork bundled in `assets/images/` (derived from the
/// uploaded logo by `tool/generate_logo_assets.py`), then an admin-configured
/// URL from `settings/app`, then a clean text lockup, so the brand is never
/// missing.
///
/// The artwork is always laid out with [BoxFit.contain], which preserves the
/// logo's aspect ratio instead of stretching it to fill.
class BrandLogo extends StatelessWidget {
  const BrandLogo({
    super.key,
    this.logoUrl = '',
    this.height = 40,
    this.variant = BrandLogoVariant.wordmark,
    this.showTagline = false,
    this.onDark = false,
    this.alignment = MainAxisAlignment.start,
  });

  /// Admin-configured logo. Takes precedence over the bundled artwork.
  final String logoUrl;

  final double height;

  final BrandLogoVariant variant;

  /// Shows "Imitation Jewellery" beneath the wordmark.
  final bool showTagline;

  /// Use light text when placed on a burgundy or image background.
  final bool onDark;

  final MainAxisAlignment alignment;

  @override
  Widget build(BuildContext context) {
    if (logoUrl.isNotEmpty) {
      return AppNetworkImage(
        url: logoUrl,
        height: height * (showTagline ? 1.8 : 1),
        fit: BoxFit.contain,
        memCacheWidth: (height * 4).round(),
        placeholderIcon: Icons.diamond_outlined,
      );
    }

    final Widget art = Semantics(
      label: AppConstants.appName,
      image: true,
      child: Image.asset(
        variant.asset,
        height: height,
        fit: BoxFit.contain,
        filterQuality: FilterQuality.medium,
        // A missing or corrupt asset must never blank the brand lockup.
        errorBuilder: (_, _, _) => _textLockup(),
      ),
    );

    if (!showTagline) return art;

    return Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: _cross,
      children: <Widget>[
        art,
        SizedBox(height: height * 0.12),
        Text(
          AppConstants.appSubtitle,
          style: AppTypography.bodySmall.copyWith(
            color: onDark
                ? Colors.white.withValues(alpha: 0.85)
                : AppColors.textSecondary,
            letterSpacing: 0.6,
          ),
        ),
      ],
    );
  }

  /// Horizontal alignment shared by the lockup and its fallback.
  CrossAxisAlignment get _cross => switch (alignment) {
    MainAxisAlignment.center => CrossAxisAlignment.center,
    MainAxisAlignment.end => CrossAxisAlignment.end,
    _ => CrossAxisAlignment.start,
  };

  /// Text-only lockup, used only when the bundled artwork cannot be decoded.
  Widget _textLockup() {
    final Color primary = onDark ? AppColors.white : AppColors.burgundy;

    return Column(
      crossAxisAlignment: _cross,
      mainAxisSize: MainAxisSize.min,
      children: <Widget>[
        Row(
          mainAxisSize: MainAxisSize.min,
          children: <Widget>[
            Container(
              width: height * 0.82,
              height: height * 0.82,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: onDark
                    ? Colors.white.withValues(alpha: 0.16)
                    : AppColors.goldSoft,
                border: Border.all(color: AppColors.gold, width: 1.2),
              ),
              child: Icon(
                Icons.auto_awesome,
                size: height * 0.44,
                color: onDark ? AppColors.goldLight : AppColors.goldDark,
              ),
            ),
            const SizedBox(width: AppSpacing.sm),
            Text(
              'PADMA',
              style: TextStyle(
                fontFamily: AppTypography.heading,
                fontSize: height * 0.52,
                fontWeight: FontWeight.w700,
                letterSpacing: height * 0.09,
                height: 1.05,
                color: primary,
              ),
            ),
          ],
        ),
        Text(
          'COLLECTIONS',
          style: TextStyle(
            fontFamily: AppTypography.body,
            fontSize: height * 0.26,
            fontWeight: FontWeight.w600,
            letterSpacing: height * 0.17,
            height: 1.2,
            color: onDark ? AppColors.goldLight : AppColors.goldDark,
          ),
        ),
        if (showTagline) ...<Widget>[
          SizedBox(height: height * 0.12),
          Text(
            AppConstants.appSubtitle,
            style: AppTypography.bodySmall.copyWith(
              color: onDark
                  ? Colors.white.withValues(alpha: 0.85)
                  : AppColors.textSecondary,
              letterSpacing: 0.6,
            ),
          ),
        ],
      ],
    );
  }
}

/// Section header with an optional eyebrow label and "See all" action.
class SectionHeader extends StatelessWidget {
  const SectionHeader({
    super.key,
    required this.title,
    this.eyebrow,
    this.actionLabel,
    this.onAction,
    this.padding,
  });

  final String title;
  final String? eyebrow;
  final String? actionLabel;
  final VoidCallback? onAction;
  final EdgeInsetsGeometry? padding;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding:
          padding ??
          const EdgeInsets.fromLTRB(
            AppSpacing.gutter,
            AppSpacing.xxl,
            AppSpacing.gutter,
            AppSpacing.md,
          ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.end,
        children: <Widget>[
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: <Widget>[
                if (eyebrow != null) ...<Widget>[
                  Text(eyebrow!.toUpperCase(), style: AppTypography.overline),
                  const SizedBox(height: AppSpacing.xs),
                ],
                Text(title, style: AppTypography.headlineMedium),
              ],
            ),
          ),
          if (actionLabel != null && onAction != null)
            TextButton(
              onPressed: onAction,
              style: TextButton.styleFrom(
                foregroundColor: AppColors.burgundy,
                padding: const EdgeInsets.symmetric(horizontal: AppSpacing.sm),
              ),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: <Widget>[
                  Text(
                    actionLabel!,
                    style: AppTypography.bodyMedium.copyWith(
                      color: AppColors.burgundy,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                  const Icon(Icons.arrow_forward_rounded, size: 16),
                ],
              ),
            ),
        ],
      ),
    );
  }
}

/// Small pill badge used for status, discount and category labels.
class AppBadge extends StatelessWidget {
  const AppBadge({
    super.key,
    required this.label,
    this.color = AppColors.burgundy,
    this.background,
    this.icon,
    this.dense = false,
  });

  final String label;
  final Color color;
  final Color? background;
  final IconData? icon;

  /// Tighter padding for overlays on product imagery.
  final bool dense;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: EdgeInsets.symmetric(
        horizontal: dense ? AppSpacing.sm : AppSpacing.md,
        vertical: dense ? 3 : AppSpacing.xs + 1,
      ),
      decoration: BoxDecoration(
        color: background ?? color.withValues(alpha: 0.1),
        borderRadius: BorderRadius.circular(AppRadius.pill),
        border: Border.all(color: color.withValues(alpha: 0.28)),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: <Widget>[
          if (icon != null) ...<Widget>[
            Icon(icon, size: dense ? 11 : 13, color: color),
            SizedBox(width: dense ? 3 : AppSpacing.xs),
          ],
          Text(
            label,
            style: AppTypography.bodySmall.copyWith(
              color: color,
              fontWeight: FontWeight.w600,
              fontSize: dense ? 10.5 : 12,
            ),
          ),
        ],
      ),
    );
  }
}
