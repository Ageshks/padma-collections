import 'dart:async';

import 'package:get/get.dart';

import '../../../core/utils/error_handler.dart';
import '../../../data/models/models.dart';
import '../../../data/repositories/product_repository.dart';

/// Drives the product listing screen: search, filters, sorting and pagination.
///
/// The catalogue is fetched **once** as a stream and filtered in memory. For a
/// single-store jewellery catalogue (hundreds of products, not millions) this is
/// both faster and far cheaper than re-querying Firestore on every keystroke,
/// and it makes debounced typing feel instant. Results are still paged into the
/// UI so the grid never builds thousands of widgets at once.
class ProductListController extends GetxController {
  ProductListController({ProductRepository? repository})
    : _products = repository ?? Get.find<ProductRepository>();

  final ProductRepository _products;

  StreamSubscription<List<ProductModel>>? _sub;

  /// Everything the admin has marked active.
  final RxList<ProductModel> _all = <ProductModel>[].obs;

  final RxBool isLoading = true.obs;
  final RxString errorMessage = ''.obs;

  // ---------------------------------------------------------------------------
  // Query state
  // ---------------------------------------------------------------------------

  final RxString query = ''.obs;
  final RxString categoryId = ''.obs;

  final RxDouble minPrice = 0.0.obs;
  final RxDouble maxPrice = 0.0.obs;

  final RxBool onlyNewArrival = false.obs;
  final RxBool onlyFastMoving = false.obs;
  final RxBool onlyFeatured = false.obs;
  final RxBool onlyInStock = false.obs;

  final Rx<ProductSortOption> sort = ProductSortOption.newest.obs;

  /// How many products are currently revealed; grows as the user scrolls.
  final RxInt visibleCount = 24.obs;

  static const int pageSize = 24;

  /// Debounce so typing does not re-filter on every keystroke.
  static const Duration _debounce = Duration(milliseconds: 250);

  Timer? _debounceTimer;

  @override
  void onInit() {
    super.onInit();
    load();
  }

  @override
  void onClose() {
    _debounceTimer?.cancel();
    _sub?.cancel();
    super.onClose();
  }

  void load() {
    isLoading.value = true;
    errorMessage.value = '';
    _sub?.cancel();
    _sub = _products.watchActiveProducts().listen(
      (List<ProductModel> list) {
        _all.assignAll(list);
        isLoading.value = false;
      },
      onError: (Object e) {
        errorMessage.value = AppErrorHandler.wrap(e).message;
        isLoading.value = false;
      },
    );
  }

  // ---------------------------------------------------------------------------
  // Derived results
  // ---------------------------------------------------------------------------

  /// Products after search, filters and sorting — the full result set.
  List<ProductModel> get results =>
      ProductRepository.sortProducts(_applyFilters(_all), sort.value);

  /// The first page of [results], which is what the grid renders.
  List<ProductModel> get visibleResults =>
      results.take(visibleCount.value).toList();

  bool get hasMore => visibleCount.value < results.length;

  /// True when a search or any filter is narrowing the catalogue.
  bool get hasActiveFilters =>
      query.value.trim().isNotEmpty ||
      categoryId.value.isNotEmpty ||
      onlyNewArrival.value ||
      onlyFastMoving.value ||
      onlyFeatured.value ||
      onlyInStock.value ||
      minPrice.value > 0 ||
      maxPrice.value > 0;

  /// Price bounds of the whole catalogue, used to bound the filter sheet.
  double get catalogueMinPrice => _all.isEmpty
      ? 0
      : _all
            .map((ProductModel p) => p.price)
            .reduce((double a, double b) => a < b ? a : b);

  double get catalogueMaxPrice => _all.isEmpty
      ? 10000
      : _all
            .map((ProductModel p) => p.price)
            .reduce((double a, double b) => a > b ? a : b);

  /// Number of filters currently switched on, for the badge on the button.
  int get activeFilterCount {
    int count = 0;
    if (categoryId.value.isNotEmpty) count++;
    if (onlyNewArrival.value) count++;
    if (onlyFastMoving.value) count++;
    if (onlyFeatured.value) count++;
    if (onlyInStock.value) count++;
    if (minPrice.value > 0 || maxPrice.value > 0) count++;
    return count;
  }

  /// Categories represented in the current result set, for the filter sheet.
  List<String> get availableCategoryIds => <String>{
    ..._applyFilters(_all).map((ProductModel p) => p.categoryId),
  }.where((String id) => id.isNotEmpty).toList();

