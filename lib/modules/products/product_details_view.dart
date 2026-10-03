import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';
import 'package:get/get.dart';

import '../../core/constants/app_colors.dart';
import '../../core/constants/app_constants.dart';
import '../../core/constants/app_sizes.dart';
import '../../core/constants/cloudinary_config.dart';
import '../../core/routes/app_routes.dart';
import '../../core/theme/app_typography.dart';
import '../../core/utils/app_formatter.dart';
import '../../core/utils/error_handler.dart';
import '../../core/widgets/app_network_image.dart';
import '../../core/widgets/brand_widgets.dart';
import '../../core/widgets/product_card.dart';
import '../../core/widgets/state_views.dart';
import '../../data/models/models.dart';
import '../../data/repositories/product_repository.dart';
import '../cart/cart_controller.dart';
import '../common/controllers/app_controller.dart';
import '../wishlist/wishlist_controller.dart';

/// Premium product detail screen: gallery, full specification and the three
/// primary actions — wishlist, cart and WhatsApp enquiry.
///
/// The product is re-read from the repository on open so pricing and stock are
/// always the live values, never a stale copy passed in as an argument.
class ProductDetailsView extends StatefulWidget {
  const ProductDetailsView({super.key, required this.productId});

  /// Firestore id of the product to display.
  final String productId;

  @override
  State<ProductDetailsView> createState() => _ProductDetailsViewState();
}

class _ProductDetailsViewState extends State<ProductDetailsView> {
  final ProductRepository _products = Get.find<ProductRepository>();
  final AppController _app = Get.find<AppController>();
  final CartController _cart = Get.find<CartController>();

  late Future<ProductModel?> _future;

  /// Quantity the customer has selected before adding to the cart.
  int _quantity = 1;

  @override
  void initState() {
    super.initState();
    _future = _load();
  }

  /// Fetches the product and records the view for the "popular" ranking.
  Future<ProductModel?> _load() async {
    final ProductModel? product = await _products.getById(widget.productId);
    if (product != null) {
      // Fire-and-forget: a failed view counter must not block the screen.
      _products.incrementViews(product.productId);
    }
    return product;
  }

  Future<void> _reload() async {
    final ProductModel? product = await _products.getById(widget.productId);
    if (!mounted) return;
    setState(() {
      _future = Future<ProductModel?>.value(product);
      _quantity = 1;
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.background,
      body: FutureBuilder<ProductModel?>(
        future: _future,
        builder: (BuildContext context, AsyncSnapshot<ProductModel?> snap) {
          if (snap.connectionState == ConnectionState.waiting) {
            return const Center(
              child: CircularProgressIndicator(color: AppColors.burgundy),
            );
          }

          if (snap.hasError) {
            return SafeArea(
              child: Column(
                children: <Widget>[
                  const _BackBar(),
                  Expanded(
                    child: ErrorStateView(
                      message: AppErrorHandler.wrap(snap.error!).message,
                      onRetry: _reload,
                    ),
                  ),
                ],
              ),
            );
          }

          final ProductModel? product = snap.data;
          if (product == null) {
            return SafeArea(
              child: Column(
                children: <Widget>[
                  const _BackBar(),
                  Expanded(
                    child: EmptyState(
                      title: 'This piece is no longer available.',
                      message:
                          'It may have been removed from the collection. '
                          'Browse the rest of our jewellery instead.',
                      icon: Icons.diamond_outlined,
                      actionLabel: 'Continue shopping',
                      onAction: () => Get.back<void>(),
                    ),
                  ),
                ],
              ),
            );
          }

          return _content(product);
        },
      ),
    );
  }

  Widget _content(ProductModel product) {
    return Column(
      children: <Widget>[
        _TopBar(product: product),
        Expanded(
          child: SingleChildScrollView(
            padding: const EdgeInsets.only(bottom: AppSpacing.xxxl),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: <Widget>[
                _Gallery(product: product),
                _TitleBlock(product: product),
                _Description(product: product),
                _Specification(product: product),
                _Availability(product: product),
                _Related(product: product),
              ],
            ),
          ),
        ),
        _ActionBar(
          product: product,
          quantity: _quantity,
          onQuantityChanged: (int value) => setState(() => _quantity = value),
          onAddToCart: () => _addToCart(product),
          onEnquire: () => _enquire(product),
        ),
      ],
    );
  }

