import 'package:flutter/widgets.dart';
import 'package:get/get.dart';

import '../../modules/admin/admin_login_view.dart';
import '../../modules/admin/admin_management_views.dart';
import '../../modules/admin/admin_shell_view.dart';
import '../../modules/admin/admin_catalogue_forms.dart';
import '../../modules/admin/admin_settings_views.dart';
import '../../modules/checkout/checkout_view.dart';
import '../../modules/auth/forgot_password_view.dart';
import '../../modules/auth/login_view.dart';
import '../../modules/auth/register_view.dart';
import '../../modules/customer/customer_bindings.dart';
import '../../modules/customer/customer_shell_view.dart';
import '../../modules/common/controllers/app_controller.dart';
import '../../modules/notifications/notifications_view.dart';
import '../../modules/orders/my_orders_view.dart';
import '../../modules/products/product_details_view.dart';
import '../../modules/products/product_list_controller.dart';
import '../../modules/products/product_list_view.dart';
import '../../modules/profile/profile_subpages.dart';
import '../../modules/splash/splash_view.dart';
import '../../data/models/models.dart';
import 'app_routes.dart';

/// Resolves the product id carried by a [Routes.productDetails] navigation.
///
/// The id travels as a GetX argument rather than a route parameter so deep
/// links from notifications, banners and rails can reuse the one route, which
/// means **every** caller must pass `product.productId` and nothing else.
///
/// This is deliberately strict, because the lenient version shipped a real bug:
/// a caller passed a whole `ProductModel`, the type check quietly produced an
/// empty id, and the screen failed much later as a blank error page after a
/// wasted `getById('')` round trip — with nothing pointing back at the actual
/// mistake. The home-screen rails did exactly this while the product list,
/// cart, wishlist and related-products paths all passed an id correctly, so
/// only those rails appeared broken.
///
/// In debug the assertion names the offending type and the fix. In release the
/// empty-string fallback is kept so a malformed deep link renders the error
/// view rather than crashing.
String productDetailsId(Object? argument) {
  assert(
    argument is String,
    'Routes.productDetails expects a product id String but received '
    '${argument.runtimeType}. Pass `product.productId`, not the model.',
  );
  return argument is String ? argument : '';
}

/// Resolves the category id carried by a [Routes.categoryProducts] navigation.
///
/// Two shapes legitimately arrive here and both are accepted:
///
///   * a whole [CategoryModel] — from the home category rail and the
///     **Categories** tab;
///   * a bare id [String] — from a banner's `actionValue`.
///
/// Returns null when there is nothing to filter by, which renders the full
/// catalogue. That is the same treatment a banner with no `actionValue` already
/// gets, since its caller guards the navigation.
String? categoryProductsId(Object? argument) {
  if (argument is CategoryModel) return argument.categoryId;
  if (argument is String) return argument.isEmpty ? null : argument;
  return null;
}

/// Builds [ProductListView] with [applyScope] applied to the shared controller.
///
/// [ProductListController] is a permanent service, so its filters otherwise
/// survive every navigation. Applying the scope here — at the point of
/// navigation, where the intent is actually known — is what stops a "New
/// Arrivals" tap from showing up as a category tile's products, or from
/// inheriting a category chosen earlier.
///
/// Guarded with [Get.isRegistered] because these routes can be resolved before
/// the customer binding has run; the grid then simply opens unfiltered rather
/// than throwing during navigation.
Widget _scopedCatalogue(void Function(ProductListController controller) apply) {
  if (Get.isRegistered<ProductListController>()) {
    apply(Get.find<ProductListController>());
  }
  return const ProductListView();
}

/// Route table for the whole app.
///
/// GetX bindings are attached per-route so controllers are created lazily and
/// disposed automatically when their screen is popped.
class AppPages {
  AppPages._();

  static List<GetMiddleware> get _adminGuard => <GetMiddleware>[
    _AdminRouteGuard(),
  ];

