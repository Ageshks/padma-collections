import 'package:flutter/material.dart';
import 'package:get/get.dart';

import '../../core/constants/app_colors.dart';
import '../../core/constants/app_sizes.dart';
import '../../core/theme/app_typography.dart';
import '../../data/models/models.dart';
import 'product_list_controller.dart';

/// Bottom sheet for choosing how results are ordered.
///
/// Reads and writes [ProductListController] directly, so the grid behind the
/// sheet updates the instant a choice is tapped.
class ProductSortSheet extends StatelessWidget {
  const ProductSortSheet({super.key});

  /// Presents the sheet over the current route.
  static Future<void> show(BuildContext context) {
    return Get.bottomSheet<void>(
      const _SortSheetBody(),
      isScrollControlled: true,
    );
  }

  @override
  Widget build(BuildContext context) => const _SortSheetBody();
}

class _SortSheetBody extends StatelessWidget {
  const _SortSheetBody();

  @override
  Widget build(BuildContext context) {
    final ProductListController controller = Get.find<ProductListController>();

    return SafeArea(
      child: Container(
        decoration: const BoxDecoration(
          color: AppColors.surface,
          borderRadius: BorderRadius.vertical(
            top: Radius.circular(AppRadius.lg),
          ),
        ),
        padding: const EdgeInsets.symmetric(vertical: AppSpacing.lg),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: <Widget>[
            const Padding(
              padding: EdgeInsets.symmetric(horizontal: AppSpacing.gutter),
              child: Text('Sort by', style: AppTypography.titleMedium),
            ),
            const SizedBox(height: AppSpacing.sm),
            // A single RadioGroup drives every option and dismisses the sheet as
            // soon as a choice is made.
            Obx(
              () => RadioGroup<ProductSortOption>(
                groupValue: controller.sort.value,
                onChanged: (ProductSortOption? value) {
                  if (value == null) return;
                  controller.setSort(value);
                  Navigator.of(context).pop();
                },
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: <Widget>[
                    for (final ProductSortOption option
                        in ProductSortOption.values)
                      RadioListTile<ProductSortOption>(
                        value: option,
                        title: Text(option.label),
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