  Future<void> _addToCart(ProductModel product) =>
      _cart.addToCart(product, quantity: _quantity);

  /// Enquiry copy comes from admin-configurable WhatsApp settings.
  Future<void> _enquire(ProductModel product) =>
      _app.openWhatsAppProduct(product, _quantity);
}

/// Shared back bar so every state of the screen can navigate away.
class _BackBar extends StatelessWidget {
  const _BackBar();

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(
        horizontal: AppSpacing.sm,
        vertical: AppSpacing.sm,
      ),
      child: Row(
        children: <Widget>[
          IconButton(
            onPressed: Get.back<void>,
            icon: const Icon(Icons.arrow_back_rounded),
            tooltip: 'Back',
          ),
          const Spacer(),
          IconButton(
            onPressed: () => Get.toNamed(Routes.search),
            icon: const Icon(Icons.search_rounded),
            tooltip: 'Search',
          ),
        ],
      ),
    );
  }
}

/// Top bar with the wishlist toggle reflected live.
class _TopBar extends StatelessWidget {
  const _TopBar({required this.product});

  final ProductModel product;

  @override
  Widget build(BuildContext context) {
    final WishlistController wishlist = Get.find<WishlistController>();

    return Padding(
      padding: const EdgeInsets.symmetric(
        horizontal: AppSpacing.sm,
        vertical: AppSpacing.sm,
      ),
      child: Row(
        children: <Widget>[
          IconButton(
            onPressed: Get.back<void>,
            icon: const Icon(Icons.arrow_back_rounded),
            tooltip: 'Back',
          ),
          const Spacer(),
          Obx(
            () => IconButton(
              onPressed: () => wishlist.toggle(product),
              tooltip: 'Save',
              icon: Icon(
                wishlist.contains(product.productId)
                    ? Icons.favorite_rounded
                    : Icons.favorite_border_rounded,
                color: wishlist.contains(product.productId)
                    ? AppColors.burgundy
                    : null,
              ),
            ),
          ),
          IconButton(
            onPressed: () => Get.toNamed(Routes.search),
            icon: const Icon(Icons.search_rounded),
            tooltip: 'Search',
          ),
        ],
      ),
    );
  }
}

/// Full-screen pinch-to-zoom image viewer.
///
/// Opened from the product gallery. Swiping between photos and zooming are
/// mutually exclusive gestures, so a horizontal drag only pages once the zoom
/// is at 1×.
class _ZoomViewer extends StatefulWidget {
  const _ZoomViewer({required this.urls, this.initialIndex = 0});

  final List<String> urls;
  final int initialIndex;

  @override
  State<_ZoomViewer> createState() => _ZoomViewerState();
}

class _ZoomViewerState extends State<_ZoomViewer> {
  late final PageController _pages = PageController(
    initialPage: widget.initialIndex,
  );
  final TransformationController _transform = TransformationController();
  late int _index = widget.initialIndex;
  TapDownDetails? _lastTap;

  @override
  void dispose() {
    _pages.dispose();
    _transform.dispose();
    super.dispose();
  }

