/// A clause inside a contract template version (TDD §16). Distinct from the
/// contract-level clause (§18), which additionally carries reviewStatus /
/// rejectionNote once copied onto a contract during the approval workflow
/// (a later phase) — a template clause has neither.
///
/// Title/content are bilingual (Ar/En) so a contract's Terms & Conditions can
/// render as two full pages, one per language, from the same clause list —
/// see lib/pdf/contract_pdf_builder.dart. `content` may contain `{{token}}`
/// placeholders resolved at PDF-render time only (see
/// lib/features/contracts/domain/clause_placeholder_resolver.dart); the
/// stored text always keeps the raw tokens.
class TemplateClause {
  final String id;
  final int order;
  final String titleAr;
  final String titleEn;
  final String contentAr;
  final String contentEn;
  final bool isLocked;

  const TemplateClause({
    required this.id,
    required this.order,
    required this.titleAr,
    required this.titleEn,
    required this.contentAr,
    required this.contentEn,
    this.isLocked = false,
  });

  /// Back-compat accessor for display-only call sites written before the
  /// bilingual split — prefers English, falls back to Arabic.
  String get title => titleEn.isNotEmpty ? titleEn : titleAr;

  /// Back-compat accessor, see [title].
  String get content => contentEn.isNotEmpty ? contentEn : contentAr;
}
