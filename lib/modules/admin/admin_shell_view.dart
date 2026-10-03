import 'package:flutter/material.dart';
import 'package:get/get.dart';

import '../../core/constants/app_colors.dart';
import '../../core/constants/app_sizes.dart';
import '../../core/constants/cloudinary_config.dart';
import '../../core/routes/app_routes.dart';
import '../../core/theme/admin_theme.dart';
import '../../core/widgets/app_network_image.dart';
import '../../core/widgets/brand_widgets.dart';
import '../../data/models/models.dart';
import '../common/controllers/app_controller.dart';
import '../../data/repositories/category_repository.dart';
import '../../data/repositories/order_repository.dart';
import '../../data/repositories/product_repository.dart';
import '../../data/repositories/user_repository.dart';
import 'admin_management_views.dart';
import 'admin_settings_views.dart';

class AdminShellView extends StatefulWidget {
  const AdminShellView({super.key});

  @override
  State<AdminShellView> createState() => _AdminShellViewState();
}

class _AdminShellViewState extends State<AdminShellView> {
  final List<_AdminRoute> _routes = <_AdminRoute>[
    _AdminRoute(
      title: 'Dashboard',
      icon: Icons.dashboard_rounded,
      page: const AdminDashboardView(),
      routeName: Routes.adminDashboard,
    ),
    _AdminRoute(
      title: 'Products',
      icon: Icons.inventory_2_outlined,
      page: const AdminProductsView(),
      routeName: Routes.adminProducts,
    ),
    _AdminRoute(
      title: 'Categories',
      icon: Icons.category_outlined,
      page: const AdminCategoriesView(),
      routeName: Routes.adminCategories,
    ),
    _AdminRoute(
      title: 'Orders',
      icon: Icons.shopping_bag_outlined,
      page: const AdminOrdersView(),
      routeName: Routes.adminOrders,
    ),
    _AdminRoute(
      title: 'Customers',
      icon: Icons.people_alt_outlined,
      page: const AdminCustomersView(),
      routeName: Routes.adminCustomers,
    ),
    _AdminRoute(
      title: 'Banners',
      icon: Icons.panorama_outlined,
      page: const AdminBannersView(),
      routeName: Routes.adminBanners,
    ),
    _AdminRoute(
      title: 'Rate Settings',
      icon: Icons.currency_rupee_rounded,
      page: const AdminRateSettingsView(),
      routeName: Routes.adminRateSettings,
    ),
    _AdminRoute(
      title: 'WhatsApp Settings',
      icon: Icons.chat_bubble_outline_rounded,
      page: const AdminWhatsAppSettingsView(),
      routeName: Routes.adminWhatsAppSettings,
    ),
    _AdminRoute(
      title: 'Notifications',
      icon: Icons.notifications_active_outlined,
      page: const AdminNotificationsView(),
      routeName: Routes.adminNotifications,
    ),
    _AdminRoute(
      title: 'App Settings',
      icon: Icons.settings_outlined,
      page: const AdminAppSettingsView(),
      routeName: Routes.adminAppSettings,
    ),
  ];

  int _selectedIndex = 0;

  @override
  Widget build(BuildContext context) {
    final Widget currentPage = _routes[_selectedIndex].page;

    return Theme(
      data: AdminTheme.theme,
      child: Scaffold(
        backgroundColor: AppColors.adminBackground,
        appBar: AppBar(
          title: Text(_routes[_selectedIndex].title),
          actions: <Widget>[
            IconButton(
              tooltip: 'Sign out',
              onPressed: _signOut,
              icon: const Icon(Icons.logout_rounded),
            ),
          ],
        ),
        drawer: Drawer(
          width: 260,
          child: Column(
            children: <Widget>[
              SafeArea(
                child: Padding(
                  padding: const EdgeInsets.all(AppSpacing.lg),
                  child: const BrandLogo(height: 28),
                ),
              ),
              const Divider(),
              Expanded(
                child: ListView.builder(
                  itemCount: _routes.length,
                  itemBuilder: (BuildContext context, int index) {
                    final _AdminRoute route = _routes[index];
                    final bool active = index == _selectedIndex;
                    return ListTile(
                      selected: active,
                      leading: Icon(
                        route.icon,
                        color: active ? AppColors.gold : null,
                      ),
                      title: Text(route.title),
                      onTap: () {
                        setState(() => _selectedIndex = index);
                        if (Navigator.canPop(context)) {
                          Navigator.of(context).pop();
                        }
                      },
                    );
                  },
                ),
              ),
              const Divider(),
              ListTile(
                leading: const Icon(Icons.logout_rounded),
                title: const Text('Logout'),
                onTap: _signOut,
              ),
            ],
          ),
        ),
        body: currentPage,
      ),
    );
  }

