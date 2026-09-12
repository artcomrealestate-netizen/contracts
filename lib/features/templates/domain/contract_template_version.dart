import 'template_clause.dart';

/// Mirrors the `contractTemplateVersions/{versionId}` document (TDD §16).
/// Immutable once created — a revision is always a new document, never an
/// update to this one.
class ContractTemplateVersion {
  final String id;
  final String templateId;
  final int version;
  final List<TemplateClause> clauses;
  final String createdBy;
  final DateTime? createdAt;

  const ContractTemplateVersion({
    required this.id,
    required this.templateId,
    required this.version,
    required this.clauses,
    required this.createdBy,
    this.createdAt,
  });
}
