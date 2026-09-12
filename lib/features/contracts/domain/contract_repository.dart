import 'contract.dart';
import 'contract_clause.dart';
import 'rejection.dart';

abstract class ContractRepository {
  /// Creates a DRAFT contract with a server-assigned, sequential
  /// `contractNumber` (TDD §39 — never entered by the user).
  Future<Contract> createDraftContract({
    required String customerId,
    required String propertyId,
    required String templateId,
    required int templateVersion,
    required List<ContractClause> clauses,
    required String createdBy,
    String? sourceQuotationId,
  });

  /// Saves edited clause content on a Draft the caller owns — content only;
  /// customer/property/template/version stay fixed once created.
  Future<void> updateDraftClauses(String id, List<ContractClause> clauses);

  /// DRAFT -> PENDING_APPROVAL (TDD §23 Submit).
  Future<void> submitContract(String id, {required String actorId});

  /// PENDING_APPROVAL -> APPROVED (TDD §23 Approve). Every clause becomes
  /// APPROVED (clearing any earlier rejection note).
  Future<void> approveContract(String id, {required String actorId});

  /// PENDING_APPROVAL -> REJECTED (TDD §23/§24 Reject). Clauses named in
  /// [clauseNotes] become NEEDS_REVISION with that note; every other clause
  /// becomes APPROVED.
  Future<void> rejectContract(
    String id, {
    required String actorId,
    required String generalNote,
    required List<ClauseRejectionNote> clauseNotes,
  });

  /// REJECTED -> DRAFT so the owner can revise and resubmit (TDD §1/§22).
  Future<void> reviseRejectedContract(String id, {required String actorId});

  Future<Contract?> getContract(String id);

  /// Live single-contract view — used by the detail screen so a status
  /// change (submit/approve/reject/revise) shows up immediately.
  Stream<Contract?> watchContract(String id);

  /// Newest-first. No pagination yet (TDD §36 pagination lands with
  /// Dashboard/Search, phase 10) — fine for the small lists this phase deals
  /// with. [ownerId] restricts the list to contracts that user created —
  /// pass it for anyone without contract.edit_any (an admin-level scope);
  /// the Firestore rules require a matching query filter for non-admins
  /// regardless, so the caller can't just filter the result client-side.
  Stream<List<Contract>> watchContracts({String? ownerId});
}
