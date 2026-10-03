import 'dart:async';
import 'dart:io';

import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';

import '../constants/app_colors.dart';

/// A normalised, user-presentable failure.
class AppException implements Exception {
  const AppException(this.message, {this.code, this.debugInfo});

  final String message;
  final String? code;

  /// Original error, kept for logs only — never shown in the UI.
  final Object? debugInfo;

  @override
  String toString() => message;
}

/// Centralised, human-friendly error handling.
///
/// Raw Firebase/plugin exceptions are never shown to the user. Every failure
/// that can reach the UI passes through [AppErrorHandler.from] first, which
/// maps known platform codes onto plain language.
class AppErrorHandler {
  AppErrorHandler._();

  static const String genericMessage =
      'Something went wrong. Please try again in a moment.';

  static const String offlineMessage =
      'You appear to be offline. Check your internet connection and try again.';

  // -------------------------------------------------------------------------
  // Firebase code → plain language
  // -------------------------------------------------------------------------

  static const Map<String, String> _authMessages = <String, String>{
    'weak-password':
        'That password is too weak. Use at least 8 characters with a mix of letters and numbers.',
    'email-already-in-use':
        'An account with this email already exists. Try logging in instead.',
    'invalid-email': 'That email address does not look valid.',
    'operation-not-allowed':
        'This sign-in method is disabled. Please contact support.',
    'user-disabled':
        'This account has been disabled. Please contact Padma Collections support.',
    'user-not-found': 'We could not find an account with those details.',
    'wrong-password': 'Incorrect password. Please try again.',
    'invalid-credential': 'Incorrect email or password. Please try again.',
    'invalid-login-credentials':
        'Incorrect email or password. Please try again.',
    'account-exists-with-different-credential':
        'An account already exists with this email using a different sign-in method.',
    'requires-recent-login': 'Please sign in again to complete this action.',
    'too-many-requests':
        'Too many attempts. Please wait a few minutes and try again.',
    'network-request-failed': offlineMessage,
    'timeout': 'The request timed out. Please check your connection and retry.',
  };

  static const Map<String, String> _firestoreMessages = <String, String>{
    'permission-denied': "You don't have permission to perform this action.",
    'unauthenticated': 'Please sign in to continue.',
    'not-found': 'The requested item could not be found.',
    'already-exists': 'That item already exists.',
    'unavailable': offlineMessage,
    'deadline-exceeded': 'The request timed out. Please try again.',
    'failed-precondition':
        'Something changed while we were saving. Please reload and retry.',
    'aborted': 'The operation was interrupted. Please try again.',
    'cancelled': 'The operation was cancelled.',
    'resource-exhausted': 'Too many requests right now. Please retry shortly.',
    'internal': 'We hit a problem on our side. Please try again.',
  };

  static const Map<String, String> _storageMessages = <String, String>{
    'unauthorized': "You don't have permission to upload this file.",
    'storage/unauthorized': "You don't have permission to upload this file.",
    'storage/canceled': 'The upload was cancelled.',
    'storage/quota-exceeded': 'Storage limit reached. Please contact support.',
    'storage/retry-limit-exceeded':
        'Upload failed after several attempts. Try a smaller image.',
    'object-not-found': 'That file could not be found.',
    'bucket-not-found': 'Storage is not configured correctly.',
    'invalid-argument': 'That file is not valid and could not be uploaded.',
  };

  // -------------------------------------------------------------------------
  // Public API
  // -------------------------------------------------------------------------

  /// Converts any thrown object into an [AppException] with friendly copy.
  static AppException from(Object error) {
    if (error is AppException) return error;

    final String code = _extractCode(error);
    final String? authMessage = _authMessages[code];
    if (authMessage != null) {
      return AppException(authMessage, code: code, debugInfo: error);
    }
    final String? fsMessage =
        _firestoreMessages[code] ?? _storageMessages[code];
    if (fsMessage != null) {
      return AppException(fsMessage, code: code, debugInfo: error);
    }

    if (error is SocketException || error is HttpException) {
      return const AppException(offlineMessage, code: 'network');
    }
    if (error is TimeoutException) {
      return const AppException(
        'The request timed out. Please try again.',
        code: 'timeout',
      );
    }
    if (error is FormatException) {
      return const AppException(
        'We received an unexpected response. Please try again.',
        code: 'format',
      );
    }

    if (kDebugMode) debugPrint('Unhandled error: $error');
    return AppException(genericMessage, debugInfo: error);
  }

