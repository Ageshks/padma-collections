import 'package:flutter/material.dart';
import 'package:get/get.dart';

import '../../../core/constants/app_colors.dart';
import '../../../core/constants/app_sizes.dart';
import '../../common/controllers/app_controller.dart';

/// Floating WhatsApp button.
///
/// Deliberately visible on every customer screen: WhatsApp is how Padma
/// Collections confirms orders, so it should never be more than one tap away.
class WhatsappFab extends StatelessWidget {
  const WhatsappFab({super.key});

  @override
  Widget build(BuildContext context) {
    final AppController app = Get.find<AppController>();

    return Semantics(
      button: true,
      label: 'Chat with us on WhatsApp',
      child: FloatingActionButton(
        onPressed: () => app.openWhatsAppGeneral(),
        tooltip: 'Chat on WhatsApp',
        elevation: 6,
        child: const Icon(Icons.chat_rounded, size: 26),
      ),
    );
  }
}

/// A wide, inline WhatsApp call-to-action used on the home and contact screens.
class WhatsappBanner extends StatelessWidget {
  const WhatsappBanner({
    super.key,
    this.title = 'Need help choosing?',
    this.message =
        'Message us on WhatsApp for availability, sizing and bulk orders.',
    this.onTap,
  });

  final String title;
  final String message;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    final AppController app = Get.find<AppController>();

    return Container(
      margin: const EdgeInsets.symmetric(
        horizontal: AppSpacing.gutter,
        vertical: AppSpacing.lg,
      ),
      decoration: BoxDecoration(
        borderRadius: AppRadius.cardRadius,
        gradient: const LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: <Color>[AppColors.whatsapp, AppColors.whatsappDark],
        ),
        boxShadow: <BoxShadow>[
          BoxShadow(
            color: AppColors.whatsapp.withValues(alpha: 0.3),
            blurRadius: 18,
            offset: const Offset(0, 8),
          ),
        ],
      ),
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          borderRadius: AppRadius.cardRadius,
          onTap: onTap ?? () => app.openWhatsAppGeneral(),
          child: Padding(
            padding: const EdgeInsets.all(AppSpacing.lg),
            child: Row(
              children: <Widget>[
                Container(
                  width: 46,
                  height: 46,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    color: Colors.white.withValues(alpha: 0.22),
                  ),
                  child: const Icon(
                    Icons.chat_rounded,
                    color: Colors.white,
                    size: 24,
                  ),
                ),
                const SizedBox(width: AppSpacing.lg),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    mainAxisSize: MainAxisSize.min,
                    children: <Widget>[
                      Text(
                        title,
                        style: const TextStyle(
                          fontFamily: 'Inter',
                          fontSize: 15,
                          fontWeight: FontWeight.w600,
                          color: Colors.white,
                        ),
                      ),
                      const SizedBox(height: 2),
                      Text(
                        message,
                        style: TextStyle(
                          fontFamily: 'Inter',
                          fontSize: 12.5,
                          height: 1.35,
                          color: Colors.white.withValues(alpha: 0.92),
                        ),
                      ),
                    ],
                  ),
                ),
                const Icon(
                  Icons.arrow_forward_rounded,
                  color: Colors.white,
                  size: 20,
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
