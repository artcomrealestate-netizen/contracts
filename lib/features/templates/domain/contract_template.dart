enum TemplateStatus { active, archived }

TemplateStatus templateStatusFromString(String value) {
  return TemplateStatus.values.firstWhere(
    (s) => s.name == value,
    orElse: () => TemplateStatus.active,
  );
}

/// Mirrors the `contractTemplates/{templateId}` document (TDD §15).
/// [currentVersion] points at the latest published `contractTemplateVersions`
/// doc — versions are immutable, so publishing a revision creates a new
/// version doc and bumps this number rather than editing one in place.
class ContractTemplate {
  final String id;
  final String name;
  final String code;
  final TemplateStatus status;
  final int currentVersion;
  final String createdBy;
  final DateTime? createdAt;
  final DateTime? updatedAt;

  const ContractTemplate({
    required this.id,
    required this.name,
    required this.code,
    required this.status,
    required this.currentVersion,
    required this.createdBy,
    this.createdAt,
    this.updatedAt,
  });
}
