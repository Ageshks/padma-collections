import 'package:flutter/material.dart';
import 'package:get/get.dart';

import '../../core/constants/app_colors.dart';
import '../../core/constants/app_sizes.dart';
import '../../core/routes/app_routes.dart';
import '../../core/widgets/product_card.dart';
import '../../core/widgets/state_views.dart';
import '../../data/models/models.dart';
import '../cart/cart_controller.dart';
import '../wishlist/wishlist_controller.dart';
import 'product_filter_sheet.dart';
import 'product_list_controller.dart';
import 'product_sort_sheet.dart';

/// Searchable, filterable, infinitely scrolling product grid.
///
/// The screen is driven entirely by [ProductListController] — this widget only
/// renders state and forwards user intent, so no Firestore logic leaks into UI.
class ProductListView extends StatefulWidget {
  const ProductListView({super.key});

  /// Which slice of the catalogue to show is *not* a constructor parameter.
  ///
  /// It used to be `initialCategoryId`, but nothing ever passed it — the route
  /// built `const ProductListView()` and dropped the argument on the floor, so
  /// this screen always showed the whole catalogue. The scope now lives in
  /// [ProductListController], set by the route that navigates here, which is
  /// the only place that actually knows the intent.

  @override
  State<ProductListView> createState() => _ProductListViewState();
}

class _ProductListViewState extends State<ProductListView> {
  late final ProductListController _controller;
  final ScrollController _scroll = ScrollController();

  @override
  void initState() {
    super.initState();
    _controller = Get.find<ProductListController>();
    _scroll.addListener(_onScroll);
  }

  @override
  void dispose() {
    _scroll.removeListener(_onScroll);
    _scroll.dispose();
    super.dispose();
  }

  /// Loads the next page slightly before the user reaches the bottom.
  void _onScroll() {
    if (!_scroll.hasClients) return;
    final double remaining =
        _scroll.position.maxScrollExtent - _scroll.position.pixels;
    if (remaining < 600) _controller.loadMore();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        title: const Text('Shop'),
        actions: <Widget>[
          IconButton(
            tooltip: 'Sort',
            onPressed: () => ProductSortSheet.show(context),
            icon: const Icon(Icons.swap_vert_rounded),
          ),
        ],
      ),
      body: Column(
        children: <Widget>[
          const _SearchBar(),
          const _FilterBar(),
          Expanded(child: Obx(() => _body())),
        ],
      ),
    );
  }

  Widget _body() {
    if (_controller.isLoading.value) {
      return const Center(
        child: CircularProgressIndicator(color: AppColors.burgundy),
      );
    }

    if (_controller.errorMessage.value.isNotEmpty) {
      return ErrorStateView(
        message: _controller.errorMessage.value,
        onRetry: _controller.load,
      );
    }

    final List<ProductModel> items = _controller.visibleResults;
    if (items.isEmpty) return _empty();

    return RefreshIndicator(
      onRefresh: () async => _controller.load(),
      child: GridView.builder(
        controller: _scroll,
        padding: const EdgeInsets.fromLTRB(
          AppSpacing.md,
          AppSpacing.sm,
          AppSpacing.md,
          AppSpacing.xxl,
        ),
        // A fixed `mainAxisExtent` rather than a `childAspectRatio`: the card's
        // content is a fixed-height text block plus a flexible image, so a fixed
        // extent is what actually matches it. An aspect ratio would shrink the
        // cell as the screen got wider and overflow the text at the bottom.
        gridDelegate: const SliverGridDelegateWithMaxCrossAxisExtent(
          maxCrossAxisExtent: 220,
          mainAxisExtent: 320,
          mainAxisSpacing: AppSpacing.md,
          crossAxisSpacing: AppSpacing.md,
        ),
        itemCount: items.length + 1,
        itemBuilder: (BuildContext context, int i) {
          // Trailing slot shows the "loading more" spinner only when another
          // page genuinely exists.
          if (i == items.length) {
            return _controller.hasMore
                ? const Center(
                    child: Padding(
                      padding: EdgeInsets.all(AppSpacing.lg),
                      child: CircularProgressIndicator(
                        color: AppColors.burgundy,
                      ),
                    ),
                  )
                : const SizedBox.shrink();
          }
          return _tile(items[i]);
        },
      ),
    );
  }

  Widget _tile(ProductModel product) {
    final CartController cart = Get.find<CartController>();
    final WishlistController wishlist = Get.find<WishlistController>();

    return ProductCard(
      product: product,
      isInWishlist: wishlist.contains(product.productId),
      onTap: () =>
          Get.toNamed(Routes.productDetails, arguments: product.productId),
      onAddToCart: () => cart.addToCart(product),
      onToggleWishlist: () => wishlist.toggle(product),
    );
  }

  Widget _empty() {
    if (_controller.hasActiveFilters) {
      return EmptyState(
        title: 'No pieces match your filters.',
        message: 'Try widening the price range or clearing a few filters.',
        icon: Icons.search_off_rounded,
        actionLabel: 'Clear all filters',
        onAction: _controller.resetAll,
      );
    }
    return const EmptyState(
      title: 'The collection is being updated.',
      message: 'New arrivals are on their way. Please check back shortly.',
      icon: Icons.diamond_outlined,
    );
  }
}

