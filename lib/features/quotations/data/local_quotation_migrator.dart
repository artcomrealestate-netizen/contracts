import 'dart:convert';

import 'package:shared_preferences/shared_preferences.dart';

import '../../../models/saved_quotation.dart';
import '../domain/quotation_repository.dart';

/// One-time migration of quotations saved by the pre-Firestore ArchiveStore
/// (local SharedPreferences, key `quotation_archive`) into Firestore, now
/// that quotation storage requires an account. Runs once per device: on
/// success it clears the local key so it never re-runs there.
///
/// Known limitation: each quotation keeps the `quotaNumber` it already had
/// locally rather than being re-numbered, since that number may already be
/// on a PDF a customer received. If more than one device migrates archives
/// that happen to share a quota number (e.g. two devices both reached
/// QT-2026-001 independently before this update), both records land in
/// Firestore with that same number — this migrator does not attempt to
/// detect or resolve that across devices.
class LocalQuotationMigrator {
  static const _legacyStorageKey = 'quotation_archive';

  Future<void> migrateIfNeeded({
    required QuotationRepository repository,
    required String migratedByUid,
  }) async {
    final prefs = await SharedPreferences.getInstance();
    final raw = prefs.getString(_legacyStorageKey);
    if (raw == null) return;

    final quotations = (jsonDecode(raw) as List<dynamic>)
        .map((e) => SavedQuotation.fromJson(e as Map<String, dynamic>))
        .toList();
    for (final quotation in quotations) {
      await repository.add(quotation, createdBy: migratedByUid);
    }
    await prefs.remove(_legacyStorageKey);
  }
}
