/// Clause-level feedback attached to a [Rejection] (TDD §24) — identifies
/// exactly which clause needs revision and why.
class ClauseRejectionNote {
  final String clauseId;
  final String note;

  const ClauseRejectionNote({required this.clauseId, required this.note});
}

/// Mirrors the rejection object embedded in a contract document when it
/// moves PENDING_APPROVAL -> REJECTED (TDD §24).
class Rejection {
  final String generalNote;
  final String rejectedBy;
  final DateTime? rejectedAt;
  final List<ClauseRejectionNote> clauses;

  const Rejection({
    required this.generalNote,
    required this.rejectedBy,
    required this.clauses,
    this.rejectedAt,
  });
}
