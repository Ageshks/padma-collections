import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:get/get.dart';
import 'package:google_sign_in/google_sign_in.dart';
import 'package:padma/core/services/google_sign_in_service.dart';
import 'package:padma/core/utils/error_handler.dart';

/// Scriptable stand-in for the platform plugin, so these run headless.
class FakeGoogleAuthClient implements GoogleAuthClient {
  FakeGoogleAuthClient({
    this.supportsAuthenticateValue = true,
    this.authenticateResult,
    this.lightweightResult,
    this.throwOnAuthenticate,
    this.throwOnSignOut = false,
    this.throwOnInitialize = false,
  });

  bool supportsAuthenticateValue;
  GoogleAuthResult? authenticateResult;
  GoogleAuthResult? lightweightResult;
  GoogleSignInException? throwOnAuthenticate;
  bool throwOnSignOut;
  bool throwOnInitialize;

  int initializeCalls = 0;
  int signOutCalls = 0;
  String? lastServerClientId;

  @override
  Future<void> initialize({String? serverClientId}) async {
    initializeCalls++;
    lastServerClientId = serverClientId;
    if (throwOnInitialize) throw StateError('boom');
  }

  @override
  bool get supportsAuthenticate => supportsAuthenticateValue;

  @override
  Future<GoogleAuthResult> authenticate() async {
    if (throwOnAuthenticate != null) throw throwOnAuthenticate!;
    return authenticateResult ??
        const GoogleAuthResult(idToken: 'fake-id-token');
  }

  @override
  Future<GoogleAuthResult?> attemptLightweightAuthentication() async =>
      lightweightResult;

  @override
  Future<void> signOut() async {
    signOutCalls++;
    if (throwOnSignOut) throw StateError('sign-out failed');
  }
}

