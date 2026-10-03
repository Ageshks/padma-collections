import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';
import 'package:shimmer/shimmer.dart';

import '../constants/app_colors.dart';
import '../constants/app_sizes.dart';
import '../constants/cloudinary_config.dart';
import '../utils/app_formatter.dart';
import '../../data/models/cloudinary_image.dart';

/// A cached, shimmering, placeholder-aware network image.
///
/// Every product photo in the app goes through this widget so imagery is
/// cached on disk (dramatically cutting Firebase Storage egress on repeat
/// views) and so loading, error and empty states are consistent everywhere.
class AppNetworkImage extends StatelessWidget {
  const AppNetworkImage({
    super.key,
    required this.url,
    this.width,
    this.height,
    this.fit = BoxFit.cover,
    this.borderRadius,
    this.memCacheWidth,
    this.placeholderIcon = Icons.diamond_outlined,
  });

  /// Renders a Cloudinary image at a specific transformation.
  ///
  /// Preferred over passing a raw URL: it requests the right size for the
  /// context (a 200px wishlist row should never download the 1200px detail
  /// image) and falls back to the stored original when no cloud name is
  /// configured.
  ///
  /// Not `const`: building the URL reads the cloud name, which is loaded at
  /// runtime rather than being a compile-time constant.
  AppNetworkImage.cloudinary(
    CloudinaryImage image,
    CloudinaryTransform variant, {
    super.key,
    this.width,
    this.height,
    this.fit = BoxFit.cover,
    this.borderRadius,
    int? memCacheWidth,
    this.placeholderIcon = Icons.diamond_outlined,
  }) : url = image.urlFor(variant),
       memCacheWidth = memCacheWidth ?? _defaultDecodeWidth(variant);

  final String url;
  final double? width;
  final double? height;
  final BoxFit fit;
  final BorderRadius? borderRadius;

  /// Decoded pixel width. Supplying this keeps memory use down on long lists.
  final int? memCacheWidth;

  final IconData placeholderIcon;

  /// Sensible decode width for a transformation, so callers rarely hardcode one.
  static int _defaultDecodeWidth(CloudinaryTransform variant) =>
      variant.decodeWidth;

  @override
  Widget build(BuildContext context) {
    final Widget image = url.isEmpty
        ? _placeholder()
        : CachedNetworkImage(
            imageUrl: url,
            width: width,
            height: height,
            fit: fit,
            memCacheWidth: memCacheWidth,
            fadeInDuration: AppDurations.normal,
            fadeOutDuration: AppDurations.fast,
            placeholder: (_, __) => _shimmer(),
            errorWidget: (_, __, ___) => _placeholder(isError: true),
          );

    if (borderRadius == null) return image;
    return ClipRRect(borderRadius: borderRadius!, child: image);
  }

  /// Neutral placeholder used when there is no image at all.
  Widget _placeholder({bool isError = false}) {
    return Container(
      width: width,
      height: height,
      color: AppColors.surfaceMuted,
      alignment: Alignment.center,
      child: Icon(
        isError ? Icons.broken_image_outlined : placeholderIcon,
        color: AppColors.textHint,
        size: 28,
      ),
    );
  }

  Widget _shimmer() {
    return Container(
      width: width,
      height: height,
      color: AppColors.surfaceMuted,
      child: Shimmer.fromColors(
        baseColor: AppColors.surfaceMuted,
        highlightColor: AppColors.goldSoft,
        period: const Duration(milliseconds: 1400),
        child: Container(color: Colors.white),
      ),
    );
  }
}

/// A square or circular user avatar with a graceful initials fallback.
class AppAvatar extends StatelessWidget {
  const AppAvatar({
    super.key,
    required this.name,
    this.imageUrl = '',
    this.radius = 24,
    this.showBorder = false,
  });

  final String name;
  final String imageUrl;
  final double radius;
  final bool showBorder;

  @override
  Widget build(BuildContext context) {
    final Widget avatar = Container(
      width: radius * 2,
      height: radius * 2,
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        color: AppColors.burgundySoft,
        border: showBorder
            ? Border.all(color: AppColors.gold, width: 1.5)
            : null,
      ),
      clipBehavior: Clip.antiAlias,
      child: imageUrl.isNotEmpty
          ? AppNetworkImage(
              url: imageUrl,
              width: radius * 2,
              height: radius * 2,
              memCacheWidth: (radius * 4).round(),
              placeholderIcon: Icons.person_outline,
            )
          : Center(
              child: Text(
                StringUtils.initials(name),
                style: TextStyle(
                  fontFamily: AppTypographyFallback.body,
                  fontSize: radius * 0.7,
                  fontWeight: FontWeight.w600,
                  color: AppColors.burgundy,
                ),
              ),
            ),
    );
    return avatar;
  }
}

/// Minimal local alias so this widget file does not import the whole theme
/// barrel just for one font family.
class AppTypographyFallback {
  AppTypographyFallback._();

  static const String body = 'Inter';
}
