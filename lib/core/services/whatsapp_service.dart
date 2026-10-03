import 'dart:convert';

import 'package:url_launcher/url_launcher.dart';

import '../../core/utils/app_formatter.dart';
import '../../data/models/models.dart';

/// Builds and opens WhatsApp conversations.
///
/// Padma Collections has **no payment gateway** — WhatsApp *is* the order
/// confirmation channel. Every message is generated from admin-configurable
/// settings (`settings/whatsapp`) so the business number and wording can be
/// changed without shipping an app update.
class WhatsappService {
  WhatsappService();

  /// Opens a chat with [number] pre-filled with [message].
  ///
  /// Prefers the `https://wa.me/` universal link (works on Android, iOS and
  /// web), then falls back to the `whatsapp://` app scheme, and finally to a
  /// plain `https://wa.me/` in an external browser.
  Future<bool> open({required String number, required String message}) async {
    final String digits = StringUtils.toWhatsappNumber(number);
    if (digits.isEmpty) return false;

    final String encoded = Uri.encodeComponent(message);
    final List<String> candidates = <String>[
      'https://wa.me/$digits?text=$encoded',
      'whatsapp://send?phone=$digits&text=$encoded',
    ];

    for (final String url in candidates) {
      try {
        final Uri uri = Uri.parse(url);
        if (await canLaunchUrl(uri) &&
            await launchUrl(uri, mode: LaunchMode.externalApplication)) {
          return true;
        }
      } catch (_) {
        // Try the next scheme.
      }
    }
    return false;
  }

  /// Generic greeting used by the home FAB and contact screens.
  String generalMessage(WhatsAppSettings settings) =>
      settings.effectiveDefaultMessage;

  /// Product-specific enquiry, including SKU, price and quantity.
  String productMessage({
    required ProductModel product,
    required int quantity,
    required WhatsAppSettings settings,
  }) {
    final StringBuffer b = StringBuffer()
      ..writeln(settings.greeting)
      ..writeln()
      ..writeln('I am interested in the following product:')
      ..writeln()
      ..writeln('Product: ${product.name}');

    if (product.sku.isNotEmpty) b.writeln('SKU: ${product.sku}');
    b
      ..writeln('Quantity: $quantity')
      ..writeln('Price: ${AppFormatter.currency(product.price)}');

    if (product.categoryName.isNotEmpty) {
      b.writeln('Category: ${product.categoryName}');
    }

    b
      ..writeln()
      ..writeln('Please provide more details and confirm availability.')
      ..writeln()
      ..writeln('Thank you.');

    return b.toString();
  }

  /// Full cart / order enquiry with every line item and the customer details.
  String orderMessage({
    required List<CartItem> items,
    required double subtotal,
    required double total,
    required WhatsAppSettings settings,
    String customerName = '',
    String phone = '',
    String address = '',
    String customerNote = '',
  }) {
    final StringBuffer b = StringBuffer()
      ..writeln(settings.greeting)
      ..writeln()
      ..writeln('I would like to enquire about the following order:')
      ..writeln();

    for (int i = 0; i < items.length; i++) {
      final CartItem item = items[i];
      b
        ..writeln('${i + 1}. ${item.name}')
        ..writeln('Quantity: ${item.quantity}')
        ..writeln('Price: ${AppFormatter.currency(item.price)}');
      if (item.sku.isNotEmpty) b.writeln('SKU: ${item.sku}');
      b.writeln();
    }

    b
      ..writeln('Total: ${AppFormatter.currency(total)}')
      ..writeln()
      ..writeln('Customer Name: ${customerName.isEmpty ? '—' : customerName}')
      ..writeln('Phone: ${phone.isEmpty ? '—' : phone}')
      ..writeln('Delivery Address: ${address.isEmpty ? '—' : address}');
    b.writeln();

    if (customerNote.trim().isNotEmpty) {
      b
        ..writeln()
        ..writeln('Note: ${customerNote.trim()}');
    }

    b
      ..writeln()
      ..writeln('Please confirm the availability and order details.')
      ..writeln()
      ..writeln('Thank you.');

    return b.toString();
  }

  /// Follow-up message sent from a confirmed order's detail screen.
  String orderFollowUpMessage({
    required OrderModel order,
    required WhatsAppSettings settings,
  }) {
    final StringBuffer b = StringBuffer()
      ..writeln(settings.greeting)
      ..writeln()
      ..writeln(
        'Regarding my order '
        '${order.orderNumber.isEmpty ? '' : '#${order.orderNumber} '}'
        '(${order.status}):',
      )
      ..writeln();

    for (int i = 0; i < order.items.length; i++) {
      final OrderItem item = order.items[i];
      b.writeln(
        '${i + 1}. ${item.name} x${item.quantity} — '
        '${AppFormatter.currency(item.subtotal)}',
      );
    }

    b
      ..writeln()
      ..writeln('Total: ${AppFormatter.currency(order.total)}')
      ..writeln()
      ..writeln('Please share an update. Thank you.');

    return b.toString();
  }

  /// Short enquiry used by banner and support CTAs.
  String customMessage(String template, WhatsAppSettings settings) {
    if (template.trim().isEmpty) return generalMessage(settings);
    return '${settings.greeting}\n\n${template.trim()}';
  }

  /// Escapes text for safe embedding in a URL query string.
  String encode(String message) => Uri.encodeComponent(message);

  /// Pretty copy for the share sheet / clipboard.
  String toClipboard(String message) => jsonEncode(message);
}
