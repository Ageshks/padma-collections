import 'package:flutter/material.dart';
import 'package:get/get.dart';

import '../../core/constants/app_colors.dart';
import '../../core/constants/app_sizes.dart';
import '../../core/constants/cloudinary_config.dart';
import '../../core/routes/app_routes.dart';
import '../../core/theme/app_typography.dart';
import '../../core/widgets/app_network_image.dart';
import '../../core/widgets/brand_widgets.dart';
import '../../core/widgets/state_views.dart';
import '../../data/models/models.dart';
import '../home/widgets/category_rail.dart';
import 'categories_controller.dart';

/// Categories tab: the full jewellery range as a tappable grid.
class CategoriesView extends StatelessWidget {
  const CategoriesView({super.key});

  @override
  Widget build(BuildContext context) {
    final CategoriesController controller = Get.find<CategoriesController>();

    return Scaffold(
      backgroundColor: AppColors.background,
      body: SafeArea(
        bottom: false,
        child: Obx(() {
          if (controller.isLoading.value) {
            return const Center(
              child: CircularProgressIndicator(color: AppColors.burgundy),
            );
          }
          if (controller.categories.isEmpty) {
            return EmptyState(
              title: 'No categories yet.',
              message:
                  'We are organising the collection. Please check back soon.',
              icon: Icons.category_outlined,
              actionLabel: 'Refresh',
              onAction: controller.load,
            );
          }

          return RefreshIndicator(
            color: AppColors.burgundy,
            onRefresh: () async => controller.load(),
            child: CustomScrollView(
              slivers: <Widget>[
                SliverToBoxAdapter(child: _header(controller)),
                SliverPadding(
                  padding: const EdgeInsets.fromLTRB(
                    AppSpacing.gutter,
                    0,
                    AppSpacing.gutter,
                    AppSpacing.bottomBarClearance,
                  ),
                  sliver: SliverGrid(
                    gridDelegate:
                        const SliverGridDelegateWithFixedCrossAxisCount(
                          crossAxisCount: 2,
                          mainAxisSpacing: AppSpacing.lg,
                          crossAxisSpacing: AppSpacing.lg,
                          childAspectRatio: 1.05,
                        ),
                    delegate: SliverChildBuilderDelegate(
                      (BuildContext context, int i) => _CategoryCard(
                        category: controller.categories[i],
                        onTap: () => Get.toNamed(
                          Routes.categoryProducts,
                          arguments: controller.categories[i],
                        ),
                      ),
                      childCount: controller.categories.length,
                    ),
                  ),
                ),
              ],
            ),
          );
        }),
      ),
    );
  }

  Widget _header(CategoriesController controller) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(
        AppSpacing.gutter,
        AppSpacing.lg,
        AppSpacing.gutter,
        AppSpacing.lg,
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          const SectionHeader(
            title: 'Categories',
            eyebrow: 'Explore',
            padding: EdgeInsets.zero,
          ),
          const SizedBox(height: AppSpacing.xs),
          Text(
            'Find the piece that fits the occasion.',
            style: AppTypography.bodyMedium,
          ),
        ],
      ),
    );
  }
}

/// A single category card: image, gold-icon fallback and a readable label.
class _CategoryCard extends StatelessWidget {
  const _CategoryCard({required this.category, required this.onTap});

  final CategoryModel category;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: AppRadius.cardRadius,
        boxShadow: AppColors.cardShadow,
      ),
      clipBehavior: Clip.antiAlias,
      child: InkWell(
        onTap: onTap,
        child: Stack(
          fit: StackFit.expand,
          children: <Widget>[
            if (category.hasImage)
              AppNetworkImage.cloudinary(
                category.image!,
                CloudinaryTransform.category,
              )
            else
              Container(
                color: AppColors.surfaceMuted,
                alignment: Alignment.center,
                child: Icon(
                  categoryIcon(category.icon),
                  size: 40,
                  color: AppColors.goldDark,
                ),
              ),

            // Gradient keeps the label readable over any image.
            Container(
              decoration: const BoxDecoration(
                gradient: LinearGradient(
                  begin: Alignment.topCenter,
                  end: Alignment.bottomCenter,
                  colors: <Color>[Colors.transparent, Color(0x99000000)],
                ),
              ),
            ),

            Positioned(
              left: AppSpacing.md,
              right: AppSpacing.md,
              bottom: AppSpacing.md,
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisSize: MainAxisSize.min,
                children: <Widget>[
                  Text(
                    category.name,
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                    style: AppTypography.titleMedium.copyWith(
                      color: Colors.white,
                    ),
                  ),
                  if (category.productCount > 0) ...<Widget>[
                    const SizedBox(height: 2),
                    Text(
                      '${category.productCount} '
                      '${category.productCount == 1 ? 'design' : 'designs'}',
                      style: AppTypography.bodySmall.copyWith(
                        color: Colors.white.withValues(alpha: 0.85),
                        fontSize: 11.5,
                      ),
                    ),
                  ],
                ],
              ),
            ),

            if (!category.isActive)
              Positioned(
                top: AppSpacing.sm,
                right: AppSpacing.sm,
                child: AppBadge(
                  label: 'Hidden',
                  dense: true,
                  color: AppColors.textSecondary,
                  background: Colors.white,
                ),
              ),
          ],
        ),
      ),
    );
  }
}
