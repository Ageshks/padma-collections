import 'dart:async';

import 'package:get/get.dart';

import '../../../core/constants/app_constants.dart';
import '../../../core/utils/error_handler.dart';
import '../../../data/models/models.dart';
import '../../../data/repositories/banner_repository.dart';
import '../../../data/repositories/category_repository.dart';
import '../../../data/repositories/product_repository.dart';
import '../common/controllers/app_controller.dart';

/// Drives every section of the home screen.
///
/// Each section is an independent stream, so a slow or failing one never
/// blocks the rest of the page from rendering.
class HomeController extends GetxController {
  HomeController({
    BannerRepository? bannerRepository,
    CategoryRepository? categoryRepository,
    ProductRepository? productRepository,
    AppController? appController,
  }) : _banners = bannerRepository ?? Get.find<BannerRepository>(),
       _categories = categoryRepository ?? Get.find<CategoryRepository>(),
       _products = productRepository ?? Get.find<ProductRepository>(),
       _app = appController ?? Get.find<AppController>();

  final BannerRepository _banners;
  final CategoryRepository _categories;
  final ProductRepository _products;
  final AppController _app;

  final RxList<BannerModel> banners = <BannerModel>[].obs;
  final RxList<CategoryModel> categories = <CategoryModel>[].obs;
  final RxList<ProductModel> newArrivals = <ProductModel>[].obs;
  final RxList<ProductModel> fastMoving = <ProductModel>[].obs;
  final RxList<ProductModel> featured = <ProductModel>[].obs;
  final RxList<ProductModel> popular = <ProductModel>[].obs;
  final RxList<ProductModel> recentlyAdded = <ProductModel>[].obs;

  final RxBool isLoading = true.obs;
  final RxString errorMessage = ''.obs;

  final List<StreamSubscription<dynamic>> _subs =
      <StreamSubscription<dynamic>>[];

  @override
  void onInit() {
    super.onInit();
    load();
  }

  @override
  void onClose() {
    for (final StreamSubscription<dynamic> sub in _subs) {
      sub.cancel();
    }
    super.onClose();
  }

  void load() {
    isLoading.value = true;
    errorMessage.value = '';

    // Cancel whatever is already listening before starting again. Without
    // this, every pull-to-refresh added seven more live subscriptions that
    // were never released, all writing to the same lists.
    for (final StreamSubscription<dynamic> sub in _subs) {
      sub.cancel();
    }
    _subs.clear();

    _subs
      ..add(_banners.watchActiveBanners().listen(_setBanners))
      ..add(_categories.watchActiveCategories().listen(_setCategories))
      ..add(_products.watchNewArrivals().listen(_setNewArrivals))
      ..add(_products.watchFastMoving().listen(_setFastMoving))
      ..add(_products.watchFeatured().listen(_setFeatured))
      ..add(_products.watchPopular().listen(_setPopular))
      ..add(_products.watchRecentlyAdded().listen(_setRecentlyAdded));
  }

  void _setBanners(List<BannerModel> value) {
    banners.assignAll(value);
    _done();
  }

  void _setCategories(List<CategoryModel> value) {
    categories.assignAll(value);
    _done();
  }

  void _setNewArrivals(List<ProductModel> value) {
    newArrivals.assignAll(value);
    _done();
  }

  void _setFastMoving(List<ProductModel> value) {
    fastMoving.assignAll(value);
    _done();
  }

  void _setFeatured(List<ProductModel> value) {
    featured.assignAll(value);
    _done();
  }

  void _setPopular(List<ProductModel> value) {
    popular.assignAll(value);
    _done();
  }

  void _setRecentlyAdded(List<ProductModel> value) {
    recentlyAdded.assignAll(value);
    _done();
  }

  /// The first load is "done" once any section has landed.
  void _done() => isLoading.value = false;

  /// True when the catalogue is genuinely empty (not merely still loading).
  bool get hasContent =>
      newArrivals.isNotEmpty ||
      featured.isNotEmpty ||
      recentlyAdded.isNotEmpty ||
      fastMoving.isNotEmpty;

  /// Count of products in a category, for the section badge.
  int categoryCount(String categoryId) =>
      categories
          .firstWhereOrNull((CategoryModel c) => c.categoryId == categoryId)
          ?.productCount ??
      0;

  String get tagline => _app.settings.value.tagline;

  /// New-arrival window currently in effect, for the "see all" subtitle.
  int get newArrivalDays => AppConstants.defaultNewArrivalDays;

  void reportError(Object error) {
    errorMessage.value = AppErrorHandler.wrap(error).message;
    isLoading.value = false;
  }
}
