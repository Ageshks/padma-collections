import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:image_picker/image_picker.dart';

import '../../core/constants/app_colors.dart';
import '../../core/constants/app_constants.dart';
import '../../core/constants/app_sizes.dart';
import '../../core/constants/cloudinary_config.dart';
import '../../core/services/cloudinary_image_service.dart';
import '../../core/utils/validators.dart';
import '../../data/models/models.dart';
import '../../data/repositories/settings_repository.dart';
import '../common/controllers/app_controller.dart';

class AdminWhatsAppSettingsView extends StatefulWidget {
  const AdminWhatsAppSettingsView({super.key});

  @override
  State<AdminWhatsAppSettingsView> createState() =>
      _AdminWhatsAppSettingsViewState();
}

class _AdminWhatsAppSettingsViewState extends State<AdminWhatsAppSettingsView> {
  final GlobalKey<FormState> _formKey = GlobalKey<FormState>();
  final TextEditingController _phone = TextEditingController();
  final TextEditingController _business = TextEditingController();
  final TextEditingController _message = TextEditingController();
  final TextEditingController _orderTemplate = TextEditingController();
  bool _autoOpen = true;
  bool _loading = true;
  bool _saving = false;
  String? _loadError;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    try {
      final WhatsAppSettings settings = await Get.find<SettingsRepository>()
          .getWhatsAppSettings();
      if (!mounted) return;
      _phone.text = settings.phoneNumber;
      _business.text = settings.businessName;
      _message.text = settings.defaultMessage;
      _orderTemplate.text = settings.orderTemplate;
      setState(() {
        _autoOpen = settings.autoOpenOnCheckout;
        _loading = false;
      });
    } catch (error) {
      if (mounted)
        setState(() {
          _loadError = error.toString();
          _loading = false;
        });
    }
  }

  @override
  void dispose() {
    _phone.dispose();
    _business.dispose();
    _message.dispose();
    _orderTemplate.dispose();
    super.dispose();
  }

  Future<void> _save() async {
    if (_saving || !(_formKey.currentState?.validate() ?? false)) return;
    setState(() => _saving = true);
    try {
      final WhatsAppSettings settings = WhatsAppSettings(
        phoneNumber: _phone.text.trim(),
        businessName: _business.text.trim(),
        defaultMessage: _message.text.trim(),
        orderTemplate: _orderTemplate.text.trim(),
        autoOpenOnCheckout: _autoOpen,
        updatedAt: DateTime.now(),
      );
      await Get.find<SettingsRepository>().saveWhatsAppSettings(settings);
      Get.find<AppController>().whatsappSettings.value = settings;
      _settingsSaved();
    } catch (error) {
      _settingsError('Could not save WhatsApp settings: $error');
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    if (_loading) return const Center(child: CircularProgressIndicator());
    if (_loadError != null) {
      return _SettingsLoadError(message: _loadError!, onRetry: _load);
    }

    return _SettingsPage(
      title: 'WhatsApp Settings',
      description: 'Set the contact used for product enquiries and orders.',
      child: Form(
        key: _formKey,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: <Widget>[
            TextFormField(
              controller: _phone,
              keyboardType: TextInputType.phone,
              decoration: const InputDecoration(
                labelText: 'WhatsApp number',
                helperText: 'Include country code, for example 919812345678.',
              ),
              validator: AppValidators.whatsappNumber,
            ),
            const SizedBox(height: AppSpacing.md),
            TextFormField(
              controller: _business,
              decoration: const InputDecoration(labelText: 'Business name'),
              validator: (String? value) =>
                  AppValidators.name(value, field: 'Business name'),
            ),
            const SizedBox(height: AppSpacing.md),
            TextFormField(
              controller: _message,
              minLines: 2,
              maxLines: 5,
              decoration: const InputDecoration(
                labelText: 'Default enquiry message',
                alignLabelWithHint: true,
              ),
            ),
            const SizedBox(height: AppSpacing.md),
            TextFormField(
              controller: _orderTemplate,
              minLines: 3,
              maxLines: 7,
              decoration: const InputDecoration(
                labelText: 'Order message template (optional)',
                alignLabelWithHint: true,
                helperText: 'Leave blank to use the built-in order summary.',
              ),
            ),
            SwitchListTile(
              contentPadding: EdgeInsets.zero,
              title: const Text('Open WhatsApp after order submission'),
              value: _autoOpen,
              onChanged: (bool value) => setState(() => _autoOpen = value),
            ),
            const SizedBox(height: AppSpacing.md),
            _SaveButton(saving: _saving, onPressed: _save),
          ],
        ),
      ),
    );
  }
}

