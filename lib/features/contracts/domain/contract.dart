import 'contract_clause.dart';

/// The full state machine from TDD §22. Only [draft] is reachable through
/// this phase's UI (Implementation Order §68 phase 5, "Contracts / Draft");
/// the rest exist here so [contractStatusFromString] never has to guess at
/// a status written by a later phase (approval workflow, finalization, ...).
enum ContractStatus { draft, pendingApproval, rejected, approved, finalized, archived, cancelled }

ContractStatus contractStatusFromString(String value) {
  switch (value) {
    case 'PENDING_APPROVAL':
      return ContractStatus.pendingApproval;
    case 'REJECTED':
      return ContractStatus.rejected;
    case 'APPROVED':
      return ContractStatus.approved;
    case 'FINALIZED':
      return ContractStatus.finalized;
    case 'ARCHIVED':
      return ContractStatus.archived;
    case 'CANCELLED':
      return ContractStatus.cancelled;
    case 'DRAFT':
    default:
      return ContractStatus.draft;
  }
}

String contractStatusToString(ContractStatus status) {
  switch (status) {
    case ContractStatus.draft:
      return 'DRAFT';
    case ContractStatus.pendingApproval:
      return 'PENDING_APPROVAL';
    case ContractStatus.rejected:
      return 'REJECTED';
    case ContractStatus.approved:
      return 'APPROVED';
    case ContractStatus.finalized:
      return 'FINALIZED';
    case ContractStatus.archived:
      return 'ARCHIVED';
    case ContractStatus.cancelled:
      return 'CANCELLED';
  }
}

/// Mirrors the `contracts/{contractId}` document (TDD §17). Fields that only
/// matter from the approval/finalization phases on (submittedAt,
/// approvedBy, finalPdfUrl, snapshots, ...) aren't modeled here yet — they
/// stay null on every document this phase writes, and get added to this
/// class when the phase that reads them lands.
class Contract {
  final String id;
  final String contractNumber;
  final ContractStatus status;
  final int version;
  final String customerId;
  final String propertyId;
  final String? sourceQuotationId;
  final String templateId;
  final int templateVersion;
  final List<ContractClause> clauses;
  final String createdBy;
  final DateTime? createdAt;
  final DateTime? updatedAt;

  const Contract({
    required this.id,
    required this.contractNumber,
    required this.status,
    required this.version,
    required this.customerId,
    required this.propertyId,
    required this.templateId,
    required this.templateVersion,
    required this.clauses,
    required this.createdBy,
    this.sourceQuotationId,
    this.createdAt,
    this.updatedAt,
  });
}
