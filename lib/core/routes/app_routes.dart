/// Named routes for the whole app.
///
/// Names are grouped by role so it is obvious at a glance which screens a
/// customer must never reach — the admin block is enforced by both route
/// guards and Firestore security rules.
class Routes {
  Routes._();

  // Splash / bootstrap.
  static const String splash = '/splash';

  // Authentication.
  static const String splashToLogin = '/login';
  static const String splashToHome = '/home';
  static const String login = '/login';
  static const String register = '/register';
  static const String forgotPassword = '/forgot-password';

  // Customer shell and its tabs.
  static const String customerShell = '/customer';
  static const String home = '/home';
  static const String categories = '/categories';
  static const String wishlist = '/wishlist';
  static const String cart = '/cart';
  static const String profile = '/profile';

  // Catalogue.
  static const String productDetails = '/product-details';
  static const String productList = '/products';
  static const String categoryProducts = '/category-products';
  static const String newArrivals = '/new-arrivals';
  static const String fastMoving = '/fast-moving';
  static const String search = '/search';

  // Orders.
  static const String checkout = '/checkout';
  static const String orderSuccess = '/order-success';
  static const String myOrders = '/my-orders';
  static const String orderDetails = '/order-details';

  // Profile and static pages.
  static const String editProfile = '/edit-profile';
  static const String notifications = '/notifications';
  static const String contactUs = '/contact-us';
  static const String aboutUs = '/about-us';
  static const String privacyPolicy = '/privacy-policy';
  static const String termsConditions = '/terms-conditions';

  // Admin.
  static const String adminLogin = '/admin/login';
  static const String adminShell = '/admin';
  static const String adminDashboard = '/admin/dashboard';
  static const String adminProducts = '/admin/products';
  static const String adminProductForm = '/admin/product-form';
  static const String adminCategories = '/admin/categories';
  static const String adminCategoryForm = '/admin/category-form';
  static const String adminOrders = '/admin/orders';
  static const String adminOrderDetails = '/admin/order-details';
  static const String adminCustomers = '/admin/customers';
  static const String adminCustomerDetail = '/admin/customer-detail';
  static const String adminBanners = '/admin/banners';
  static const String adminBannerForm = '/admin/banner-form';
  static const String adminNewArrivals = '/admin/new-arrivals';
  static const String adminFastMoving = '/admin/fast-moving';
  static const String adminRateSettings = '/admin/rate-settings';
  static const String adminWhatsAppSettings = '/admin/whatsapp-settings';
  static const String adminNotifications = '/admin/notifications';
  static const String adminAppSettings = '/admin/app-settings';
}