class AdminRateSettingsView extends StatefulWidget {
  const AdminRateSettingsView({super.key});

  @override
  State<AdminRateSettingsView> createState() => _AdminRateSettingsViewState();
}

class _AdminRateSettingsViewState extends State<AdminRateSettingsView> {
  final GlobalKey<FormState> _formKey = GlobalKey<FormState>();
  final List<TextEditingController> _controllers =
      List<TextEditingController>.generate(7, (_) => TextEditingController());
  bool _applyMaking = true;
  bool _applyDiscount = false;
  bool _applyTax = false;
  bool _applyShipping = true;
  bool _loading = true;
  bool _saving = false;
  String? _loadError;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    try {
      final RateSettings settings = await Get.find<SettingsRepository>()
          .getRateSettings();
      if (!mounted) return;
      final List<double> values = <double>[
        settings.baseRate,
        settings.makingChargePercent,
        settings.makingChargeFlat,
        settings.defaultDiscountPercent,
        settings.taxPercent,
        settings.shippingCharge,
        settings.freeShippingAbove,
      ];
      for (int i = 0; i < values.length; i++) {
        _controllers[i].text = values[i].toString();
      }
      setState(() {
        _applyMaking = settings.applyMakingCharge;
        _applyDiscount = settings.applyDiscount;
        _applyTax = settings.applyTax;
        _applyShipping = settings.applyShipping;
        _loading = false;
      });
    } catch (error) {
      if (mounted)
        setState(() {
          _loadError = error.toString();
          _loading = false;
        });
    }
  }

  @override
  void dispose() {
    for (final TextEditingController controller in _controllers) {
      controller.dispose();
    }
    super.dispose();
  }

  Future<void> _save() async {
    if (_saving || !(_formKey.currentState?.validate() ?? false)) return;
    setState(() => _saving = true);
    try {
      final List<double> value = _controllers
          .map((TextEditingController c) => double.parse(c.text.trim()))
          .toList();
      final RateSettings settings = RateSettings(
        baseRate: value[0],
        makingChargePercent: value[1],
        makingChargeFlat: value[2],
        defaultDiscountPercent: value[3],
        taxPercent: value[4],
        shippingCharge: value[5],
        freeShippingAbove: value[6],
        applyMakingCharge: _applyMaking,
        applyDiscount: _applyDiscount,
        applyTax: _applyTax,
        applyShipping: _applyShipping,
        updatedAt: DateTime.now(),
      );
      await Get.find<SettingsRepository>().saveRateSettings(settings);
      Get.find<AppController>().rateSettings.value = settings;
      _settingsSaved();
    } catch (error) {
      _settingsError('Could not save rate settings: $error');
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    if (_loading) return const Center(child: CircularProgressIndicator());
    if (_loadError != null) {
      return _SettingsLoadError(message: _loadError!, onRetry: _load);
    }

    return _SettingsPage(
      title: 'Rate Settings',
      description: 'Set the charges used when calculating customer totals.',
      child: Form(
        key: _formKey,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: <Widget>[
            _amountField(0, 'Base rate'),
            SwitchListTile(
              contentPadding: EdgeInsets.zero,
              title: const Text('Apply making charge'),
              value: _applyMaking,
              onChanged: (bool value) => setState(() => _applyMaking = value),
            ),
            _amountField(1, 'Making charge percent', percentage: true),
            _amountField(2, 'Flat making charge'),
            SwitchListTile(
              contentPadding: EdgeInsets.zero,
              title: const Text('Apply default discount'),
              value: _applyDiscount,
              onChanged: (bool value) => setState(() => _applyDiscount = value),
            ),
            _amountField(3, 'Default discount percent', percentage: true),
            SwitchListTile(
              contentPadding: EdgeInsets.zero,
              title: const Text('Apply tax'),
              value: _applyTax,
              onChanged: (bool value) => setState(() => _applyTax = value),
            ),
            _amountField(4, 'Tax percent', percentage: true),
            SwitchListTile(
              contentPadding: EdgeInsets.zero,
              title: const Text('Apply shipping'),
              value: _applyShipping,
              onChanged: (bool value) => setState(() => _applyShipping = value),
            ),
            _amountField(5, 'Shipping charge'),
            _amountField(6, 'Free shipping above'),
            const SizedBox(height: AppSpacing.md),
            _SaveButton(saving: _saving, onPressed: _save),
          ],
        ),
      ),
    );
  }

  Widget _amountField(int index, String label, {bool percentage = false}) {
    return Padding(
      padding: const EdgeInsets.only(bottom: AppSpacing.md),
      child: TextFormField(
        controller: _controllers[index],
        keyboardType: const TextInputType.numberWithOptions(decimal: true),
        decoration: InputDecoration(labelText: label),
        validator: percentage
            ? (String? value) => AppValidators.percentage(value, field: label)
            : (String? value) => AppValidators.price(value, field: label),
      ),
    );
  }
}

