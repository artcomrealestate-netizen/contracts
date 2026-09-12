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

  /// Saves edits to a Draft the caller owns: clause content always, and
  /// optionally which customer/property this contract is for (template/
  /// version stay fixed once created — see Contract's own doc comment).
  Future<void> updateDraft(
    String id,
    List<ContractClause> clauses, {
    String? customerId,
    String? propertyId,
  });

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

  /// APPROVED -> FINALIZED (TDD §22/§27) — content becomes immutable from
  /// here (no update rule reaches a FINALIZED contract). Does not itself
  /// generate/store a PDF (see the Contract class doc comment).
  Future<void> finalizeContract(String id, {required String actorId});

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
