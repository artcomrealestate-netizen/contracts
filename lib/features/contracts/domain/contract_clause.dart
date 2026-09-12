/// Review statuses for a clause once it's on a contract (TDD §18) — distinct
/// from [TemplateClause] (`../../templates/domain/template_clause.dart`),
/// which has no review state because it isn't attached to an approval flow.
enum ClauseReviewStatus { pending, approved, needsRevision }

ClauseReviewStatus clauseReviewStatusFromString(String value) {
  switch (value) {
    case 'APPROVED':
      return ClauseReviewStatus.approved;
    case 'NEEDS_REVISION':
      return ClauseReviewStatus.needsRevision;
    case 'PENDING':
    default:
      return ClauseReviewStatus.pending;
  }
}

String clauseReviewStatusToString(ClauseReviewStatus status) {
  switch (status) {
    case ClauseReviewStatus.approved:
      return 'APPROVED';
    case ClauseReviewStatus.needsRevision:
      return 'NEEDS_REVISION';
    case ClauseReviewStatus.pending:
      return 'PENDING';
  }
}

class ContractClause {
  final String id;
  final int order;
  final String title;
  final String content;
  final bool isLocked;
  final ClauseReviewStatus reviewStatus;
  final String? rejectionNote;

  const ContractClause({
    required this.id,
    required this.order,
    required this.title,
    required this.content,
    this.isLocked = false,
    this.reviewStatus = ClauseReviewStatus.pending,
    this.rejectionNote,
  });
}
