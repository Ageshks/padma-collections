import 'package:flutter/foundation.dart';
import 'package:get/get.dart';
import 'package:google_sign_in/google_sign_in.dart';

import '../utils/error_handler.dart';

/// The result of a successful Google Sign-In.
///
/// Deliberately a plain Dart object so the rest of the app never depends on
/// the `google_sign_in` package.
class GoogleAuthResult {
  const GoogleAuthResult({
    required this.idToken,
    this.email = '',
    this.displayName = '',
    this.photoUrl = '',
  });

  /// The OIDC ID token exchanged with Firebase Authentication.
  final String idToken;

  final String email;
  final String displayName;
  final String photoUrl;

  /// First name, used to pre-fill the profile on registration.
  String get firstName => displayName.trim().split(RegExp(r'\s+')).first;
}

/// Thin abstraction over the Google account chooser.
///
/// [GoogleSignIn] cannot be subclassed (it has a private constructor), so the
/// service depends on this interface instead. That keeps the plugin at the edge
/// of the app and makes the flow straightforward to test.
abstract class GoogleAuthClient {
  /// Prepares the platform plugin. [serverClientId] is the OAuth web client id.
  Future<void> initialize({String? serverClientId});

  /// Whether this platform can present the account chooser at all.
  bool get supportsAuthenticate;

  /// Runs the interactive chooser and returns the signed-in account.
  Future<GoogleAuthResult> authenticate();

  /// Attempts a silent sign-in; null when there is no saved account.
  Future<GoogleAuthResult?> attemptLightweightAuthentication();

  /// Signs out. Must not throw — logout must always succeed.
  Future<void> signOut();
}

/// Real implementation backed by `google_sign_in` v7.
class GoogleSignInClient implements GoogleAuthClient {
  GoogleSignInClient({GoogleSignIn? signIn})
    : _signIn = signIn ?? GoogleSignIn.instance;

  final GoogleSignIn _signIn;

  @override
  Future<void> initialize({String? serverClientId}) =>
      _signIn.initialize(serverClientId: serverClientId);

  @override
  bool get supportsAuthenticate => _signIn.supportsAuthenticate();

  @override
  Future<GoogleAuthResult> authenticate() async {
    final GoogleSignInAccount account = await _signIn.authenticate();
    return _toResult(account);
  }

  @override
  Future<GoogleAuthResult?> attemptLightweightAuthentication() async {
    final GoogleSignInAccount? account = await _signIn
        .attemptLightweightAuthentication();
    if (account == null) return null;
    return _toResult(account);
  }

  @override
  Future<void> signOut() => _signIn.signOut();

  GoogleAuthResult _toResult(GoogleSignInAccount account) {
    // In v7 the email is non-nullable, but the id token, display name and
    // photo are optional — hence the guards on each.
    return GoogleAuthResult(
      idToken: account.authentication.idToken ?? '',
      email: account.email,
      displayName: account.displayName ?? '',
      photoUrl: account.photoUrl ?? '',
    );
  }
}

/// Drives Google Sign-In for the app.
///
/// Responsibilities:
///  * initialise the client once, with the Web client id that
///    `flutterfire configure` writes into `firebase_options.dart`;
///  * surface failures as the app's friendly [AppException]s;
///  * report whether Google Sign-In is usable, so the UI hides the button
///    rather than letting a customer tap into a dead end.
class GoogleSignInService {
  GoogleSignInService({GoogleAuthClient? client})
    : _client = client ?? GoogleSignInClient();

  final GoogleAuthClient _client;

  /// Set when initialisation genuinely fails (usually a misconfiguration).
  String? _unavailableReason;

  /// The Web OAuth client id, used on Android as the `serverClientId`.
  ///
  /// Supplied by the app so this class stays free of Firebase imports.
  static String? webClientId;

