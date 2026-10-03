import 'dart:async';

import 'package:flutter/material.dart';
import 'package:get/get.dart';

import '../../../core/constants/app_colors.dart';
import '../../../core/constants/app_constants.dart';
import '../../../core/constants/cloudinary_config.dart';
import '../../../core/utils/error_handler.dart';
import '../../../data/models/models.dart';
import '../../../data/repositories/cart_repository.dart';
import '../common/controllers/app_controller.dart';

/// The customer's cart, shared across every tab.
///
/// Registered permanently by the customer binding so a product card on the home
/// screen and the cart screen are always looking at the same state.
class CartController extends GetxController {
  CartController({CartRepository? repository, AppController? appController})
    : _cart = repository ?? Get.find<CartRepository>(),
      _app = appController ?? Get.find<AppController>();

  final CartRepository _cart;
  final AppController _app;

  final RxList<CartItem> items = <CartItem>[].obs;
  final RxBool isLoading = true.obs;

  StreamSubscription<List<CartItem>>? _sub;

  @override
  void onInit() {
    super.onInit();
    bindToUser();
  }

  @override
  void onClose() {
    _sub?.cancel();
    super.onClose();
  }

  /// (Re)binds the cart stream to whoever is signed in right now.
  ///
  /// This controller is registered `permanent: true` so that every tab shares
  /// one cart, which means it is *not* recreated on sign-in. Subscribing only
  /// in [onInit] therefore left it bound to the user who happened to be signed
  /// in at launch: a customer signing in later saw an empty cart, and after a
  /// sign-out a second customer could briefly see the first one's items.
  ///
  /// `AppController` calls this on every auth-state change.
  void bindToUser() {
    _sub?.cancel();
    isLoading.value = true;

    final String uid = _app.currentUid;
    _sub = _cart
        .watchCart(uid)
        .listen(
          (List<CartItem> list) {
            items.assignAll(list);
            isLoading.value = false;
          },
          // A rejected read (e.g. permissions after a sign-out race) must not
          // surface as an unhandled stream error, and must not leave the spinner
          // running forever.
          onError: (Object e) {
            items.clear();
            isLoading.value = false;
          },
        );
  }

  // ---------------------------------------------------------------------------
  // Totals
  // ---------------------------------------------------------------------------

  bool get isEmpty => items.isEmpty;

  int get itemCount => items.length;

  /// Total number of physical units, which is what the badge shows.
  int get totalUnits =>
      items.fold<int>(0, (int sum, CartItem i) => sum + i.quantity);

  double get subtotal =>
      items.fold<double>(0, (double sum, CartItem i) => sum + i.subtotal);

  /// Applies the admin's rate settings (shipping, tax, discount, making charge).
  PriceBreakdown get breakdown => _app.rateSettings.value.compute(subtotal);

  double get total => breakdown.total;

  /// True when at least one line exceeds available stock.
  bool get hasStockIssues => items.any((CartItem i) => i.exceedsStock);

  List<CartItem> get unavailableItems =>
      items.where((CartItem i) => !i.isAvailable || i.exceedsStock).toList();

  // ---------------------------------------------------------------------------
  // Mutations
  // ---------------------------------------------------------------------------

  /// Adds a product to the cart, merging with any existing line.
  Future<void> addToCart(ProductModel product, {int quantity = 1}) async {
    if (!product.inStock) {
      _toast('This item is out of stock.');
      return;
    }
    final String uid = _app.currentUid;
    try {
      await _cart.add(
        uid,
        CartItem(
          productId: product.productId,
          name: product.name,
          // Snapshotted at the thumbnail variant: a cart row is ~64px tall and
          // must never drag the full product image into memory.
          image: product.primaryImage(variant: CloudinaryTransform.thumbnail),
          price: product.price,
          quantity: quantity,
          sku: product.sku,
          stock: product.stock,
          isAvailable: product.isAvailable,
          addedAt: DateTime.now(),
        ),
      );
      _toast('${product.name} added to cart');
    } on AppException catch (e) {
      _toast(e.message, isError: true);
    } catch (e) {
      _toast(AppErrorHandler.wrap(e).message, isError: true);
    }
  }

  /// Adds a wishlist snapshot to the cart.
  ///
  /// Wishlist rows only store a lightweight copy of the product, so the cart
  /// line gets no stock ceiling until the catalogue is re-joined.
  Future<void> addFromWishlist(WishlistItem item) async {
    await _cart.add(
      _app.currentUid,
      CartItem(
        productId: item.productId,
        name: item.name,
        image: item.image,
        price: item.price,
        quantity: 1,
        // Zero means "unknown", which the cart treats as no ceiling.
        stock: 0,
        isAvailable: item.isAvailable,
        addedAt: DateTime.now(),
      ),
    );
    _toast('${item.name} added to cart');
  }

  Future<void> updateQuantity(String productId, int quantity) async {
    try {
      await _cart.updateQuantity(_app.currentUid, productId, quantity);
    } on AppException catch (e) {
      _toast(e.message, isError: true);
    }
  }

  Future<void> increase(String productId) async {
    final CartItem? item = _find(productId);
    if (item == null) return;
    if (!item.canIncrease) {
      _toast('No more stock available.');
      return;
    }
    await updateQuantity(productId, item.quantity + 1);
  }

  Future<void> decrease(String productId) async {
    final CartItem? item = _find(productId);
    if (item == null) return;
    if (!item.canDecrease) {
      await remove(productId);
      return;
    }
    await updateQuantity(productId, item.quantity - 1);
  }

  Future<void> remove(String productId) async {
    try {
      await _cart.remove(_app.currentUid, productId);
      _toast('Removed from cart');
    } on AppException catch (e) {
      _toast(e.message, isError: true);
    }
  }

  Future<void> clear() async {
    await _cart.clear(_app.currentUid);
    _toast('Cart cleared');
  }

  CartItem? _find(String productId) {
    for (final CartItem item in items) {
      if (item.productId == productId) return item;
    }
    return null;
  }

  void _toast(String message, {bool isError = false}) {
    Get.rawSnackbar(
      message: message,
      snackPosition: SnackPosition.BOTTOM,
      backgroundColor: isError ? AppColors.danger : AppColors.darkBrown,
      margin: const EdgeInsets.all(12),
      borderRadius: 8,
      duration: const Duration(seconds: 2),
    );
  }
}

/// Capped at the global maximum so a quantity field cannot be abused.
int clampCartQuantity(int value, int stock) {
  final int max = stock > 0
      ? stock.clamp(AppConstants.cartQuantityMin, AppConstants.cartQuantityMax)
      : AppConstants.cartQuantityMax;
  return value.clamp(AppConstants.cartQuantityMin, max);
}
