import 'package:flutter_test/flutter_test.dart';
import 'package:qouta_calculator/features/contracts/domain/contract.dart';
import 'package:qouta_calculator/features/contracts/domain/contract_clause.dart';

void main() {
  group('contractStatusFromString / contractStatusToString', () {
    test('round-trips every documented status (TDD §22)', () {
      for (final status in ContractStatus.values) {
        expect(contractStatusFromString(contractStatusToString(status)), status);
      }
    });

    test('falls back safely to DRAFT on unknown/malformed values', () {
      expect(contractStatusFromString('bogus'), ContractStatus.draft);
    });

    test('uses the exact TDD §17 string spellings', () {
      expect(contractStatusToString(ContractStatus.draft), 'DRAFT');
      expect(contractStatusToString(ContractStatus.pendingApproval), 'PENDING_APPROVAL');
      expect(contractStatusToString(ContractStatus.finalized), 'FINALIZED');
    });
  });

  group('clauseReviewStatusFromString / clauseReviewStatusToString', () {
    test('round-trips every documented review status (TDD §18)', () {
      for (final status in ClauseReviewStatus.values) {
        expect(clauseReviewStatusFromString(clauseReviewStatusToString(status)), status);
      }
    });

    test('falls back safely to PENDING on unknown/malformed values', () {
      expect(clauseReviewStatusFromString('bogus'), ClauseReviewStatus.pending);
    });
  });

  group('Contract', () {
    test('stores the fields a Draft is created with', () {
      const contract = Contract(
        id: 'c1',
        contractNumber: 'CTR-2026-000001',
        status: ContractStatus.draft,
        version: 1,
        customerId: 'cust1',
        propertyId: 'prop1',
        templateId: 'tmpl1',
        templateVersion: 1,
        clauses: [],
        createdBy: 'u1',
      );
      expect(contract.status, ContractStatus.draft);
      expect(contract.sourceQuotationId, isNull);
    });
  });
}
