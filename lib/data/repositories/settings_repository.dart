import 'dart:async';

import 'package:cloud_firestore/cloud_firestore.dart';

import '../../core/constants/app_constants.dart';
import '../models/models.dart';
import 'base_repository.dart';

/// Reads and writes the three settings documents under `settings`.
///
/// These hold the store's branding, pricing rules and WhatsApp configuration.
/// Keeping them in Firestore is what lets the owner change a business detail
/// without shipping a new build of the app.
class SettingsRepository extends BaseRepository {
  SettingsRepository({super.firestore});

  DocumentReference<Map<String, dynamic>> _doc(String id) =>
      firestore.collection(AppConstants.settingsCollection).doc(id);

  // ---------------------------------------------------------------------------
  // App settings — settings/app
  // ---------------------------------------------------------------------------

  Stream<AppSettings> watchAppSettings() {
    return _doc(AppConstants.settingsApp).snapshots().map(
      (DocumentSnapshot<Map<String, dynamic>> d) =>
          AppSettings.fromMap(FirestoreMap.fromDocument(d)),
    );
  }

  Future<AppSettings> getAppSettings() async {
    final DocumentSnapshot<Map<String, dynamic>> doc = await _doc(
      AppConstants.settingsApp,
    ).get();
    if (!doc.exists) return const AppSettings();
    return AppSettings.fromMap(FirestoreMap.fromDocument(doc));
  }

  Future<void> saveAppSettings(AppSettings settings) async {
    await _doc(
      AppConstants.settingsApp,
    ).set(settings.toMap(), SetOptions(merge: true));
  }

  // ---------------------------------------------------------------------------
  // Rate settings — settings/rates
  // ---------------------------------------------------------------------------

  Stream<RateSettings> watchRateSettings() {
    return _doc(AppConstants.settingsRates).snapshots().map(
      (DocumentSnapshot<Map<String, dynamic>> d) =>
          RateSettings.fromMap(FirestoreMap.fromDocument(d)),
    );
  }

  Future<RateSettings> getRateSettings() async {
    final DocumentSnapshot<Map<String, dynamic>> doc = await _doc(
      AppConstants.settingsRates,
    ).get();
    if (!doc.exists) return const RateSettings();
    return RateSettings.fromMap(FirestoreMap.fromDocument(doc));
  }

  Future<void> saveRateSettings(RateSettings settings) async {
    await _doc(
      AppConstants.settingsRates,
    ).set(settings.toMap(), SetOptions(merge: true));
  }

  // ---------------------------------------------------------------------------
  // WhatsApp settings — settings/whatsapp
  // ---------------------------------------------------------------------------

  Stream<WhatsAppSettings> watchWhatsAppSettings() {
    return _doc(AppConstants.settingsWhatsapp).snapshots().map(
      (DocumentSnapshot<Map<String, dynamic>> d) =>
          WhatsAppSettings.fromMap(FirestoreMap.fromDocument(d)),
    );
  }

  Future<WhatsAppSettings> getWhatsAppSettings() async {
    final DocumentSnapshot<Map<String, dynamic>> doc = await _doc(
      AppConstants.settingsWhatsapp,
    ).get();
    if (!doc.exists) return const WhatsAppSettings();
    return WhatsAppSettings.fromMap(FirestoreMap.fromDocument(doc));
  }

  Future<void> saveWhatsAppSettings(WhatsAppSettings settings) async {
    await _doc(
      AppConstants.settingsWhatsapp,
    ).set(settings.toMap(), SetOptions(merge: true));
  }

  // ---------------------------------------------------------------------------
  // New arrival detection window — settings/rates
  // ---------------------------------------------------------------------------

  /// How recently an item must have been added to count as a new arrival.
  ///
  /// Read from the app-wide default rather than a hard-coded literal, so the
  /// window is defined in exactly one place.
  Stream<int> watchNewArrivalDays() {
    return watchRateSettings().map(
      (RateSettings _) => AppConstants.defaultNewArrivalDays,
    );
  }
}