  /// Double tap toggles between fit and 2.5×, centred on the tap.
  void _onDoubleTap() {
    if (_transform.value.isIdentity()) {
      final Offset position = _lastTap?.localPosition ?? Offset.zero;
      setState(() {
        _transform.value = Matrix4.identity()
          ..translateByDouble(-position.dx * 1.5, -position.dy * 1.5, 0, 1)
          ..scaleByDouble(2.5, 2.5, 1, 1);
      });
    } else {
      setState(() => _transform.value = Matrix4.identity());
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.black,
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        foregroundColor: Colors.white,
        title: Text('${_index + 1} / ${widget.urls.length}'),
      ),
      body: GestureDetector(
        onDoubleTapDown: (TapDownDetails details) => _lastTap = details,
        onDoubleTap: _onDoubleTap,
        child: PageView.builder(
          controller: _pages,
          itemCount: widget.urls.length,
          onPageChanged: (int i) => setState(() => _index = i),
          itemBuilder: (BuildContext context, int i) {
            return InteractiveViewer(
              transformationController: _transform,
              minScale: 1,
              maxScale: 5,
              child: Center(
                child: CachedNetworkImage(
                  imageUrl: widget.urls[i],
                  fit: BoxFit.contain,
                  placeholder: (_, __) =>
                      const CircularProgressIndicator(color: Colors.white),
                  errorWidget: (_, __, ___) => const Icon(
                    Icons.broken_image_outlined,
                    color: Colors.white54,
                    size: 48,
                  ),
                ),
              ),
            );
          },
        ),
      ),
    );
  }
}

class _Gallery extends StatefulWidget {
  const _Gallery({required this.product});

  final ProductModel product;

  @override
  State<_Gallery> createState() => _GalleryState();
}

class _GalleryState extends State<_Gallery> {
  /// Index of the photo currently shown, mirrored for the thumbnail highlight.
  int _index = 0;

