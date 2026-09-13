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
      const clause = TemplateClause(
        id: 'c1',
        order: 1,
        titleEn: 'Payment Terms',
        titleAr: 'شروط الدفع',
        contentEn: '...',
        contentAr: '...',
      );
      expect(clause.isLocked, isFalse);
    });

    test('title/content getters prefer English, fall back to Arabic', () {
      const bilingual = TemplateClause(
        id: 'c1',
        order: 1,
        titleEn: 'Payment Terms',
        titleAr: 'شروط الدفع',
        contentEn: 'Pay on time.',
        contentAr: 'ادفع في الوقت المحدد.',
      );
      expect(bilingual.title, 'Payment Terms');
      expect(bilingual.content, 'Pay on time.');

      const arabicOnly = TemplateClause(id: 'c2', order: 1, titleEn: '', titleAr: 'شروط الدفع', contentEn: '', contentAr: 'ادفع.');
      expect(arabicOnly.title, 'شروط الدفع');
      expect(arabicOnly.content, 'ادفع.');
    });
  });
}
