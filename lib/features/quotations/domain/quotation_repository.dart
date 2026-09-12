import '../../../models/saved_quotation.dart';

abstract class QuotationRepository {
  /// Reserves the next sequential quota number for the current year
  /// (e.g. `QT-2026-001`) via a server-side counter — never entered by the
  /// user, same principle as contract numbering (TDD §39).
  Future<String> reserveNextQuotaNumber();

  Future<void> add(SavedQuotation quotation, {required String createdBy});

  Future<void> delete(String id);

  /// Newest-first.
  Stream<List<SavedQuotation>> watchQuotations();
}
