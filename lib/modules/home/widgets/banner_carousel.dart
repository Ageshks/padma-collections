import 'dart:async';

import 'package:flutter/material.dart';

import '../../../core/constants/app_colors.dart';
import '../../../core/constants/app_sizes.dart';
import '../../../core/constants/cloudinary_config.dart';
import '../../../core/theme/app_typography.dart';
import '../../../core/widgets/app_network_image.dart';
import '../../../core/widgets/brand_widgets.dart';
import '../../../data/models/models.dart';

/// Auto-advancing hero carousel for the home screen.
///
/// Falls back to a brand-styled gradient panel when the admin has not uploaded
/// an image, so the slot is never blank.
class BannerCarousel extends StatefulWidget {
  const BannerCarousel({super.key, required this.banners, this.onTap});

  final List<BannerModel> banners;
  final void Function(BannerModel banner)? onTap;

  @override
  State<BannerCarousel> createState() => _BannerCarouselState();
}

class _BannerCarouselState extends State<BannerCarousel> {
  final PageController _controller = PageController();
  int _index = 0;
  Timer? _timer;

  @override
  void initState() {
    super.initState();
    _startAutoAdvance();
  }

  @override
  void didUpdateWidget(BannerCarousel oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.banners.length != widget.banners.length) {
      _index = 0;
      _startAutoAdvance();
    }
  }

  @override
  void dispose() {
    _timer?.cancel();
    _controller.dispose();
    super.dispose();
  }

  /// Cycles every 5 seconds; a single banner does not need a timer.
  void _startAutoAdvance() {
    _timer?.cancel();
    if (widget.banners.length <= 1) return;
    _timer = Timer.periodic(const Duration(seconds: 5), (_) {
      if (!mounted || !_controller.hasClients) return;
      final int next = (_index + 1) % widget.banners.length;
      _controller.animateToPage(
        next,
        duration: AppDurations.normal,
        curve: AppDurations.ease,
      );
    });
  }

  @override
  Widget build(BuildContext context) {
    if (widget.banners.isEmpty) return const SizedBox.shrink();

    return Column(
      children: <Widget>[
        SizedBox(
          height: AppBreakpoints.isMobile(context) ? 196 : 260,
          child: PageView.builder(
            controller: _controller,
            itemCount: widget.banners.length,
            onPageChanged: (int i) => setState(() => _index = i),
            itemBuilder: (BuildContext context, int i) {
              return Padding(
                padding: const EdgeInsets.symmetric(
                  horizontal: AppSpacing.gutter,
                ),
                child: _BannerSlide(
                  banner: widget.banners[i],
                  onTap: () => widget.onTap?.call(widget.banners[i]),
                ),
              );
            },
          ),
        ),
        if (widget.banners.length > 1)
          Padding(
            padding: const EdgeInsets.only(top: AppSpacing.md),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: List<Widget>.generate(widget.banners.length, (int i) {
                final bool active = i == _index;
                return AnimatedContainer(
                  duration: AppDurations.fast,
                  margin: const EdgeInsets.symmetric(horizontal: 3),
                  width: active ? 20 : 6,
                  height: 6,
                  decoration: BoxDecoration(
                    color: active ? AppColors.burgundy : AppColors.border,
                    borderRadius: BorderRadius.circular(AppRadius.pill),
                  ),
                );
              }),
            ),
          ),
      ],
    );
  }
}

/// A single banner panel.
class _BannerSlide extends StatelessWidget {
  const _BannerSlide({required this.banner, required this.onTap});

  final BannerModel banner;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onTap,
      borderRadius: AppRadius.cardRadius,
      child: ClipRRect(
        borderRadius: AppRadius.cardRadius,
        child: Stack(
          fit: StackFit.expand,
          children: <Widget>[
            if (banner.hasImage)
              AppNetworkImage.cloudinary(
                banner.image!,
                CloudinaryTransform.banner,
              )
            else
              Container(
                decoration: const BoxDecoration(
                  gradient: AppGradients.burgundy,
                ),
                alignment: Alignment.center,
                child: const BrandLogo(
                  height: 52,
                  variant: BrandLogoVariant.full,
                  onDark: true,
                  alignment: MainAxisAlignment.center,
                ),
              ),

            // Scrim keeps white text legible over photography.
            Container(
              decoration: const BoxDecoration(gradient: AppGradients.heroScrim),
            ),

            Positioned(
              left: AppSpacing.lg,
              right: AppSpacing.lg,
              bottom: AppSpacing.lg,
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisSize: MainAxisSize.min,
                children: <Widget>[
                  Text(
                    banner.title,
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                    style: AppTypography.displayMedium.copyWith(
                      color: Colors.white,
                      fontSize: AppBreakpoints.isMobile(context) ? 22 : 28,
                    ),
                  ),
                  if (banner.subtitle.isNotEmpty) ...<Widget>[
                    const SizedBox(height: AppSpacing.xs),
                    Text(
                      banner.subtitle,
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                      style: AppTypography.bodyMedium.copyWith(
                        color: Colors.white.withValues(alpha: 0.92),
                      ),
                    ),
                  ],
                  if (banner.buttonText.isNotEmpty) ...<Widget>[
                    const SizedBox(height: AppSpacing.lg),
                    Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: AppSpacing.lg,
                        vertical: AppSpacing.md,
                      ),
                      decoration: BoxDecoration(
                        color: AppColors.gold,
                        borderRadius: BorderRadius.circular(AppRadius.sm),
                      ),
                      child: Text(
                        banner.buttonText,
                        style: AppTypography.button.copyWith(
                          color: AppColors.darkBrown,
                        ),
                      ),
                    ),
                  ],
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}