  /// Opens the full-screen, pinch-zoomable viewer for one gallery image.
  ///
  /// Every image is passed, not just [url], so the viewer can page between
  /// photos without the customer returning to the gallery first.
  void _openZoom(BuildContext context, String url, int index) {
    if (url.isEmpty) return;
    Navigator.of(context).push<void>(
      MaterialPageRoute<void>(
        builder: (_) => _ZoomViewer(
          urls: widget.product.imageUrls(
            variant: CloudinaryTransform.productDetail,
          ),
          initialIndex: index,
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    // product_detail (1200px) rather than the original: this is the only
    // surface where a customer may zoom, and it is the only place the large
    // variant is worth the bandwidth.
    final List<String> images = widget.product.imageUrls(
      variant: CloudinaryTransform.productDetail,
    );

    if (images.isEmpty) {
      return AspectRatio(
        aspectRatio: 3 / 4,
        child: Container(
          color: AppColors.surfaceMuted,
          alignment: Alignment.center,
          child: const Icon(
            Icons.diamond_outlined,
            size: 56,
            color: AppColors.textHint,
          ),
        ),
      );
    }

    return Column(
      children: <Widget>[
        AspectRatio(
          aspectRatio: 3 / 4,
          child: PageView.builder(
            itemCount: images.length,
            onPageChanged: (int i) => setState(() => _index = i),
            itemBuilder: (BuildContext context, int i) {
              return Hero(
                tag: 'product-image-${widget.product.productId}',
                child: GestureDetector(
                  // Tap opens the zoom viewer. Pinch-zoom inside a scrollable
                  // PageView fights the swipe gesture, so zoom is opt-in via
                  // the tap rather than always-on.
                  onTap: () => _openZoom(context, images[i], i),
                  child: AppNetworkImage(
                    url: images[i],
                    fit: BoxFit.cover,
                    memCacheWidth: 1200,
                  ),
                ),
              );
            },
          ),
        ),
        if (images.length > 1)
          Padding(
            padding: const EdgeInsets.only(top: AppSpacing.md),
            child: SizedBox(
              height: 62,
              child: ListView.separated(
                scrollDirection: Axis.horizontal,
                padding: const EdgeInsets.symmetric(
                  horizontal: AppSpacing.gutter,
                ),
                itemCount: images.length,
                separatorBuilder: (_, _) =>
                    const SizedBox(width: AppSpacing.sm),
                itemBuilder: (BuildContext context, int i) {
                  final bool selected = i == _index;
                  return GestureDetector(
                    onTap: () => setState(() => _index = i),
                    child: Container(
                      width: 52,
                      decoration: BoxDecoration(
                        borderRadius: BorderRadius.circular(AppRadius.sm),
                        border: Border.all(
                          color: selected
                              ? AppColors.burgundy
                              : AppColors.divider,
                          width: selected ? 2 : 1,
                        ),
                      ),
                      clipBehavior: Clip.antiAlias,
                      child: AppNetworkImage(
                        url: images[i],
                        memCacheWidth: 200,
                      ),
                    ),
                  );
                },
              ),
            ),
          ),
      ],
    );
  }
}

/// Name, price block and the discount/saving callout.
class _TitleBlock extends StatelessWidget {
  const _TitleBlock({required this.product});

  final ProductModel product;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(
        AppSpacing.gutter,
        AppSpacing.xl,
        AppSpacing.gutter,
        0,
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          Text(product.name, style: AppTypography.headlineMedium),
          const SizedBox(height: AppSpacing.xs),
          Row(
            children: <Widget>[
              if (product.sku.isNotEmpty) ...<Widget>[
                Text('SKU: ${product.sku}', style: AppTypography.bodySmall),
                const SizedBox(width: AppSpacing.md),
              ],
              if (product.categoryName.isNotEmpty)
                Flexible(
                  child: Text(
                    product.categoryName,
                    style: AppTypography.bodySmall.copyWith(
                      color: AppColors.burgundy,
                      fontWeight: FontWeight.w600,
                    ),
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
            ],
          ),
          const SizedBox(height: AppSpacing.md),
          Row(
            crossAxisAlignment: CrossAxisAlignment.end,
            children: <Widget>[
              Text(
                AppFormatter.currency(product.price),
                style: AppTypography.displayMedium.copyWith(
                  color: AppColors.burgundy,
                ),
              ),
              if (product.hasDiscount) ...<Widget>[
                const SizedBox(width: AppSpacing.sm),
                Padding(
                  padding: const EdgeInsets.only(bottom: 4),
                  child: Text(
                    AppFormatter.currency(product.compareAtPrice),
                    style: AppTypography.bodyMedium.copyWith(
                      color: AppColors.textHint,
                      decoration: TextDecoration.lineThrough,
                    ),
                  ),
                ),
                const SizedBox(width: AppSpacing.sm),
                Padding(
                  padding: const EdgeInsets.only(bottom: 4),
                  child: AppBadge(
                    label: AppFormatter.discountLabel(
                      product.price,
                      product.compareAtPrice,
                    ),
                    color: AppColors.burgundy,
                  ),
                ),
              ],
            ],
          ),
          if (product.hasDiscount)
            Padding(
              padding: const EdgeInsets.only(top: AppSpacing.xs),
              child: Text(
                'You save '
                '${AppFormatter.currency(product.compareAtPrice - product.price)}',
                style: AppTypography.bodySmall.copyWith(
                  color: AppColors.success,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ),
        ],
      ),
    );
  }
}

/// Long-form description, split into paragraphs.
class _Description extends StatelessWidget {
  const _Description({required this.product});

  final ProductModel product;

  @override
  Widget build(BuildContext context) {
    final List<String> paragraphs = StringUtils.paragraphs(product.description);
    if (paragraphs.isEmpty) return const SizedBox.shrink();

    return Padding(
      padding: const EdgeInsets.fromLTRB(
        AppSpacing.gutter,
        AppSpacing.xl,
        AppSpacing.gutter,
        0,
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          Text('Description', style: AppTypography.titleMedium),
          const SizedBox(height: AppSpacing.sm),
          ...paragraphs.map(
            (String p) => Padding(
              padding: const EdgeInsets.only(bottom: AppSpacing.sm),
              child: Text(p, style: AppTypography.bodyMedium),
            ),
          ),
        ],
      ),
    );
  }
}

/// Material / colour / size / weight grid. Hidden entirely when the admin left
/// every field blank, so the screen never shows an empty table.
class _Specification extends StatelessWidget {
  const _Specification({required this.product});

  final ProductModel product;

  @override
  Widget build(BuildContext context) {
    // Only rows the admin actually filled in, so the block can hide entirely.
    final List<(String, String)> rows = <(String, String)>[
      ('Material', product.material),
      ('Colour', product.color),
      ('Size', product.size),
      ('Weight', product.weight),
    ].where(((String, String) row) => row.$2.trim().isNotEmpty).toList();

    if (rows.isEmpty) return const SizedBox.shrink();

    return Padding(
      padding: const EdgeInsets.fromLTRB(
        AppSpacing.gutter,
        AppSpacing.lg,
        AppSpacing.gutter,
        0,
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          Text('Details', style: AppTypography.titleMedium),
          const SizedBox(height: AppSpacing.sm),
          Container(
            decoration: BoxDecoration(
              color: AppColors.surface,
              borderRadius: AppRadius.cardRadius,
              border: Border.all(color: AppColors.divider),
            ),
            child: Column(
              children: <Widget>[
                for (int i = 0; i < rows.length; i++) ...<Widget>[
                  if (i > 0) const Divider(height: 1, indent: AppSpacing.lg),
                  Padding(
                    padding: const EdgeInsets.symmetric(
                      horizontal: AppSpacing.lg,
                      vertical: AppSpacing.md,
                    ),
                    child: Row(
                      children: <Widget>[
                        SizedBox(
                          width: 92,
                          child: Text(
                            rows[i].$1,
                            style: AppTypography.bodySmall,
                          ),
                        ),
                        Expanded(
                          child: Text(
                            rows[i].$2,
                            style: AppTypography.bodyMedium.copyWith(
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ],
            ),
          ),
        ],
      ),
    );
  }
}

/// Stock availability, with a warning when the admin's threshold is reached.
class _Availability extends StatelessWidget {
  const _Availability({required this.product});

  final ProductModel product;

  @override
  Widget build(BuildContext context) {
    if (product.inStock) {
      return Padding(
        padding: const EdgeInsets.fromLTRB(
          AppSpacing.gutter,
          AppSpacing.lg,
          AppSpacing.gutter,
          0,
        ),
        child: Row(
          children: <Widget>[
            const Icon(
              Icons.check_circle_outline_rounded,
              size: 18,
              color: AppColors.success,
            ),
            const SizedBox(width: AppSpacing.sm),
            Text(
              product.stock <= 10
                  ? 'Only ${product.stock} left in stock'
                  : 'In stock',
              style: AppTypography.bodyMedium.copyWith(
                color: product.stock <= 10
                    ? AppColors.warning
                    : AppColors.success,
                fontWeight: FontWeight.w600,
              ),
            ),
          ],
        ),
      );
    }

    return Padding(
      padding: const EdgeInsets.fromLTRB(
        AppSpacing.gutter,
        AppSpacing.lg,
        AppSpacing.gutter,
        0,
      ),
      child: Container(
        padding: const EdgeInsets.all(AppSpacing.md),
        decoration: BoxDecoration(
          color: AppColors.dangerSoft,
          borderRadius: BorderRadius.circular(AppRadius.sm),
        ),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: <Widget>[
            const Icon(
              Icons.error_outline_rounded,
              size: 18,
              color: AppColors.danger,
            ),
            const SizedBox(width: AppSpacing.sm),
            Expanded(
              child: Text.rich(
                TextSpan(
                  children: <InlineSpan>[
                    const TextSpan(
                      text: 'Out of stock. ',
                      style: TextStyle(
                        color: AppColors.danger,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                    TextSpan(
                      text:
                          'Message us on WhatsApp and we will let you know when '
                          'it is back.',
                      style: AppTypography.bodySmall,
                    ),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

/// Related pieces from the same category, so a customer is never forced back
/// to the grid to keep browsing.
class _Related extends StatelessWidget {
  const _Related({required this.product});

  final ProductModel product;

  @override
  Widget build(BuildContext context) {
    final ProductRepository repository = Get.find<ProductRepository>();
    final CartController cart = Get.find<CartController>();
    final WishlistController wishlist = Get.find<WishlistController>();

    if (product.categoryId.isEmpty) return const SizedBox.shrink();

    return StreamBuilder<List<ProductModel>>(
      stream: repository.watchByCategory(product.categoryId, limit: 8),
      builder: (BuildContext context, AsyncSnapshot<List<ProductModel>> snap) {
        final List<ProductModel> related = (snap.data ?? <ProductModel>[])
            .where((ProductModel p) => p.productId != product.productId)
            .take(8)
            .toList();

        if (related.isEmpty) return const SizedBox.shrink();

        return Padding(
          padding: const EdgeInsets.only(top: AppSpacing.xl),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: <Widget>[
              Padding(
                padding: const EdgeInsets.symmetric(
                  horizontal: AppSpacing.gutter,
                ),
                child: Text(
                  'You may also like',
                  style: AppTypography.titleMedium,
                ),
              ),
              const SizedBox(height: AppSpacing.md),
              SizedBox(
                // Tall enough for a 148-wide card: flexible image plus the
                // category/name/price/button block underneath.
                height: 310,
                child: ListView.separated(
                  scrollDirection: Axis.horizontal,
                  padding: const EdgeInsets.symmetric(
                    horizontal: AppSpacing.gutter,
                  ),
                  itemCount: related.length,
                  separatorBuilder: (_, _) =>
                      const SizedBox(width: AppSpacing.md),
                  itemBuilder: (BuildContext context, int i) {
                    final ProductModel item = related[i];
                    return ProductCard(
                      product: item,
                      width: 148,
                      isInWishlist: wishlist.contains(item.productId),
                      onTap: () => Get.toNamed(
                        Routes.productDetails,
                        arguments: item.productId,
                      ),
                      onAddToCart: () => cart.addToCart(item),
                      onToggleWishlist: () => wishlist.toggle(item),
                    );
                  },
                ),
              ),
            ],
          ),
        );
      },
    );
  }
}

/// Pinned bottom bar: quantity, add to cart and the WhatsApp enquiry.
class _ActionBar extends StatelessWidget {
  const _ActionBar({
    required this.product,
    required this.quantity,
    required this.onQuantityChanged,
    required this.onAddToCart,
    required this.onEnquire,
  });

  final ProductModel product;
  final int quantity;
  final ValueChanged<int> onQuantityChanged;
  final VoidCallback onAddToCart;
  final VoidCallback onEnquire;

  @override
  Widget build(BuildContext context) {
    final bool canBuy = product.isPurchasable;

    return Container(
      decoration: BoxDecoration(
        color: AppColors.surface,
        border: const Border(top: BorderSide(color: AppColors.divider)),
        boxShadow: <BoxShadow>[
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.06),
            blurRadius: 12,
            offset: const Offset(0, -2),
          ),
        ],
      ),
      padding: EdgeInsets.fromLTRB(
        AppSpacing.gutter,
        AppSpacing.md,
        AppSpacing.gutter,
        MediaQuery.paddingOf(context).bottom + AppSpacing.md,
      ),
      child: Row(
        children: <Widget>[
          if (canBuy)
            QuantityStepper(
              quantity: quantity,
              max: product.stock > AppConstants.cartQuantityMax
                  ? AppConstants.cartQuantityMax
                  : product.stock,
              onChanged: onQuantityChanged,
            ),
          if (canBuy) const SizedBox(width: AppSpacing.md),
          Expanded(
            child: SizedBox(
              height: 48,
              child: ElevatedButton.icon(
                onPressed: canBuy ? onAddToCart : null,
                icon: const Icon(Icons.shopping_bag_outlined, size: 18),
                label: Text(canBuy ? 'Add to Cart' : 'Out of Stock'),
                style: ElevatedButton.styleFrom(
                  padding: EdgeInsets.zero,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(AppRadius.md),
                  ),
                ),
              ),
            ),
          ),
          const SizedBox(width: AppSpacing.sm),
          SizedBox(
            height: 48,
            width: 52,
            child: OutlinedButton(
              onPressed: onEnquire,
              style: OutlinedButton.styleFrom(
                padding: EdgeInsets.zero,
                side: const BorderSide(color: AppColors.gold),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(AppRadius.md),
                ),
              ),
              child: const Icon(
                Icons.chat_bubble_outline_rounded,
                size: 20,
                color: AppColors.goldDark,
              ),
            ),
          ),
        ],
      ),
    );
  }
}
