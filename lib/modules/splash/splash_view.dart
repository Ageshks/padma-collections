import 'package:flutter/material.dart';
import 'package:get/get.dart';

import '../../core/constants/app_colors.dart';
import '../../core/constants/app_constants.dart';
import '../../core/constants/app_sizes.dart';
import '../../core/routes/app_routes.dart';
import '../../core/theme/app_typography.dart';
import '../../core/widgets/brand_widgets.dart';
import '../../data/firebase/firebase_bootstrap.dart';
import '../common/controllers/app_controller.dart';

/// Premium splash screen.
///
/// Holds for a moment so the brand registers, then hands off to the login or
/// customer shell depending on the restored session. It also carries the first
/// impression of the Padma Collections identity.
class SplashView extends StatefulWidget {
  const SplashView({super.key});

  @override
  State<SplashView> createState() => _SplashViewState();
}

class _SplashViewState extends State<SplashView>
    with SingleTickerProviderStateMixin {
  late final AnimationController _controller;
  late final Animation<double> _fade;
  late final Animation<double> _scale;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(vsync: this, duration: AppDurations.slow);

    _fade = CurvedAnimation(parent: _controller, curve: Curves.easeOut);
    _scale = Tween<double>(
      begin: 0.9,
      end: 1.0,
    ).animate(CurvedAnimation(parent: _controller, curve: AppDurations.ease));

    _controller.forward();
    _decideDestination();
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  /// Waits for the session to restore, then routes.
  Future<void> _decideDestination() async {
    final AppController app = Get.find<AppController>();

    // Give the brand a beat, and time for the auth listener to fire.
    await Future.wait<void>(<Future<void>>[
      Future<void>.delayed(AppDurations.splash),
      _waitForSession(app),
    ]);

    if (!mounted) return;

    if (app.isAdmin) {
      Get.offAllNamed(Routes.adminShell);
      return;
    }
    if (app.isSignedIn) {
      Get.offAllNamed(Routes.customerShell);
      return;
    }
    Get.offAllNamed(Routes.login);
  }

  /// Waits for the auth listener, but never past the splash duration.
  Future<void> _waitForSession(AppController app) async {
    final int start = DateTime.now().millisecondsSinceEpoch;
    while (app.isInitialising.value &&
        DateTime.now().millisecondsSinceEpoch - start < 2500) {
      await Future<void>.delayed(const Duration(milliseconds: 80));
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.burgundy,
      body: Container(
        decoration: const BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
            colors: <Color>[
              AppColors.burgundyLight,
              AppColors.burgundy,
              AppColors.burgundyDark,
            ],
          ),
        ),
        child: Stack(
          children: <Widget>[
            // Soft gold blooms behind the wordmark.
            Positioned(
              top: -80,
              right: -60,
              child: Container(
                width: 260,
                height: 260,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  color: AppColors.gold.withValues(alpha: 0.14),
                ),
              ),
            ),
            Positioned(
              bottom: -100,
              left: -70,
              child: Container(
                width: 220,
                height: 220,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  color: AppColors.gold.withValues(alpha: 0.1),
                ),
              ),
            ),

            Center(
              child: FadeTransition(
                opacity: _fade,
                child: ScaleTransition(
                  scale: _scale,
                  child: Padding(
                    padding: const EdgeInsets.all(AppSpacing.xxxl),
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: <Widget>[
                        const BrandLogo(
                          height: 190,
                          variant: BrandLogoVariant.full,
                          onDark: true,
                          alignment: MainAxisAlignment.center,
                        ),
                        const SizedBox(height: AppSpacing.xl),
                        const Text(
                          AppConstants.appSubtitle,
                          style: TextStyle(
                            fontFamily: 'Inter',
                            fontSize: 13,
                            letterSpacing: 3,
                            color: AppColors.goldLight,
                            fontWeight: FontWeight.w500,
                          ),
                        ),
                        const SizedBox(height: AppSpacing.huge),
                        SizedBox(
                          width: 26,
                          height: 26,
                          child: CircularProgressIndicator(
                            strokeWidth: 2,
                            valueColor: AlwaysStoppedAnimation<Color>(
                              AppColors.gold.withValues(alpha: 0.85),
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ),
            ),

            // Blocking failure state: the backend is the source of truth for
            // stock, pricing and orders, so the app refuses to continue rather
            // than showing an empty or invented catalogue.
            if (!FirebaseBootstrap.isReady) _BootFailure(),
          ],
        ),
      ),
    );
  }
}

/// Full-screen error shown when Firebase could not be initialised.
class _BootFailure extends StatefulWidget {
  @override
  State<_BootFailure> createState() => _BootFailureState();
}

class _BootFailureState extends State<_BootFailure> {
  bool _retrying = false;

  Future<void> _retry() async {
    setState(() => _retrying = true);
    final FirebaseBootStatus status = await FirebaseBootstrap.init();
    if (!mounted) return;
    setState(() => _retrying = false);

    if (status == FirebaseBootStatus.ready) {
      // A fresh start is the only reliable way to rebuild the GetX graph now
      // that the backend is available.
      Get.until((Route<dynamic> route) => route.settings.name == Routes.splash);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Positioned.fill(
      child: ColoredBox(
        color: AppColors.burgundy,
        child: Center(
          child: Padding(
            padding: const EdgeInsets.all(AppSpacing.xl),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: <Widget>[
                const Icon(
                  Icons.cloud_off_rounded,
                  size: 48,
                  color: AppColors.gold,
                ),
                const SizedBox(height: AppSpacing.lg),
                Text(
                  'We could not reach the store',
                  textAlign: TextAlign.center,
                  style: AppTypography.titleLarge.copyWith(color: Colors.white),
                ),
                const SizedBox(height: AppSpacing.sm),
                Text(
                  FirebaseBootstrap.error ??
                      'Please check your internet connection and try again.',
                  textAlign: TextAlign.center,
                  style: AppTypography.bodySmall.copyWith(
                    color: Colors.white70,
                  ),
                ),
                const SizedBox(height: AppSpacing.xl),
                SizedBox(
                  width: 200,
                  height: 44,
                  child: ElevatedButton(
                    onPressed: _retrying ? null : _retry,
                    style: ElevatedButton.styleFrom(
                      backgroundColor: AppColors.gold,
                      foregroundColor: AppColors.burgundy,
                    ),
                    child: _retrying
                        ? const SizedBox(
                            height: 18,
                            width: 18,
                            child: CircularProgressIndicator(
                              strokeWidth: 2,
                              color: AppColors.burgundy,
                            ),
                          )
                        : const Text('Try again'),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
