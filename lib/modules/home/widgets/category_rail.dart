import 'package:flutter/material.dart';

import '../../../core/constants/app_colors.dart';
import '../../../core/constants/app_sizes.dart';
import '../../../core/constants/cloudinary_config.dart';
import '../../../core/theme/app_typography.dart';
import '../../../core/widgets/app_network_image.dart';
import '../../../data/models/models.dart';
import 'product_tile.dart';

/// Maps the admin's icon key to a Material icon.
IconData categoryIcon(String key) {
  switch (key) {
    case 'diamond':
      return Icons.diamond_outlined;
    case 'auto_awesome':
      return Icons.auto_awesome_outlined;
    case 'link':
      return Icons.link_rounded;
    case 'donut_large':
      return Icons.donut_large_rounded;
    case 'watch':
      return Icons.watch_outlined;
    case 'radio_button_unchecked':
      return Icons.radio_button_unchecked_rounded;
    case 'waves':
      return Icons.waves_rounded;
    case 'auto_awesome_motion':
      return Icons.auto_awesome_motion_outlined;
    case 'favorite':
      return Icons.favorite_outline_rounded;
    case 'child_care':
      return Icons.child_care_outlined;
    case 'redeem':
      return Icons.redeem_outlined;
    case 'category':
      return Icons.category_outlined;
    default:
      return Icons.diamond_outlined;
  }
}

/// Horizontal rail of category tiles shown at the top of the home screen.
class CategoryRail extends StatelessWidget {
  const CategoryRail({
    super.key,
    required this.categories,
    required this.onTap,
  });

  final List<CategoryModel> categories;
  final void Function(CategoryModel category) onTap;

  @override
  Widget build(BuildContext context) {
    if (categories.isEmpty) return const SizedBox.shrink();

    return SizedBox(
      height: 112,
      child: ListView.separated(
        scrollDirection: Axis.horizontal,
        padding: const EdgeInsets.symmetric(horizontal: AppSpacing.gutter),
        itemCount: categories.length,
        separatorBuilder: (_, __) => const SizedBox(width: AppSpacing.lg),
        itemBuilder: (BuildContext context, int i) {
          final CategoryModel category = categories[i];
          return _CategoryTile(
            category: category,
            onTap: () => onTap(category),
          );
        },
      ),
    );
  }
}

class _CategoryTile extends StatelessWidget {
  const _CategoryTile({required this.category, required this.onTap});

  final CategoryModel category;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: 78,
      child: InkWell(
        onTap: onTap,
        borderRadius: AppRadius.cardRadius,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: <Widget>[
            Container(
              width: 66,
              height: 66,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: AppColors.surfaceMuted,
                border: Border.all(color: AppColors.border),
              ),
              clipBehavior: Clip.antiAlias,
              child: category.hasImage
                  ? AppNetworkImage.cloudinary(
                      category.image!,
                      CloudinaryTransform.category,
                      width: 66,
                      height: 66,
                    )
                  : Icon(
                      categoryIcon(category.icon),
                      size: 26,
                      color: AppColors.goldDark,
                    ),
            ),
            const SizedBox(height: AppSpacing.sm),
            Text(
              category.name,
              maxLines: 2,
              textAlign: TextAlign.center,
              overflow: TextOverflow.ellipsis,
              style: AppTypography.bodySmall.copyWith(
                color: AppColors.textPrimary,
                fontWeight: FontWeight.w500,
                height: 1.25,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

/// A vertically scrolling product grid, used for "See all" style pages.
class ProductGrid extends StatelessWidget {
  const ProductGrid({
    super.key,
    required this.products,
    required this.onTap,
    this.onAddToCart,
    this.onToggleWishlist,
    this.wishlistIds = const <String>{},
    this.padding,
  });

  final List<ProductModel> products;
  final void Function(ProductModel product) onTap;
  final void Function(ProductModel product)? onAddToCart;
  final void Function(ProductModel product)? onToggleWishlist;
  final Set<String> wishlistIds;
  final EdgeInsetsGeometry? padding;

  @override
  Widget build(BuildContext context) {
    final int columns = AppBreakpoints.productGridColumns(context);

    return GridView.builder(
      padding:
          padding ??
          const EdgeInsets.fromLTRB(
            AppSpacing.gutter,
            0,
            AppSpacing.gutter,
            AppSpacing.bottomBarClearance,
          ),
      physics: const NeverScrollableScrollPhysics(),
      shrinkWrap: true,
      itemCount: products.length,
      gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
        crossAxisCount: columns,
        mainAxisSpacing: AppSpacing.xl,
        crossAxisSpacing: AppSpacing.lg,
        // Photography-led cards need a tall aspect ratio.
        childAspectRatio: 0.56,
      ),
      itemBuilder: (BuildContext context, int i) {
        final ProductModel product = products[i];
        return ProductGridTile(
          product: product,
          onTap: () => onTap(product),
          onAddToCart: onAddToCart == null ? null : () => onAddToCart!(product),
          onToggleWishlist: onToggleWishlist == null
              ? null
              : () => onToggleWishlist!(product),
          isInWishlist: wishlistIds.contains(product.productId),
        );
      },
    );
  }
}
