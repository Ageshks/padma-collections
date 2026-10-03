import 'package:flutter/material.dart';
import 'package:get/get.dart';

import '../../core/constants/app_colors.dart';
import '../../core/constants/app_sizes.dart';
import '../../core/theme/app_typography.dart';
import '../../core/utils/app_formatter.dart';
import '../../core/widgets/brand_widgets.dart';
import '../../core/widgets/state_views.dart';
import '../../data/models/models.dart';
import '../../data/repositories/order_repository.dart';
import '../common/controllers/app_controller.dart';

class MyOrdersView extends StatelessWidget {
  const MyOrdersView({super.key});

  @override
  Widget build(BuildContext context) {
    final AppController app = Get.find<AppController>();
    final OrderRepository orders = Get.find<OrderRepository>();

    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(title: const Text('My orders')),
      body: StreamBuilder<List<OrderModel>>(
        stream: orders.watchUserOrders(app.currentUid),
        builder: (BuildContext context, AsyncSnapshot<List<OrderModel>> snap) {
          if (snap.hasError) {
            return ErrorStateView(
              message: 'Orders could not be loaded. Please try again.',
              onRetry: () {},
            );
          }
          if (snap.connectionState == ConnectionState.waiting) {
            return const Center(child: CircularProgressIndicator());
          }
          final List<OrderModel> list = snap.data ?? const <OrderModel>[];
          if (list.isEmpty) {
            return const EmptyState(
              title: 'No orders yet.',
              message: 'Your confirmed order requests will appear here.',
              icon: Icons.receipt_long_outlined,
            );
          }

          return ListView.separated(
            padding: const EdgeInsets.all(AppSpacing.gutter),
            itemCount: list.length,
            separatorBuilder: (_, _) => const SizedBox(height: AppSpacing.md),
            itemBuilder: (BuildContext context, int index) =>
                _OrderTile(order: list[index]),
          );
        },
      ),
    );
  }
}

class _OrderTile extends StatelessWidget {
  const _OrderTile({required this.order});

  final OrderModel order;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(AppSpacing.lg),
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: AppRadius.cardRadius,
        boxShadow: AppColors.cardShadow,
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          Row(
            children: <Widget>[
              Expanded(
                child: Text(
                  order.orderNumber.isEmpty ? 'Order' : order.orderNumber,
                  style: AppTypography.titleMedium,
                ),
              ),
              Flexible(
                child: Align(
                  alignment: Alignment.centerRight,
                  child: AppBadge(
                    label: order.status,
                    color: AppColors.burgundy,
                    background: AppColors.burgundySoft,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: AppSpacing.xs),
          Text(
            '${order.itemCount} ${order.itemCount == 1 ? 'item' : 'items'} · ${AppFormatter.dateTime(order.createdAt)}',
            style: AppTypography.bodySmall,
          ),
          const SizedBox(height: AppSpacing.sm),
          for (final OrderItem item in order.items.take(3))
            Padding(
              padding: const EdgeInsets.only(top: 3),
              child: Text(
                '${item.name} × ${item.quantity}',
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
              ),
            ),
          if (order.items.length > 3)
            Text('+ ${order.items.length - 3} more items'),
          const Divider(height: AppSpacing.lg),
          Row(
            children: <Widget>[
              const Expanded(child: Text('Total')),
              Text(
                AppFormatter.currency(order.total),
                style: AppTypography.priceSmall,
              ),
            ],
          ),
        ],
      ),
    );
  }
}
