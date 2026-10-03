import 'package:flutter/material.dart';
import 'package:get/get.dart';

import '../../core/constants/app_colors.dart';
import '../../core/constants/app_sizes.dart';
import '../../core/theme/app_typography.dart';
import '../../core/utils/validators.dart';
import '../../core/widgets/brand_widgets.dart';
import '../../data/models/models.dart';
import '../common/controllers/app_controller.dart';

class EditProfileView extends StatefulWidget {
  const EditProfileView({super.key});

  @override
  State<EditProfileView> createState() => _EditProfileViewState();
}

class _EditProfileViewState extends State<EditProfileView> {
  final GlobalKey<FormState> _formKey = GlobalKey<FormState>();
  final TextEditingController _name = TextEditingController();
  final TextEditingController _phone = TextEditingController();
  bool _saving = false;

  @override
  void initState() {
    super.initState();
    final UserModel? user = Get.find<AppController>().currentUser.value;
    _name.text = user?.name ?? '';
    _phone.text = user?.phone ?? '';
  }

  @override
  void dispose() {
    _name.dispose();
    _phone.dispose();
    super.dispose();
  }

  Future<void> _save() async {
    if (_saving || !(_formKey.currentState?.validate() ?? false)) return;
    setState(() => _saving = true);
    try {
      await Get.find<AppController>().updateProfile(
        name: _name.text.trim(),
        phone: _phone.text.trim(),
      );
      Get.back<void>();
      Get.rawSnackbar(
        message: 'Profile updated.',
        snackPosition: SnackPosition.BOTTOM,
      );
    } catch (_) {
      Get.rawSnackbar(
        message: 'Profile could not be updated. Please try again.',
        snackPosition: SnackPosition.BOTTOM,
        backgroundColor: AppColors.danger,
      );
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(title: const Text('Edit profile')),
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(AppSpacing.gutter),
          child: AppBreakpoints.constrainContent(
            context,
            Form(
              key: _formKey,
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: <Widget>[
                  TextFormField(
                    controller: _name,
                    textCapitalization: TextCapitalization.words,
                    textInputAction: TextInputAction.next,
                    decoration: const InputDecoration(labelText: 'Full name'),
                    validator: AppValidators.name,
                  ),
                  const SizedBox(height: AppSpacing.md),
                  TextFormField(
                    controller: _phone,
                    keyboardType: TextInputType.phone,
                    textInputAction: TextInputAction.done,
                    decoration: const InputDecoration(
                      labelText: 'Phone number',
                    ),
                    validator: AppValidators.phone,
                  ),
                  const SizedBox(height: AppSpacing.xl),
                  SizedBox(
                    height: 52,
                    child: ElevatedButton(
                      onPressed: _saving ? null : _save,
                      child: _saving
                          ? const CircularProgressIndicator(color: Colors.white)
                          : const Text('Save changes'),
                    ),
                  ),
                ],
              ),
            ),
            maxWidth: 460,
          ),
        ),
      ),
    );
  }
}

enum StoreInfoPage { about, privacy, terms }

class StoreInfoView extends StatelessWidget {
  const StoreInfoView({super.key, required this.page});

  final StoreInfoPage page;

  @override
  Widget build(BuildContext context) {
    final AppSettings settings = Get.find<AppController>().settings.value;
    final (String title, String content) = switch (page) {
      StoreInfoPage.about => ('About us', settings.aboutUs),
      StoreInfoPage.privacy => ('Privacy policy', settings.privacyPolicy),
      StoreInfoPage.terms => (
        'Terms & Conditions',
        settings.termsAndConditions,
      ),
    };
    final String text = content.trim().isEmpty
        ? 'This information has not been configured yet.'
        : content.trim();

    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(title: Text(title)),
      body: SafeArea(
        child: ListView(
          padding: const EdgeInsets.all(AppSpacing.gutter),
          children: <Widget>[
            const Center(
              child: BrandLogo(height: 42, variant: BrandLogoVariant.wordmark),
            ),
            const SizedBox(height: AppSpacing.xl),
            Text(title, style: AppTypography.headlineMedium),
            const SizedBox(height: AppSpacing.md),
            Text(text, style: AppTypography.bodyLarge),
          ],
        ),
      ),
    );
  }
}
