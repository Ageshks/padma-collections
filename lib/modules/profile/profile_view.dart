import 'package:flutter/material.dart';
import 'package:get/get.dart';

import '../../core/constants/app_colors.dart';
import '../../core/constants/app_sizes.dart';
import '../../core/routes/app_routes.dart';
import '../../core/theme/app_typography.dart';
import '../../core/utils/app_formatter.dart';
import '../../core/widgets/app_network_image.dart';
import '../../core/widgets/brand_widgets.dart';
import '../cart/cart_controller.dart';
import '../common/controllers/app_controller.dart';
import '../customer/customer_bindings.dart';
import '../home/widgets/whatsapp_fab.dart';
import '../wishlist/wishlist_controller.dart';

/// Profile tab: identity, order shortcuts and the policy pages.
class ProfileView extends StatelessWidget {
  const ProfileView({super.key});

  @override
  Widget build(BuildContext context) {
    final AppController app = Get.find<AppController>();
    final WishlistController wishlist = Get.find<WishlistController>();
    final CartController cart = Get.find<CartController>();

    return Scaffold(
      backgroundColor: AppColors.background,
      floatingActionButton: const WhatsappFab(),
      body: SafeArea(
        bottom: false,
        child: Obx(() {
          final user = app.currentUser.value;

          return ListView(
            padding: const EdgeInsets.only(
              bottom: AppSpacing.bottomBarClearance,
            ),
            children: <Widget>[
              _ProfileHeader(
                name: user?.name ?? 'Guest',
                email: user?.email ?? '',
                phone: user?.phone ?? '',
                imageUrl: user?.profileImage ?? '',
              ),
              const SizedBox(height: AppSpacing.lg),

              Row(
                children: <Widget>[
                  Expanded(
                    child: _ShortcutTile(
                      icon: Icons.favorite_border_rounded,
                      label: 'Wishlist',
                      count: wishlist.count,
                      onTap: () =>
                          Get.find<CustomerShellController>().changeTab(2),
                    ),
                  ),
                  Expanded(
                    child: _ShortcutTile(
                      icon: Icons.shopping_bag_outlined,
                      label: 'Cart',
                      count: cart.itemCount,
                      onTap: () =>
                          Get.find<CustomerShellController>().changeTab(3),
                    ),
                  ),
                  Expanded(
                    child: _ShortcutTile(
                      icon: Icons.receipt_long_outlined,
                      label: 'Orders',
                      count: 0,
                      onTap: () => Get.toNamed(Routes.myOrders),
                    ),
                  ),
                ],
              ),

              const SizedBox(height: AppSpacing.lg),
              _Group(
                title: 'Account',
                children: <Widget>[
                  _Tile(
                    icon: Icons.person_outline_rounded,
                    label: 'Edit Profile',
                    onTap: () => Get.toNamed(Routes.editProfile),
                  ),
                  _Tile(
                    icon: Icons.notifications_none_rounded,
                    label: 'Notifications',
                    badge: app.unreadNotifications.value,
                    onTap: () => Get.toNamed(Routes.notifications),
                  ),
                  _Tile(
                    icon: Icons.receipt_long_outlined,
                    label: 'My Orders',
                    onTap: () => Get.toNamed(Routes.myOrders),
                  ),
                ],
              ),
              const SizedBox(height: AppSpacing.md),
              _Group(
                title: 'Padma Collections',
                children: <Widget>[
                  _Tile(
                    icon: Icons.chat_rounded,
                    label: 'Contact Us',
                    iconColor: AppColors.whatsapp,
                    onTap: app.openWhatsAppGeneral,
                  ),
                  _Tile(
                    icon: Icons.info_outline_rounded,
                    label: 'About Us',
                    onTap: () => Get.toNamed(Routes.aboutUs),
                  ),
                  _Tile(
                    icon: Icons.privacy_tip_outlined,
                    label: 'Privacy Policy',
                    onTap: () => Get.toNamed(Routes.privacyPolicy),
                  ),
                  _Tile(
                    icon: Icons.gavel_rounded,
                    label: 'Terms & Conditions',
                    onTap: () => Get.toNamed(Routes.termsConditions),
                  ),
                ],
              ),

              const SizedBox(height: AppSpacing.lg),
              Padding(
                padding: const EdgeInsets.symmetric(
                  horizontal: AppSpacing.gutter,
                ),
                child: OutlinedButton.icon(
                  onPressed: () => _confirmSignOut(app),
                  icon: const Icon(
                    Icons.logout_rounded,
                    size: 18,
                    color: AppColors.danger,
                  ),
                  label: const Text(
                    'Logout',
                    style: TextStyle(
                      fontFamily: 'Inter',
                      fontWeight: FontWeight.w600,
                      color: AppColors.danger,
                    ),
                  ),
                  style: OutlinedButton.styleFrom(
                    minimumSize: const Size.fromHeight(48),
                    side: const BorderSide(color: AppColors.dangerSoft),
                  ),
                ),
              ),
              const SizedBox(height: AppSpacing.xl),
              const Center(
                child: BrandLogo(
                  height: 34,
                  variant: BrandLogoVariant.wordmark,
                ),
              ),
              const SizedBox(height: AppSpacing.sm),
              Center(
                child: Text(
                  app.settings.value.tagline,
                  style: AppTypography.bodySmall,
                ),
              ),
              const SizedBox(height: AppSpacing.md),
            ],
          );
        }),
      ),
    );
  }

