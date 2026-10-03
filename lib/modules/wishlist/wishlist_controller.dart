import 'dart:async';

import 'package:flutter/material.dart';
import 'package:get/get.dart';

import '../../../core/constants/app_colors.dart';
import '../../../core/constants/cloudinary_config.dart';
import '../../../core/utils/error_handler.dart';
import '../../../data/models/models.dart';
import '../../../data/repositories/wishlist_repository.dart';
import '../common/controllers/app_controller.dart';

/// The customer's wishlist, shared across every tab.
///
/// Also tracks the raw set of saved product ids so product cards can paint a
/// filled heart without each one issuing its own read.
class WishlistController extends GetxController {
  WishlistController({
    WishlistRepository? repository,
    AppController? appController,
  }) : _wishlist = repository ?? Get.find<WishlistRepository>(),
       _app = appController ?? Get.find<AppController>();

  final WishlistRepository _wishlist;
  final AppController _app;

  final RxList<WishlistItem> items = <WishlistItem>[].obs;
  final RxBool isLoading = true.obs;

  StreamSubscription<List<WishlistItem>>? _sub;

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

  /// (Re)binds the wishlist stream to whoever is signed in right now.
  ///
  /// Registered `permanent: true` and so never recreated on sign-in, which
  /// means subscribing only in [onInit] would leave it bound to whoever was
  /// signed in at launch — showing the wrong person's saved items, or nothing
  /// at all for a customer who signs in later.
  ///
  /// `AppController` calls this on every auth-state change.
  void bindToUser() {
    _sub?.cancel();
    isLoading.value = true;

    _sub = _wishlist
        .watchWishlist(_app.currentUid)
        .listen(
          (List<WishlistItem> list) {
            items.assignAll(list);
            isLoading.value = false;
          },
          onError: (Object e) {
            items.clear();
            isLoading.value = false;
          },
        );
  }

  bool get isEmpty => items.isEmpty;

  int get count => items.length;

  bool contains(String productId) =>
      items.any((WishlistItem i) => i.productId == productId);

  /// Toggles a product and reports the resulting state, so the caller can show
  /// the right confirmation without a second read.
  Future<bool> toggle(ProductModel product) async {
    final bool nowSaved = await toggleId(
      product.productId,
      name: product.name,
      // Wishlist rows are small list items, so they snapshot the thumbnail.
      image: product.primaryImage(variant: CloudinaryTransform.thumbnail),
      price: product.price,
      compareAtPrice: product.compareAtPrice,
    );
    _toast(nowSaved ? 'Saved to wishlist' : 'Removed from wishlist');
    return nowSaved;
  }

  /// Low-level toggle used by cards that only hold an id.
  Future<bool> toggleId(
    String productId, {
    String name = '',
    String image = '',
    double price = 0,
    double compareAtPrice = 0,
  }) async {
    try {
      final bool saved = await _wishlist.toggle(
        _app.currentUid,
        WishlistItem(
          productId: productId,
          name: name,
          image: image,
          price: price,
          compareAtPrice: compareAtPrice,
          addedAt: DateTime.now(),
        ),
      );
      return saved;
    } on AppException catch (e) {
      _toast(e.message, isError: true);
      return contains(productId);
    } catch (e) {
      _toast(AppErrorHandler.wrap(e).message, isError: true);
      return contains(productId);
    }
  }

  Future<void> remove(String productId) async {
    try {
      await _wishlist.remove(_app.currentUid, productId);
      _toast('Removed from wishlist');
    } on AppException catch (e) {
      _toast(e.message, isError: true);
    }
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
