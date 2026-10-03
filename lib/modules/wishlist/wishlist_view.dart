import 'package:flutter/material.dart';
import 'package:get/get.dart';

import '../../core/constants/app_colors.dart';
import '../../core/constants/app_sizes.dart';
import '../../core/routes/app_routes.dart';
import '../../core/theme/app_typography.dart';
import '../../core/utils/app_formatter.dart';
import '../../core/widgets/app_network_image.dart';
import '../../core/widgets/brand_widgets.dart';
import '../../core/widgets/state_views.dart';
import '../../data/models/models.dart';
import '../cart/cart_controller.dart';
import '../customer/customer_bindings.dart';
import '../home/widgets/whatsapp_fab.dart';
import 'wishlist_controller.dart';

/// Wishlist tab: saved pieces, ready to move into the cart.
class WishlistView extends StatelessWidget {
  const WishlistView({super.key});

  @override
  Widget build(BuildContext context) {
    final WishlistController controller = Get.find<WishlistController>();

    return Scaffold(
      backgroundColor: AppColors.background,
      floatingActionButton: const WhatsappFab(),
      body: SafeArea(
        bottom: false,
        child: Obx(() {
          if (controller.isLoading.value) {
            return const Center(
              child: CircularProgressIndicator(color: AppColors.burgundy),
            );
          }
          if (controller.isEmpty) {
            return EmptyState(
              title: 'Your wishlist is empty.',
              message:
                  'Tap the heart on any piece you love and it will be saved '
                  'here.',
              icon: Icons.favorite_border_rounded,
              actionLabel: 'Start browsing',
              onAction: () => Get.find<CustomerShellController>().changeTab(0),
            );
          }

          return Column(
            children: <Widget>[
              Padding(
                padding: const EdgeInsets.fromLTRB(
                  AppSpacing.gutter,
                  AppSpacing.lg,
                  AppSpacing.gutter,
                  AppSpacing.sm,
                ),
                child: Row(
                  children: <Widget>[
                    const Expanded(
                      child: SectionHeader(
                        title: 'Wishlist',
                        eyebrow: 'Saved',
                        padding: EdgeInsets.zero,
                      ),
                    ),
                    Text(
                      '${controller.count} '
                      '${controller.count == 1 ? 'item' : 'items'}',
                      style: AppTypography.bodyMedium,
                    ),
                  ],
                ),
              ),
              Expanded(
                child: ListView.separated(
                  padding: const EdgeInsets.fromLTRB(
                    AppSpacing.gutter,
                    AppSpacing.sm,
                    AppSpacing.gutter,
                    AppSpacing.bottomBarClearance,
                  ),
                  itemCount: controller.items.length,
                  separatorBuilder: (_, __) =>
                      const SizedBox(height: AppSpacing.md),
                  itemBuilder: (BuildContext context, int i) =>
                      _WishlistTile(item: controller.items[i]),
                ),
              ),
            ],
          );
        }),
      ),
    );
  }
}

/// One saved product: thumbnail, price and a quick add-to-cart.
class _WishlistTile extends StatelessWidget {
  const _WishlistTile({required this.item});

  final WishlistItem item;

  @override
  Widget build(BuildContext context) {
    final WishlistController wishlist = Get.find<WishlistController>();
    final CartController cart = Get.find<CartController>();

    return Container(
      padding: const EdgeInsets.all(AppSpacing.md),
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: AppRadius.cardRadius,
        boxShadow: AppColors.cardShadow,
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          InkWell(
            onTap: () =>
                Get.toNamed(Routes.productDetails, arguments: item.productId),
            borderRadius: AppRadius.tileRadius,
            child: SizedBox(
              width: 88,
              height: 110,
              child: AppNetworkImage(
                url: item.image,
                borderRadius: AppRadius.tileRadius,
                memCacheWidth: 300,
              ),
            ),
          ),
          const SizedBox(width: AppSpacing.md),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: <Widget>[
                Text(
                  item.name,
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                  style: AppTypography.titleMedium,
                ),
                const SizedBox(height: AppSpacing.xs),
                Row(
                  children: <Widget>[
                    Text(
                      AppFormatter.currency(item.price),
                      style: AppTypography.priceSmall,
                    ),
                    if (item.hasDiscount) ...<Widget>[
                      const SizedBox(width: AppSpacing.sm),
                      Flexible(
                        child: Text(
                          AppFormatter.currency(item.compareAtPrice),
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
                const SizedBox(height: AppSpacing.md),
                Row(
                  children: <Widget>[
                    Expanded(
                      child: SizedBox(
                        height: 36,
                        child: FilledButton(
                          onPressed: item.isAvailable
                              ? () => cart.addFromWishlist(item)
                              : null,
                          style: FilledButton.styleFrom(
                            backgroundColor: AppColors.burgundy,
                            padding: EdgeInsets.zero,
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(AppRadius.sm),
                            ),
                          ),
                          child: Text(
                            item.isAvailable ? 'Add to Cart' : 'Unavailable',
                            style: AppTypography.bodySmall.copyWith(
                              fontWeight: FontWeight.w600,
                              color: Colors.white,
                            ),
                          ),
                        ),
                      ),
                    ),
                    const SizedBox(width: AppSpacing.sm),
                    IconButton(
                      tooltip: 'Remove from wishlist',
                      onPressed: () => wishlist.remove(item.productId),
                      icon: const Icon(
                        Icons.delete_outline_rounded,
                        size: 20,
                        color: AppColors.danger,
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
