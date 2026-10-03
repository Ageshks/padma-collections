import 'package:flutter/material.dart';

import '../../../core/constants/app_colors.dart';
import '../../../core/constants/app_sizes.dart';
import '../../../core/constants/cloudinary_config.dart';
import '../../../core/theme/app_typography.dart';
import '../../../core/utils/app_formatter.dart';
import '../../../core/widgets/app_network_image.dart';
import '../../../core/widgets/brand_widgets.dart';
import '../../../data/models/models.dart';

/// Grid cell variant of the product card.
///
/// Functionally the same as `ProductCard`, but sized for a grid rather than a
/// fixed-width horizontal rail.
class ProductGridTile extends StatelessWidget {
  const ProductGridTile({
    super.key,
    required this.product,
    required this.onTap,
    this.onAddToCart,
    this.onToggleWishlist,
    this.isInWishlist = false,
  });

  final ProductModel product;
  final VoidCallback onTap;
  final VoidCallback? onAddToCart;
  final VoidCallback? onToggleWishlist;
  final bool isInWishlist;

  @override
  Widget build(BuildContext context) {
    final String badge = product.badgeLabel;

    return InkWell(
      onTap: onTap,
      borderRadius: AppRadius.cardRadius,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisSize: MainAxisSize.min,
        children: <Widget>[
          AspectRatio(
            aspectRatio: 1,
            child: _image(context, badge),
          ),
          const SizedBox(height: AppSpacing.md),
          Text(
            product.name,
            maxLines: 2,
            overflow: TextOverflow.ellipsis,
            style: AppTypography.titleMedium.copyWith(height: 1.3),
          ),
          const SizedBox(height: AppSpacing.xs),
          _price(),
          if (onAddToCart != null) ...<Widget>[
            const SizedBox(height: AppSpacing.sm),
            _addButton(context),
          ],
        ],
      ),
    );
  }

  Widget _image(BuildContext context, String badge) {
    return Stack(
      fit: StackFit.expand,
      children: <Widget>[
        Container(
          decoration: BoxDecoration(
            borderRadius: AppRadius.cardRadius,
            color: AppColors.surfaceMuted,
          ),
          child: product.primaryImageRef == null
              ? null
              : AppNetworkImage.cloudinary(
                  product.primaryImageRef!,
                  CloudinaryTransform.productCard,
                ),
        ),
        if (badge.isNotEmpty)
          Positioned(
            top: AppSpacing.sm,
            left: AppSpacing.sm,
            child: AppBadge(
              label: badge,
              dense: true,
              color: product.inStock
                  ? AppColors.burgundy
                  : AppColors.textSecondary,
              background: product.inStock
                  ? AppColors.white
                  : AppColors.surfaceMuted,
            ),
          ),
        if (onToggleWishlist != null)
          Positioned(
            top: AppSpacing.sm,
            right: AppSpacing.sm,
            child: _Heart(active: isInWishlist, onTap: onToggleWishlist!),
          ),
        if (!product.inStock)
          Positioned.fill(
            child: Container(
              decoration: BoxDecoration(
                borderRadius: AppRadius.cardRadius,
                color: Colors.white.withValues(alpha: 0.55),
              ),
            ),
          ),
      ],
    );
  }

  Widget _price() {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.end,
      children: <Widget>[
        Text(
          AppFormatter.currency(product.price),
          style: AppTypography.priceSmall,
        ),
        if (product.hasDiscount) ...<Widget>[
          const SizedBox(width: AppSpacing.xs),
          Expanded(
            child: Text(
              AppFormatter.currency(product.compareAtPrice),
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: AppTypography.bodySmall.copyWith(
                decoration: TextDecoration.lineThrough,
                color: AppColors.textHint,
                fontSize: 11,
              ),
            ),
          ),
        ],
      ],
    );
  }

  Widget _addButton(BuildContext context) {
    return SizedBox(
      height: 36,
      width: double.infinity,
      child: OutlinedButton(
        onPressed: product.inStock ? onAddToCart : null,
        style: OutlinedButton.styleFrom(
          padding: EdgeInsets.zero,
          side: BorderSide(
            color: product.inStock ? AppColors.border : AppColors.divider,
          ),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(AppRadius.sm),
          ),
        ),
        child: Text(
          product.inStock ? 'Add to Cart' : 'Out of Stock',
          style: AppTypography.bodySmall.copyWith(
            fontSize: 12,
            fontWeight: FontWeight.w600,
            color: product.inStock ? AppColors.burgundy : AppColors.textHint,
          ),
        ),
      ),
    );
  }
}

class _Heart extends StatelessWidget {
  const _Heart({required this.active, required this.onTap});

  final bool active;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Material(
      color: AppColors.white,
      shape: const CircleBorder(),
      elevation: 2,
      child: InkWell(
        onTap: onTap,
        customBorder: const CircleBorder(),
        child: Padding(
          padding: const EdgeInsets.all(6),
          child: Icon(
            active ? Icons.favorite_rounded : Icons.favorite_border_rounded,
            size: 16,
            color: active ? AppColors.burgundy : AppColors.textSecondary,
          ),
        ),
      ),
    );
  }
}
