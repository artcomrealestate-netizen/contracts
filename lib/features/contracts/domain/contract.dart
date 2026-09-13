import 'contract_clause.dart';
import 'lease_terms.dart';
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

/// Mirrors the `contracts/{contractId}` document (TDD §17). finalPdfUrl/
/// fileHash (a Firebase Storage upload + SHA-256 hash of the final document,
/// per TDD §28) aren't modeled here — Finalize only flips status and records
/// who/when, and the existing PDF export (any status, ContractDetailScreen's
/// AppBar action) covers getting the document itself without adding a
/// Storage bucket to what a fresh environment needs configured.
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
  final LeaseTerms leaseTerms;
  final String createdBy;
  final DateTime? createdAt;
  final DateTime? updatedAt;
  final DateTime? submittedAt;
  final DateTime? approvedAt;
  final String? approvedBy;
  final DateTime? finalizedAt;
  final String? finalizedBy;
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
    this.leaseTerms = const LeaseTerms(),
    this.sourceQuotationId,
    this.createdAt,
    this.updatedAt,
    this.submittedAt,
    this.approvedAt,
    this.approvedBy,
    this.finalizedAt,
    this.finalizedBy,
    this.rejection,
  });
}
