import 'package:flutter/material.dart';
import 'package:get/get.dart';

import '../../../core/utils/error_handler.dart';
import '../../../core/utils/validators.dart';
import '../../../data/repositories/auth_repository.dart';
import '../common/controllers/app_controller.dart';

/// Drives the login, registration and password-reset forms.
class AuthController extends GetxController {
  AuthController({AuthRepository? authRepository, AppController? appController})
    : _auth = authRepository ?? Get.find<AuthRepository>(),
      _app = appController ?? Get.find<AppController>();

  final AuthRepository _auth;
  final AppController _app;

  final GlobalKey<FormState> formKey = GlobalKey<FormState>();
  final GlobalKey<FormState> adminFormKey = GlobalKey<FormState>();
  final GlobalKey<FormState> registerFormKey = GlobalKey<FormState>();
  final GlobalKey<FormState> resetFormKey = GlobalKey<FormState>();

  // Login
  final TextEditingController emailController = TextEditingController();
  final TextEditingController passwordController = TextEditingController();
  final RxBool obscureLoginPassword = true.obs;
  final RxBool isLoggingIn = false.obs;

  // Register
  final TextEditingController nameController = TextEditingController();
  final TextEditingController registerEmailController = TextEditingController();
  final TextEditingController registerPhoneController = TextEditingController();
  final TextEditingController registerPasswordController =
      TextEditingController();
  final TextEditingController confirmPasswordController =
      TextEditingController();
  final RxBool obscureRegisterPassword = true.obs;
  final RxBool obscureConfirmPassword = true.obs;
  final RxBool isRegistering = false.obs;
  final RxBool acceptTerms = false.obs;

  // Reset
  final TextEditingController resetEmailController = TextEditingController();
  final RxBool isSendingReset = false.obs;

  // Google sign-in
  final RxBool isGoogleSignInLoading = false.obs;

  @override
  void onClose() {
    emailController.dispose();
    passwordController.dispose();
    nameController.dispose();
    registerEmailController.dispose();
    registerPhoneController.dispose();
    registerPasswordController.dispose();
    confirmPasswordController.dispose();
    resetEmailController.dispose();
    super.onClose();
  }

  void toggleLoginPassword() => obscureLoginPassword.toggle();
  void toggleRegisterPassword() => obscureRegisterPassword.toggle();
  void toggleConfirmPassword() => obscureConfirmPassword.toggle();

  void setAcceptTerms(bool value) => acceptTerms.value = value;

  /// Signs in. Returns true on success so the view can navigate.
  Future<bool> login({bool asAdmin = false}) async {
    final GlobalKey<FormState> key = asAdmin ? adminFormKey : formKey;
    if (!(key.currentState?.validate() ?? false)) return false;

    isLoggingIn.value = true;
    try {
      await _app.signIn(
        email: emailController.text.trim(),
        password: passwordController.text,
      );
      if (asAdmin && !_app.isAdmin) {
        await _app.signOut();
        throw const AppException(
          'You do not have permission to access the admin panel.',
          code: 'admin-access-denied',
        );
      }
      return true;
    } on AppException catch (e) {
      _showError(e.message);
      return false;
    } catch (e) {
      _showError(AppErrorHandler.wrap(e).message);
      return false;
    } finally {
      isLoggingIn.value = false;
    }
  }

  /// Signs in with Google. Returns true on success so the view can navigate.
  Future<bool> loginWithGoogle() async {
    if (isGoogleSignInLoading.value) return false;
    isGoogleSignInLoading.value = true;
    try {
      await _app.signInWithGoogle();
      return true;
    } on AppException catch (e) {
      _showError(e.message);
      return false;
    } catch (e) {
      _showError(AppErrorHandler.wrap(e).message);
      return false;
    } finally {
      isGoogleSignInLoading.value = false;
    }
  }

  /// Whether the Google button should be rendered.
  /// Whether the Google sign-in button should be offered.
  ///
  /// Read inside an `Obx` by the login screen, so that the button appears as
  /// soon as the plugin has initialised.
  RxBool get isGoogleSignInAvailable => _app.isGoogleSignInAvailable;

  /// Registers a new customer account.
  Future<bool> register() async {
    if (!(registerFormKey.currentState?.validate() ?? false)) {
      return false;
    }
    if (!acceptTerms.value) {
      _showError('Please accept the Terms & Conditions to continue.');
      return false;
    }

    isRegistering.value = true;
    try {
      await _app.register(
        name: nameController.text.trim(),
        email: registerEmailController.text.trim(),
        password: registerPasswordController.text,
        phone: registerPhoneController.text.trim(),
      );
      return true;
    } on AppException catch (e) {
      _showError(e.message);
      return false;
    } catch (e) {
      _showError(AppErrorHandler.wrap(e).message);
      return false;
    } finally {
      isRegistering.value = false;
    }
  }

  /// Sends a password reset email.
  Future<bool> sendPasswordReset() async {
    if (!(resetFormKey.currentState?.validate() ?? false)) return false;

    isSendingReset.value = true;
    try {
      await _auth.sendPasswordReset(resetEmailController.text.trim());
      Get.rawSnackbar(
        message: 'If that email is registered, a reset link is on its way.',
        snackPosition: SnackPosition.BOTTOM,
        margin: const EdgeInsets.all(12),
        borderRadius: 8,
        duration: const Duration(seconds: 4),
      );
      return true;
    } catch (e) {
      _showError(AppErrorHandler.wrap(e).message);
      return false;
    } finally {
      isSendingReset.value = false;
    }
  }

  void clearLoginForm() {
    emailController.clear();
    passwordController.clear();
  }

  void _showError(String message) {
    Get.rawSnackbar(
      message: message,
      snackPosition: SnackPosition.BOTTOM,
      backgroundColor: const Color(0xFFC0392B),
      margin: const EdgeInsets.all(12),
      borderRadius: 8,
      duration: const Duration(seconds: 4),
    );
  }
}

/// Shared validators re-exported so views import from one place.
typedef AuthValidators = AppValidators;
