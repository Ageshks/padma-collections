import 'package:flutter/material.dart';

import '../../core/constants/app_colors.dart';
import '../../core/constants/app_sizes.dart';
import '../../core/constants/cloudinary_config.dart';
import '../../core/theme/app_typography.dart';
import '../../core/utils/app_formatter.dart';
import '../../core/widgets/app_network_image.dart';
import '../../core/widgets/brand_widgets.dart';
import '../../data/models/models.dart';

/// The product card used across home rails, category listings and search.
///
/// Photography leads: the image takes the whole card, with only a name, price
/// and a single action beneath it. This is what keeps the interface from
/// feeling crowded.
class ProductCard extends StatelessWidget {
  const ProductCard({
    super.key,
    required this.product,
    required this.onTap,
    this.onAddToCart,
    this.onToggleWishlist,
    this.isInWishlist = false,
    this.width,
    this.showAddButton = true,
  });

  final ProductModel product;
  final VoidCallback onTap;
  final VoidCallback? onAddToCart;
  final VoidCallback? onToggleWishlist;
  final bool isInWishlist;

  /// Fixed width for horizontal rails; null means "fill the grid cell".
  final double? width;

  /// Hidden in dense listings where a tap already opens the product.
  final bool showAddButton;

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: width,
      child: InkWell(
        onTap: onTap,
        borderRadius: AppRadius.cardRadius,
        // The card is laid out against whatever height the parent gives it, so
        // it must be a bounded-height slot: the image absorbs the leftover
        // space and the text block below keeps its intrinsic size. Deriving
        // the image height from an AspectRatio instead would make the card's
        // natural height depend on its width, which overflows the moment a
        // grid cell is narrower than the ratio assumed.
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: <Widget>[
            ConstrainedBox(
              constraints: const BoxConstraints(minHeight: 0),
              child: AspectRatio(
                aspectRatio: 1,
                child: _image(),
              ),
            ),
            const SizedBox(height: AppSpacing.sm),
            _details(),
          ],
        ),
      ),
    );
  }

  Widget _image() {
    final String badge = product.badgeLabel;
    // No AspectRatio here on purpose: the parent owns the height and the image
    // fills it, cropping with BoxFit.cover. Photography is therefore always
    // fully visible rather than being squeezed out of the card.
    return Stack(
      fit: StackFit.expand,
      children: <Widget>[
        Hero(
          tag: 'product-image-${product.productId}',
          child: Container(
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
        ),

        // Discount or stock badge, top-left.
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

        // Wishlist heart, top-right.
        if (onToggleWishlist != null)
          Positioned(
            top: AppSpacing.sm,
            right: AppSpacing.sm,
            child: _HeartButton(
              isActive: isInWishlist,
              onTap: onToggleWishlist!,
            ),
          ),

        // Dim out sold-out items rather than hiding them.
        if (!product.inStock)
          Positioned.fill(
            child: Container(
              decoration: BoxDecoration(
                borderRadius: AppRadius.cardRadius,
                color: AppColors.white.withValues(alpha: 0.55),
              ),
            ),
          ),
      ],
    );
  }

  Widget _details() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      mainAxisSize: MainAxisSize.min,
      children: <Widget>[
        Text(
          product.categoryName.toUpperCase(),
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
          style: AppTypography.overline.copyWith(
            fontSize: 10,
            letterSpacing: 1.2,
          ),
        ),
        const SizedBox(height: AppSpacing.xs),
        // A fixed two-line box keeps every card in a row the same height
        // whether the name wraps once or twice, so the grid stays aligned.
        SizedBox(
          height: 36,
          child: Text(
            product.name,
            maxLines: 2,
            overflow: TextOverflow.ellipsis,
            style: AppTypography.titleMedium.copyWith(height: 1.3),
          ),
        ),
        const SizedBox(height: AppSpacing.sm),
        Row(
          crossAxisAlignment: CrossAxisAlignment.end,
          children: <Widget>[
            Text(
              AppFormatter.currency(product.price),
              style: AppTypography.price,
            ),
            if (product.hasDiscount) ...<Widget>[
              const SizedBox(width: AppSpacing.sm),
              Flexible(
                child: Text(
                  AppFormatter.currency(product.compareAtPrice),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: AppTypography.bodySmall.copyWith(
                    decoration: TextDecoration.lineThrough,
                    color: AppColors.textHint,
                  ),
                ),
              ),
            ],
          ],
        ),
        if (showAddButton && onAddToCart != null) ...<Widget>[
          const SizedBox(height: AppSpacing.md),
          _AddToCartButton(enabled: product.inStock, onTap: onAddToCart!),
        ],
      ],
    );
  }
}

