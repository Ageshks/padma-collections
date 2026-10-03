// ignore_for_file: avoid_classes_with_only_static_members

import 'package:firebase_core/firebase_core.dart';
import 'package:flutter/foundation.dart';

/// Firebase configuration for **Padma Collections**.
///
/// Generated from the real Firebase project `padma-cb65f`
/// (Console → Project settings → Your apps → `padma collections`).
///
/// These are public client identifiers, safe to commit. Access is governed by
/// `firestore.rules` and `storage.rules`, never by hiding this file.
///
/// Only an **Android** app is registered on the project today. iOS and macOS
/// require an Apple Developer team to register an app, so their options are
/// absent and [currentPlatform] throws a clear, actionable error rather than
/// silently degrading — a silent fallback would ship an app that appears to work
/// while every request fails.
class DefaultFirebaseOptions {
  DefaultFirebaseOptions._();

  static const String projectId = 'padma-cb65f';
  static const String messagingSenderId = '22887538827';
  static const String apiKey = 'AIzaSyBmxsaCpxHt4jBwI_6EerzprFZl-g1qHDk';
  static const String storageBucket = 'padma-cb65f.firebasestorage.app';

  /// OAuth **Web client id** from the Firebase console
  /// (Project settings → Your apps → Android app → SDK setup).
  ///
  /// Android needs this as the `serverClientId` for Google Sign-In, which is
  /// why it is declared separately from the API key. It is already present in
  /// `android/app/google-services.json` as the `client_type: 3` entry, and
  /// copied here because Flutter needs it on the Dart side too.
  static const String webClientId =
      '22887538827-jloh59p85vr0h5ksljjnvlme87f4df96.apps.googleusercontent.com';

  /// True once a real OAuth web client id has been supplied, which is the
  /// signal that Google Sign-In is worth showing on Android.
  static bool get hasWebClientId => webClientId.trim().isNotEmpty;

  /// Android is the only platform with a registered app.
  ///
  /// Kept as a getter (rather than a constant) so the Dart compiler can still
  /// tree-shake the other platform branches.
  static FirebaseOptions get currentPlatform {
    if (kIsWeb) {
      throw UnsupportedError(
        'Padma Collections has no web app registered. Add one with '
        '`firebase apps:create WEB padma-collections-web` and re-run '
        '`flutterfire configure`.',
      );
    }
    return switch (defaultTargetPlatform) {
      TargetPlatform.android => android,
      TargetPlatform.iOS || TargetPlatform.macOS => throw UnsupportedError(
        'Padma Collections has no iOS app registered. Add one with '
        '`firebase apps:create IOS com.padmacollections.app`, then run '
        '`flutterfire configure` to generate ios/Runner/'
        'GoogleService-Info.plist.',
      ),
      _ => throw UnsupportedError(
        'Padma Collections supports Android only. '
        'Platform: $defaultTargetPlatform',
      ),
    };
  }

  static const FirebaseOptions android = FirebaseOptions(
    apiKey: apiKey,
    appId: '1:22887538827:android:f080f108b1a6324f51748e',
    messagingSenderId: messagingSenderId,
    projectId: projectId,
    storageBucket: storageBucket,
  );
}
