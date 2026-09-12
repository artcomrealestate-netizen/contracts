/// A clause inside a contract template version (TDD §16). Distinct from the
/// contract-level clause (§18), which additionally carries reviewStatus /
/// rejectionNote once copied onto a contract during the approval workflow
/// (a later phase) — a template clause has neither.
class TemplateClause {
  final String id;
  final int order;
  final String title;
  final String content;
  final bool isLocked;

  const TemplateClause({
    required this.id,
    required this.order,
    required this.title,
    required this.content,
    this.isLocked = false,
  });
}