  Future<void> _signOut() async {
    final AppController app = Get.find<AppController>();
    await app.signOut();
    Get.offAllNamed(Routes.login);
  }
}

class _AdminRoute {
  const _AdminRoute({
    required this.title,
    required this.icon,
    required this.page,
    required this.routeName,
  });

  final String title;
  final IconData icon;
  final Widget page;
  final String routeName;
}

class AdminDashboardView extends StatelessWidget {
  const AdminDashboardView({super.key});

  Future<DashboardStats> _loadStats() async {
    final ProductRepository products = Get.find<ProductRepository>();
    final UserRepository users = Get.find<UserRepository>();
    final OrderRepository orders = Get.find<OrderRepository>();
    final CategoryRepository categories = Get.find<CategoryRepository>();

    final List<ProductModel> productList = await products
        .watchAllProducts()
        .first;
    final List<OrderModel> orderList = await orders.watchAllOrders().first;
    final List<CategoryModel> categoryList = await categories
        .watchAllCategories()
        .first;
    await users.watchCustomers().first;

    return users.dashboardStats(
      products: productList,
      orders: orderList,
      totalCategories: categoryList.length,
    );
  }

  @override
  Widget build(BuildContext context) {
    return FutureBuilder<DashboardStats>(
      future: _loadStats(),
      builder: (BuildContext context, AsyncSnapshot<DashboardStats> snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return const Center(child: CircularProgressIndicator());
        }
        if (snapshot.hasError) {
          return Center(
            child: Text('Unable to load dashboard: ${snapshot.error}'),
          );
        }

        final DashboardStats stats = snapshot.data ?? const DashboardStats();
        final List<_MetricCardData> cards = <_MetricCardData>[
          _MetricCardData(
            'Total Products',
            stats.totalProducts.toString(),
            Icons.inventory_2_outlined,
          ),
          _MetricCardData(
            'Active Products',
            stats.activeProducts.toString(),
            Icons.check_circle_outline_rounded,
          ),
          _MetricCardData(
            'Out of Stock',
            stats.outOfStockProducts.toString(),
            Icons.block_rounded,
          ),
          _MetricCardData(
            'Total Categories',
            stats.totalCategories.toString(),
            Icons.category_outlined,
          ),
          _MetricCardData(
            'Total Customers',
            stats.totalCustomers.toString(),
            Icons.people_alt_outlined,
          ),
          _MetricCardData(
            'Total Orders',
            stats.totalOrders.toString(),
            Icons.shopping_cart_outlined,
          ),
          _MetricCardData(
            'Pending Orders',
            stats.pendingOrders.toString(),
            Icons.pending_actions_outlined,
          ),
          _MetricCardData(
            'Confirmed Orders',
            stats.confirmedOrders.toString(),
            Icons.checklist_rounded,
          ),
          _MetricCardData(
            'Delivered Orders',
            stats.deliveredOrders.toString(),
            Icons.local_shipping_outlined,
          ),
          _MetricCardData(
            'Cancelled Orders',
            stats.cancelledOrders.toString(),
            Icons.cancel_outlined,
          ),
          _MetricCardData(
            'New Arrivals',
            stats.newArrivals.toString(),
            Icons.new_releases_outlined,
          ),
          _MetricCardData(
            'Fast Moving',
            stats.fastMoving.toString(),
            Icons.flash_on_rounded,
          ),
          _MetricCardData(
            'Featured',
            stats.featured.toString(),
            Icons.star_border_rounded,
          ),
        ];

        return SingleChildScrollView(
          padding: const EdgeInsets.all(AppSpacing.lg),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: <Widget>[
              _SectionHeader(
                title: 'Padma Collections Overview',
                subtitle:
                    'Live performance from the product, customer and order data.',
              ),
              const SizedBox(height: AppSpacing.lg),
              GridView.builder(
                shrinkWrap: true,
                physics: const NeverScrollableScrollPhysics(),
                itemCount: cards.length,
                gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
                  crossAxisCount: AppBreakpoints.adminStatColumns(context),
                  crossAxisSpacing: AppSpacing.md,
                  mainAxisSpacing: AppSpacing.md,
                  mainAxisExtent: 192,
                ),
                itemBuilder: (BuildContext context, int index) {
                  final _MetricCardData card = cards[index];
                  return _MetricCard(
                    title: card.title,
                    value: card.value,
                    icon: card.icon,
                  );
                },
              ),
            ],
          ),
        );
      },
    );
  }
}

