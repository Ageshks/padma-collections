import 'dart:async';

import 'package:firebase_analytics/firebase_analytics.dart';
import 'package:firebase_app_check/firebase_app_check.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_crashlytics/firebase_crashlytics.dart';
import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:flutter/foundation.dart';

import '../../core/utils/error_handler.dart';

import 'firebase_options.dart';

/// Result of booting Firebase.
enum FirebaseBootStatus {
  /// Firebase initialised and the app is talking to the live backend.
  ready,

  /// Initialisation failed. The app shows a blocking retry screen rather than
  /// pretending to work — see [FirebaseBootstrap.error].
  failed,
}

/// Boots the real Firebase backend for Padma Collections.
///
/// There is deliberately **no demo fallback**. An app that quietly serves fake
/// stock levels and fake orders is worse than one that refuses to start, so
/// any failure is surfaced to the user with a retry.
class FirebaseBootstrap {
  FirebaseBootstrap._();

  /// Fires for messages received while the app is in the foreground.
  @pragma('vm:prefer-inline')
  static FirebaseMessaging? messaging;

  /// Shared analytics instance, for event tracking across the app.
  @pragma('vm:prefer-inline')
  static FirebaseAnalytics? analytics;

  /// Set when [init] fails, so the UI can explain what went wrong.
  static String? error;

  /// True once the app is running against the live backend.
  static bool isReady = false;

  /// Initialises Firebase and the optional services layered on top of it.
  ///
  /// App Check, Analytics and Crashlytics are best-effort: they must never stop
  /// a customer from shopping, so a failure in any of them is logged and the
  /// boot still reports [FirebaseBootStatus.ready].
  static Future<FirebaseBootStatus> init() async {
    error = null;
    isReady = false;

    try {
      await Firebase.initializeApp(
        options: DefaultFirebaseOptions.currentPlatform,
      );
    } on Object catch (e) {
      error = AppErrorHandler.wrap(e).message;
      if (kDebugMode) debugPrint('Firebase init failed: $error');
      return FirebaseBootStatus.failed;
    }

    isReady = true;

    // Everything below is optional. Run them concurrently and never let a
    // failure reject into [init].
    unawaited(
      Future.wait<void>(<Future<void>>[
        _initAppCheck(),
        _initAnalytics(),
        _initCrashlytics(),
        _initMessaging(),
      ]).then<void>((List<void> _) {}).catchError((Object e) {
        if (kDebugMode) debugPrint('Optional Firebase services: $e');
      }),
    );

    return FirebaseBootStatus.ready;
  }

  /// Registers the app with App Check, in release builds only.
  ///
  /// App Check is deliberately **not** activated in debug builds:
  ///
  ///  * Play Integrity cannot validate a side-loaded APK — Play only vouches for
  ///    apps it distributed itself — so it returns `DEVELOPER_ERROR` every time.
  ///  * The `debug` provider is not a fix: its token must first be registered in
  ///    the App Check console, and until it is, Firebase Auth rejects the
  ///    credential. That silently breaks Google Sign-In during development,
  ///    which is exactly the confusion it is meant to prevent.
  ///  * It buys nothing locally: `firestore.rules` and `storage.rules` do not
  ///    gate on App Check, so no rule changes behaviour either way.
  ///
  /// Release builds keep the real Play Integrity check, which is the point of
  /// it — it stops a repackaged copy of the app from reaching the backend.
  static Future<void> _initAppCheck() async {
    if (kIsWeb || kDebugMode) return;
    try {
      await FirebaseAppCheck.instance.activate(
        androidProvider: AndroidProvider.playIntegrity,
      );
    } catch (e) {
      debugPrint('App Check unavailable: ${AppErrorHandler.wrap(e).message}');
    }
  }

  static Future<void> _initAnalytics() async {
    if (kIsWeb) return;
    try {
      analytics = FirebaseAnalytics.instance;
    } catch (e) {
      if (kDebugMode) {
        debugPrint('Analytics unavailable: ${AppErrorHandler.wrap(e).message}');
      }
    }
  }

  /// Crashlytics is a no-op on web and in debug builds by design: a debug
  /// build's framework errors are not representative of production.
  static Future<void> _initCrashlytics() async {
    if (kIsWeb || kDebugMode) return;
    try {
      await FirebaseCrashlytics.instance.setCrashlyticsCollectionEnabled(true);
    } catch (e) {
      if (kDebugMode) {
        debugPrint(
          'Crashlytics unavailable: ${AppErrorHandler.wrap(e).message}',
        );
      }
    }
  }

  static Future<void> _initMessaging() async {
    try {
      final FirebaseMessaging fm = FirebaseMessaging.instance;
      messaging = fm;
      await fm.requestPermission(
        alert: true,
        badge: true,
        sound: true,
        provisional: false,
      );
      FirebaseMessaging.onMessage.listen((RemoteMessage message) {
        // Foreground notifications are surfaced by the in-app notification
        // list, which is fed by Firestore — nothing to do here.
        if (kDebugMode) {
          debugPrint('Foreground message: ${message.messageId}');
        }
      });
    } catch (e) {
      if (kDebugMode) {
        debugPrint('FCM unavailable: ${AppErrorHandler.wrap(e).message}');
      }
    }
  }

  /// Records a handled error in Crashlytics so it reaches the console in
  /// release builds. Safe to call in any environment.
  static Future<void> recordError(
    Object error,
    StackTrace stack, {
    bool fatal = false,
  }) async {
    if (kIsWeb || kDebugMode) return;
    try {
      await FirebaseCrashlytics.instance.recordError(
        error,
        stack,
        reason: fatal ? 'fatal' : 'handled',
      );
    } catch (_) {
      // Reporting must never itself throw.
    }
  }

  /// Requests notification permission, returning whether it was granted.
  static Future<bool> requestNotificationPermission() async {
    try {
      final NotificationSettings settings = await FirebaseMessaging.instance
          .requestPermission();
      return settings.authorizationStatus == AuthorizationStatus.authorized ||
          settings.authorizationStatus == AuthorizationStatus.provisional;
    } catch (_) {
      return false;
    }
  }

  /// Current device token, or null when unavailable.
  static Future<String?> deviceToken() async {
    try {
      return await FirebaseMessaging.instance.getToken();
    } catch (_) {
      return null;
    }
  }
}
