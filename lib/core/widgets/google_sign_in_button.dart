import 'package:flutter/material.dart';

import '../../core/constants/app_colors.dart';
import '../../core/constants/app_sizes.dart';
import '../../core/theme/app_typography.dart';

/// "Continue with Google" button.
///
/// Hidden entirely when Google Sign-In is unavailable on the current build or
/// platform, so customers are never offered a button that cannot work.
class GoogleSignInButton extends StatelessWidget {
  const GoogleSignInButton({
    super.key,
    required this.onPressed,
    this.isLoading = false,
    this.label = 'Continue with Google',
  });

  final VoidCallback? onPressed;
  final bool isLoading;
  final String label;

  /// Official Google brand colours — kept local so the button always looks
  /// correct even if the app palette changes.
  static const Color _googleBlue = Color(0xFF4285F4);
  static const Color _googleRed = Color(0xFFEA4335);
  static const Color _googleYellow = Color(0xFFFBBC05);
  static const Color _googleGreen = Color(0xFF34A853);

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      height: 52,
      width: double.infinity,
      child: OutlinedButton(
        onPressed: isLoading ? null : onPressed,
        style: OutlinedButton.styleFrom(
          backgroundColor: AppColors.surface,
          foregroundColor: AppColors.textPrimary,
          side: const BorderSide(color: AppColors.border, width: 1.4),
          padding: const EdgeInsets.symmetric(horizontal: AppSpacing.lg),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(AppRadius.md),
          ),
        ),
        child: isLoading
            ? const SizedBox(
                width: 20,
                height: 20,
                child: CircularProgressIndicator(strokeWidth: 2),
              )
            : Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: <Widget>[
                  const _GoogleGlyph(),
                  const SizedBox(width: AppSpacing.md),
                  Text(label, style: AppTypography.button),
                ],
              ),
      ),
    );
  }
}

/// The four-colour Google "G" mark, drawn rather than shipped as an asset so
/// it stays crisp at any size.
class _GoogleGlyph extends StatelessWidget {
  const _GoogleGlyph();

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: 19,
      height: 19,
      child: CustomPaint(painter: _GoogleGlyphPainter()),
    );
  }
}

class _GoogleGlyphPainter extends CustomPainter {
  @override
  void paint(Canvas canvas, Size size) {
    final double w = size.width;
    final double h = size.height;
    final Paint paint = Paint()..style = PaintingStyle.stroke;
    paint.strokeWidth = w * 0.19;
    paint.strokeCap = StrokeCap.round;

    // Blue — right arc.
    paint.color = GoogleSignInButton._googleBlue;
    canvas.drawArc(
      Rect.fromLTWH(w * 0.28, 0, w * 0.44, h),
      -1.5708,
      2.0944,
      false,
      paint,
    );

    // Green — bottom arc.
    paint.color = GoogleSignInButton._googleGreen;
    canvas.drawArc(
      Rect.fromLTWH(w * 0.28, h * 0.18, w * 0.44, h * 0.64),
      1.5708,
      2.0944,
      false,
      paint,
    );

    // Yellow — left arc.
    paint.color = GoogleSignInButton._googleYellow;
    canvas.drawArc(
      Rect.fromLTWH(w * 0.26, 0, w * 0.48, h),
      3.1416,
      1.5708,
      false,
      paint,
    );

    // Red — top bar.
    paint.color = GoogleSignInButton._googleRed;
    canvas.drawLine(Offset(w * 0.5, h * 0.5), Offset(w * 0.5, 0), paint);
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}
