import 'package:flutter/material.dart';
import 'package:get/get.dart';

import '../../core/constants/app_colors.dart';
import '../../core/constants/app_sizes.dart';
import '../../core/routes/app_routes.dart';
import '../../core/theme/app_typography.dart';
import '../../core/utils/app_formatter.dart';
import '../../core/utils/validators.dart';
import '../../data/models/models.dart';
import '../../modules/cart/cart_controller.dart';
import '../common/controllers/app_controller.dart';
import 'checkout_controller.dart';

class CheckoutBinding extends Bindings {
  @override
  void dependencies() {
    Get.put<CheckoutController>(CheckoutController());
  }
}

class CheckoutView extends StatefulWidget {
  const CheckoutView({super.key});

  @override
  State<CheckoutView> createState() => _CheckoutViewState();
}

class _CheckoutViewState extends State<CheckoutView> {
  late final CheckoutController _checkout;
  late final CartController _cart;

  @override
  void initState() {
    super.initState();
    _checkout = Get.find<CheckoutController>();
    _cart = Get.find<CartController>();
    _checkout.seedFromProfile();
    _refreshDraft();
  }

  void _refreshDraft() {
    _checkout.refreshTotals(
      cartItems: _cart.items.toList(),
      breakdown: _cart.breakdown,
    );
  }

  Future<void> _submit() async {
    _refreshDraft();
    final OrderModel? order = await _checkout.submit();
    if (order == null) return;
    Get.toNamed(Routes.orderSuccess, arguments: order);
  }

  @override
  Widget build(BuildContext context) {
    final AppController app = Get.find<AppController>();

    return Scaffold(
      appBar: AppBar(title: const Text('Place your order')),
      backgroundColor: AppColors.background,
      body: SafeArea(
        child: Obx(() {
          if (!_checkout.hasItems) {
            return Center(
              child: Padding(
                padding: const EdgeInsets.all(AppSpacing.xl),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: <Widget>[
                    const Icon(Icons.shopping_bag_outlined, size: 42),
                    const SizedBox(height: AppSpacing.md),
                    const Text('Your cart is empty.'),
                    TextButton(
                      onPressed: () => Get.back<void>(),
                      child: const Text('Return to cart'),
                    ),
                  ],
                ),
              ),
            );
          }

          return Column(
            children: <Widget>[
              Expanded(
                child: SingleChildScrollView(
                  padding: const EdgeInsets.all(AppSpacing.gutter),
                  child: AppBreakpoints.constrainContent(
                    context,
                    Form(
                      key: _checkout.formKey,
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.stretch,
                        children: <Widget>[
                          Text(
                            'Delivery details',
                            style: AppTypography.titleLarge,
                          ),
                          const SizedBox(height: AppSpacing.md),
                          TextFormField(
                            initialValue: _checkout.customerName.value,
                            textCapitalization: TextCapitalization.words,
                            textInputAction: TextInputAction.next,
                            decoration: const InputDecoration(
                              labelText: 'Full name',
                              prefixIcon: Icon(Icons.person_outline_rounded),
                            ),
                            validator: AppValidators.name,
                            onChanged: _checkout.setName,
                          ),
                          const SizedBox(height: AppSpacing.md),
                          TextFormField(
                            initialValue: _checkout.phone.value,
                            keyboardType: TextInputType.phone,
                            textInputAction: TextInputAction.next,
                            decoration: const InputDecoration(
                              labelText: 'Phone number',
                              prefixIcon: Icon(Icons.phone_outlined),
                            ),
                            validator: AppValidators.phone,
                            onChanged: _checkout.setPhone,
                          ),
                          const SizedBox(height: AppSpacing.md),
                          TextFormField(
                            textCapitalization: TextCapitalization.sentences,
                            minLines: 3,
                            maxLines: 5,
                            decoration: const InputDecoration(
                              labelText: 'Delivery address',
                              alignLabelWithHint: true,
                              prefixIcon: Icon(Icons.location_on_outlined),
                            ),
                            validator: AppValidators.address,
                            onChanged: _checkout.setAddress,
                          ),
                          const SizedBox(height: AppSpacing.md),
                          TextFormField(
                            textCapitalization: TextCapitalization.sentences,
                            minLines: 2,
                            maxLines: 4,
                            decoration: const InputDecoration(
                              labelText: 'Order note (optional)',
                              alignLabelWithHint: true,
                              prefixIcon: Icon(Icons.notes_rounded),
                            ),
                            onChanged: _checkout.setNote,
                          ),
                          const SizedBox(height: AppSpacing.xl),
                          Text(
                            'Order summary',
                            style: AppTypography.titleLarge,
                          ),
                          const SizedBox(height: AppSpacing.md),
                          ..._checkout.items.map(
                            (CartItem item) => _SummaryRow(
                              label: '${item.name} × ${item.quantity}',
                              value: AppFormatter.currency(item.subtotal),
                            ),
                          ),
                          const Divider(height: AppSpacing.xl),
                          _SummaryRow(
                            label: 'Subtotal',
                            value: AppFormatter.currency(
                              _checkout.subtotal.value,
                            ),
                          ),
                          if (_checkout.makingCharge.value > 0)
                            _SummaryRow(
                              label: 'Making charge',
                              value: AppFormatter.currency(
                                _checkout.makingCharge.value,
                              ),
                            ),
                          if (_checkout.discount.value > 0)
                            _SummaryRow(
                              label: 'Discount',
                              value:
                                  '- ${AppFormatter.currency(_checkout.discount.value)}',
                            ),
                          if (_checkout.tax.value > 0)
                            _SummaryRow(
                              label: 'Tax',
                              value: AppFormatter.currency(_checkout.tax.value),
                            ),
                          _SummaryRow(
                            label: 'Shipping',
                            value:
                                _checkout.shipping.value == 0 &&
                                    app.rateSettings.value.applyShipping
                                ? 'Free'
                                : AppFormatter.currency(
                                    _checkout.shipping.value,
                                  ),
                          ),
                          const Divider(height: AppSpacing.xl),
                          _SummaryRow(
                            label: 'Total',
                            value: AppFormatter.currency(_checkout.total),
                            emphasized: true,
                          ),
                          const SizedBox(height: AppSpacing.md),
                          Text(
                            'No online payment. We will confirm your order on WhatsApp.',
                            style: AppTypography.bodySmall.copyWith(
                              color: AppColors.textSecondary,
                            ),
                          ),
                          Obx(
                            () => _checkout.errorMessage.value.isEmpty
                                ? const SizedBox.shrink()
                                : Padding(
                                    padding: const EdgeInsets.only(
                                      top: AppSpacing.md,
                                    ),
                                    child: Text(
                                      _checkout.errorMessage.value,
                                      style: AppTypography.bodySmall.copyWith(
                                        color: AppColors.danger,
                                      ),
                                    ),
                                  ),
                          ),
                        ],
                      ),
                    ),
                    maxWidth: 600,
                  ),
                ),
              ),
              Padding(
                padding: const EdgeInsets.all(AppSpacing.gutter),
                child: Obx(
                  () => SizedBox(
                    width: double.infinity,
                    height: 52,
                    child: ElevatedButton(
                      onPressed: _checkout.isSubmitting.value ? null : _submit,
                      child: _checkout.isSubmitting.value
                          ? const CircularProgressIndicator(color: Colors.white)
                          : const Text('Submit order'),
                    ),
                  ),
                ),
              ),
            ],
          );
        }),
      ),
    );
  }
}

