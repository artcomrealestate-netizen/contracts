import 'package:flutter_test/flutter_test.dart';
import 'package:qouta_calculator/features/templates/domain/contract_template.dart';
import 'package:qouta_calculator/features/templates/domain/template_clause.dart';

void main() {
  group('templateStatusFromString', () {
    test('parses known values', () {
      expect(templateStatusFromString('active'), TemplateStatus.active);
      expect(templateStatusFromString('archived'), TemplateStatus.archived);
    });

    test('falls back safely on unknown/malformed values', () {
      expect(templateStatusFromString('bogus'), TemplateStatus.active);
    });
  });

  group('ContractTemplate', () {
    test('stores currentVersion and status as given', () {
      const template = ContractTemplate(
        id: 't1',
        name: 'Commercial Lease',
        code: 'COMM_LEASE',
        status: TemplateStatus.active,
        currentVersion: 3,
        createdBy: 'u1',
      );
      expect(template.currentVersion, 3);
      expect(template.status, TemplateStatus.active);
    });
  });

  group('TemplateClause', () {
    test('defaults isLocked to false', () {
      const clause = TemplateClause(id: 'c1', order: 1, title: 'Payment Terms', content: '...');
      expect(clause.isLocked, isFalse);
    });
  });
}
