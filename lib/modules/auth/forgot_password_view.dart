import 'package:flutter/material.dart';
import 'package:get/get.dart';

import '../../core/constants/app_colors.dart';
import '../../core/constants/app_sizes.dart';
import '../../core/utils/validators.dart';
import '../../core/widgets/brand_widgets.dart';
import 'auth_controller.dart';

class ForgotPasswordView extends StatelessWidget {
  const ForgotPasswordView({super.key});

  @override
  Widget build(BuildContext context) {
    final AuthController controller = Get.find<AuthController>();

    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(title: const Text('Reset password')),
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(AppSpacing.gutter),
          child: AppBreakpoints.constrainContent(
            context,
            Form(
              key: controller.resetFormKey,
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: <Widget>[
                  const Center(child: BrandLogo(height: 72)),
                  const SizedBox(height: AppSpacing.xl),
                  Text(
                    'Reset your password',
                    textAlign: TextAlign.center,
                    style: Theme.of(context).textTheme.headlineSmall,
                  ),
                  const SizedBox(height: AppSpacing.sm),
                  const Text(
                    'Enter the email address for your account and we will '
                    'send a password reset link.',
                    textAlign: TextAlign.center,
                  ),
                  const SizedBox(height: AppSpacing.xl),
                  TextFormField(
                    controller: controller.resetEmailController,
                    keyboardType: TextInputType.emailAddress,
                    textInputAction: TextInputAction.done,
                    autocorrect: false,
                    onFieldSubmitted: (_) => _submit(controller),
                    decoration: const InputDecoration(
                      labelText: 'Email',
                      prefixIcon: Icon(Icons.mail_outline_rounded),
                    ),
                    validator: AppValidators.email,
                  ),
                  const SizedBox(height: AppSpacing.lg),
                  Obx(
                    () => SizedBox(
                      height: 52,
                      child: ElevatedButton(
                        onPressed: controller.isSendingReset.value
                            ? null
                            : () => _submit(controller),
                        child: controller.isSendingReset.value
                            ? const SizedBox.square(
                                dimension: 20,
                                child: CircularProgressIndicator(
                                  strokeWidth: 2,
                                  color: Colors.white,
                                ),
                              )
                            : const Text('Send reset link'),
                      ),
                    ),
                  ),
                  const SizedBox(height: AppSpacing.md),
                  TextButton(
                    onPressed: Get.back,
                    child: const Text('Back to sign in'),
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
    await controller.sendPasswordReset();
  }
}
