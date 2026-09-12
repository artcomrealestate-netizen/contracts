import 'contract.dart';
import 'contract_clause.dart';

abstract class ContractRepository {
  /// Creates a DRAFT contract with a server-assigned, sequential
  /// `contractNumber` (TDD §39 — never entered by the user). Submit/approve/
  /// reject/finalize/clone (§42) land with the Approval Workflow phase.
  Future<Contract> createDraftContract({
    required String customerId,
    required String propertyId,
    required String templateId,
    required int templateVersion,
    required List<ContractClause> clauses,
    required String createdBy,
    String? sourceQuotationId,
  });

  Future<Contract?> getContract(String id);

  /// Newest-first. No pagination yet (TDD §36 pagination lands with
  /// Dashboard/Search, phase 10) — fine for the small lists this phase deals with.
  Stream<List<Contract>> watchContracts();
}
