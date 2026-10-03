import 'package:cloud_firestore/cloud_firestore.dart';

/// Tiny helper: `firstWhere` that returns null instead of throwing.
extension FirstWhereOrNull<T> on Iterable<T> {
  T? firstWhereOrNull(bool Function(T) test) {
    for (final T item in this) {
      if (test(item)) return item;
    }
    return null;
  }
}

/// Shared behaviour for repositories that must work with or without Firebase.
///
/// Every repository follows the same pattern: if Firebase failed to boot, fall
/// back to an in-memory dataset. That keeps the entire app — customer *and*
/// admin — reviewable before a real project is connected.
abstract class BaseRepository {
  BaseRepository({FirebaseFirestore? firestore})
    : _injectedFirestore = firestore;

  /// Injected instance, if any. Only tests and custom wiring pass one in.
  final FirebaseFirestore? _injectedFirestore;

  /// Lazily resolved Firestore handle.
  ///
  /// Deliberately **not** resolved in the constructor: `FirebaseFirestore
  /// .instance` throws when Firebase has not been initialised. Resolving on
  /// first use keeps repositories constructible during binding setup, before
  /// the bootstrap has completed.
  FirebaseFirestore get firestore =>
      _injectedFirestore ?? FirebaseFirestore.instance;

  /// Reports whether a failure is simply "no Firebase project configured".
  static bool isUnavailable(Object error) =>
      error is StateError || error.toString().contains('no-app');
}

/// instances observe the same mutable catalogue.