class OrderSuccessView extends StatelessWidget {
  const OrderSuccessView({super.key, required this.order});

  final OrderModel? order;

  @override
  Widget build(BuildContext context) {
    final OrderModel? submitted = order;

    return Scaffold(
      backgroundColor: AppColors.background,
      body: SafeArea(
        child: Center(
          child: SingleChildScrollView(
            padding: const EdgeInsets.all(AppSpacing.xl),
            child: AppBreakpoints.constrainContent(
              context,
              Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: <Widget>[
                  const Icon(
                    Icons.check_circle_outline_rounded,
                    size: 64,
                    color: AppColors.success,
                  ),
                  const SizedBox(height: AppSpacing.lg),
                  Text(
                    submitted == null ? 'Order received' : 'Thank you',
                    textAlign: TextAlign.center,
                    style: AppTypography.headlineMedium,
                  ),
                  const SizedBox(height: AppSpacing.sm),
                  Text(
                    submitted == null
                        ? 'Your order details are being processed.'
                        : 'Order ${submitted.orderNumber} is saved. Contact us on WhatsApp to confirm it.',
                    textAlign: TextAlign.center,
                  ),
                  const SizedBox(height: AppSpacing.xl),
                  if (submitted != null)
                    ElevatedButton.icon(
                      onPressed: () async {
                        final bool opened = await Get.find<CheckoutController>()
                            .sendToWhatsApp(submitted);
                        if (!opened) {
                          Get.rawSnackbar(
                            message:
                                'Order saved. WhatsApp could not be opened on this device.',
                            snackPosition: SnackPosition.BOTTOM,
                          );
                        }
                      },
                      icon: const Icon(Icons.chat_rounded),
                      label: const Text('Confirm on WhatsApp'),
                    ),
                  OutlinedButton(
                    onPressed: () async {
                      await Get.find<CartController>().clear();
                      Get.offAllNamed(Routes.customerShell);
                    },
                    child: const Text('Continue shopping'),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class _SummaryRow extends StatelessWidget {
  const _SummaryRow({
    required this.label,
    required this.value,
    this.emphasized = false,
  });

  final String label;
  final String value;
  final bool emphasized;

  @override
  Widget build(BuildContext context) {
    final TextStyle style = emphasized
        ? AppTypography.titleMedium
        : AppTypography.bodyMedium;

    return Padding(
      padding: const EdgeInsets.symmetric(vertical: AppSpacing.xs),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          Expanded(child: Text(label, style: style)),
          const SizedBox(width: AppSpacing.md),
          Flexible(
            child: Text(value, textAlign: TextAlign.end, style: style),
          ),
        ],
      ),
    );
  }
}