/// Debounced search field. Typing updates the controller on a 250 ms timer.
class _SearchBar extends StatelessWidget {
  const _SearchBar();

  @override
  Widget build(BuildContext context) {
    final ProductListController controller = Get.find<ProductListController>();

    return Padding(
      padding: const EdgeInsets.fromLTRB(
        AppSpacing.gutter,
        AppSpacing.sm,
        AppSpacing.gutter,
        0,
      ),
      child: TextField(
        onChanged: controller.onQueryChanged,
        textInputAction: TextInputAction.search,
        decoration: InputDecoration(
          hintText: 'Search rings, necklaces, bangles…',
          prefixIcon: const Icon(Icons.search_rounded),
          isDense: true,
          border: OutlineInputBorder(
            borderRadius: BorderRadius.circular(AppRadius.md),
          ),
          suffixIcon: Obx(
            () => controller.query.value.isEmpty
                ? const SizedBox.shrink()
                : IconButton(
                    tooltip: 'Clear',
                    icon: const Icon(Icons.close_rounded),
                    onPressed: controller.clearQuery,
                  ),
          ),
        ),
      ),
    );
  }
}

/// Horizontal row of quick filters: all, new arrivals, fast moving, in stock.
class _FilterBar extends StatelessWidget {
  const _FilterBar();

  @override
  Widget build(BuildContext context) {
    final ProductListController controller = Get.find<ProductListController>();

    return SizedBox(
      height: 56,
      child: ListView(
        scrollDirection: Axis.horizontal,
        padding: const EdgeInsets.symmetric(
          horizontal: AppSpacing.gutter,
          vertical: AppSpacing.sm,
        ),
        children: <Widget>[
          Obx(
            () => _chip(
              label: 'All',
              selected: controller.activeFilterCount == 0,
              onTap: controller.clearFilters,
            ),
          ),
          Obx(
            () => _chip(
              label: 'New Arrivals',
              selected: controller.onlyNewArrival.value,
              onTap: () =>
                  controller.toggleNewArrival(!controller.onlyNewArrival.value),
            ),
          ),
          Obx(
            () => _chip(
              label: 'Fast Moving',
              selected: controller.onlyFastMoving.value,
              onTap: () =>
                  controller.toggleFastMoving(!controller.onlyFastMoving.value),
            ),
          ),
          Obx(
            () => _chip(
              label: 'Featured',
              selected: controller.onlyFeatured.value,
              onTap: () =>
                  controller.toggleFeatured(!controller.onlyFeatured.value),
            ),
          ),
          Obx(
            () => _chip(
              label: 'In Stock',
              selected: controller.onlyInStock.value,
              onTap: () =>
                  controller.toggleInStock(!controller.onlyInStock.value),
            ),
          ),
          Obx(
            () => ActionChip(
              avatar: const Icon(Icons.tune_rounded, size: 18),
              label: Text(
                controller.activeFilterCount > 0
                    ? 'More (${controller.activeFilterCount})'
                    : 'More',
              ),
              onPressed: () => ProductFilterSheet.show(context),
            ),
          ),
        ],
      ),
    );
  }

  Widget _chip({
    required String label,
    required bool selected,
    required VoidCallback onTap,
  }) {
    return Padding(
      padding: const EdgeInsets.only(right: AppSpacing.sm),
      child: ChoiceChip(
        label: Text(label),
        selected: selected,
        onSelected: (_) => onTap(),
      ),
    );
  }
}
