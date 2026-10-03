import 'package:flutter/material.dart';
import 'package:get/get.dart';

import '../../core/utils/error_handler.dart';
import '../../data/models/models.dart';
import '../../data/repositories/order_repository.dart';
import '../common/controllers/app_controller.dart';

/// Drives the checkout form: validation, order creation and the WhatsApp
/// handoff that confirms the request with the seller.
///
/// The order is written to Firestore **first**, so a customer who never opens
/// WhatsApp still has a request the admin can act on. The WhatsApp step is then
/// offered as the confirmation channel rather than the submission mechanism.
class CheckoutController extends GetxController {
  CheckoutController({OrderRepository? orders, AppController? app})
    : _orders = orders ?? Get.find<OrderRepository>(),
      _app = app ?? Get.find<AppController>();

  final OrderRepository _orders;
  final AppController _app;

  final GlobalKey<FormState> formKey = GlobalKey<FormState>();

  final RxBool isSubmitting = false.obs;
  final RxString errorMessage = ''.obs;

  // --- Draft order -----------------------------------------------------------

  final RxString customerName = ''.obs;
  final RxString phone = ''.obs;
  final RxString address = ''.obs;
  final RxString customerNote = ''.obs;

  /// Cart lines captured at the moment checkout opened.
  ///
  /// A snapshot is taken so a background cart edit cannot change the total
  /// after the customer has already seen and agreed to it.
  final RxList<CartItem> items = <CartItem>[].obs;

  final RxDouble subtotal = 0.0.obs;
  final RxDouble makingCharge = 0.0.obs;
  final RxDouble discount = 0.0.obs;
  final RxDouble tax = 0.0.obs;
  final RxDouble shipping = 0.0.obs;

  double get total =>
      subtotal.value +
      makingCharge.value -
      discount.value +
      tax.value +
      shipping.value;

  int get unitCount =>
      items.fold<int>(0, (int sum, CartItem i) => sum + i.quantity);

  bool get hasItems => items.isNotEmpty;

  /// Pre-fills the form from the signed-in customer's saved profile.
  void seedFromProfile() {
    final UserModel? user = _app.currentUser.value;
    if (user == null) return;
    if (customerName.value.isEmpty && user.name.isNotEmpty) {
      customerName.value = user.name;
    }
    if (phone.value.isEmpty && user.phone.isNotEmpty) phone.value = user.phone;
  }

  /// Re-reads the cart and rate settings into the draft.
  void refreshTotals({
    required List<CartItem> cartItems,
    required PriceBreakdown breakdown,
  }) {
    items.assignAll(cartItems);
    subtotal.value = breakdown.subtotal;
    makingCharge.value = breakdown.makingCharge;
    discount.value = breakdown.discount;
    tax.value = breakdown.tax;
    shipping.value = breakdown.shipping;
  }

  void reset() {
    customerName.value = '';
    phone.value = '';
    address.value = '';
    customerNote.value = '';
    items.clear();
    subtotal.value = 0;
    makingCharge.value = 0;
    discount.value = 0;
    tax.value = 0;
    shipping.value = 0;
    errorMessage.value = '';
  }

  // --- Submission ------------------------------------------------------------

  /// Validates, persists the order and returns it for the success screen.
  ///
  /// Returns `null` when validation fails or the write is rejected, in which
  /// case [errorMessage] explains what the customer should do.
  Future<OrderModel?> submit() async {
    if (isSubmitting.value) return null;
    if (!hasItems) {
      errorMessage.value = 'Your cart is empty.';
      return null;
    }
    if (!(formKey.currentState?.validate() ?? false)) return null;

    isSubmitting.value = true;
    errorMessage.value = '';

    try {
      final OrderModel order = await _orders.create(
        userId: _app.currentUid,
        customerName: customerName.value,
        phone: phone.value,
        address: address.value,
        items: items
            .map(
              (CartItem c) => OrderItem(
                productId: c.productId,
                name: c.name,
                image: c.image,
                price: c.price,
                quantity: c.quantity,
                sku: c.sku,
                categoryName: '',
              ),
            )
            .toList(),
        subtotal: subtotal.value,
        makingCharge: makingCharge.value,
        discount: discount.value,
        tax: tax.value,
        shippingCharge: shipping.value,
        customerNote: customerNote.value,
      );
      return order;
    } on AppException catch (e) {
      errorMessage.value = e.message;
      return null;
    } catch (e) {
      errorMessage.value = AppErrorHandler.wrap(e).message;
      return null;
    } finally {
      isSubmitting.value = false;
    }
  }

  /// Offers the WhatsApp confirmation for a freshly created order.
  Future<bool> sendToWhatsApp(OrderModel order) async {
    final bool sent = await _app.openWhatsAppOrder(
      items: items.toList(),
      subtotal: subtotal.value,
      total: total,
      customerName: customerName.value,
      phone: phone.value,
      address: address.value,
      customerNote: customerNote.value,
    );
    if (sent) await _orders.markWhatsAppSent(order.orderId);
    return sent;
  }

  // --- Field setters ---------------------------------------------------------

  void setName(String value) => customerName.value = value;
  void setPhone(String value) => phone.value = value;
  void setAddress(String value) => address.value = value;
  void setNote(String value) => customerNote.value = value;
}