class AdminAppSettingsView extends StatefulWidget {
  const AdminAppSettingsView({super.key});

  @override
  State<AdminAppSettingsView> createState() => _AdminAppSettingsViewState();
}

class _AdminAppSettingsViewState extends State<AdminAppSettingsView> {
  final GlobalKey<FormState> _formKey = GlobalKey<FormState>();
  final ImagePicker _picker = ImagePicker();
  final Map<String, TextEditingController> _fields =
      <String, TextEditingController>{
        'storeName': TextEditingController(),
        'tagline': TextEditingController(),
        'cloudinaryCloudName': TextEditingController(),
        'cloudinaryUploadPreset': TextEditingController(),
        'phone': TextEditingController(),
        'email': TextEditingController(),
        'address': TextEditingController(),
        'instagramUrl': TextEditingController(),
        'facebookUrl': TextEditingController(),
        'websiteUrl': TextEditingController(),
        'aboutUs': TextEditingController(),
        'privacyPolicy': TextEditingController(),
        'termsAndConditions': TextEditingController(),
        'shippingInformation': TextEditingController(),
      };
  AppSettings _settings = const AppSettings();
  XFile? _logo;
  bool _loading = true;
  bool _saving = false;
  String? _loadError;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    try {
      final AppSettings settings = await Get.find<SettingsRepository>()
          .getAppSettings();
      if (!mounted) return;
      _settings = settings;
      _fields['storeName']!.text = settings.storeName;
      _fields['tagline']!.text = settings.tagline;
      _fields['cloudinaryCloudName']!.text = settings.cloudinaryCloudName;
      _fields['cloudinaryUploadPreset']!.text = settings.cloudinaryUploadPreset;
      _fields['phone']!.text = settings.phone;
      _fields['email']!.text = settings.email;
      _fields['address']!.text = settings.address;
      _fields['instagramUrl']!.text = settings.instagramUrl;
      _fields['facebookUrl']!.text = settings.facebookUrl;
      _fields['websiteUrl']!.text = settings.websiteUrl;
      _fields['aboutUs']!.text = settings.aboutUs;
      _fields['privacyPolicy']!.text = settings.privacyPolicy;
      _fields['termsAndConditions']!.text = settings.termsAndConditions;
      _fields['shippingInformation']!.text = settings.shippingInformation;
      setState(() => _loading = false);
    } catch (error) {
      if (mounted)
        setState(() {
          _loadError = error.toString();
          _loading = false;
        });
    }
  }

  @override
  void dispose() {
    for (final TextEditingController controller in _fields.values) {
      controller.dispose();
    }
    super.dispose();
  }

  Future<void> _pickLogo() async {
    try {
      final XFile? image = await _picker.pickImage(
        source: ImageSource.gallery,
        imageQuality: 90,
      );
      if (image != null && mounted) setState(() => _logo = image);
    } catch (error) {
      _settingsError('Could not open the photo picker: $error');
    }
  }

  Future<void> _save() async {
    if (_saving || !(_formKey.currentState?.validate() ?? false)) return;
    setState(() => _saving = true);
    try {
      AppSettings updated = _settings.copyWith(
        storeName: _fields['storeName']!.text.trim(),
        tagline: _fields['tagline']!.text.trim(),
        cloudinaryCloudName: _fields['cloudinaryCloudName']!.text.trim(),
        cloudinaryUploadPreset: _fields['cloudinaryUploadPreset']!.text.trim(),
        phone: _fields['phone']!.text.trim(),
        email: _fields['email']!.text.trim(),
        address: _fields['address']!.text.trim(),
        instagramUrl: _fields['instagramUrl']!.text.trim(),
        facebookUrl: _fields['facebookUrl']!.text.trim(),
        websiteUrl: _fields['websiteUrl']!.text.trim(),
        aboutUs: _fields['aboutUs']!.text.trim(),
        privacyPolicy: _fields['privacyPolicy']!.text.trim(),
        termsAndConditions: _fields['termsAndConditions']!.text.trim(),
        shippingInformation: _fields['shippingInformation']!.text.trim(),
        updatedAt: DateTime.now(),
      );
      await Get.find<SettingsRepository>().saveAppSettings(updated);
      if (_logo != null) {
        if (!Get.isRegistered<CloudinaryImageService>()) {
          throw StateError('Image service is not available.');
        }
        // Upload before saving, so the store is never left pointing at a logo
        // that failed to upload.
        //
        // The logo is stored under padma_collections/store/ and delivered
        // without a transformation, because it must keep its own aspect ratio
        // and cannot be cropped into a fixed box.
        final CloudinaryImage uploaded =
            await Get.find<CloudinaryImageService>().uploadImage(
              _logo!,
              type: CloudinaryImageService.typeStore,
            );
        updated = updated.copyWith(logoImage: uploaded);
        await Get.find<SettingsRepository>().saveAppSettings(updated);

        // The new logo is live; release the one it replaced.
        final CloudinaryImage? previous = _settings.logoImage;
        if (previous != null && !previous.isExternal) {
          await Get.find<CloudinaryImageService>().deleteImage(
            previous.publicId,
          );
        }
      }
      Get.find<AppController>().settings.value = updated;
      _settingsSaved();
    } catch (error) {
      _settingsError('Could not save store settings: $error');
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    if (_loading) return const Center(child: CircularProgressIndicator());
    if (_loadError != null) {
      return _SettingsLoadError(message: _loadError!, onRetry: _load);
    }

    return _SettingsPage(
      title: 'Store Settings',
      description:
          'Manage the branding, contact details, and customer policies shown in the shop.',
      child: Form(
        key: _formKey,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: <Widget>[
            _textField('storeName', 'Store name', required: true),
            _textField('tagline', 'Tagline'),
            _textField(
              'cloudinaryCloudName',
              'Cloudinary cloud name',
              helperText: 'From Cloudinary → Settings → API Keys',
            ),
            _textField(
              'cloudinaryUploadPreset',
              'Cloudinary upload preset',
              helperText: 'Unsigned preset name used for product uploads',
            ),
            _textField(
              'phone',
              'Phone number',
              keyboardType: TextInputType.phone,
            ),
            _textField(
              'email',
              'Email',
              keyboardType: TextInputType.emailAddress,
            ),
            _textField('address', 'Address', minLines: 2, maxLines: 4),
            _textField('instagramUrl', 'Instagram URL'),
            _textField('facebookUrl', 'Facebook URL'),
            _textField('websiteUrl', 'Website URL'),
            const SizedBox(height: AppSpacing.md),
            OutlinedButton.icon(
              onPressed: _pickLogo,
              icon: const Icon(Icons.add_photo_alternate_outlined),
              label: Text(_logo?.name ?? 'Upload store logo'),
            ),
            _textField('aboutUs', 'About us', minLines: 3, maxLines: 8),
            _textField(
              'shippingInformation',
              'Shipping information',
              minLines: 3,
              maxLines: 8,
            ),
            _textField(
              'privacyPolicy',
              'Privacy policy',
              minLines: 3,
              maxLines: 8,
            ),
            _textField(
              'termsAndConditions',
              'Terms and conditions',
              minLines: 3,
              maxLines: 8,
            ),
            const SizedBox(height: AppSpacing.md),
            _SaveButton(saving: _saving, onPressed: _save),
          ],
        ),
      ),
    );
  }

  Widget _textField(
    String key,
    String label, {
    bool required = false,
    TextInputType? keyboardType,
    String? helperText,
    int minLines = 1,
    int maxLines = 1,
  }) {
    return Padding(
      padding: const EdgeInsets.only(bottom: AppSpacing.md),
      child: TextFormField(
        controller: _fields[key],
        keyboardType: keyboardType,
        minLines: minLines,
        maxLines: maxLines,
        decoration: InputDecoration(
          labelText: label,
          alignLabelWithHint: maxLines > 1,
          helperText: helperText,
        ),
        validator: (String? value) {
          if (required) return AppValidators.name(value, field: label);
          if (key == 'email' && value != null && value.trim().isNotEmpty) {
            return AppValidators.email(value);
          }
          return null;
        },
      ),
    );
  }
}

