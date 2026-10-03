import 'package:flutter/material.dart';
import 'package:get/get.dart';

import '../../core/constants/app_colors.dart';
import '../../core/constants/app_sizes.dart';
import '../../core/theme/app_typography.dart';
import '../../core/utils/app_formatter.dart';
import '../../data/models/models.dart';
import '../../data/repositories/category_repository.dart';
import 'product_list_controller.dart';

/// Modal sheet exposing the full filter set: category and price range.
///
/// Every control writes straight through to [ProductListController], so the
/// grid behind the sheet re-renders live and the footer button only closes it.
class ProductFilterSheet extends StatelessWidget {
  const ProductFilterSheet({super.key});

  /// Presents the filter sheet.
  static Future<void> show(BuildContext context) {
    return Get.bottomSheet<void>(
      const ProductFilterSheet(),
      isScrollControlled: true,
    );
  }

  @override
  Widget build(BuildContext context) {
    final ProductListController controller = Get.find<ProductListController>();
    final CategoryRepository categories = Get.find<CategoryRepository>();

    return SafeArea(
      child: Container(
        constraints: BoxConstraints(
          maxHeight: MediaQuery.sizeOf(context).height * 0.75,
        ),
        decoration: const BoxDecoration(
          color: AppColors.surface,
          borderRadius: BorderRadius.vertical(
            top: Radius.circular(AppRadius.lg),
          ),
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: <Widget>[
            Padding(
              padding: const EdgeInsets.fromLTRB(
                AppSpacing.gutter,
                AppSpacing.lg,
                AppSpacing.sm,
                0,
              ),
              child: Row(
                children: <Widget>[
                  Text('Filters', style: AppTypography.titleLarge),
                  const Spacer(),
                  TextButton(
                    onPressed: controller.clearFilters,
                    child: const Text('Reset'),
                  ),
                ],
              ),
            ),
            const Divider(height: 1),
            Flexible(
              child: ListView(
                shrinkWrap: true,
                padding: const EdgeInsets.symmetric(
                  horizontal: AppSpacing.gutter,
                  vertical: AppSpacing.lg,
                ),
                children: <Widget>[
                  _CategoryPicker(categories: categories),
                  const SizedBox(height: AppSpacing.xl),
                  const _PriceFilter(),
                ],
              ),
            ),
            const Divider(height: 1),
            Padding(
              padding: const EdgeInsets.all(AppSpacing.gutter),
              child: SizedBox(
                width: double.infinity,
                height: 48,
                child: ElevatedButton(
                  onPressed: () => Navigator.of(context).pop(),
                  child: Obx(() {
                    final int count = controller.results.length;
                    return Text(
                      count == 0
                          ? 'No matches — close to adjust'
                          : 'Show $count product${count == 1 ? '' : 's'}',
                    );
                  }),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

/// Radio list of active categories, including an "All categories" option.
class _CategoryPicker extends StatelessWidget {
  const _CategoryPicker({required this.categories});

  final CategoryRepository categories;

  @override
  Widget build(BuildContext context) {
    final ProductListController controller = Get.find<ProductListController>();

    return StreamBuilder<List<CategoryModel>>(
      stream: categories.watchActiveCategories(),
      builder: (BuildContext context, AsyncSnapshot<List<CategoryModel>> snap) {
        if (snap.connectionState == ConnectionState.waiting) {
          return const SizedBox(
            height: 80,
            child: Center(
              child: CircularProgressIndicator(color: AppColors.burgundy),
            ),
          );
        }

        final List<CategoryModel> items = snap.data ?? <CategoryModel>[];
        if (items.isEmpty) return const SizedBox.shrink();

        return Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: <Widget>[
            Text('Category', style: AppTypography.titleMedium),
            const SizedBox(height: AppSpacing.sm),
            // One RadioGroup owns the selection, so the whole list stays in
            // sync with a single source of truth in the controller.
            Obx(
              () => RadioGroup<String>(
                groupValue: controller.categoryId.value,
                onChanged: (String? v) => controller.setCategory(v ?? ''),
                child: Column(
                  children: <Widget>[
                    const RadioListTile<String>(
                      value: '',
                      title: Text('All categories'),
                      contentPadding: EdgeInsets.zero,
                    ),
                    for (final CategoryModel category in items)
                      RadioListTile<String>(
                        value: category.categoryId,
                        title: Text(category.name),
                        contentPadding: EdgeInsets.zero,
                      ),
                  ],
                ),
              ),
            ),
          ],
        );
      },
    );
  }
}

/// Dual price range bounded by the catalogue's actual min/max.
class _PriceFilter extends StatefulWidget {
  const _PriceFilter();

  @override
  State<_PriceFilter> createState() => _PriceFilterState();
}

class _PriceFilterState extends State<_PriceFilter> {
  RangeValues? _range;

  @override
  Widget build(BuildContext context) {
    final ProductListController controller = Get.find<ProductListController>();

    return Obx(() {
      final double min = controller.catalogueMinPrice;
      final double max = controller.catalogueMaxPrice <= min
          ? min + 1
          : controller.catalogueMaxPrice;

      // Seed the slider from controller state the first time the sheet builds,
      // so reopening it shows the range that is actually applied.
      _range ??= RangeValues(
        controller.minPrice.value <= 0 ? min : controller.minPrice.value,
        controller.maxPrice.value <= 0 ? max : controller.maxPrice.value,
      );

      return Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          Text('Price', style: AppTypography.titleMedium),
          const SizedBox(height: AppSpacing.xs),
          Text(
            '${AppFormatter.currency(_range!.start)} — '
            '${AppFormatter.currency(_range!.end)}',
            style: AppTypography.bodySmall,
          ),
          RangeSlider(
            values: _range!,
            min: min,
            max: max,
            // Fixed divisions keep the slider usable across a wide price span.
            divisions: 14,
            labels: RangeLabels(
              AppFormatter.currency(_range!.start),
              AppFormatter.currency(_range!.end),
            ),
            onChanged: (RangeValues value) => setState(() => _range = value),
            // 0 means "unbounded" in the controller, so snap the handles back.
            onChangeEnd: (RangeValues value) => controller.setPriceRange(
              value.start <= min ? 0 : value.start,
              value.end >= max ? 0 : value.end,
            ),
          ),
        ],
      );
    });
  }
}
