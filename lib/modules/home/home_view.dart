import 'package:flutter/material.dart';
import 'package:get/get.dart';

import '../../core/constants/app_colors.dart';
import '../../core/constants/app_sizes.dart';
import '../../core/routes/app_routes.dart';
import '../../core/widgets/brand_widgets.dart';
import '../../core/widgets/product_card.dart';
import '../../core/widgets/state_views.dart';
import '../../data/models/models.dart';
import '../cart/cart_controller.dart';
import '../common/controllers/app_controller.dart';
import '../customer/customer_bindings.dart';
import '../wishlist/wishlist_controller.dart';
import 'home_controller.dart';
import 'widgets/banner_carousel.dart';
import 'widgets/category_rail.dart';
import 'widgets/whatsapp_fab.dart';

/// The customer home screen: banners, categories and the curated product rails.
class HomeView extends GetView<HomeController> {
  const HomeView({super.key});

  @override
  Widget build(BuildContext context) {
    final AppController app = Get.find<AppController>();

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
          if (!controller.hasContent) {
            return EmptyState(
              title: 'No jewellery found.',
              message:
                  'We could not load the collection right now. Please pull to '
                  'refresh or try again shortly.',
              icon: Icons.diamond_outlined,
              actionLabel: 'Try again',
              onAction: controller.load,
            );
          }

          return RefreshIndicator(
            color: AppColors.burgundy,
            onRefresh: () async => controller.load(),
            child: CustomScrollView(
              slivers: <Widget>[
                _header(app),
                SliverToBoxAdapter(
                  child: BannerCarousel(
                    banners: controller.banners,
                    onTap: _handleBannerTap,
                  ),
                ),
                SliverToBoxAdapter(
                  child: WhatsappBanner(onTap: app.openWhatsAppGeneral),
                ),
                if (controller.categories.isNotEmpty) ...<Widget>[
                  const SliverToBoxAdapter(
                    child: SectionHeader(
                      title: 'Shop by Category',
                      eyebrow: 'Browse',
                    ),
                  ),
                  SliverToBoxAdapter(
                    child: CategoryRail(
                      categories: controller.categories,
                      onTap: _openCategory,
                    ),
                  ),
                ],
                ..._buildRail(
                  eyebrow: 'Just In',
                  title: 'New Arrivals',
                  products: controller.newArrivals,
                  seeAllRoute: Routes.newArrivals,
                ),
                ..._buildRail(
                  eyebrow: 'Loved Right Now',
                  title: 'Fast Moving',
                  products: controller.fastMoving,
                  seeAllRoute: Routes.fastMoving,
                ),
                ..._buildRail(
                  eyebrow: 'Handpicked',
                  title: 'Featured Collection',
                  products: controller.featured,
                ),
                ..._buildRail(
                  eyebrow: 'Trending',
                  title: 'Popular Products',
                  products: controller.popular,
                ),
                ..._buildRail(
                  eyebrow: 'Fresh',
                  title: 'Recently Added',
                  products: controller.recentlyAdded,
                ),
                const SliverToBoxAdapter(child: SizedBox(height: 8)),
              ],
            ),
          );
        }),
      ),
    );
  }

  /// Brand header with search, notifications and wishlist shortcuts.
  Widget _header(AppController app) {
    return SliverToBoxAdapter(
      child: Padding(
        padding: const EdgeInsets.fromLTRB(
          AppSpacing.gutter,
          AppSpacing.lg,
          AppSpacing.gutter,
          AppSpacing.lg,
        ),
        child: Row(
          children: <Widget>[
            Expanded(
              child: Align(
                alignment: Alignment.centerLeft,
                child: BrandLogo(
                  height: 38,
                  variant: BrandLogoVariant.mark,
                  logoUrl: app.settings.value.logoUrl ?? '',
                ),
              ),
            ),
            _HeaderIcon(
              icon: Icons.search_rounded,
              tooltip: 'Search',
              onTap: () => Get.toNamed(Routes.search),
            ),
            _HeaderIcon(
              icon: Icons.notifications_none_rounded,
              tooltip: 'Notifications',
              badgeCount: app.unreadNotifications.value,
              onTap: () => Get.toNamed(Routes.notifications),
            ),
            Obx(
              () => _HeaderIcon(
                icon: Icons.favorite_border_rounded,
                tooltip: 'Wishlist',
                badgeCount: Get.find<WishlistController>().count,
                onTap: () => Get.find<CustomerShellController>().changeTab(2),
              ),
            ),
          ],
        ),
      ),
    );
  }

  /// Builds one product rail. Hidden entirely when empty.
  List<Widget> _buildRail({
    required String eyebrow,
    required String title,
    required List<ProductModel> products,
    String? seeAllRoute,
  }) {
    if (products.isEmpty) return const <Widget>[];

    final WishlistController wishlist = Get.find<WishlistController>();
    final CartController cart = Get.find<CartController>();

    return <Widget>[
      SliverToBoxAdapter(
        child: SectionHeader(
          eyebrow: eyebrow,
          title: title,
          actionLabel: seeAllRoute == null ? null : 'See all',
          onAction: seeAllRoute == null ? null : () => Get.toNamed(seeAllRoute),
        ),
      ),
      SliverToBoxAdapter(
        child: SizedBox(
          // Sized for a 162-wide card: flexible image plus the fixed
          // category/name/price/button block beneath it.
          height: 344,
          child: ListView.separated(
            scrollDirection: Axis.horizontal,
            padding: const EdgeInsets.symmetric(horizontal: AppSpacing.gutter),
            itemCount: products.length,
            separatorBuilder: (_, __) => const SizedBox(width: AppSpacing.lg),
            itemBuilder: (BuildContext context, int i) {
              final ProductModel product = products[i];
              return ProductCard(
                product: product,
                width: 162,
                onTap: () => Get.toNamed(
                  Routes.productDetails,
                  // The route expects the Firestore id, not the model. Passing
                  // the model silently resolved to an empty id and rendered an
                  // error page — the route's type check hid the mistake.
                  arguments: product.productId,
                ),
                onAddToCart: () => cart.addToCart(product),
                onToggleWishlist: () => wishlist.toggle(product),
                isInWishlist: wishlist.contains(product.productId),
              );
            },
          ),
        ),
      ),
    ];
  }

  void _openCategory(CategoryModel category) {
    Get.toNamed(Routes.categoryProducts, arguments: category);
  }

  /// Maps a banner's configured action onto a navigation target.
  void _handleBannerTap(BannerModel banner) {
    final AppController app = Get.find<AppController>();

    switch (banner.action) {
      case BannerAction.openCategory:
        if (banner.actionValue.isNotEmpty) {
          Get.toNamed(Routes.categoryProducts, arguments: banner.actionValue);
        } else {
          Get.find<CustomerShellController>().changeTab(1);
        }
      case BannerAction.openProduct:
        if (banner.actionValue.isNotEmpty) {
          Get.toNamed(Routes.productDetails, arguments: banner.actionValue);
        }
      case BannerAction.openNewArrivals:
        Get.toNamed(Routes.newArrivals);
      case BannerAction.scrollToSection:
        Get.find<CustomerShellController>().changeTab(0);
      case BannerAction.openWhatsapp:
        app.openWhatsAppGeneral();
    }
  }
}

