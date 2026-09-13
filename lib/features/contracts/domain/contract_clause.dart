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

/// Bilingual (Ar/En) clause copied onto a contract from a [TemplateClause]
/// (see that class's doc comment for the placeholder/rendering model, which
/// applies identically here) — same shape plus the approval-workflow fields.
class ContractClause {
  final String id;
  final int order;
  final String titleAr;
  final String titleEn;
  final String contentAr;
  final String contentEn;
  final bool isLocked;
  final ClauseReviewStatus reviewStatus;
  final String? rejectionNote;

  const ContractClause({
    required this.id,
    required this.order,
    required this.titleAr,
    required this.titleEn,
    required this.contentAr,
    required this.contentEn,
    this.isLocked = false,
    this.reviewStatus = ClauseReviewStatus.pending,
    this.rejectionNote,
  });

  /// Back-compat accessor for display-only call sites written before the
  /// bilingual split — prefers English, falls back to Arabic.
  String get title => titleEn.isNotEmpty ? titleEn : titleAr;

  /// Back-compat accessor, see [title].
  String get content => contentEn.isNotEmpty ? contentEn : contentAr;
}