/// Circular wishlist toggle that sits over product photography.
class _HeartButton extends StatelessWidget {
  const _HeartButton({required this.isActive, required this.onTap});

  final bool isActive;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Semantics(
      button: true,
      label: isActive ? 'Remove from wishlist' : 'Add to wishlist',
      child: Material(
        color: AppColors.white,
        shape: const CircleBorder(),
        elevation: 2,
        child: InkWell(
          onTap: onTap,
          customBorder: const CircleBorder(),
          child: Padding(
            padding: const EdgeInsets.all(7),
            child: AnimatedSwitcher(
              duration: AppDurations.fast,
              transitionBuilder: (Widget child, Animation<double> anim) =>
                  ScaleTransition(scale: anim, child: child),
              child: Icon(
                isActive
                    ? Icons.favorite_rounded
                    : Icons.favorite_border_rounded,
                key: ValueKey<bool>(isActive),
                size: 17,
                color: isActive ? AppColors.burgundy : AppColors.textSecondary,
              ),
            ),
          ),
        ),
      ),
    );
  }
}

/// Compact "Add to cart" button.
class _AddToCartButton extends StatelessWidget {
  const _AddToCartButton({required this.enabled, required this.onTap});

  final bool enabled;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      height: 38,
      width: double.infinity,
      child: OutlinedButton.icon(
        onPressed: enabled ? onTap : null,
        icon: Icon(
          Icons.add_shopping_cart_rounded,
          size: 16,
          color: enabled ? AppColors.burgundy : AppColors.textHint,
        ),
        label: Text(
          enabled ? 'Add to Cart' : 'Out of Stock',
          style: AppTypography.bodySmall.copyWith(
            fontWeight: FontWeight.w600,
            color: enabled ? AppColors.burgundy : AppColors.textHint,
          ),
        ),
        style: OutlinedButton.styleFrom(
          padding: EdgeInsets.zero,
          side: BorderSide(
            color: enabled ? AppColors.border : AppColors.divider,
          ),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(AppRadius.sm),
          ),
        ),
      ),
    );
  }
}

/// Plus / minus quantity stepper used on the product page and in the cart.
class QuantityStepper extends StatelessWidget {
  const QuantityStepper({
    super.key,
    required this.quantity,
    required this.onChanged,
    this.min = 1,
    this.max = 20,
    this.compact = false,
  });

  final int quantity;
  final ValueChanged<int> onChanged;
  final int min;
  final int max;

  /// Tighter sizing for cart rows.
  final bool compact;

  @override
  Widget build(BuildContext context) {
    final double buttonSize = compact ? 30 : 38;

    return Container(
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(AppRadius.sm),
        border: Border.all(color: AppColors.border),
        color: AppColors.surface,
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: <Widget>[
          _StepperButton(
            icon: Icons.remove_rounded,
            size: buttonSize,
            enabled: quantity > min,
            onTap: () => onChanged(quantity - 1),
          ),
          Container(
            constraints: BoxConstraints(minWidth: compact ? 26 : 34),
            alignment: Alignment.center,
            child: Text(
              '$quantity',
              style: compact
                  ? AppTypography.titleMedium
                  : AppTypography.titleLarge,
            ),
          ),
          _StepperButton(
            icon: Icons.add_rounded,
            size: buttonSize,
            enabled: quantity < max,
            onTap: () => onChanged(quantity + 1),
          ),
        ],
      ),
    );
  }
}

class _StepperButton extends StatelessWidget {
  const _StepperButton({
    required this.icon,
    required this.size,
    required this.enabled,
    required this.onTap,
  });

  final IconData icon;
  final double size;
  final bool enabled;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: enabled ? onTap : null,
      borderRadius: BorderRadius.circular(AppRadius.sm),
      child: SizedBox(
        width: size,
        height: size,
        child: Icon(
          icon,
          size: size * 0.5,
          color: enabled ? AppColors.burgundy : AppColors.textHint,
        ),
      ),
    );
  }
}
