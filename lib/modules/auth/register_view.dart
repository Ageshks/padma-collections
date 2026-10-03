import 'package:flutter/material.dart';
import 'package:get/get.dart';

import '../../core/constants/app_colors.dart';
import '../../core/constants/app_sizes.dart';
import '../../core/routes/app_routes.dart';
import '../../core/utils/validators.dart';
import '../../core/widgets/brand_widgets.dart';
import '../common/controllers/app_controller.dart';
import 'auth_controller.dart';

class RegisterView extends StatelessWidget {
  const RegisterView({super.key});

  @override
  Widget build(BuildContext context) {
    final AuthController controller = Get.find<AuthController>();

    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(title: const Text('Create account')),
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(AppSpacing.gutter),
          child: AppBreakpoints.constrainContent(
            context,
            Form(
              key: controller.registerFormKey,
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: <Widget>[
                  const Center(child: BrandLogo(height: 72)),
                  const SizedBox(height: AppSpacing.xl),
                  TextFormField(
                    controller: controller.nameController,
                    textCapitalization: TextCapitalization.words,
                    textInputAction: TextInputAction.next,
                    decoration: const InputDecoration(
                      labelText: 'Full name',
                      prefixIcon: Icon(Icons.person_outline_rounded),
                    ),
                    validator: AppValidators.name,
                  ),
                  const SizedBox(height: AppSpacing.md),
                  TextFormField(
                    controller: controller.registerEmailController,
                    keyboardType: TextInputType.emailAddress,
                    textInputAction: TextInputAction.next,
                    autocorrect: false,
                    decoration: const InputDecoration(
                      labelText: 'Email',
                      prefixIcon: Icon(Icons.mail_outline_rounded),
                    ),
                    validator: AppValidators.email,
                  ),
                  const SizedBox(height: AppSpacing.md),
                  TextFormField(
                    controller: controller.registerPhoneController,
                    keyboardType: TextInputType.phone,
                    textInputAction: TextInputAction.next,
                    decoration: const InputDecoration(
                      labelText: 'Phone number',
                      prefixIcon: Icon(Icons.phone_outlined),
                    ),
                    validator: AppValidators.phone,
                  ),
                  const SizedBox(height: AppSpacing.md),
                  Obx(
                    () => TextFormField(
                      controller: controller.registerPasswordController,
                      obscureText: controller.obscureRegisterPassword.value,
                      textInputAction: TextInputAction.next,
                      decoration: InputDecoration(
                        labelText: 'Password',
                        prefixIcon: const Icon(Icons.lock_outline_rounded),
                        suffixIcon: IconButton(
                          tooltip: controller.obscureRegisterPassword.value
                              ? 'Show password'
                              : 'Hide password',
                          onPressed: controller.toggleRegisterPassword,
                          icon: Icon(
                            controller.obscureRegisterPassword.value
                                ? Icons.visibility_outlined
                                : Icons.visibility_off_outlined,
                          ),
                        ),
                      ),
                      validator: AppValidators.strongPassword,
                    ),
                  ),
                  const SizedBox(height: AppSpacing.md),
                  Obx(
                    () => TextFormField(
                      controller: controller.confirmPasswordController,
                      obscureText: controller.obscureConfirmPassword.value,
                      textInputAction: TextInputAction.done,
                      onFieldSubmitted: (_) => _submit(controller),
                      decoration: InputDecoration(
                        labelText: 'Confirm password',
                        prefixIcon: const Icon(Icons.lock_outline_rounded),
                        suffixIcon: IconButton(
                          tooltip: controller.obscureConfirmPassword.value
                              ? 'Show password'
                              : 'Hide password',
                          onPressed: controller.toggleConfirmPassword,
                          icon: Icon(
                            controller.obscureConfirmPassword.value
                                ? Icons.visibility_outlined
                                : Icons.visibility_off_outlined,
                          ),
                        ),
                      ),
                      validator: (String? value) =>
                          AppValidators.confirmPassword(
                            value,
                            controller.registerPasswordController.text,
                          ),
                    ),
                  ),
                  const SizedBox(height: AppSpacing.sm),
                  Obx(
                    () => CheckboxListTile(
                      contentPadding: EdgeInsets.zero,
                      controlAffinity: ListTileControlAffinity.leading,
                      value: controller.acceptTerms.value,
                      onChanged: (bool? value) =>
                          controller.setAcceptTerms(value ?? false),
                      title: const Text('I accept the Terms & Conditions'),
                    ),
                  ),
                  const SizedBox(height: AppSpacing.md),
                  Obx(
                    () => SizedBox(
                      height: 52,
                      child: ElevatedButton(
                        onPressed: controller.isRegistering.value
                            ? null
                            : () => _submit(controller),
                        child: controller.isRegistering.value
                            ? const SizedBox.square(
                                dimension: 20,
                                child: CircularProgressIndicator(
                                  strokeWidth: 2,
                                  color: Colors.white,
                                ),
                              )
                            : const Text('Create account'),
                      ),
                    ),
                  ),
                  const SizedBox(height: AppSpacing.md),
                  TextButton(
                    onPressed: Get.back,
                    child: const Text('Already have an account? Sign in'),
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

  Future<void> _submit(AuthController controller) async {
    if (!await controller.register()) return;
    final AppController app = Get.find<AppController>();
    Get.offAllNamed(app.isAdmin ? Routes.adminShell : Routes.customerShell);
  }
}