  static final List<GetPage<dynamic>> pages = <GetPage<dynamic>>[
    GetPage<void>(
      name: Routes.splash,
      page: () => const SplashView(),
      transition: Transition.fadeIn,
    ),

    // ---- Authentication -----------------------------------------------------
    GetPage<void>(
      name: Routes.login,
      page: () => const LoginView(),
      // AuthController is registered in InitialBinding so it is ready before
      // the first build; registering it here would be too late.
      transition: Transition.fadeIn,
    ),
    GetPage<void>(
      name: Routes.register,
      page: () => const RegisterView(),
      transition: Transition.cupertino,
    ),
    GetPage<void>(
      name: Routes.forgotPassword,
      page: () => const ForgotPasswordView(),
      transition: Transition.cupertino,
    ),
    GetPage<void>(
      name: Routes.editProfile,
      page: () => const EditProfileView(),
      transition: Transition.cupertino,
    ),
    GetPage<void>(
      name: Routes.myOrders,
      page: () => const MyOrdersView(),
      transition: Transition.cupertino,
    ),
    GetPage<void>(
      name: Routes.notifications,
      page: () => const NotificationsView(),
      transition: Transition.cupertino,
    ),
    GetPage<void>(
      name: Routes.aboutUs,
      page: () => const StoreInfoView(page: StoreInfoPage.about),
      transition: Transition.cupertino,
    ),
    GetPage<void>(
      name: Routes.privacyPolicy,
      page: () => const StoreInfoView(page: StoreInfoPage.privacy),
      transition: Transition.cupertino,
    ),
    GetPage<void>(
      name: Routes.termsConditions,
      page: () => const StoreInfoView(page: StoreInfoPage.terms),
      transition: Transition.cupertino,
    ),
    GetPage<void>(
      name: Routes.checkout,
      page: () => const CheckoutView(),
      binding: CheckoutBinding(),
      transition: Transition.cupertino,
    ),
    GetPage<void>(
      name: Routes.orderSuccess,
      page: () => OrderSuccessView(
        order: Get.arguments is OrderModel ? Get.arguments as OrderModel : null,
      ),
      transition: Transition.cupertino,
    ),

    GetPage<void>(
      name: Routes.adminLogin,
      page: () => const AdminLoginView(),
      transition: Transition.fadeIn,
    ),

    GetPage<void>(
      name: Routes.adminShell,
      page: () => const AdminShellView(),
      middlewares: _adminGuard,
      transition: Transition.fadeIn,
    ),

    GetPage<void>(
      name: Routes.adminDashboard,
      page: () => const AdminDashboardView(),
      middlewares: _adminGuard,
      transition: Transition.fadeIn,
    ),
    GetPage<void>(
      name: Routes.adminProducts,
      page: () => const AdminProductsView(),
      middlewares: _adminGuard,
      transition: Transition.fadeIn,
    ),
    GetPage<void>(
      name: Routes.adminProductForm,
      page: () => AdminProductFormView(
        product: Get.arguments is ProductModel
            ? Get.arguments as ProductModel
            : null,
      ),
      middlewares: _adminGuard,
      transition: Transition.fadeIn,
    ),
    GetPage<void>(
      name: Routes.adminCategories,
      page: () => const AdminCategoriesView(),
      middlewares: _adminGuard,
      transition: Transition.fadeIn,
    ),
    GetPage<void>(
      name: Routes.adminCategoryForm,
      page: () => AdminCategoryFormView(
        category: Get.arguments is CategoryModel
            ? Get.arguments as CategoryModel
            : null,
      ),
      middlewares: _adminGuard,
      transition: Transition.fadeIn,
    ),
    GetPage<void>(
      name: Routes.adminOrders,
      page: () => const AdminOrdersView(),
      middlewares: _adminGuard,
      transition: Transition.fadeIn,
    ),
    GetPage<void>(
      name: Routes.adminOrderDetails,
      page: () => AdminOrderDetailsView(
        order: Get.arguments is OrderModel ? Get.arguments as OrderModel : null,
      ),
      middlewares: _adminGuard,
      transition: Transition.fadeIn,
    ),
    GetPage<void>(
      name: Routes.adminCustomers,
      page: () => const AdminCustomersView(),
      middlewares: _adminGuard,
      transition: Transition.fadeIn,
    ),
    GetPage<void>(
      name: Routes.adminCustomerDetail,
      page: () => AdminCustomerDetailView(
        customer: Get.arguments is UserModel
            ? Get.arguments as UserModel
            : null,
      ),
      middlewares: _adminGuard,
      transition: Transition.fadeIn,
    ),
    GetPage<void>(
      name: Routes.adminBanners,
      page: () => const AdminBannersView(),
      middlewares: _adminGuard,
      transition: Transition.fadeIn,
    ),
    GetPage<void>(
      name: Routes.adminBannerForm,
      page: () => AdminBannerFormView(
        banner: Get.arguments is BannerModel
            ? Get.arguments as BannerModel
            : null,
      ),
      middlewares: _adminGuard,
      transition: Transition.cupertino,
    ),
    GetPage<void>(
      name: Routes.adminNewArrivals,
      page: () => const AdminNewArrivalsView(),
      middlewares: _adminGuard,
      transition: Transition.fadeIn,
    ),
    GetPage<void>(
      name: Routes.adminFastMoving,
      page: () => const AdminFastMovingView(),
      middlewares: _adminGuard,
      transition: Transition.fadeIn,
    ),
    GetPage<void>(
      name: Routes.adminRateSettings,
      page: () => const AdminRateSettingsView(),
      middlewares: _adminGuard,
      transition: Transition.fadeIn,
    ),
    GetPage<void>(
      name: Routes.adminWhatsAppSettings,
      page: () => const AdminWhatsAppSettingsView(),
      middlewares: _adminGuard,
      transition: Transition.fadeIn,
    ),
    GetPage<void>(
      name: Routes.adminNotifications,
      page: () => const AdminNotificationsView(),
      middlewares: _adminGuard,
      transition: Transition.fadeIn,
    ),
    GetPage<void>(
      name: Routes.adminAppSettings,
      page: () => const AdminAppSettingsView(),
      middlewares: _adminGuard,
      transition: Transition.fadeIn,
    ),

    // ---- Catalogue ----------------------------------------------------------
    // The listing controller is a permanent service (see CustomerBinding) so the
    // grid keeps its search and filter state while details are pushed on top.
    GetPage<void>(
      name: Routes.productList,
      page: () => _scopedCatalogue(
        (ProductListController c) => c.showAllProducts(),
      ),
      transition: Transition.fadeIn,
    ),
    GetPage<void>(
      name: Routes.search,
      page: () => _scopedCatalogue(
        (ProductListController c) => c.showSearchResults(),
      ),
      transition: Transition.fadeIn,
    ),
    GetPage<void>(
      name: Routes.categoryProducts,
      page: () => _scopedCatalogue(
        (ProductListController c) =>
            c.showCategory(categoryProductsId(Get.arguments) ?? ''),
      ),
      transition: Transition.fadeIn,
    ),
    GetPage<void>(
      name: Routes.newArrivals,
      page: () => _scopedCatalogue(
        (ProductListController c) => c.showNewArrivals(),
      ),
      transition: Transition.fadeIn,
    ),
    GetPage<void>(
      name: Routes.fastMoving,
      page: () => _scopedCatalogue(
        (ProductListController c) => c.showFastMoving(),
      ),
      transition: Transition.fadeIn,
    ),
    GetPage<void>(
      name: Routes.productDetails,
      // The id travels as a GetX argument rather than a route parameter so
      // deep links from notifications and banners reuse the same route.
      page: () => ProductDetailsView(productId: productDetailsId(Get.arguments)),
      transition: Transition.cupertino,
    ),

    // ---- Customer shell -----------------------------------------------------
    GetPage<void>(
      name: Routes.customerShell,
      page: () => const CustomerShellView(),
      binding: CustomerBinding(),
      transition: Transition.fadeIn,
    ),
  ];
}

class _AdminRouteGuard extends GetMiddleware {
  @override
  RouteSettings? redirect(String? route) {
    if (!Get.isRegistered<AppController>()) {
      return const RouteSettings(name: Routes.login);
    }
    final AppController app = Get.find<AppController>();
    if (app.isAdmin) return null;
    return RouteSettings(
      name: app.isSignedIn ? Routes.customerShell : Routes.login,
    );
  }
}