/// Round icon button used in the home header, with an optional count badge.
class _HeaderIcon extends StatelessWidget {
  const _HeaderIcon({
    required this.icon,
    required this.tooltip,
    required this.onTap,
    this.badgeCount = 0,
  });

  final IconData icon;
  final String tooltip;
  final VoidCallback onTap;
  final int badgeCount;

  @override
  Widget build(BuildContext context) {
    return Tooltip(
      message: tooltip,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(AppRadius.pill),
        child: Padding(
          padding: const EdgeInsets.all(AppSpacing.sm),
          child: Stack(
            clipBehavior: Clip.none,
            children: <Widget>[
              Icon(icon, size: 23, color: AppColors.textPrimary),
              if (badgeCount > 0)
                Positioned(
                  right: -4,
                  top: -3,
                  child: Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 4,
                      vertical: 1,
                    ),
                    constraints: const BoxConstraints(minWidth: 15),
                    decoration: BoxDecoration(
                      color: AppColors.burgundy,
                      borderRadius: BorderRadius.circular(AppRadius.pill),
                    ),
                    child: Text(
                      badgeCount > 9 ? '9+' : '$badgeCount',
                      textAlign: TextAlign.center,
                      style: const TextStyle(
                        fontFamily: 'Inter',
                        fontSize: 9,
                        fontWeight: FontWeight.w700,
                        color: Colors.white,
                        height: 1.35,
                      ),
                    ),
                  ),
                ),
            ],
          ),
        ),
      ),
    );
  }
}