  /// Wrapper for `catch (e) { throw AppErrorHandler.wrap(e); }`.
  ///
  /// Named [wrap] rather than `rethrow`, which is a reserved word.
  static AppException wrap(Object error) => from(error);

  /// Friendly copy when only a raw message string is available (e.g. a rule
  /// rejection surfaced as plain text).
  static String messageFor(String raw) {
    final String lower = raw.toLowerCase();
    if (lower.contains('permission-denied')) {
      return _firestoreMessages['permission-denied']!;
    }
    if (lower.contains('unavailable') || lower.contains('network')) {
      return offlineMessage;
    }
    if (lower.contains('deadline-exceeded') || lower.contains('timeout')) {
      return _firestoreMessages['deadline-exceeded']!;
    }
    return genericMessage;
  }

  /// True when the failure is a connectivity problem worth retrying.
  static bool isRetryable(Object error) {
    final String code = _extractCode(error);
    if (const <String>{
      'unavailable',
      'network-request-failed',
      'deadline-exceeded',
      'timeout',
      'aborted',
      'internal',
    }.contains(code)) {
      return true;
    }
    return error is SocketException || error is TimeoutException;
  }

  /// True when the failure means "signed out" or "not allowed".
  static bool isAuthError(Object error) {
    final String code = _extractCode(error);
    return code == 'unauthenticated' ||
        code == 'user-not-found' ||
        code == 'invalid-credential' ||
        code == 'invalid-login-credentials' ||
        code == 'user-disabled' ||
        code == 'requires-recent-login';
  }

  /// Pulls a comparable `code` out of any Firebase exception shape.
  ///
  /// Storage and Messaging exceptions both extend [FirebaseException] in
  /// recent Firebase releases, so a single check covers all of them.
  static String _extractCode(Object error) {
    if (error is FirebaseAuthException) return error.code;
    if (error is FirebaseException) return error.code;
    if (error is SocketException) return 'network';
    if (error is TimeoutException) return 'timeout';
    return '';
  }

  // -------------------------------------------------------------------------
  // Semantic colours for status pills
  // -------------------------------------------------------------------------

  static Color colourForOrderStatus(String status) {
    switch (status) {
      case 'Pending':
        return AppColors.warning;
      case 'Confirmed':
      case 'Processing':
        return AppColors.info;
      case 'Ready to Ship':
        return const Color(0xFF6A4C93);
      case 'Shipped':
        return AppColors.info;
      case 'Delivered':
        return AppColors.success;
      case 'Cancelled':
        return AppColors.danger;
      default:
        return AppColors.textSecondary;
    }
  }

  static Color softColourForOrderStatus(String status) {
    switch (status) {
      case 'Pending':
        return AppColors.warningSoft;
      case 'Confirmed':
      case 'Processing':
      case 'Shipped':
        return AppColors.infoSoft;
      case 'Ready to Ship':
        return const Color(0xFFEFE9F6);
      case 'Delivered':
        return AppColors.successSoft;
      case 'Cancelled':
        return AppColors.dangerSoft;
      default:
        return AppColors.surfaceMuted;
    }
  }

  /// Icon that best represents an order status.
  static IconData iconForOrderStatus(String status) {
    switch (status) {
      case 'Pending':
        return Icons.hourglass_empty_rounded;
      case 'Confirmed':
        return Icons.task_alt_rounded;
      case 'Processing':
        return Icons.autorenew_rounded;
      case 'Ready to Ship':
        return Icons.inventory_2_outlined;
      case 'Shipped':
        return Icons.local_shipping_outlined;
      case 'Delivered':
        return Icons.check_circle_outline_rounded;
      case 'Cancelled':
        return Icons.cancel_outlined;
      default:
        return Icons.circle_outlined;
    }
  }
}