  // ---------------------------------------------------------------------------
  // Mutations
  // ---------------------------------------------------------------------------

  /// Debounced search entry point, called from the search field.
  void onQueryChanged(String value) {
    _debounceTimer?.cancel();
    _debounceTimer = Timer(_debounce, () {
      query.value = value;
      _resetPaging();
    });
  }

  /// Immediate set, used by the clear button.
  void clearQuery() {
    _debounceTimer?.cancel();
    query.value = '';
    _resetPaging();
  }

  void setCategory(String id) {
    categoryId.value = id;
    _resetPaging();
  }

  void setSort(ProductSortOption option) {
    sort.value = option;
    _resetPaging();
  }

  void setPriceRange(double min, double max) {
    minPrice.value = min;
    maxPrice.value = max;
    _resetPaging();
  }

  void toggleNewArrival(bool value) {
    onlyNewArrival.value = value;
    _resetPaging();
  }

  void toggleFastMoving(bool value) {
    onlyFastMoving.value = value;
    _resetPaging();
  }

  void toggleFeatured(bool value) {
    onlyFeatured.value = value;
    _resetPaging();
  }

  void toggleInStock(bool value) {
    onlyInStock.value = value;
    _resetPaging();
  }

  /// Clears every filter but keeps the current search text.
  void clearFilters() {
    categoryId.value = '';
    onlyNewArrival.value = false;
    onlyFastMoving.value = false;
    onlyFeatured.value = false;
    onlyInStock.value = false;
    minPrice.value = 0;
    maxPrice.value = 0;
    _resetPaging();
  }

  /// Clears search and filters together.
  void resetAll() {
    _debounceTimer?.cancel();
    query.value = '';
    clearFilters();
  }

  // ---------------------------------------------------------------------------
  // Scope
  //
  // Each catalogue entry point (a home rail's "See all", a category tile, the
  // search screen) declares exactly which slice of the catalogue it wants, and
  // these helpers apply that slice *decisively*.
  //
  // That decisiveness is the point. The controller is a permanent service, so
  // without this its filters leaked across navigations: tapping a category tile
  // after browsing New Arrivals inherited the new-arrival flag, and the routes
  // themselves passed no arguments at all — so every one of those entry points
  // silently showed the entire catalogue.
  //
  // Each of these clears every other filter first, so the result is exactly the
  // requested set and never a combination with leftover state.
  // ---------------------------------------------------------------------------

  /// Shows the entire active catalogue.
  void showAllProducts() => resetAll();

  /// Shows only the products in [id].
  ///
  /// An empty [id] falls back to the whole catalogue, so callers do not have to
  /// branch on whether the category argument was present.
  void showCategory(String id) {
    resetAll();
    if (id.isNotEmpty) categoryId.value = id;
  }

  /// Shows only new arrivals.
  void showNewArrivals() {
    resetAll();
    onlyNewArrival.value = true;
  }

  /// Shows only fast-moving products.
  void showFastMoving() {
    resetAll();
    onlyFastMoving.value = true;
  }

  /// Prepares the grid for the search screen.
  ///
  /// Keeps whatever the customer has typed — that is the search screen's own
  /// filter — but drops every other scope so a search never inherits, say, a
  /// category left over from a previous tile tap.
  void showSearchResults() => clearFilters();

  /// Reveals the next page.
  void loadMore() {
    if (!hasMore) return;
    visibleCount.value += pageSize;
  }

  void _resetPaging() => visibleCount.value = pageSize;

  // ---------------------------------------------------------------------------
  // Filtering
  // ---------------------------------------------------------------------------

  List<ProductModel> _applyFilters(List<ProductModel> source) {
    final String q = query.value.trim();
    final String category = categoryId.value;
    final double min = minPrice.value;
    final double max = maxPrice.value;

    return source.where((ProductModel p) {
      if (!p.isActive) return false;
      if (q.isNotEmpty && !p.matchesQuery(q)) return false;
      if (category.isNotEmpty && p.categoryId != category) return false;
      if (onlyNewArrival.value && !p.isNewArrival) return false;
      if (onlyFastMoving.value && !p.isFastMoving) return false;
      if (onlyFeatured.value && !p.isFeatured) return false;
      if (onlyInStock.value && !p.inStock) return false;
      if (min > 0 && p.price < min) return false;
      if (max > 0 && p.price > max) return false;
      return true;
    }).toList();
  }
}