class _SettingsPage extends StatelessWidget {
  const _SettingsPage({
    required this.title,
    required this.description,
    required this.child,
  });

  final String title;
  final String description;
  final Widget child;

  @override
  Widget build(BuildContext context) {
    return ListView(
      padding: const EdgeInsets.all(AppSpacing.lg),
      children: <Widget>[
        Text(title, style: Theme.of(context).textTheme.titleLarge),
        const SizedBox(height: AppSpacing.xs),
        Text(description),
        const SizedBox(height: AppSpacing.lg),
        Card(
          child: Padding(
            padding: const EdgeInsets.all(AppSpacing.lg),
            child: child,
          ),
        ),
      ],
    );
  }
}

class _SettingsLoadError extends StatelessWidget {
  const _SettingsLoadError({required this.message, required this.onRetry});

  final String message;
  final Future<void> Function() onRetry;

  @override
  Widget build(BuildContext context) => Center(
    child: Padding(
      padding: const EdgeInsets.all(AppSpacing.lg),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: <Widget>[
          Text(message, textAlign: TextAlign.center),
          const SizedBox(height: AppSpacing.md),
          OutlinedButton(onPressed: onRetry, child: const Text('Retry')),
        ],
      ),
    ),
  );
}

class _SaveButton extends StatelessWidget {
  const _SaveButton({required this.saving, required this.onPressed});

  final bool saving;
  final VoidCallback onPressed;

  @override
  Widget build(BuildContext context) => SizedBox(
    height: 50,
    child: FilledButton.icon(
      onPressed: saving ? null : onPressed,
      icon: saving
          ? const SizedBox.square(
              dimension: 18,
              child: CircularProgressIndicator(strokeWidth: 2),
            )
          : const Icon(Icons.save_outlined),
      label: const Text('Save settings'),
    ),
  );
}

void _settingsSaved() {
  Get.rawSnackbar(
    message: 'Settings saved.',
    snackPosition: SnackPosition.BOTTOM,
    backgroundColor: AppColors.success,
    margin: const EdgeInsets.all(AppSpacing.md),
    borderRadius: AppRadius.sm,
  );
}

void _settingsError(String message) {
  Get.rawSnackbar(
    message: message,
    snackPosition: SnackPosition.BOTTOM,
    backgroundColor: AppColors.danger,
    margin: const EdgeInsets.all(AppSpacing.md),
    borderRadius: AppRadius.sm,
  );
}