const GoogleAuthResult _success = GoogleAuthResult(
  idToken: 'fake-id-token',
  email: 'aarav@example.com',
  displayName: 'Aarav Mehta',
  photoUrl: 'https://example.com/a.png',
);
void main() {
  setUp(() => GoogleSignInService.webClientId = null);

  group('lifecycle', () {
    test('initialises only once across repeated calls', () async {
      final FakeGoogleAuthClient client = FakeGoogleAuthClient();
      final GoogleSignInService service = GoogleSignInService(client: client);

      await service.initialize();
      await service.initialize();

      expect(client.initializeCalls, 1);
      expect(service.unavailableReason, isNull);
    });

    test('forwards the web client id as serverClientId', () async {
      GoogleSignInService.webClientId = 'demo.apps.googleusercontent.com';
      final FakeGoogleAuthClient client = FakeGoogleAuthClient();

      await GoogleSignInService(client: client).initialize();

      expect(client.lastServerClientId, 'demo.apps.googleusercontent.com');
    });

    test('is unsupported until initialisation has run', () {
      final GoogleSignInService service = GoogleSignInService(
        client: FakeGoogleAuthClient(),
      );
      expect(service.isSupported, isFalse);
    });

    test('reports unavailable instead of throwing when init fails', () async {
      final GoogleSignInService service = GoogleSignInService(
        client: FakeGoogleAuthClient(throwOnInitialize: true),
      );

      await service.initialize();

      expect(service.unavailableReason, isNotNull);
      expect(service.isSupported, isFalse);
    });
  });

  group('signIn', () {
    test('returns the id token and profile on success', () async {
      final GoogleSignInService service = GoogleSignInService(
        client: FakeGoogleAuthClient(authenticateResult: _success),
      );

      final GoogleAuthResult result = await service.signIn();

      expect(result.idToken, 'fake-id-token');
      expect(result.email, 'aarav@example.com');
      expect(result.firstName, 'Aarav');
    });

    test('fails clearly when the platform cannot show the chooser', () async {
      final GoogleSignInService service = GoogleSignInService(
        client: FakeGoogleAuthClient(supportsAuthenticateValue: false),
      );

      await expectLater(
        service.signIn(),
        throwsA(
          isA<AppException>().having(
            (AppException e) => e.code,
            'code',
            'google-unsupported',
          ),
        ),
      );
    });

    test('fails when Google returns no id token', () async {
      final GoogleSignInService service = GoogleSignInService(
        client: FakeGoogleAuthClient(
          authenticateResult: const GoogleAuthResult(idToken: ''),
        ),
      );

      await expectLater(
        service.signIn(),
        throwsA(
          isA<AppException>().having(
            (AppException e) => e.code,
            'code',
            'google-no-token',
          ),
        ),
      );
    });

    test('never leaks a raw plugin exception to the caller', () async {
      final GoogleSignInService service = GoogleSignInService(
        client: FakeGoogleAuthClient(
          throwOnAuthenticate: GoogleSignInException(
            code: GoogleSignInExceptionCode.canceled,
          ),
        ),
      );

      await expectLater(
        service.signIn(),
        throwsA(
          isA<AppException>().having(
            (AppException e) => e.message,
            'message',
            'Sign-in was cancelled.',
          ),
        ),
      );
    });
  });
  group('signOut', () {
    test('signs out of Google', () async {
      final FakeGoogleAuthClient client = FakeGoogleAuthClient();
      await GoogleSignInService(client: client).signOut();
      expect(client.signOutCalls, 1);
    });

    test('swallows platform errors so logout always completes', () async {
      final GoogleSignInService service = GoogleSignInService(
        client: FakeGoogleAuthClient(throwOnSignOut: true),
      );

      // Must not throw, otherwise a user could get stuck signed in.
      await service.signOut();
      expect(true, isTrue);
    });
  });

  group('hasPreviousSignIn', () {
    test('is true when a saved account yields a token', () async {
      final GoogleSignInService service = GoogleSignInService(
        client: FakeGoogleAuthClient(lightweightResult: _success),
      );
      expect(await service.hasPreviousSignIn, isTrue);
    });

    test('is false when there is no saved account', () async {
      final GoogleSignInService service = GoogleSignInService(
        client: FakeGoogleAuthClient(),
      );
      expect(await service.hasPreviousSignIn, isFalse);
    });
  });

  group('exception mapping', () {
    test('maps every known failure mode to friendly copy', () {
      final Map<GoogleSignInExceptionCode, String> expected =
          <GoogleSignInExceptionCode, String>{
            GoogleSignInExceptionCode.canceled: 'canceled',
            GoogleSignInExceptionCode.interrupted: 'interrupted',
            GoogleSignInExceptionCode.clientConfigurationError:
                'google-misconfigured',
            GoogleSignInExceptionCode.providerConfigurationError:
                'google-misconfigured',
            GoogleSignInExceptionCode.uiUnavailable: 'google-ui-unavailable',
            GoogleSignInExceptionCode.userMismatch: 'google-user-mismatch',
            GoogleSignInExceptionCode.unknownError: 'google-unknown',
          };

      expected.forEach((GoogleSignInExceptionCode code, String expectedCode) {
        final AppException mapped = GoogleSignInService.mapGoogleException(
          GoogleSignInException(code: code),
        );
        expect(mapped.code, expectedCode, reason: 'code $code');
        expect(mapped.message.trim(), isNotEmpty);
      });
    });

    test('always suggests the email fallback', () {
      for (final GoogleSignInExceptionCode code in <GoogleSignInExceptionCode>[
        GoogleSignInExceptionCode.clientConfigurationError,
        GoogleSignInExceptionCode.uiUnavailable,
        GoogleSignInExceptionCode.unknownError,
      ]) {
        final AppException mapped = GoogleSignInService.mapGoogleException(
          GoogleSignInException(code: code),
        );
        expect(mapped.message, contains('email and password'));
      }
    });
  });

  // ---------------------------------------------------------------------------
  // The sign-in button must appear once initialisation finishes.
  //
  // `initialize()` is fired off the critical path during start-up, so it always
  // completes *after* the first frame. When availability was a plain getter
  // read outside a reactive scope, the login screen built once with the button
  // unavailable and then never rebuilt — so Google Sign-In looked permanently
  // broken even though the plugin had initialised fine.
  // ---------------------------------------------------------------------------
  group('button visibility reacts to initialisation', () {
    tearDown(Get.reset);

    Future<GoogleSignInService> pumpLogin(WidgetTester tester) async {
      final GoogleSignInService service = GoogleSignInService(
        client: FakeGoogleAuthClient(),
      );
      Get.put<GoogleSignInService>(service);

      await tester.pumpWidget(
        GetMaterialApp(
          home: Scaffold(
            body: Builder(
              builder: (BuildContext context) {
                // Mirrors the structure used in login_view.dart.
                return Obx(
                  () => service.isReady.value
                      ? const Text('Continue with Google')
                      : const SizedBox.shrink(),
                );
              },
            ),
          ),
        ),
      );
      return service;
    }

    testWidgets('the button is absent before init and appears after', (
      WidgetTester tester,
    ) async {
      final GoogleSignInService service = await pumpLogin(tester);

      expect(
        find.text('Continue with Google'),
        findsNothing,
        reason: 'not initialised yet',
      );

      // Initialisation completes off the first frame, exactly as at start-up.
      unawaited(service.initialize());
      await tester.pumpAndSettle();

      expect(
        find.text('Continue with Google'),
        findsOneWidget,
        reason: 'the button must appear once the plugin is ready',
      );
    });

    testWidgets('a failed init keeps the button hidden', (
      WidgetTester tester,
    ) async {
      final GoogleSignInService service = GoogleSignInService(
        client: FakeGoogleAuthClient(throwOnInitialize: true),
      );
      Get.put<GoogleSignInService>(service);

      await tester.pumpWidget(
        GetMaterialApp(
          home: Scaffold(
            body: Obx(
              () => service.isReady.value
                  ? const Text('Continue with Google')
                  : const SizedBox.shrink(),
            ),
          ),
        ),
      );

      await service.initialize();
      await tester.pumpAndSettle();

      expect(find.text('Continue with Google'), findsNothing);
      expect(service.unavailableReason, isNotNull);
    });
  });
}
