import 'package:flutter/material.dart';
import 'package:get/get.dart';

import '../../core/constants/app_colors.dart';
import '../../core/constants/app_sizes.dart';
import '../../core/routes/app_routes.dart';
import '../../core/theme/admin_theme.dart';
import '../../core/utils/validators.dart';
import '../../core/widgets/brand_widgets.dart';
import '../auth/auth_controller.dart';
import '../common/controllers/app_controller.dart';

class AdminLoginView extends StatelessWidget {
  const AdminLoginView({super.key});

  @override
  Widget build(BuildContext context) {
    final AuthController controller = Get.find<AuthController>();

    return Theme(
      data: AdminTheme.theme,
      child: Scaffold(
        backgroundColor: AppColors.adminBackground,
        body: SafeArea(
          child: Center(
            child: SingleChildScrollView(
              padding: const EdgeInsets.all(AppSpacing.xxl),
              child: ConstrainedBox(
                constraints: const BoxConstraints(maxWidth: 480),
                child: Card(
                  child: Padding(
                    padding: const EdgeInsets.all(AppSpacing.xxl),
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: <Widget>[
                        const Center(child: BrandLogo(height: 42)),
                        const SizedBox(height: AppSpacing.xl),
                        Text(
                          'Admin Sign In',
                          textAlign: TextAlign.center,
                          style: Theme.of(context).textTheme.headlineSmall
                              ?.copyWith(fontWeight: FontWeight.w700),
                        ),
                        const SizedBox(height: AppSpacing.xs),
                        Text(
                          'Manage products, stock, orders and store settings.',
                          textAlign: TextAlign.center,
                          style: Theme.of(context).textTheme.bodyMedium
                              ?.copyWith(color: AppColors.textSecondary),
                        ),
                        const SizedBox(height: AppSpacing.xxl),
                        Form(
                          key: controller.adminFormKey,
                          child: Column(
                            children: <Widget>[
                              TextFormField(
                                controller: controller.emailController,
                                keyboardType: TextInputType.emailAddress,
                                textInputAction: TextInputAction.next,
                                decoration: const InputDecoration(
                                  labelText: 'Email',
                                  hintText: 'admin@padmacollections.com',
                                  prefixIcon: Icon(Icons.email_outlined),
                                ),
                                validator: AppValidators.email,
                              ),
                              const SizedBox(height: AppSpacing.lg),
                              // Wrapped in Obx so the eye toggle repaints; read
                              // outside a reactive scope it flipped the flag
                              // with nothing rebuilding behind it.
                              Obx(
                                () => TextFormField(
                                  controller: controller.passwordController,
                                  obscureText:
                                      controller.obscureLoginPassword.value,
                                  textInputAction: TextInputAction.done,
                                  onFieldSubmitted: (_) => _submit(),
                                  decoration: InputDecoration(
                                    labelText: 'Password',
                                    prefixIcon: const Icon(
                                      Icons.lock_outline_rounded,
                                    ),
                                    suffixIcon: IconButton(
                                      tooltip:
                                          controller.obscureLoginPassword.value
                                          ? 'Show password'
                                          : 'Hide password',
                                      icon: Icon(
                                        controller.obscureLoginPassword.value
                                            ? Icons.visibility_outlined
                                            : Icons.visibility_off_outlined,
                                      ),
                                      onPressed: controller.toggleLoginPassword,
                                    ),
                                  ),
                                  validator: AppValidators.password,
                                ),
                              ),
                              const SizedBox(height: AppSpacing.xl),
                              Obx(
                                () => SizedBox(
                                  height: 52,
                                  child: ElevatedButton(
                                    onPressed: controller.isLoggingIn.value
                                        ? null
                                        : _submit,
                                    child: controller.isLoggingIn.value
                                        ? const SizedBox(
                                            width: 20,
                                            height: 20,
                                            child: CircularProgressIndicator(
                                              strokeWidth: 2,
                                              color: Colors.white,
                                            ),
                                          )
                                        : const Text('Sign In to Admin'),
                                  ),
                                ),
                              ),
                              const SizedBox(height: AppSpacing.md),
                            ],
                          ),
                        ),
                        const SizedBox(height: AppSpacing.lg),
                        TextButton(
                          onPressed: () => Get.offAllNamed(Routes.login),
                          child: const Text('Back to customer sign in'),
                        ),
                      ],
                    ),
                  ),
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }

  Future<void> _submit() async {
    final AuthController controller = Get.find<AuthController>();
    final AppController app = Get.find<AppController>();

    final bool success = await controller.login(asAdmin: true);
    if (!success) return;

    if (app.isAdmin) Get.offAllNamed(Routes.adminShell);
  }
}
