import 'dart:convert';

import 'package:shared_preferences/shared_preferences.dart';

import '../../../models/saved_quotation.dart';
import '../domain/quotation_repository.dart';

/// One-time migration of quotations saved by the pre-Firestore ArchiveStore
/// (local SharedPreferences, key `quotation_archive`) into Firestore, now
/// that quotation storage requires an account. Runs once per device: on
/// success it clears the local key so it never re-runs there.
///
/// Each quotation normally keeps the `quotaNumber` it already had locally,
/// since that number may already be on a PDF a customer received. If two
/// devices independently reached the same local number before this update,
/// the second one to migrate gets a fresh number from the same shared
/// counter every new quotation uses going forward — this can only happen
/// once, for archives that predate Firestore-backed numbering — and keeps
/// its original number on [SavedQuotation.renumberedFrom] so it isn't lost.
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
      final toAdd = await repository.quotaNumberExists(quotation.quotaNumber)
          ? await _renumbered(quotation, repository)
          : quotation;
      await repository.add(toAdd, createdBy: migratedByUid);
    }
    await prefs.remove(_legacyStorageKey);
  }

  Future<SavedQuotation> _renumbered(SavedQuotation quotation, QuotationRepository repository) async {
    // The shared counter only knows about numbers it has issued — it's
    // blind to numbers preserved as-is from an earlier device's migration
    // (like the one being resolved right now), so a freshly reserved number
    // can itself collide with one of those. Keep drawing until it's clear.
    var newNumber = await repository.reserveNextQuotaNumber();
    while (await repository.quotaNumberExists(newNumber)) {
      newNumber = await repository.reserveNextQuotaNumber();
    }
    return SavedQuotation(
      id: quotation.id,
      quotaNumber: newNumber,
      customerName: quotation.customerName,
      createdAt: quotation.createdAt,
      roomType: quotation.roomType,
      contractType: quotation.contractType,
      quantity: quotation.quantity,
      priceMonth: quotation.priceMonth,
      vat: quotation.vat,
      cd: quotation.cd,
      camera: quotation.camera,
      includeCd: quotation.includeCd,
      includeCamera: quotation.includeCamera,
      service: quotation.service,
      managementPercent: quotation.managementPercent,
      vatPercent: quotation.vatPercent,
      deposit: quotation.deposit,
      industrialDepositPercent: quotation.industrialDepositPercent,
      contractMonths: quotation.contractMonths,
      numberOfPayments: quotation.numberOfPayments,
      yearlyPrice: quotation.yearlyPrice,
      finalPrice: quotation.finalPrice,
      khana: quotation.khana,
      shabraNumbers: quotation.shabraNumbers,
      shabraCount: quotation.shabraCount,
      area: quotation.area,
      pricePerSqft: quotation.pricePerSqft,
      warehouseDepositPercent: quotation.warehouseDepositPercent,
      civilDefensePerShabraRate: quotation.civilDefensePerShabraRate,
      contractCertFee: quotation.contractCertFee,
      hemayaInsuranceRate: quotation.hemayaInsuranceRate,
      hemayaContractFeeRate: quotation.hemayaContractFeeRate,
      renumberedFrom: quotation.quotaNumber,
    );
  }
}
