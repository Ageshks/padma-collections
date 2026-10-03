import 'package:flutter/material.dart';

import '../constants/app_colors.dart';
import '../constants/app_sizes.dart';
import '../theme/app_typography.dart';

/// Friendly empty state — e.g. "No jewellery found.", "Your cart is empty."
class EmptyState extends StatelessWidget {
  const EmptyState({
    super.key,
    required this.title,
    this.message,
    this.icon = Icons.inbox_outlined,
    this.actionLabel,
    this.onAction,
    this.compact = false,
  });

  final String title;
  final String? message;
  final IconData icon;

  /// Optional call-to-action button label.
  final String? actionLabel;
  final VoidCallback? onAction;

  /// Tighter spacing for use inside a tab or section.
  final bool compact;

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: EdgeInsets.symmetric(
          horizontal: AppSpacing.xxl,
          vertical: compact ? AppSpacing.xxl : AppSpacing.huge,
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: <Widget>[
            Container(
              width: compact ? 72 : 96,
              height: compact ? 72 : 96,
              decoration: const BoxDecoration(
                shape: BoxShape.circle,
                color: AppColors.surfaceMuted,
              ),
              child: Icon(
                icon,
                size: compact ? 30 : 40,
                color: AppColors.goldDark,
              ),
            ),
            SizedBox(height: compact ? AppSpacing.lg : AppSpacing.xxl),
            Text(
              title,
              textAlign: TextAlign.center,
              style: compact
                  ? AppTypography.titleMedium
                  : AppTypography.headlineMedium,
            ),
            if (message != null && message!.isNotEmpty) ...<Widget>[
              const SizedBox(height: AppSpacing.sm),
              Text(
                message!,
                textAlign: TextAlign.center,
                style: AppTypography.bodyMedium,
              ),
            ],
            if (actionLabel != null && onAction != null) ...<Widget>[
              SizedBox(height: compact ? AppSpacing.lg : AppSpacing.xxl),
              FilledButton(
                onPressed: onAction,
                style: FilledButton.styleFrom(
                  backgroundColor: AppColors.burgundy,
                  foregroundColor: AppColors.white,
                  padding: const EdgeInsets.symmetric(
                    horizontal: AppSpacing.xxl,
                    vertical: AppSpacing.md,
                  ),
                  textStyle: AppTypography.button,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(AppRadius.md),
                  ),
                ),
                child: Text(actionLabel!),
              ),
            ],
          ],
        ),
      ),
    );
  }
}

/// Friendly error state with a retry affordance.
class ErrorStateView extends StatelessWidget {
  const ErrorStateView({
    super.key,
    required this.message,
    this.onRetry,
    this.title = 'Something went wrong',
    this.icon = Icons.cloud_off_rounded,
  });

  final String message;
  final String title;
  final IconData icon;
  final VoidCallback? onRetry;

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(AppSpacing.xxl),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: <Widget>[
            Container(
              width: 88,
              height: 88,
              decoration: const BoxDecoration(
                shape: BoxShape.circle,
                color: AppColors.dangerSoft,
              ),
              child: Icon(icon, size: 38, color: AppColors.danger),
            ),
            const SizedBox(height: AppSpacing.xl),
            Text(
              title,
              textAlign: TextAlign.center,
              style: AppTypography.headlineMedium,
            ),
            const SizedBox(height: AppSpacing.sm),
            Text(
              message,
              textAlign: TextAlign.center,
              style: AppTypography.bodyMedium,
            ),
            if (onRetry != null) ...<Widget>[
              const SizedBox(height: AppSpacing.xl),
              OutlinedButton.icon(
                onPressed: onRetry,
                icon: const Icon(Icons.refresh_rounded, size: 18),
                label: const Text('Try again'),
                style: OutlinedButton.styleFrom(
                  foregroundColor: AppColors.burgundy,
                  side: const BorderSide(color: AppColors.border, width: 1.4),
                  padding: const EdgeInsets.symmetric(
                    horizontal: AppSpacing.xl,
                    vertical: AppSpacing.md,
                  ),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(AppRadius.md),
                  ),
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }
}

/// A slim offline banner shown above page content.
class OfflineBanner extends StatelessWidget {
  const OfflineBanner({super.key, this.isOnline = true});

  final bool isOnline;

  @override
  Widget build(BuildContext context) {
    return AnimatedSize(
      duration: AppDurations.normal,
      curve: AppDurations.ease,
      alignment: Alignment.topCenter,
      child: isOnline
          ? const SizedBox.shrink()
          : Container(
              width: double.infinity,
              color: AppColors.warningSoft,
              padding: const EdgeInsets.symmetric(
                horizontal: AppSpacing.lg,
                vertical: AppSpacing.sm,
              ),
              child: Row(
                children: <Widget>[
                  const Icon(
                    Icons.wifi_off_rounded,
                    size: 16,
                    color: AppColors.warning,
                  ),
                  const SizedBox(width: AppSpacing.sm),
                  Expanded(
                    child: Text(
                      "You're offline. Some things may not update.",
                      style: AppTypography.bodySmall.copyWith(
                        color: AppColors.warning,
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                  ),
                ],
              ),
            ),
    );
  }
}