class _MetricCardData {
  const _MetricCardData(this.title, this.value, this.icon);

  final String title;
  final String value;
  final IconData icon;
}

class _MetricCard extends StatelessWidget {
  const _MetricCard({
    required this.title,
    required this.value,
    required this.icon,
  });

  final String title;
  final String value;
  final IconData icon;

  @override
  Widget build(BuildContext context) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(AppSpacing.lg),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: <Widget>[
            Row(
              children: <Widget>[
                Container(
                  width: 36,
                  height: 36,
                  decoration: BoxDecoration(
                    color: AppColors.burgundySoft,
                    borderRadius: BorderRadius.circular(10),
                  ),
                  child: Icon(icon, color: AppColors.burgundy),
                ),
                const Spacer(),
              ],
            ),
            const SizedBox(height: AppSpacing.md),
            Text(
              title,
              style: Theme.of(
                context,
              ).textTheme.labelLarge?.copyWith(color: AppColors.textSecondary),
            ),
            const SizedBox(height: AppSpacing.sm),
            Text(
              value,
              style: Theme.of(context).textTheme.headlineSmall?.copyWith(
                fontWeight: FontWeight.w700,
                color: AppColors.textPrimary,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class AdminProductsView extends StatelessWidget {
  const AdminProductsView({super.key});

  @override
  Widget build(BuildContext context) {
    final ProductRepository repository = Get.find<ProductRepository>();

    return StreamBuilder<List<ProductModel>>(
      stream: repository.watchAllProducts(),
      builder:
          (BuildContext context, AsyncSnapshot<List<ProductModel>> snapshot) {
            if (snapshot.hasError) {
              return _AdminListPage(
                title: 'Products',
                subtitle: 'Could not load products from Firebase.',
                body: Center(child: Text('${snapshot.error}')),
              );
            }
            if (!snapshot.hasData) {
              return const Center(child: CircularProgressIndicator());
            }
            final List<ProductModel> products = snapshot.data!;

            return _AdminListPage(
              title: 'Products',
              subtitle: 'Manage inventory, pricing, visibility and highlights.',
              trailing: OutlinedButton.icon(
                onPressed: () => Get.toNamed(Routes.adminProductForm),
                icon: const Icon(Icons.add_rounded),
                label: const Text('Add Product'),
              ),
              body: SingleChildScrollView(
                padding: const EdgeInsets.all(AppSpacing.lg),
                scrollDirection: Axis.horizontal,
                child: ConstrainedBox(
                  constraints: const BoxConstraints(minWidth: 800),
                  child: DataTable(
                    columns: const <DataColumn>[
                      DataColumn(label: Text('Product')),
                      DataColumn(label: Text('Category')),
                      DataColumn(label: Text('Price')),
                      DataColumn(label: Text('Stock')),
                      DataColumn(label: Text('Status')),
                      DataColumn(label: Text('Tags')),
                      DataColumn(label: Text('Actions')),
                    ],
                    rows: products.map((ProductModel product) {
                      return DataRow(
                        cells: <DataCell>[
                          DataCell(
                            Row(
                              children: <Widget>[
                                if (product.primaryImageRef != null)
                                  ClipRRect(
                                    borderRadius: BorderRadius.circular(8),
                                    child: AppNetworkImage.cloudinary(
                                      product.primaryImageRef!,
                                      CloudinaryTransform.thumbnail,
                                      width: 42,
                                      height: 42,
                                    ),
                                  )
                                else
                                  Container(
                                    width: 42,
                                    height: 42,
                                    decoration: BoxDecoration(
                                      borderRadius: BorderRadius.circular(8),
                                      color: AppColors.burgundySoft,
                                    ),
                                    child: const Icon(
                                      Icons.image_not_supported_outlined,
                                      size: 20,
                                    ),
                                  ),
                                const SizedBox(width: AppSpacing.sm),
                                SizedBox(width: 180, child: Text(product.name)),
                              ],
                            ),
                          ),
                          DataCell(
                            Text(
                              product.categoryName.isEmpty
                                  ? 'General'
                                  : product.categoryName,
                            ),
                          ),
                          DataCell(
                            Text('₹${product.price.toStringAsFixed(0)}'),
                          ),
                          DataCell(Text(product.stock.toString())),
                          DataCell(
                            Text(product.isActive ? 'Active' : 'Inactive'),
                          ),
                          DataCell(
                            Text(
                              <String>[
                                if (product.isFeatured) 'Featured',
                                if (product.isNewArrival) 'New',
                                if (product.isFastMoving) 'Fast',
                              ].join(', '),
                            ),
                          ),
                          DataCell(
                            Row(
                              children: <Widget>[
                                IconButton(
                                  tooltip: 'Edit',
                                  icon: const Icon(Icons.edit_outlined),
                                  onPressed: () => Get.toNamed(
                                    Routes.adminProductForm,
                                    arguments: product,
                                  ),
                                ),
                                IconButton(
                                  tooltip: 'Deactivate',
                                  icon: const Icon(
                                    Icons.delete_outline_rounded,
                                  ),
                                  onPressed: () => _deleteProduct(product),
                                ),
                              ],
                            ),
                          ),
                        ],
                      );
                    }).toList(),
                  ),
                ),
              ),
            );
          },
    );
  }

  Future<void> _deleteProduct(ProductModel product) async {
    final bool confirmed =
        await Get.dialog<bool>(
          AlertDialog(
            title: const Text('Deactivate product?'),
            content: Text('${product.name} will be hidden from the store.'),
            actions: <Widget>[
              TextButton(
                onPressed: () => Get.back(result: false),
                child: const Text('Cancel'),
              ),
              FilledButton.tonal(
                onPressed: () => Get.back(result: true),
                child: const Text('Delete'),
              ),
            ],
          ),
        ) ??
        false;

    if (!confirmed) return;

    final ProductRepository repository = Get.find<ProductRepository>();
    try {
      await repository.setActive(product.productId, false);
      Get.rawSnackbar(
        message: 'Product deactivated.',
        snackPosition: SnackPosition.BOTTOM,
      );
    } catch (error) {
      Get.rawSnackbar(
        message: 'Could not deactivate product: $error',
        snackPosition: SnackPosition.BOTTOM,
        backgroundColor: AppColors.danger,
      );
    }
  }
}

class AdminCategoriesView extends StatelessWidget {
  const AdminCategoriesView({super.key});

  @override
  Widget build(BuildContext context) {
    final CategoryRepository repository = Get.find<CategoryRepository>();

    return StreamBuilder<List<CategoryModel>>(
      stream: repository.watchAllCategories(),
      builder: (BuildContext context, AsyncSnapshot<List<CategoryModel>> snapshot) {
        if (snapshot.hasError) {
          return _AdminListPage(
            title: 'Categories',
            subtitle: 'Could not load categories from Firebase.',
            body: Center(child: Text('${snapshot.error}')),
          );
        }
        if (!snapshot.hasData) {
          return const Center(child: CircularProgressIndicator());
        }
        final List<CategoryModel> categories = snapshot.data!;

        return _AdminListPage(
          title: 'Categories',
          subtitle:
              'Maintain the jewellery catalogue structure and layout order.',
          trailing: OutlinedButton.icon(
            onPressed: () => Get.toNamed(Routes.adminCategoryForm),
            icon: const Icon(Icons.add_rounded),
            label: const Text('Add Category'),
          ),
          body: ListView.builder(
            padding: const EdgeInsets.all(AppSpacing.lg),
            itemCount: categories.length,
            itemBuilder: (BuildContext context, int index) {
              final CategoryModel category = categories[index];
              return Card(
                margin: const EdgeInsets.only(bottom: AppSpacing.md),
                child: ListTile(
                  leading: CircleAvatar(
                    backgroundColor: AppColors.burgundySoft,
                    child: Icon(
                      Icons.category_outlined,
                      color: AppColors.burgundy,
                    ),
                  ),
                  title: Text(category.name),
                  subtitle: Text(
                    'Sort order: ${category.sortOrder} • ${category.productCount} products',
                  ),
                  trailing: Wrap(
                    spacing: 8,
                    children: <Widget>[
                      IconButton(
                        tooltip: 'Edit',
                        icon: const Icon(Icons.edit_outlined),
                        onPressed: () => Get.toNamed(
                          Routes.adminCategoryForm,
                          arguments: category,
                        ),
                      ),
                      IconButton(
                        tooltip: category.isActive ? 'Deactivate' : 'Activate',
                        icon: Icon(
                          category.isActive
                              ? Icons.visibility_outlined
                              : Icons.visibility_off_outlined,
                        ),
                        onPressed: () => repository.setActive(
                          category.categoryId,
                          !category.isActive,
                        ),
                      ),
                    ],
                  ),
                ),
              );
            },
          ),
        );
      },
    );
  }
}

class AdminOrdersView extends StatelessWidget {
  const AdminOrdersView({super.key});

  @override
  Widget build(BuildContext context) {
    final OrderRepository repository = Get.find<OrderRepository>();

    return StreamBuilder<List<OrderModel>>(
      stream: repository.watchAllOrders(),
      builder: (BuildContext context, AsyncSnapshot<List<OrderModel>> snapshot) {
        if (snapshot.hasError) {
          return _AdminListPage(
            title: 'Orders',
            subtitle: 'Could not load orders from Firebase.',
            body: Center(child: Text('${snapshot.error}')),
          );
        }
        if (!snapshot.hasData) {
          return const Center(child: CircularProgressIndicator());
        }
        final List<OrderModel> orders = snapshot.data!;

        return _AdminListPage(
          title: 'Orders',
          subtitle:
              'Track order status, shipping updates and customer requests.',
          body: ListView.builder(
            padding: const EdgeInsets.all(AppSpacing.lg),
            itemCount: orders.length,
            itemBuilder: (BuildContext context, int index) {
              final OrderModel order = orders[index];
              return Card(
                margin: const EdgeInsets.only(bottom: AppSpacing.md),
                child: ListTile(
                  title: Text(
                    '#${order.orderNumber.isEmpty ? order.orderId : order.orderNumber}',
                  ),
                  subtitle: Text(
                    '${order.customerName} • ${order.items.length} items • ₹${order.total.toStringAsFixed(0)}',
                  ),
                  trailing: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    crossAxisAlignment: CrossAxisAlignment.end,
                    children: <Widget>[
                      Text(order.status),
                      Text(order.createdAt.toLocal().toString().split(' ')[0]),
                    ],
                  ),
                  onTap: () =>
                      Get.toNamed(Routes.adminOrderDetails, arguments: order),
                ),
              );
            },
          ),
        );
      },
    );
  }
}

class AdminCustomersView extends StatelessWidget {
  const AdminCustomersView({super.key});

  @override
  Widget build(BuildContext context) {
    final UserRepository repository = Get.find<UserRepository>();

    return StreamBuilder<List<UserModel>>(
      stream: repository.watchCustomers(),
      builder: (BuildContext context, AsyncSnapshot<List<UserModel>> snapshot) {
        if (snapshot.hasError) {
          return _AdminListPage(
            title: 'Customers',
            subtitle: 'Could not load customers from Firebase.',
            body: Center(child: Text('${snapshot.error}')),
          );
        }
        if (!snapshot.hasData) {
          return const Center(child: CircularProgressIndicator());
        }
        final List<UserModel> customers = snapshot.data!;

        return _AdminListPage(
          title: 'Customers',
          subtitle:
              'View customer activity without exposing passwords or security data.',
          body: ListView.builder(
            padding: const EdgeInsets.all(AppSpacing.lg),
            itemCount: customers.length,
            itemBuilder: (BuildContext context, int index) {
              final UserModel customer = customers[index];
              return Card(
                margin: const EdgeInsets.only(bottom: AppSpacing.md),
                child: ListTile(
                  leading: CircleAvatar(
                    backgroundColor: AppColors.goldSoft,
                    child: Text(
                      customer.firstName.isNotEmpty
                          ? customer.firstName[0].toUpperCase()
                          : 'C',
                    ),
                  ),
                  title: Text(customer.name),
                  subtitle: Text(
                    '${customer.email} • ${customer.phone.isNotEmpty ? customer.phone : 'No phone'}',
                  ),
                  trailing: Switch(
                    value: customer.isActive,
                    onChanged: (bool active) =>
                        repository.setActive(customer.uid, active),
                  ),
                  onTap: () => Get.toNamed(
                    Routes.adminCustomerDetail,
                    arguments: customer,
                  ),
                ),
              );
            },
          ),
        );
      },
    );
  }
}

class _AdminListPage extends StatelessWidget {
  const _AdminListPage({
    required this.title,
    required this.subtitle,
    this.trailing,
    required this.body,
  });

  final String title;
  final String subtitle;
  final Widget? trailing;
  final Widget body;

  @override
  Widget build(BuildContext context) {
    return Column(
      children: <Widget>[
        Container(
          width: double.infinity,
          padding: const EdgeInsets.fromLTRB(
            AppSpacing.lg,
            AppSpacing.lg,
            AppSpacing.lg,
            AppSpacing.md,
          ),
          color: AppColors.adminSurface,
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.center,
            children: <Widget>[
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: <Widget>[
                    Text(
                      title,
                      style: Theme.of(context).textTheme.titleLarge?.copyWith(
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                    const SizedBox(height: AppSpacing.xs),
                    Text(
                      subtitle,
                      style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                        color: AppColors.textSecondary,
                      ),
                    ),
                  ],
                ),
              ),
              if (trailing != null) trailing!,
            ],
          ),
        ),
        Expanded(child: body),
      ],
    );
  }
}

class _SectionHeader extends StatelessWidget {
  const _SectionHeader({required this.title, required this.subtitle});

  final String title;
  final String subtitle;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: <Widget>[
        Text(
          title,
          style: Theme.of(
            context,
          ).textTheme.headlineSmall?.copyWith(fontWeight: FontWeight.w700),
        ),
        const SizedBox(height: AppSpacing.xs),
        Text(
          subtitle,
          style: Theme.of(
            context,
          ).textTheme.bodyMedium?.copyWith(color: AppColors.textSecondary),
        ),
      ],
    );
  }
}
