import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:qouta_calculator/features/quotations/data/local_quotation_migrator.dart';
import 'package:qouta_calculator/models/saved_quotation.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../../test_support/fake_quotation_repository.dart';

SavedQuotation _quotation({required String id, required String quotaNumber}) => SavedQuotation(
      id: id,
      quotaNumber: quotaNumber,
      customerName: 'Customer $id',
      createdAt: DateTime(2026, 1, 1),
      roomType: 'Small',
      quantity: 1,
      priceMonth: 1000,
      vat: 0,
      cd: 0,
      camera: 0,
      deposit: 0,
      numberOfPayments: 1,
      yearlyPrice: 12000,
      finalPrice: 12000,
    );

void main() {
  group('LocalQuotationMigrator', () {
    test('does nothing when there is no legacy local archive', () async {
      SharedPreferences.setMockInitialValues({});
      final repository = FakeQuotationRepository(const []);

      await LocalQuotationMigrator().migrateIfNeeded(repository: repository, migratedByUid: 'u1');

      expect(repository.quotations, isEmpty);
    });

    test('migrates a legacy archive and clears it so it never re-runs', () async {
      final legacy = [_quotation(id: 'q1', quotaNumber: 'QT-2026-001')];
      SharedPreferences.setMockInitialValues({
        'quotation_archive': jsonEncode(legacy.map((q) => q.toJson()).toList()),
      });
      final repository = FakeQuotationRepository(const []);

      await LocalQuotationMigrator().migrateIfNeeded(repository: repository, migratedByUid: 'u1');

      expect(repository.quotations.single.quotaNumber, 'QT-2026-001');
      expect(repository.quotations.single.renumberedFrom, isNull);

      final prefs = await SharedPreferences.getInstance();
      expect(prefs.getString('quotation_archive'), isNull);
    });

    test('renumbers a migrated quotation whose number already exists in Firestore, keeping the original on renumberedFrom', () async {
      final legacy = [_quotation(id: 'device-b-q1', quotaNumber: 'QT-2026-001')];
      SharedPreferences.setMockInitialValues({
        'quotation_archive': jsonEncode(legacy.map((q) => q.toJson()).toList()),
      });
      // Simulates another device having already migrated the same number.
      final repository = FakeQuotationRepository([
        _quotation(id: 'device-a-q1', quotaNumber: 'QT-2026-001'),
      ]);

      await LocalQuotationMigrator().migrateIfNeeded(repository: repository, migratedByUid: 'u2');

      final migrated = repository.quotations.firstWhere((q) => q.id == 'device-b-q1');
      expect(migrated.quotaNumber, isNot('QT-2026-001'));
      expect(migrated.renumberedFrom, 'QT-2026-001');
      // The original device's record is untouched.
      expect(repository.quotations.firstWhere((q) => q.id == 'device-a-q1').quotaNumber, 'QT-2026-001');
    });
  });
}
