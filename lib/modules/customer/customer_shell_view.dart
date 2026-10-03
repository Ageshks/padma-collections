import 'package:flutter/material.dart';
import 'package:get/get.dart';

import '../../core/constants/app_colors.dart';
import '../../core/constants/app_sizes.dart';
import '../common/controllers/app_controller.dart';
import '../home/widgets/whatsapp_fab.dart';
import 'customer_bindings.dart';

/// The customer app shell: five tabs under one persistent bottom navigation.
///
/// Tabs are held in an [IndexedStack] so scroll position and loaded data
/// survive switching — going back to Home never re-triggers a fetch.
class CustomerShellView extends GetView<CustomerShellController> {
  const CustomerShellView({super.key});

  @override
  Widget build(BuildContext context) {
    final AppController app = Get.find<AppController>();

    return Scaffold(
      backgroundColor: AppColors.background,
      body: Obx(
        () => IndexedStack(
          index: controller.currentIndex.value,
          children: controller.tabs,
        ),
      ),
      floatingActionButton: const WhatsappFab(),
      // The bar must be reactive too. Tab changes are frequently *not* driven by
      // a tap on the bar — "See all" on Home, the empty-cart CTA and the profile
      // shortcuts all call changeTab() directly. Those rebuilt the body through
      // the Obx above but left the bar highlighting the previous tab.
      //
      // The index is read *here* and passed down: an Obx only tracks observables
      // read inside its own builder, so reading it inside the _BottomBar's own
      // build would register no dependency and GetX would report an improper
      // use of Obx rather than rebuilding.
      bottomNavigationBar: Obx(
        () => _BottomBar(
          selectedIndex: controller.currentIndex.value,
          controller: controller,
          app: app,
        ),
      ),
    );
  }
}

class _BottomBar extends StatelessWidget {
  const _BottomBar({
    required this.selectedIndex,
    required this.controller,
    required this.app,
  });

  /// Current tab, read by the enclosing Obx so the bar rebuilds with it.
  final int selectedIndex;

  final CustomerShellController controller;
  final AppController app;

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: const BoxDecoration(
        border: Border(top: BorderSide(color: AppColors.divider)),
      ),
      child: NavigationBar(
        selectedIndex: selectedIndex,
        onDestinationSelected: controller.changeTab,
        destinations: <Widget>[
          const NavigationDestination(
            icon: Icon(Icons.home_outlined),
            selectedIcon: Icon(Icons.home_rounded),
            label: 'Home',
          ),
          const NavigationDestination(
            icon: Icon(Icons.category_outlined),
            selectedIcon: Icon(Icons.category_rounded),
            label: 'Categories',
          ),
          const NavigationDestination(
            icon: Icon(Icons.favorite_border_rounded),
            selectedIcon: Icon(Icons.favorite_rounded),
            label: 'Wishlist',
          ),
          NavigationDestination(
            icon: Obx(() => _CartIcon(count: app.cartCount.value)),
            selectedIcon: Obx(
              () => _CartIcon(count: app.cartCount.value, active: true),
            ),
            label: 'Cart',
          ),
          const NavigationDestination(
            icon: Icon(Icons.person_outline_rounded),
            selectedIcon: Icon(Icons.person_rounded),
            label: 'Profile',
          ),
        ],
      ),
    );
  }
}

/// Cart tab icon that shows a live item-count badge.
class _CartIcon extends StatelessWidget {
  const _CartIcon({required this.count, this.active = false});

  final int count;
  final bool active;

  @override
  Widget build(BuildContext context) {
    final Widget icon = Icon(
      active ? Icons.shopping_bag_rounded : Icons.shopping_bag_outlined,
      size: 23,
    );
    if (count <= 0) return icon;

    return Stack(
      clipBehavior: Clip.none,
      children: <Widget>[
        icon,
        Positioned(
          right: -7,
          top: -5,
          child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 1),
            constraints: const BoxConstraints(minWidth: 16),
            decoration: BoxDecoration(
              color: AppColors.burgundy,
              borderRadius: BorderRadius.circular(AppRadius.pill),
              border: Border.all(color: AppColors.surface, width: 1.5),
            ),
            child: Text(
              count > 99 ? '99+' : '$count',
              textAlign: TextAlign.center,
              style: const TextStyle(
                fontFamily: 'Inter',
                fontSize: 9,
                fontWeight: FontWeight.w700,
                color: Colors.white,
                height: 1.3,
              ),
            ),
          ),
        ),
      ],
    );
  }
}
