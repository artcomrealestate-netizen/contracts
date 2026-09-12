import '../../../models/saved_quotation.dart';

abstract class QuotationRepository {
  /// Reserves the next sequential quota number for the current year
  /// (e.g. `QT-2026-001`) via a server-side counter — never entered by the
  /// user, same principle as contract numbering (TDD §39).
  Future<String> reserveNextQuotaNumber();

  Future<void> add(SavedQuotation quotation, {required String createdBy});

  /// Single-quotation lookup — the `QuotationRepository.getQuotation` TDD §19
  /// names for a contract's sourceQuotationId link to resolve.
  Future<SavedQuotation?> getQuotation(String id);

  /// Used only by LocalQuotationMigrator to detect a quotaNumber collision
  /// (two devices that independently reached the same local number) before
  /// migrating a legacy local quotation into Firestore.
  Future<bool> quotaNumberExists(String quotaNumber);

  Future<void> delete(String id);

  /// Newest-first.
  Stream<List<SavedQuotation>> watchQuotations();
}
