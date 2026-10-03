import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:image_picker/image_picker.dart';

import '../../core/constants/app_colors.dart';
import '../../core/constants/app_constants.dart';
import '../../core/constants/app_sizes.dart';
import '../../core/constants/cloudinary_config.dart';
import '../../core/routes/app_routes.dart';
import '../../core/services/cloudinary_image_service.dart';
import '../../core/utils/app_formatter.dart';
import '../../core/utils/validators.dart';
import '../../core/widgets/app_network_image.dart';
import '../../data/models/models.dart';
import '../../data/repositories/banner_repository.dart';
import '../../data/repositories/notification_repository.dart';
import '../../data/repositories/order_repository.dart';
import '../../data/repositories/product_repository.dart';
import '../../data/repositories/user_repository.dart';
import '../common/controllers/app_controller.dart';

class AdminBannersView extends StatelessWidget {
  const AdminBannersView({super.key});

  @override
  Widget build(BuildContext context) {
    final BannerRepository banners = Get.find<BannerRepository>();
    return Scaffold(
      body: StreamBuilder<List<BannerModel>>(
        stream: banners.watchAllBanners(),
        builder: (BuildContext context, AsyncSnapshot<List<BannerModel>> snapshot) {
          if (snapshot.hasError) {
            return _LoadFailure(
              message: 'Could not load banners: ${snapshot.error}',
            );
          }
          if (!snapshot.hasData) {
            return const Center(child: CircularProgressIndicator());
          }
          final List<BannerModel> items = snapshot.data!;
          return Column(
            children: <Widget>[
              _PageHeader(
                title: 'Banners',
                subtitle: 'Manage home carousel images and destinations.',
                action: IconButton(
                  tooltip: 'Add banner',
                  onPressed: () => Get.toNamed(Routes.adminBannerForm),
                  icon: const Icon(Icons.add_rounded),
                ),
              ),
              Expanded(
                child: items.isEmpty
                    ? const _EmptyAdminList(
                        message:
                            'No banners yet. Add one to the home carousel.',
                      )
                    : ListView.separated(
                        padding: const EdgeInsets.all(AppSpacing.lg),
                        itemCount: items.length,
                        separatorBuilder: (_, _) =>
                            const SizedBox(height: AppSpacing.sm),
                        itemBuilder: (BuildContext context, int index) {
                          final BannerModel banner = items[index];
                          return Card(
                            child: ListTile(
                              leading: SizedBox(
                                width: 56,
                                height: 56,
                                child: !banner.hasImage
                                    ? const Icon(Icons.panorama_outlined)
                                    : AppNetworkImage.cloudinary(
                                        banner.image!,
                                        CloudinaryTransform.thumbnail,
                                      ),
                              ),
                              title: Text(banner.title),
                              subtitle: Text(
                                '${banner.action.name} • order ${banner.sortOrder}',
                              ),
                              trailing: Wrap(
                                spacing: 0,
                                children: <Widget>[
                                  IconButton(
                                    tooltip: 'Edit banner',
                                    onPressed: () => Get.toNamed(
                                      Routes.adminBannerForm,
                                      arguments: banner,
                                    ),
                                    icon: const Icon(Icons.edit_outlined),
                                  ),
                                  Switch(
                                    value: banner.isActive,
                                    onChanged: (bool active) => banners
                                        .setActive(banner.bannerId, active),
                                  ),
                                  IconButton(
                                    tooltip: 'Delete banner',
                                    onPressed: () => _delete(banners, banner),
                                    icon: const Icon(
                                      Icons.delete_outline_rounded,
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          );
                        },
                      ),
              ),
            ],
          );
        },
      ),
    );
  }

  Future<void> _delete(BannerRepository repository, BannerModel banner) async {
    final bool confirmed =
        await Get.dialog<bool>(
          AlertDialog(
            title: const Text('Delete banner?'),
            content: Text('Remove “${banner.title}” from the carousel?'),
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
    try {
      // Remove the document first, then release the Cloudinary image. If the
      // Firestore write fails the image is still referenced and still served;
      // the reverse order could leave a live banner pointing at nothing.
      await repository.delete(banner.bannerId);
      final CloudinaryImage? image = banner.image;
      if (image != null &&
          !image.isExternal &&
          Get.isRegistered<CloudinaryImageService>()) {
        await Get.find<CloudinaryImageService>().deleteImage(image.publicId);
      }
      _adminMessage('Banner deleted.');
    } catch (error) {
      _adminMessage('Could not delete banner: $error', error: true);
    }
  }
}

class AdminBannerFormView extends StatefulWidget {
  const AdminBannerFormView({super.key, this.banner});

  final BannerModel? banner;

  @override
  State<AdminBannerFormView> createState() => _AdminBannerFormViewState();
}

class _AdminBannerFormViewState extends State<AdminBannerFormView> {
  final GlobalKey<FormState> _formKey = GlobalKey<FormState>();
  final ImagePicker _picker = ImagePicker();
  late final TextEditingController _title;
  late final TextEditingController _subtitle;
  late final TextEditingController _buttonText;
  late final TextEditingController _actionValue;
  late final TextEditingController _sortOrder;
  late BannerAction _action;
  bool _active = true;
  bool _saving = false;
  XFile? _image;

  @override
  void initState() {
    super.initState();
    final BannerModel? banner = widget.banner;
    _title = TextEditingController(text: banner?.title ?? '');
    _subtitle = TextEditingController(text: banner?.subtitle ?? '');
    _buttonText = TextEditingController(text: banner?.buttonText ?? 'Shop Now');
    _actionValue = TextEditingController(text: banner?.actionValue ?? '');
    _sortOrder = TextEditingController(
      text: banner?.sortOrder.toString() ?? '0',
    );
    _action = banner?.action ?? BannerAction.openCategory;
    _active = banner?.isActive ?? true;
  }

  @override
  void dispose() {
    _title.dispose();
    _subtitle.dispose();
    _buttonText.dispose();
    _actionValue.dispose();
    _sortOrder.dispose();
    super.dispose();
  }

  Future<void> _pickImage() async {
    final XFile? image = await _picker.pickImage(
      source: ImageSource.gallery,
      imageQuality: 90,
    );
    if (image != null && mounted) setState(() => _image = image);
  }

  Future<void> _save() async {
    if (_saving || !(_formKey.currentState?.validate() ?? false)) return;
    setState(() => _saving = true);
    try {
      final BannerRepository repository = Get.find<BannerRepository>();
      final BannerModel old =
          widget.banner ??
          BannerModel(bannerId: '', title: '', createdAt: DateTime.now());
      BannerModel draft = old.copyWith(
        title: _title.text.trim(),
        subtitle: _subtitle.text.trim(),
        buttonText: _buttonText.text.trim(),
        action: _action,
        actionValue: _actionValue.text.trim(),
        sortOrder: int.parse(_sortOrder.text.trim()),
        isActive: _active,
      );
      final String id;
      if (widget.banner == null) {
        id = await repository.create(draft);
      } else {
        id = widget.banner!.bannerId;
        await repository.update(id, draft);
      }
      if (_image != null) {
        if (!Get.isRegistered<CloudinaryImageService>()) {
          throw StateError('Image service is not available.');
        }
        // Upload before the banner document references the new image.
        final CloudinaryImage uploaded =
            await Get.find<CloudinaryImageService>().uploadImage(
              _image!,
              type: CloudinaryImageService.typeBanners,
            );
        draft = draft.copyWith(image: uploaded);
        await repository.update(id, draft);

        // The replacement is stored, so release the previous artwork.
        final CloudinaryImage? previous = old.image;
        if (previous != null && !previous.isExternal) {
          await Get.find<CloudinaryImageService>().deleteImage(
            previous.publicId,
          );
        }
      }
      if (!mounted) return;
      Get.back<void>();
      _adminMessage('Banner saved.');
    } catch (error) {
      _adminMessage('Could not save banner: $error', error: true);
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  @override
  Widget build(BuildContext context) => Scaffold(
    appBar: AppBar(
      title: Text(widget.banner == null ? 'Add banner' : 'Edit banner'),
    ),
    body: Form(
      key: _formKey,
      child: ListView(
        padding: const EdgeInsets.all(AppSpacing.lg),
        children: <Widget>[
          TextFormField(
            controller: _title,
            decoration: const InputDecoration(labelText: 'Title'),
            validator: (String? value) =>
                AppValidators.name(value, field: 'Title'),
          ),
          const SizedBox(height: AppSpacing.md),
          TextFormField(
            controller: _subtitle,
            decoration: const InputDecoration(labelText: 'Subtitle'),
          ),
          const SizedBox(height: AppSpacing.md),
          OutlinedButton.icon(
            onPressed: _pickImage,
            icon: const Icon(Icons.add_photo_alternate_outlined),
            label: Text(_image?.name ?? 'Upload banner image'),
          ),
          const SizedBox(height: AppSpacing.md),
          TextFormField(
            controller: _buttonText,
            decoration: const InputDecoration(labelText: 'Button label'),
          ),
          const SizedBox(height: AppSpacing.md),
          DropdownButtonFormField<BannerAction>(
            initialValue: _action,
            decoration: const InputDecoration(labelText: 'Button action'),
            items: BannerAction.values
                .map(
                  (BannerAction action) => DropdownMenuItem<BannerAction>(
                    value: action,
                    child: Text(action.name),
                  ),
                )
                .toList(),
            onChanged: (BannerAction? value) {
              if (value != null) setState(() => _action = value);
            },
          ),
          const SizedBox(height: AppSpacing.md),
          TextFormField(
            controller: _actionValue,
            decoration: const InputDecoration(
              labelText: 'Action value (optional)',
            ),
          ),
          const SizedBox(height: AppSpacing.md),
          TextFormField(
            controller: _sortOrder,
            keyboardType: TextInputType.number,
            decoration: const InputDecoration(labelText: 'Display order'),
            validator: AppValidators.stock,
          ),
          SwitchListTile(
            contentPadding: EdgeInsets.zero,
            title: const Text('Active'),
            value: _active,
            onChanged: (bool value) => setState(() => _active = value),
          ),
          const SizedBox(height: AppSpacing.md),
          FilledButton.icon(
            onPressed: _saving ? null : _save,
            icon: const Icon(Icons.save_outlined),
            label: Text(_saving ? 'Saving…' : 'Save banner'),
          ),
        ],
      ),
    ),
  );
}

class AdminNewArrivalsView extends StatelessWidget {
  const AdminNewArrivalsView({super.key});

  @override
  Widget build(BuildContext context) => const _AdminProductFlagView(
    title: 'New Arrivals',
    subtitle: 'Choose products to feature as new arrivals.',
    isNewArrival: true,
  );
}

class AdminFastMovingView extends StatelessWidget {
  const AdminFastMovingView({super.key});

  @override
  Widget build(BuildContext context) => const _AdminProductFlagView(
    title: 'Fast Moving',
    subtitle: 'Choose products to feature in the fast-moving collection.',
    isNewArrival: false,
  );
}

class _AdminProductFlagView extends StatelessWidget {
  const _AdminProductFlagView({
    required this.title,
    required this.subtitle,
    required this.isNewArrival,
  });

  final String title;
  final String subtitle;
  final bool isNewArrival;

  @override
  Widget build(BuildContext context) {
    final ProductRepository products = Get.find<ProductRepository>();
    return StreamBuilder<List<ProductModel>>(
      stream: products.watchAllProducts(),
      builder:
          (BuildContext context, AsyncSnapshot<List<ProductModel>> snapshot) {
            if (snapshot.hasError)
              return _LoadFailure(message: '${snapshot.error}');
            if (!snapshot.hasData)
              return const Center(child: CircularProgressIndicator());
            final List<ProductModel> items = snapshot.data!;
            if (items.isEmpty)
              return _EmptyAdminList(
                message: 'Add products before managing $title.',
              );
            return Column(
              children: <Widget>[
                _PageHeader(title: title, subtitle: subtitle),
                Expanded(
                  child: ListView.builder(
                    itemCount: items.length,
                    itemBuilder: (BuildContext context, int index) {
                      final ProductModel product = items[index];
                      return SwitchListTile(
                        title: Text(product.name),
                        subtitle: Text(
                          'SKU ${product.sku} • stock ${product.stock}',
                        ),
                        value: isNewArrival
                            ? product.isNewArrival
                            : product.isFastMoving,
                        onChanged: (bool enabled) => isNewArrival
                            ? products.setNewArrival(product.productId, enabled)
                            : products.setFastMoving(
                                product.productId,
                                enabled,
                              ),
                      );
                    },
                  ),
                ),
              ],
            );
          },
    );
  }
}

class AdminNotificationsView extends StatelessWidget {
  const AdminNotificationsView({super.key});

  @override
  Widget build(BuildContext context) {
    final AppController app = Get.find<AppController>();
    final NotificationRepository notifications =
        Get.find<NotificationRepository>();
    return Scaffold(
      body: StreamBuilder<List<NotificationModel>>(
        stream: notifications.watchForUser(uid: app.uid, isAdmin: true),
        builder:
            (
              BuildContext context,
              AsyncSnapshot<List<NotificationModel>> snapshot,
            ) {
              if (snapshot.hasError)
                return _LoadFailure(
                  message: 'Could not load notifications: ${snapshot.error}',
                );
              if (!snapshot.hasData)
                return const Center(child: CircularProgressIndicator());
              final List<NotificationModel> items = snapshot.data!;
              return Column(
                children: <Widget>[
                  _PageHeader(
                    title: 'Notifications',
                    subtitle: 'Review updates and send announcements.',
                    action: IconButton(
                      tooltip: 'Send notification',
                      onPressed: _compose,
                      icon: const Icon(Icons.add_alert_outlined),
                    ),
                  ),
                  Expanded(
                    child: items.isEmpty
                        ? const _EmptyAdminList(
                            message: 'No notifications yet.',
                          )
                        : ListView.builder(
                            itemCount: items.length,
                            itemBuilder: (BuildContext context, int index) {
                              final NotificationModel item = items[index];
                              return ListTile(
                                leading: Icon(
                                  item.isRead
                                      ? Icons.notifications_none
                                      : Icons.notifications_active,
                                ),
                                title: Text(item.title),
                                subtitle: Text(
                                  item.message,
                                  maxLines: 2,
                                  overflow: TextOverflow.ellipsis,
                                ),
                                trailing: Text(
                                  AppFormatter.relative(item.createdAt),
                                ),
                                onTap: () =>
                                    notifications.markRead(item.notificationId),
                              );
                            },
                          ),
                  ),
                ],
              );
            },
      ),
    );
  }

  Future<void> _compose() async {
    final TextEditingController title = TextEditingController();
    final TextEditingController message = TextEditingController();
    final bool? send = await Get.dialog<bool>(
      AlertDialog(
        title: const Text('Send announcement'),
        content: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: <Widget>[
              TextField(
                controller: title,
                decoration: const InputDecoration(labelText: 'Title'),
              ),
              TextField(
                controller: message,
                minLines: 2,
                maxLines: 5,
                decoration: const InputDecoration(labelText: 'Message'),
              ),
            ],
          ),
        ),
        actions: <Widget>[
          TextButton(
            onPressed: () => Get.back(result: false),
            child: const Text('Cancel'),
          ),
          FilledButton(
            onPressed: () => Get.back(result: true),
            child: const Text('Send'),
          ),
        ],
      ),
    );
    if (send == true &&
        title.text.trim().isNotEmpty &&
        message.text.trim().isNotEmpty) {
      try {
        await Get.find<NotificationRepository>().send(
          title: title.text,
          message: message.text,
          audience: 'all',
        );
        _adminMessage('Notification sent.');
      } catch (error) {
        _adminMessage('Could not send notification: $error', error: true);
      }
    }
    title.dispose();
    message.dispose();
  }
}

class AdminOrderDetailsView extends StatefulWidget {
  const AdminOrderDetailsView({super.key, this.order});

  final OrderModel? order;

  @override
  State<AdminOrderDetailsView> createState() => _AdminOrderDetailsViewState();
}

class _AdminOrderDetailsViewState extends State<AdminOrderDetailsView> {
  late String _status;
  bool _saving = false;

  @override
  void initState() {
    super.initState();
    _status = widget.order?.status ?? OrderStatus.pending;
  }

  Future<void> _save() async {
    final OrderModel? order = widget.order;
    if (order == null || _saving) return;
    setState(() => _saving = true);
    try {
      await Get.find<OrderRepository>().updateStatus(order.orderId, _status);
      _adminMessage('Order status updated.');
    } catch (error) {
      _adminMessage('Could not update order: $error', error: true);
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final OrderModel? order = widget.order;
    if (order == null)
      return const _LoadFailure(
        message: 'Order not found. Return to Orders and select an order.',
      );
    return Scaffold(
      appBar: AppBar(title: Text('Order ${order.orderNumber}')),
      body: ListView(
        padding: const EdgeInsets.all(AppSpacing.lg),
        children: <Widget>[
          _DetailCard(
            title: 'Customer',
            lines: <String>[
              order.customerName,
              order.phone,
              order.address,
              if (order.customerNote.isNotEmpty) 'Note: ${order.customerNote}',
            ],
          ),
          const SizedBox(height: AppSpacing.md),
          _DetailCard(
            title: 'Items',
            lines: order.items
                .map(
                  (OrderItem item) =>
                      '${item.name} × ${item.quantity} — ${AppFormatter.currency(item.subtotal)}',
                )
                .toList(),
          ),
          const SizedBox(height: AppSpacing.md),
          _DetailCard(
            title: 'Total',
            lines: <String>[
              'Subtotal ${AppFormatter.currency(order.subtotal)}',
              'Shipping ${AppFormatter.currency(order.shippingCharge)}',
              'Total ${AppFormatter.currency(order.total)}',
            ],
          ),
          const SizedBox(height: AppSpacing.md),
          DropdownButtonFormField<String>(
            initialValue: _status,
            decoration: const InputDecoration(labelText: 'Order status'),
            items: OrderStatus.all
                .map(
                  (String status) => DropdownMenuItem<String>(
                    value: status,
                    child: Text(status),
                  ),
                )
                .toList(),
            onChanged: (String? value) {
              if (value != null) setState(() => _status = value);
            },
          ),
          const SizedBox(height: AppSpacing.md),
          FilledButton.icon(
            onPressed: _saving ? null : _save,
            icon: const Icon(Icons.save_outlined),
            label: const Text('Update status'),
          ),
        ],
      ),
    );
  }
}

class AdminCustomerDetailView extends StatelessWidget {
  const AdminCustomerDetailView({super.key, this.customer});

  final UserModel? customer;

  @override
  Widget build(BuildContext context) {
    final UserModel? user = customer;
    if (user == null)
      return const _LoadFailure(
        message:
            'Customer not found. Return to Customers and select a customer.',
      );
    final OrderRepository orders = Get.find<OrderRepository>();
    final UserRepository users = Get.find<UserRepository>();
    return Scaffold(
      appBar: AppBar(title: Text(user.name)),
      body: Column(
        children: <Widget>[
          ListTile(
            title: Text(user.email),
            subtitle: Text(user.phone.isEmpty ? 'No phone number' : user.phone),
            trailing: Switch(
              value: user.isActive,
              onChanged: (bool active) async {
                try {
                  await users.setActive(user.uid, active);
                  _adminMessage(
                    active ? 'Customer activated.' : 'Customer deactivated.',
                  );
                } catch (error) {
                  _adminMessage(
                    'Could not update customer: $error',
                    error: true,
                  );
                }
              },
            ),
          ),
          const Divider(),
          Expanded(
            child: StreamBuilder<List<OrderModel>>(
              stream: orders.watchUserOrders(user.uid),
              builder:
                  (
                    BuildContext context,
                    AsyncSnapshot<List<OrderModel>> snapshot,
                  ) {
                    if (snapshot.hasError)
                      return _LoadFailure(
                        message:
                            'Could not load customer orders: ${snapshot.error}',
                      );
                    if (!snapshot.hasData)
                      return const Center(child: CircularProgressIndicator());
                    final List<OrderModel> items = snapshot.data!;
                    if (items.isEmpty)
                      return const _EmptyAdminList(
                        message: 'This customer has no orders.',
                      );
                    return ListView.builder(
                      itemCount: items.length,
                      itemBuilder: (BuildContext context, int index) {
                        final OrderModel order = items[index];
                        return ListTile(
                          title: Text(order.orderNumber),
                          subtitle: Text(
                            '${order.status} • ${AppFormatter.date(order.createdAt)}',
                          ),
                          trailing: Text(AppFormatter.currency(order.total)),
                        );
                      },
                    );
                  },
            ),
          ),
        ],
      ),
    );
  }
}

class _PageHeader extends StatelessWidget {
  const _PageHeader({required this.title, required this.subtitle, this.action});

  final String title;
  final String subtitle;
  final Widget? action;

  @override
  Widget build(BuildContext context) => Container(
    width: double.infinity,
    padding: const EdgeInsets.fromLTRB(
      AppSpacing.lg,
      AppSpacing.lg,
      AppSpacing.lg,
      AppSpacing.md,
    ),
    color: AppColors.adminSurface,
    child: Row(
      children: <Widget>[
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: <Widget>[
              Text(title, style: Theme.of(context).textTheme.titleLarge),
              const SizedBox(height: AppSpacing.xs),
              Text(subtitle),
            ],
          ),
        ),
        if (action != null) action!,
      ],
    ),
  );
}

class _LoadFailure extends StatelessWidget {
  const _LoadFailure({required this.message});
  final String message;
  @override
  Widget build(BuildContext context) => Center(
    child: Padding(
      padding: const EdgeInsets.all(AppSpacing.lg),
      child: Text(message, textAlign: TextAlign.center),
    ),
  );
}

class _EmptyAdminList extends StatelessWidget {
  const _EmptyAdminList({required this.message});
  final String message;
  @override
  Widget build(BuildContext context) => Center(
    child: Padding(
      padding: const EdgeInsets.all(AppSpacing.xl),
      child: Text(message, textAlign: TextAlign.center),
    ),
  );
}

class _DetailCard extends StatelessWidget {
  const _DetailCard({required this.title, required this.lines});
  final String title;
  final List<String> lines;
  @override
  Widget build(BuildContext context) => Card(
    child: Padding(
      padding: const EdgeInsets.all(AppSpacing.lg),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          Text(title, style: Theme.of(context).textTheme.titleMedium),
          const SizedBox(height: AppSpacing.sm),
          for (final String line in lines)
            Padding(
              padding: const EdgeInsets.only(bottom: AppSpacing.xs),
              child: Text(line),
            ),
        ],
      ),
    ),
  );
}

void _adminMessage(String message, {bool error = false}) {
  Get.rawSnackbar(
    message: message,
    snackPosition: SnackPosition.BOTTOM,
    backgroundColor: error ? AppColors.danger : AppColors.darkBrown,
    margin: const EdgeInsets.all(AppSpacing.md),
    borderRadius: AppRadius.sm,
  );
}
