import 'package:flutter/material.dart';
import 'package:get/get.dart';

import '../../core/constants/app_colors.dart';
import '../../core/constants/app_sizes.dart';
import '../../core/routes/app_routes.dart';
import '../../core/theme/app_typography.dart';
import '../../core/utils/validators.dart';
import '../../core/widgets/brand_widgets.dart';
import '../../core/widgets/google_sign_in_button.dart';
import '../common/controllers/app_controller.dart';
import 'auth_controller.dart';

/// Customer sign-in screen.
class LoginView extends StatelessWidget {
  const LoginView({super.key});

  @override
  Widget build(BuildContext context) {
    final AuthController controller = Get.find<AuthController>();
    final AppController app = Get.find<AppController>();

    return Scaffold(
      backgroundColor: AppColors.background,
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.symmetric(
            horizontal: AppSpacing.gutter,
            vertical: AppSpacing.xxl,
          ),
          child: AppBreakpoints.constrainContent(
            context,
            Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: <Widget>[
                const SizedBox(height: AppSpacing.xl),
                const Center(
                  child: BrandLogo(height: 120, variant: BrandLogoVariant.full),
                ),
                const SizedBox(height: AppSpacing.xxl),
                Text(
                  'Welcome back',
                  textAlign: TextAlign.center,
                  style: AppTypography.displayMedium,
                ),
                const SizedBox(height: AppSpacing.xs),
                Text(
                  'Sign in to continue shopping ${app.storeName}',
                  textAlign: TextAlign.center,
                  style: AppTypography.bodyMedium,
                ),
                const SizedBox(height: AppSpacing.xxxl),
                _LoginForm(controller: controller),
                const SizedBox(height: AppSpacing.xl),
                LayoutBuilder(
                  builder: (BuildContext context, BoxConstraints constraints) {
                    final Widget prompt = Text(
                      'New to us?',
                      style: AppTypography.bodyMedium,
                    );
                    final Widget action = TextButton(
                      onPressed: () => Get.toNamed(Routes.register),
                      child: const Text('Create an account'),
                    );

                    if (constraints.maxWidth < 360) {
                      return Column(children: <Widget>[prompt, action]);
                    }

                    return Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: <Widget>[prompt, action],
                    );
                  },
                ),
                const SizedBox(height: AppSpacing.xxl),
                Center(
                  child: TextButton.icon(
                    onPressed: () => Get.toNamed(Routes.adminLogin),
                    icon: const Icon(Icons.shield_outlined, size: 18),
                    label: const Text('Admin Sign In'),
                  ),
                ),
              ],
            ),
            maxWidth: 460,
          ),
        ),
      ),
    );
  }
}

class _LoginForm extends StatelessWidget {
  const _LoginForm({required this.controller});

  final AuthController controller;

  Future<void> _submit() async {
    final bool success = await controller.login();
    if (success) Get.offAllNamed(Routes.customerShell);
  }

  @override
  Widget build(BuildContext context) {
    return Form(
      key: controller.formKey,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: <Widget>[
          TextFormField(
            controller: controller.emailController,
            keyboardType: TextInputType.emailAddress,
            textInputAction: TextInputAction.next,
            autocorrect: false,
            decoration: const InputDecoration(
              labelText: 'Email',
              hintText: 'you@example.com',
              prefixIcon: Icon(Icons.mail_outline_rounded),
            ),
            validator: AppValidators.email,
          ),
          const SizedBox(height: AppSpacing.lg),
          // Wrapped in Obx so the eye toggle repaints. Read outside a reactive
          // scope, tapping it flipped the flag but nothing rebuilt, leaving a
          // button that looked live and did nothing.
          Obx(
            () => TextFormField(
              controller: controller.passwordController,
              obscureText: controller.obscureLoginPassword.value,
              textInputAction: TextInputAction.done,
              onFieldSubmitted: (_) => _submit(),
              decoration: InputDecoration(
                labelText: 'Password',
                prefixIcon: const Icon(Icons.lock_outline_rounded),
                suffixIcon: IconButton(
                  tooltip: controller.obscureLoginPassword.value
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
          Align(
            alignment: Alignment.centerRight,
            child: TextButton(
              onPressed: () => Get.toNamed(Routes.forgotPassword),
              child: const Text('Forgot Password?'),
            ),
          ),
          const SizedBox(height: AppSpacing.md),
          Obx(
            () => SizedBox(
              height: 54,
              child: ElevatedButton(
                onPressed: controller.isLoggingIn.value
                    ? null
                    : () => _submit(),
                child: controller.isLoggingIn.value
                    ? const SizedBox(
                        width: 22,
                        height: 22,
                        child: CircularProgressIndicator(
                          strokeWidth: 2,
                          color: Colors.white,
                        ),
                      )
                    : const Text('Sign In'),
              ),
            ),
          ),

          // Google sign-in, shown only when it is actually usable.
          //
          // The whole block is inside one Obx: the plugin initialises
          // asynchronously during start-up, so on the first frame the button is
          // not yet available. Reading availability outside a reactive scope
          // left the button permanently hidden once init later succeeded.
          Obx(
            () => controller.isGoogleSignInAvailable.value
                ? Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: <Widget>[
                      const SizedBox(height: AppSpacing.xl),
                      const _OrDivider(),
                      const SizedBox(height: AppSpacing.xl),
                      GoogleSignInButton(
                        isLoading: controller.isGoogleSignInLoading.value,
                        onPressed: () => _submitWithGoogle(),
                      ),
                    ],
                  )
                : const SizedBox.shrink(),
          ),
        ],
      ),
    );
  }

  /// Signs in with Google, then routes to whichever app the role belongs to.
  Future<void> _submitWithGoogle() async {
    final bool success = await controller.loginWithGoogle();
    if (!success) return;

    final AppController app = Get.find<AppController>();
    Get.offAllNamed(app.isAdmin ? Routes.adminShell : Routes.customerShell);
  }
}

/// "or" separator between the email form and Google sign-in.
class _OrDivider extends StatelessWidget {
  const _OrDivider();

  @override
  Widget build(BuildContext context) {
    return Row(
      children: <Widget>[
        const Expanded(child: Divider(color: AppColors.divider)),
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: AppSpacing.md),
          child: Text(
            'or',
            style: AppTypography.bodySmall.copyWith(color: AppColors.textHint),
          ),
        ),
        const Expanded(child: Divider(color: AppColors.divider)),
      ],
    );
  }
}