  /// Confirms before signing out, then returns to the login screen.
  Future<void> _confirmSignOut(AppController app) async {
    final bool? confirmed = await Get.dialog<bool>(
      AlertDialog(
        title: const Text('Logout?'),
        content: const Text('You will need to sign in again to shop.'),
        actions: <Widget>[
          TextButton(
            onPressed: () => Get.back(result: false),
            child: const Text('Cancel'),
          ),
          TextButton(
            onPressed: () => Get.back(result: true),
            style: TextButton.styleFrom(foregroundColor: AppColors.danger),
            child: const Text('Logout'),
          ),
        ],
      ),
    );
    if (!(confirmed ?? false)) return;

    await app.signOut();
    Get.offAllNamed(Routes.login);
  }
}

/// Branded identity header at the top of the profile tab.
class _ProfileHeader extends StatelessWidget {
  const _ProfileHeader({
    required this.name,
    required this.email,
    required this.phone,
    required this.imageUrl,
  });

  final String name;
  final String email;
  final String phone;
  final String imageUrl;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.fromLTRB(
        AppSpacing.gutter,
        AppSpacing.xl,
        AppSpacing.gutter,
        AppSpacing.xl,
      ),
      decoration: const BoxDecoration(gradient: AppGradients.burgundy),
      child: Column(
        children: <Widget>[
          AppAvatar(
            name: name,
            imageUrl: imageUrl,
            radius: 40,
            showBorder: true,
          ),
          const SizedBox(height: AppSpacing.md),
          Text(
            name,
            textAlign: TextAlign.center,
            style: AppTypography.headlineMedium.copyWith(color: Colors.white),
          ),
          if (email.isNotEmpty) ...<Widget>[
            const SizedBox(height: AppSpacing.xs),
            Text(
              email,
              textAlign: TextAlign.center,
              style: AppTypography.bodySmall.copyWith(
                color: Colors.white.withValues(alpha: 0.85),
              ),
            ),
          ],
          if (phone.isNotEmpty) ...<Widget>[
            const SizedBox(height: 2),
            Text(
              StringUtils.formatPhone(phone),
              style: AppTypography.bodySmall.copyWith(
                color: AppColors.goldLight,
              ),
            ),
          ],
        ],
      ),
    );
  }
}

/// Compact stat tile used for Wishlist / Cart / Orders.
class _ShortcutTile extends StatelessWidget {
  const _ShortcutTile({
    required this.icon,
    required this.label,
    required this.count,
    required this.onTap,
  });

  final IconData icon;
  final String label;
  final int count;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onTap,
      borderRadius: AppRadius.cardRadius,
      child: Container(
        margin: const EdgeInsets.symmetric(horizontal: AppSpacing.xs),
        padding: const EdgeInsets.symmetric(vertical: AppSpacing.lg),
        decoration: BoxDecoration(
          color: AppColors.surface,
          borderRadius: AppRadius.cardRadius,
          boxShadow: AppColors.cardShadow,
        ),
        child: Column(
          children: <Widget>[
            Icon(icon, size: 22, color: AppColors.burgundy),
            const SizedBox(height: AppSpacing.sm),
            if (count > 0) Text('$count', style: AppTypography.titleMedium),
            Text(label, style: AppTypography.bodySmall),
          ],
        ),
      ),
    );
  }
}

/// A titled card grouping related navigation rows.
class _Group extends StatelessWidget {
  const _Group({required this.title, required this.children});

  final String title;
  final List<Widget> children;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: <Widget>[
        Padding(
          padding: const EdgeInsets.fromLTRB(
            AppSpacing.gutter,
            0,
            AppSpacing.gutter,
            AppSpacing.sm,
          ),
          child: Text(title.toUpperCase(), style: AppTypography.overline),
        ),
        Container(
          margin: const EdgeInsets.symmetric(horizontal: AppSpacing.gutter),
          decoration: BoxDecoration(
            color: AppColors.surface,
            borderRadius: AppRadius.cardRadius,
            boxShadow: AppColors.cardShadow,
          ),
          clipBehavior: Clip.antiAlias,
          child: Column(children: children),
        ),
      ],
    );
  }
}

/// A single navigation row with an optional trailing badge.
class _Tile extends StatelessWidget {
  const _Tile({
    required this.icon,
    required this.label,
    required this.onTap,
    this.badge = 0,
    this.iconColor,
  });

  final IconData icon;
  final String label;
  final VoidCallback onTap;
  final int badge;
  final Color? iconColor;

  @override
  Widget build(BuildContext context) {
    return ListTile(
      onTap: onTap,
      leading: Icon(icon, size: 21, color: iconColor),
      title: Text(label),
      trailing: Row(
        mainAxisSize: MainAxisSize.min,
        children: <Widget>[
          if (badge > 0)
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 2),
              decoration: BoxDecoration(
                color: AppColors.burgundy,
                borderRadius: BorderRadius.circular(AppRadius.pill),
              ),
              child: Text(
                '$badge',
                style: const TextStyle(
                  fontFamily: 'Inter',
                  fontSize: 10,
                  fontWeight: FontWeight.w700,
                  color: Colors.white,
                ),
              ),
            ),
          const Icon(Icons.chevron_right_rounded, color: AppColors.textHint),
        ],
      ),
    );
  }
}