  /// Whether the client has finished initialising, as observable state.
  ///
  /// [initialize] is fired off the critical path during app start-up, so it
  /// finishes *after* the first frame. A plain `bool` would leave the sign-in
  /// button reading `false` forever, because nothing would trigger a rebuild
  /// once init completed. This is what the login screen observes.
  final RxBool isReady = false.obs;

  /// Initialises the client once per app launch. Safe to call repeatedly.
  Future<void> initialize() async {
    if (isReady.value) return;
    try {
      await _client.initialize(serverClientId: webClientId);
      isReady.value = true;
      _unavailableReason = null;
    } catch (e) {
      _unavailableReason = 'Google Sign-In is not set up for this build yet.';
      if (kDebugMode) debugPrint('Google Sign-In init failed: $e');
    }
  }

  /// Whether the current platform can present the Google account chooser.
  bool get isSupported {
    if (!isReady.value) return false;
    try {
      return _client.supportsAuthenticate;
    } catch (_) {
      return false;
    }
  }

  /// Why Google Sign-In is unavailable, when it is.
  String? get unavailableReason => _unavailableReason;

  /// True when an account is already signed in on this device, so returning
  /// customers are not made to pick an account again.
  Future<bool> get hasPreviousSignIn async {
    await initialize();
    if (!isSupported) return false;
    try {
      final GoogleAuthResult? result = await _client
          .attemptLightweightAuthentication();
      return result != null && result.idToken.isNotEmpty;
    } catch (_) {
      return false;
    }
  }

  /// Runs the interactive account-chooser flow and returns the ID token.
  ///
  /// Throws an [AppException] with user-friendly copy on every failure path.
  Future<GoogleAuthResult> signIn() async {
    await initialize();

    if (_unavailableReason != null) {
      throw AppException(_unavailableReason!, code: 'google-unavailable');
    }
    if (!isSupported) {
      throw const AppException(
        'Google Sign-In is not supported on this device. Please use your '
        'email and password instead.',
        code: 'google-unsupported',
      );
    }

    final GoogleAuthResult result;
    try {
      result = await _client.authenticate();
    } on GoogleSignInException catch (e) {
      throw mapGoogleException(e);
    } on AppException {
      rethrow;
    } catch (e) {
      throw AppErrorHandler.wrap(e);
    }

    // A missing id token means Firebase cannot verify the credential.
    if (result.idToken.isEmpty) {
      throw const AppException(
        'We could not complete Google Sign-In. Please try again.',
        code: 'google-no-token',
      );
    }
    return result;
  }

  /// Signs out of Google. Never throws — logout must always succeed.
  Future<void> signOut() async {
    try {
      await _client.signOut();
    } catch (e) {
      if (kDebugMode) debugPrint('Google sign-out failed: $e');
    }
  }

  /// Translates plugin exceptions into plain language for the customer.
  ///
  /// Static so the mapping can be unit tested without a device.
  static AppException mapGoogleException(GoogleSignInException e) {
    switch (e.code) {
      case GoogleSignInExceptionCode.canceled:
        return const AppException('Sign-in was cancelled.', code: 'canceled');
      case GoogleSignInExceptionCode.interrupted:
        return const AppException(
          'Sign-in was interrupted. Please try again.',
          code: 'interrupted',
        );
      case GoogleSignInExceptionCode.clientConfigurationError:
      case GoogleSignInExceptionCode.providerConfigurationError:
        return const AppException(
          'Google Sign-In is not configured for this app yet. Please use '
          'your email and password instead.',
          code: 'google-misconfigured',
        );
      case GoogleSignInExceptionCode.uiUnavailable:
        return const AppException(
          'Google Sign-In is unavailable right now. Please use your email '
          'and password instead.',
          code: 'google-ui-unavailable',
        );
      case GoogleSignInExceptionCode.userMismatch:
        return const AppException(
          'The selected account is not available on this device.',
          code: 'google-user-mismatch',
        );
      default:
        return const AppException(
          'We could not sign you in with Google. Please try again or use '
          'your email and password.',
          code: 'google-unknown',
        );
    }
  }
}
