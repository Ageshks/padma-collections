import 'package:cloud_firestore/cloud_firestore.dart';

/// Shared helpers for mapping Firestore documents to and from Dart models.
///
/// Models stay plain Dart objects (no Firestore types leaking into the UI);
/// this is the single boundary where `Map<String, dynamic>` is converted.
class FirestoreMap {
  FirestoreMap._();

  /// Converts a `DocumentSnapshot` into a plain map, tolerating a missing doc.
  static Map<String, dynamic> fromDocument(
    DocumentSnapshot<Map<String, dynamic>> doc,
  ) => doc.data() ?? <String, dynamic>{};

  /// Converts a query snapshot into a list of plain maps.
  static List<Map<String, dynamic>> fromQuery(
    QuerySnapshot<Map<String, dynamic>> query,
  ) => query.docs.map(fromDocument).toList();

  // -------------------------------------------------------------------------
  // Coercion helpers — Firestore can return nulls or loosely typed values
  // after schema changes, so every read is defensive.
  // -------------------------------------------------------------------------

  static String str(
    Map<String, dynamic> map,
    String key, [
    String fallback = '',
  ]) {
    final Object? value = map[key];
    if (value == null) return fallback;
    return value is String ? value : value.toString();
  }

  static String? strOrNull(Map<String, dynamic> map, String key) {
    final Object? value = map[key];
    if (value == null) return null;
    final String result = value is String ? value : value.toString();
    return result.isEmpty ? null : result;
  }

  static double num2(
    Map<String, dynamic> map,
    String key, [
    double fallback = 0,
  ]) {
    final Object? value = map[key];
    if (value is num) return value.toDouble();
    if (value is String) return double.tryParse(value) ?? fallback;
    return fallback;
  }

  static int int2(Map<String, dynamic> map, String key, [int fallback = 0]) {
    final Object? value = map[key];
    if (value is int) return value;
    if (value is num) return value.toInt();
    if (value is String) return int.tryParse(value) ?? fallback;
    return fallback;
  }

  static bool boolean(
    Map<String, dynamic> map,
    String key, [
    bool fallback = false,
  ]) {
    final Object? value = map[key];
    if (value is bool) return value;
    if (value is String) return value.toLowerCase() == 'true';
    return fallback;
  }

  /// Reads a timestamp, accepting `Timestamp`, ISO string, or millis.
  static DateTime? dateTime(Map<String, dynamic> map, String key) {
    final Object? value = map[key];
    if (value == null) return null;
    if (value is Timestamp) return value.toDate();
    if (value is DateTime) return value;
    if (value is String) return DateTime.tryParse(value);
    if (value is int) return DateTime.fromMillisecondsSinceEpoch(value);
    return null;
  }

  /// Reads a list of strings, skipping any non-string entries.
  static List<String> stringList(Map<String, dynamic> map, String key) {
    final Object? value = map[key];
    if (value is List) {
      return value.whereType<String>().toList();
    }
    return const <String>[];
  }

  /// Reads a list of nested maps (used for order items).
  static List<Map<String, dynamic>> mapList(
    Map<String, dynamic> map,
    String key,
  ) {
    final Object? value = map[key];
    if (value is List) {
      return value.whereType<Map<String, dynamic>>().toList();
    }
    return const <Map<String, dynamic>>[];
  }

  /// Serialises a [DateTime] for writing, omitting null values.
  static Map<String, dynamic> clean(Map<String, dynamic> map) {
    map.removeWhere((String key, dynamic value) => value == null);
    return map;
  }
}
