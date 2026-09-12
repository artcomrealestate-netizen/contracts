import 'contract_clause.dart';
import 'rejection.dart';

/// The full state machine from TDD §22. Draft, Pending Approval, Rejected,
/// and Approved are reachable through the UI as of the Approval Workflow
/// phase (Implementation Order §68 phase 6); Finalized/Archived/Cancelled
/// exist here so [contractStatusFromString] never has to guess at a status
/// written by a later phase (finalization, archival, ...).
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
/// matter from finalization on (finalizedAt, finalizedBy, finalPdfUrl,
/// fileHash, snapshots, ...) aren't modeled here yet — they stay null on
/// every document this phase writes, and get added to this class when
/// Finalization/PDF (Implementation Order phase 8) lands.
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
  final DateTime? submittedAt;
  final DateTime? approvedAt;
  final String? approvedBy;
  final Rejection? rejection;

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
    this.submittedAt,
    this.approvedAt,
    this.approvedBy,
    this.rejection,
  });
}
