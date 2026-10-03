import 'dart:async';

import 'package:get/get.dart';

import '../../../data/models/models.dart';
import '../../../data/repositories/category_repository.dart';

/// Streams the active categories for the Categories tab.
class CategoriesController extends GetxController {
  CategoriesController({CategoryRepository? repository})
    : _categories = repository ?? Get.find<CategoryRepository>();

  final CategoryRepository _categories;

  final RxList<CategoryModel> categories = <CategoryModel>[].obs;
  final RxBool isLoading = true.obs;

  StreamSubscription<List<CategoryModel>>? _sub;

  @override
  void onInit() {
    super.onInit();
    load();
  }

  @override
  void onClose() {
    _sub?.cancel();
    super.onClose();
  }

  void load() {
    isLoading.value = true;
    _sub?.cancel();
    _sub = _categories.watchActiveCategories().listen((
      List<CategoryModel> list,
    ) {
      categories.assignAll(list);
      isLoading.value = false;
    });
  }

  int get totalDesigns => categories.fold<int>(
    0,
    (int sum, CategoryModel c) => sum + c.productCount,
  );
}
