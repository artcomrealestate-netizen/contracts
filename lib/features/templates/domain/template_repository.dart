import 'contract_template.dart';
import 'contract_template_version.dart';
import 'template_clause.dart';

abstract class TemplateRepository {
  /// Creates a template together with its first version (version 1) as a
  /// single atomic write (TDD §15/§16 — a template never exists without a
  /// version to back `currentVersion`).
  Future<ContractTemplate> createTemplate({
    required String name,
    required String code,
    required List<TemplateClause> clauses,
    required String createdBy,
  });

  /// Publishes a new, immutable version for an existing template and bumps
  /// its `currentVersion` — never edits an existing version's clauses.
  Future<ContractTemplateVersion> publishNewVersion({
    required ContractTemplate template,
    required List<TemplateClause> clauses,
    required String createdBy,
  });

  Future<ContractTemplate?> getTemplate(String id);

  Stream<List<ContractTemplate>> watchTemplates();

  Stream<List<ContractTemplateVersion>> watchVersions(String templateId);
}
