import 'package:flutter/material.dart';
import 'package:get/get.dart';

import '../../core/constants/app_colors.dart';
import '../../core/constants/app_constants.dart';
import '../../core/constants/app_sizes.dart';
import '../../core/routes/app_routes.dart';
import '../../core/theme/app_typography.dart';
import '../../core/utils/app_formatter.dart';
import '../../core/widgets/app_network_image.dart';
import '../../core/widgets/brand_widgets.dart';
import '../../core/widgets/product_card.dart';
import '../../core/widgets/state_views.dart';
import '../../data/models/models.dart';
import '../common/controllers/app_controller.dart';
import '../customer/customer_bindings.dart';
import 'cart_controller.dart';

/// Cart tab: line items, totals and the WhatsApp-assisted checkout handoff.
class CartView extends StatelessWidget {
  const CartView({super.key});

  @override
  Widget build(BuildContext context) {
    final CartController controller = Get.find<CartController>();
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
          if (controller.isEmpty) {
            return EmptyState(
              title: 'Your cart is empty.',
              message:
                  'Browse the collection and add a piece you love, then send '
                  'it to us on WhatsApp to confirm.',
              icon: Icons.shopping_bag_outlined,
              actionLabel: 'Start shopping',
              onAction: () => Get.find<CustomerShellController>().changeTab(0),
            );
          }

          return Column(
            children: <Widget>[
              Padding(
                padding: const EdgeInsets.fromLTRB(
                  AppSpacing.gutter,
                  AppSpacing.lg,
                  AppSpacing.gutter,
                  AppSpacing.sm,
                ),
                child: Row(
                  children: <Widget>[
                    const Expanded(
                      child: SectionHeader(
                        title: 'Your Cart',
                        eyebrow: 'Review',
                        padding: EdgeInsets.zero,
                      ),
                    ),
                    TextButton.icon(
                      onPressed: () => _confirmClear(controller),
                      icon: const Icon(Icons.delete_outline, size: 17),
                      label: const Text('Clear'),
                      style: TextButton.styleFrom(
                        foregroundColor: AppColors.textSecondary,
                      ),
                    ),
                  ],
                ),
              ),

              if (controller.hasStockIssues)
                Padding(
                  padding: const EdgeInsets.symmetric(
                    horizontal: AppSpacing.gutter,
                  ),
                  child: _StockWarning(
                    count: controller.unavailableItems.length,
                  ),
                ),

              Expanded(
                child: ListView.separated(
                  padding: const EdgeInsets.fromLTRB(
                    AppSpacing.gutter,
                    AppSpacing.md,
                    AppSpacing.gutter,
                    AppSpacing.md,
                  ),
                  itemCount: controller.items.length,
                  separatorBuilder: (_, __) =>
                      const SizedBox(height: AppSpacing.md),
                  itemBuilder: (BuildContext context, int i) =>
                      _CartTile(item: controller.items[i]),
                ),
              ),

              _CheckoutBar(controller: controller, app: app),
            ],
          );
        }),
      ),
    );
  }

  Future<void> _confirmClear(CartController controller) async {
    final bool? confirmed = await Get.dialog<bool>(
      AlertDialog(
        title: const Text('Clear cart?'),
        content: const Text('This removes every item from your cart.'),
        actions: <Widget>[
          TextButton(
            onPressed: () => Get.back(result: false),
            child: const Text('Keep'),
          ),
          TextButton(
            onPressed: () => Get.back(result: true),
            style: TextButton.styleFrom(foregroundColor: AppColors.danger),
            child: const Text('Clear'),
          ),
        ],
      ),
    );
    if (confirmed ?? false) await controller.clear();
  }
}

class _StockWarning extends StatelessWidget {
  const _StockWarning({required this.count});

  final int count;

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.only(top: AppSpacing.sm),
      padding: const EdgeInsets.all(AppSpacing.md),
      decoration: BoxDecoration(
        color: AppColors.warningSoft,
        borderRadius: AppRadius.tileRadius,
      ),
      child: Row(
        children: <Widget>[
          const Icon(
            Icons.info_outline_rounded,
            size: 18,
            color: AppColors.warning,
          ),
          const SizedBox(width: AppSpacing.sm),
          Expanded(
            child: Text(
              '$count ${count == 1 ? 'item has' : 'items have'} changed or is '
              'out of stock. Please review before continuing.',
              style: AppTypography.bodySmall.copyWith(color: AppColors.warning),
            ),
          ),
        ],
      ),
    );
  }
}

/// One cart line: thumbnail, quantity stepper and subtotal.
class _CartTile extends StatelessWidget {
  const _CartTile({required this.item});

  final CartItem item;

