import 'package:flutter/material.dart';
import 'package:get/get.dart';

import '../../core/routes/app_routes.dart';
import '../cart/cart_controller.dart';
import '../cart/cart_view.dart';
import '../categories/categories_controller.dart';
import '../categories/categories_view.dart';
import '../home/home_controller.dart';
import '../home/home_view.dart';
import '../profile/profile_view.dart';
import '../products/product_list_controller.dart';
import '../wishlist/wishlist_controller.dart';
import '../wishlist/wishlist_view.dart';

/// Registers the controllers shared across the customer tabs.
///
/// The shell controller plus the cart and wishlist controllers are permanent:
/// product cards on the home screen, the cart screen and the wishlist screen
/// all mutate the same state, and re-creating it would drop live Firestore
/// subscriptions and reset the tab badges.
class CustomerBinding extends Bindings {
  @override
  void dependencies() {
    Get.put<CustomerShellController>(
      CustomerShellController(),
      permanent: true,
    );
    Get.put<CartController>(CartController(), permanent: true);
    Get.put<WishlistController>(WishlistController(), permanent: true);
    Get.put<HomeController>(HomeController(), permanent: true);
    Get.put<CategoriesController>(CategoriesController(), permanent: true);
    // Permanent so the grid keeps its search text, filters and scroll position
    // while the customer opens a product and comes back.
    Get.put<ProductListController>(ProductListController(), permanent: true);
  }
}

/// Drives the five-tab bottom navigation shell.
class CustomerShellController extends GetxController {
  final RxInt currentIndex = 0.obs;

  /// Maps a tab index to its route name, used by deep links from headers.
  static const List<String> tabRoutes = <String>[
    Routes.home,
    Routes.categories,
    Routes.wishlist,
    Routes.cart,
    Routes.profile,
  ];

  /// The tab widgets, kept in a list so state survives tab switches.
  final List<Widget> tabs = <Widget>[
    const HomeView(),
    const CategoriesView(),
    const WishlistView(),
    const CartView(),
    const ProfileView(),
  ];

  void changeTab(int index) => currentIndex.value = index;

  /// Switches to a tab by its route name, if it is one of the five.
  void selectRoute(String route) {
    final int index = tabRoutes.indexOf(route);
    if (index != -1) changeTab(index);
  }
}