  @override
  Widget build(BuildContext context) {
    final CartController controller = Get.find<CartController>();

    return Container(
      padding: const EdgeInsets.all(AppSpacing.md),
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: AppRadius.cardRadius,
        boxShadow: AppColors.cardShadow,
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          InkWell(
            onTap: () =>
                Get.toNamed(Routes.productDetails, arguments: item.productId),
            borderRadius: AppRadius.tileRadius,
            child: SizedBox(
              width: 80,
              height: 100,
              child: AppNetworkImage(
                url: item.image,
                borderRadius: AppRadius.tileRadius,
                memCacheWidth: 260,
              ),
            ),
          ),
          const SizedBox(width: AppSpacing.md),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: <Widget>[
                Text(
                  item.name,
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                  style: AppTypography.titleMedium,
                ),
                const SizedBox(height: 2),
                Text(
                  AppFormatter.currency(item.price),
                  style: AppTypography.bodyMedium,
                ),
                if (item.exceedsStock) ...<Widget>[
                  const SizedBox(height: AppSpacing.xs),
                  Text(
                    'Only ${item.stock} left in stock',
                    style: AppTypography.bodySmall.copyWith(
                      color: AppColors.danger,
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                ],
                const SizedBox(height: AppSpacing.md),
                Row(
                  children: <Widget>[
                    QuantityStepper(
                      compact: true,
                      quantity: item.quantity,
                      max: item.stock > 0
                          ? item.stock.clamp(
                              AppConstants.cartQuantityMin,
                              AppConstants.cartQuantityMax,
                            )
                          : AppConstants.cartQuantityMax,
                      onChanged: (int q) =>
                          controller.updateQuantity(item.productId, q),
                    ),
                    const Spacer(),
                    Text(
                      AppFormatter.currency(item.subtotal),
                      style: AppTypography.priceSmall,
                    ),
                  ],
                ),
              ],
            ),
          ),
          IconButton(
            tooltip: 'Remove',
            onPressed: () => controller.remove(item.productId),
            icon: const Icon(
              Icons.close_rounded,
              size: 18,
              color: AppColors.textHint,
            ),
          ),
        ],
      ),
    );
  }
}

/// Sticky summary bar with the itemised total and the order CTA.
class _CheckoutBar extends StatelessWidget {
  const _CheckoutBar({required this.controller, required this.app});

  final CartController controller;
  final AppController app;

  @override
  Widget build(BuildContext context) {
    final PriceBreakdown breakdown = controller.breakdown;

    return Container(
      padding: const EdgeInsets.fromLTRB(
        AppSpacing.gutter,
        AppSpacing.lg,
        AppSpacing.gutter,
        AppSpacing.lg,
      ),
      decoration: const BoxDecoration(
        color: AppColors.surface,
        border: Border(top: BorderSide(color: AppColors.divider)),
        boxShadow: <BoxShadow>[
          BoxShadow(
            color: Color(0x0F2B2118),
            blurRadius: 16,
            offset: Offset(0, -4),
          ),
        ],
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: <Widget>[
          if (breakdown.hasAdjustments) ...<Widget>[
            _Row(
              label: 'Subtotal',
              value: AppFormatter.currency(breakdown.subtotal),
            ),
            if (breakdown.makingCharge > 0)
              _Row(
                label: 'Making charge',
                value: AppFormatter.currency(breakdown.makingCharge),
              ),
            if (breakdown.discount > 0)
              _Row(
                label: 'Discount',
                value: '- ${AppFormatter.currency(breakdown.discount)}',
                valueColor: AppColors.success,
              ),
            if (breakdown.tax > 0)
              _Row(label: 'Tax', value: AppFormatter.currency(breakdown.tax)),
            if (breakdown.shipping > 0)
              _Row(
                label: 'Shipping',
                value: AppFormatter.currency(breakdown.shipping),
              ),
            if (breakdown.shipping == 0 &&
                app.rateSettings.value.shippingCharge > 0)
              _Row(
                label: 'Shipping',
                value: 'Free',
                valueColor: AppColors.success,
              ),
            const SizedBox(height: AppSpacing.sm),
            const Divider(height: 1),
            const SizedBox(height: AppSpacing.md),
          ],
          Row(
            children: <Widget>[
              Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisSize: MainAxisSize.min,
                children: <Widget>[
                  Text('Total', style: AppTypography.bodyMedium),
                  Text(
                    AppFormatter.currency(breakdown.total),
                    style: AppTypography.displayMedium.copyWith(fontSize: 22),
                  ),
                ],
              ),
              const SizedBox(width: AppSpacing.lg),
              Expanded(
                child: SizedBox(
                  height: 52,
                  child: ElevatedButton.icon(
                    onPressed: () => Get.toNamed(Routes.checkout),
                    icon: const Icon(Icons.lock_outline_rounded, size: 18),
                    label: const Text('Place Order'),
                    style: ElevatedButton.styleFrom(
                      padding: EdgeInsets.zero,
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(AppRadius.md),
                      ),
                    ),
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: AppSpacing.md),
          Row(
            children: <Widget>[
              const Icon(
                Icons.info_outline_rounded,
                size: 14,
                color: AppColors.textHint,
              ),
              const SizedBox(width: AppSpacing.xs),
              Expanded(
                child: Text(
                  'No online payment. You will confirm the order on WhatsApp.',
                  style: AppTypography.bodySmall.copyWith(fontSize: 11.5),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

class _Row extends StatelessWidget {
  const _Row({required this.label, required this.value, this.valueColor});

  final String label;
  final String value;
  final Color? valueColor;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 3),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: <Widget>[
          Text(label, style: AppTypography.bodySmall),
          Text(
            value,
            style: AppTypography.bodyMedium.copyWith(
              fontWeight: FontWeight.w600,
              color: valueColor,
            ),
          ),
        ],
      ),
    );
  }
}
