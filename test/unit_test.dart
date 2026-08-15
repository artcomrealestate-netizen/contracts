import 'dart:typed_data';

import 'package:flutter/widgets.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:qouta_calculator/main.dart';
import 'package:qouta_calculator/models/quotation_template.dart';
import 'package:qouta_calculator/models/saved_quotation.dart';
import 'package:qouta_calculator/services/archive_store.dart';
import 'package:qouta_calculator/services/template_store.dart';
import 'package:shared_preferences/shared_preferences.dart';

List<String> generateDynamicNotes({
  required double deposit,
  required double managementFee,
  required double cd,
  required double camera,
  required int contractPeriodMonths,
  required int roomQuantity,
}) {
  return AppLocalizations(const Locale('en')).dynamicNotes(
    deposit: deposit,
    managementFee: managementFee,
    cd: cd,
    camera: camera,
    contractPeriodMonths: contractPeriodMonths,
    roomQuantity: roomQuantity,
  );
}

void main() {
  group('Financial calculations', () {
    test('Base price defaults to a full 12-month year when months is not given', () {
      expect(calculateBasePrice(4500, 0, 1), 54000);
      expect(calculateBasePrice(1000, 0, 3), 36000);
    });

    test('Base price folds the monthly service charge into the total', () {
      // (2500 rent + 500 service) * 12 * 1 room = 36000
      expect(calculateBasePrice(2500, 500, 1), 36000);
    });

    test('Base price with zero values', () {
      expect(calculateBasePrice(0, 0, 1), 0);
      expect(calculateBasePrice(1000, 0, 0), 0);
      expect(calculateBasePrice(0, 0, 0), 0);
    });

    test('Base price respects a custom contract period in months instead of always assuming a year', () {
      // 6-month contract: (1500 rent) * 6 months * 2 rooms = 18000, not the 36000 a full year would give.
      expect(calculateBasePrice(1500, 0, 2, months: 6), 18000);
      // 3-month contract with a service charge folded in: (2000 + 500) * 3 * 1 = 7500.
      expect(calculateBasePrice(2000, 500, 1, months: 3), 7500);
      // 9-month contract, 4 rooms: 1000 * 9 * 4 = 36000.
      expect(calculateBasePrice(1000, 0, 4, months: 9), 36000);
    });

    test('Management fee is a percentage of the base yearly price', () {
      expect(calculateManagementFee(36000, 10), 3600);
      expect(calculateManagementFee(36000, 7), 2520);
      expect(calculateManagementFee(54000, 0), 0);
    });

    test('Management VAT is a percentage of the management fee, defaulting to 5%', () {
      // Verified against a real historical invoice: management 6240 * 5% = 312.
      expect(calculateManagementVat(6240, 5), 312);
      expect(calculateManagementVat(3600, defaultVatPercent), 180);
      expect(calculateManagementVat(3600, 0), 0);
    });

    test('Final price calculation matches formula', () {
      expect(calculateFinalPrice(54000, 6240, 200, 212, 0, 1500), 62152);
    });

    test('Final price with zero fees', () {
      expect(calculateFinalPrice(54000, 0, 0, 0, 0, 0), 54000);
    });

    test('Final price includes the management fee', () {
      expect(calculateFinalPrice(54000, 6240, 200, 212, 400, 1500), 62552);
    });

    test('Split payments into two equal installments', () {
      final payments = splitPayments(10001, numberOfPayments: 2);
      expect(payments, [5000.5, 5000.5]);
    });

    test('Split payments with a single payment returns the full amount', () {
      final payments = splitPayments(10001, numberOfPayments: 1);
      expect(payments, [10001]);
    });

    test('Split payments into N installments sums exactly to the total, remainder on the last', () {
      final payments = splitPayments(10000, numberOfPayments: 3);
      expect(payments.length, 3);
      expect(payments[0], payments[1]);
      expect(payments.reduce((a, b) => a + b), 10000);
    });

    test('Split payments treats zero or negative counts as a single payment', () {
      expect(splitPayments(500, numberOfPayments: 0), [500]);
      expect(splitPayments(500, numberOfPayments: -1), [500]);
    });

    test('firstPaymentExtra (deposit, C.D, camera, management fee + VAT) is added only to the first installment', () {
      // Rent (rooms) of 12000 split 3 ways, with 3000 of upfront fees bundled into payment 1.
      final payments = splitPayments(12000, numberOfPayments: 3, firstPaymentExtra: 3000);
      expect(payments, [7000, 4000, 4000]);
      expect(payments.reduce((a, b) => a + b), 15000);
    });

    test('firstPaymentExtra is folded into the single payment when only one installment is chosen', () {
      expect(splitPayments(12000, numberOfPayments: 1, firstPaymentExtra: 3000), [15000]);
    });
  });

  group('Input validation helpers', () {
    test('clampMinOne treats blank, non-numeric, zero, and negative input as invalid and falls back to 1', () {
      expect(clampMinOne(''), 1);
      expect(clampMinOne('abc'), 1);
      expect(clampMinOne('0'), 1);
      expect(clampMinOne('-5'), 1);
    });

    test('clampMinOne keeps any valid value of 1 or more as-is', () {
      expect(clampMinOne('1'), 1);
      expect(clampMinOne('7'), 7);
      expect(clampMinOne('2.5'), 2.5);
    });

    test('isBelowMinimumOne flags blank, zero, and negative input, not valid input', () {
      expect(isBelowMinimumOne(''), isTrue);
      expect(isBelowMinimumOne('0'), isTrue);
      expect(isBelowMinimumOne('-3'), isTrue);
      expect(isBelowMinimumOne('1'), isFalse);
      expect(isBelowMinimumOne('12'), isFalse);
    });

    test('clampNonNegative passes through blank and zero as zero, and floors negative input at zero', () {
      expect(clampNonNegative(''), 0);
      expect(clampNonNegative('0'), 0);
      expect(clampNonNegative('-100'), 0);
      expect(clampNonNegative('250'), 250);
    });

    test('isNegativeInput only flags an explicit negative number, not blank or zero', () {
      expect(isNegativeInput(''), isFalse);
      expect(isNegativeInput('0'), isFalse);
      expect(isNegativeInput('-1'), isTrue);
      expect(isNegativeInput('100'), isFalse);
    });
  });

  group('Dynamic notes generation', () {
    test('Adds annual increase note for long contract', () {
      final notes = generateDynamicNotes(
        deposit: 1000,
        managementFee: 100,
        cd: 100,
        camera: 100,
        contractPeriodMonths: 13,
        roomQuantity: 2,
      );
      expect(notes.first.contains('10% annual increase'), isTrue);
    });

    test('Does not add annual increase note for 12-month contract', () {
      final notes = generateDynamicNotes(
        deposit: 1000,
        managementFee: 100,
        cd: 100,
        camera: 100,
        contractPeriodMonths: 12,
        roomQuantity: 2,
      );
      expect(notes.any((note) => note.contains('10% annual increase')), isFalse);
    });

    test('Adds management fees note when the management fee is positive', () {
      final notes = generateDynamicNotes(
        deposit: 0,
        managementFee: 1,
        cd: 0,
        camera: 0,
        contractPeriodMonths: 12,
        roomQuantity: 1,
      );
      expect(notes.any((note) => note.contains('Management fees')), isTrue);
    });

    test('Adds only the applicable fee names (commercial contracts have no C.D/camera)', () {
      final notes = generateDynamicNotes(
        deposit: 0,
        managementFee: 0,
        cd: 1,
        camera: 0,
        contractPeriodMonths: 12,
        roomQuantity: 1,
      );
      expect(notes.any((note) => note.contains('Civil Defense')), isTrue);
      expect(notes.any((note) => note.contains('Management fees')), isFalse);
    });

    test('Does not add management fees note when fees are zero', () {
      final notes = generateDynamicNotes(
        deposit: 0,
        managementFee: 0,
        cd: 0,
        camera: 0,
        contractPeriodMonths: 12,
        roomQuantity: 1,
      );
      expect(notes.any((note) => note.contains('Management fees')), isFalse);
    });

    test('Adds deposit note when deposit is positive', () {
      final notes = generateDynamicNotes(
        deposit: 500,
        managementFee: 0,
        cd: 0,
        camera: 0,
        contractPeriodMonths: 12,
        roomQuantity: 1,
      );
      expect(notes.any((note) => note.contains('refundable deposit')), isTrue);
    });

    test('Room quantity text is singular or plural', () {
      final notesOneRoom = generateDynamicNotes(
        deposit: 0,
        managementFee: 0,
        cd: 0,
        camera: 0,
        contractPeriodMonths: 12,
        roomQuantity: 1,
      );
      expect(notesOneRoom.any((n) => n.contains('one room')), isTrue);

      final notesTwoRooms = generateDynamicNotes(
        deposit: 0,
        managementFee: 0,
        cd: 0,
        camera: 0,
        contractPeriodMonths: 12,
        roomQuantity: 2,
      );
      expect(notesTwoRooms.any((n) => n.contains('2 rooms')), isTrue);
    });
  });

  group('QuotationTemplate model', () {
    test('round-trips through JSON', () {
      const template = QuotationTemplate(
        id: 't1',
        templateName: 'VIP Room',
        roomType: 'Large',
        contractType: 'commercial',
        priceMonth: 7500,
        cd: 300,
        camera: 300,
        includeCd: false,
        includeCamera: true,
        service: 150,
        managementPercent: 10,
        vatPercent: 4,
        deposit: 2500,
        contractMonths: 9,
        numberOfPayments: 2,
      );

      final restored = QuotationTemplate.fromJson(template.toJson());

      expect(restored.id, template.id);
      expect(restored.templateName, template.templateName);
      expect(restored.roomType, template.roomType);
      expect(restored.contractType, template.contractType);
      expect(restored.priceMonth, template.priceMonth);
      expect(restored.service, template.service);
      expect(restored.managementPercent, template.managementPercent);
      expect(restored.vatPercent, template.vatPercent);
      expect(restored.includeCd, template.includeCd);
      expect(restored.includeCamera, template.includeCamera);
      expect(restored.contractMonths, template.contractMonths);
      expect(restored.numberOfPayments, template.numberOfPayments);
    });

    test('defaults contractType to residential, vatPercent to 5, and contractMonths to 12 when absent from JSON', () {
      const template = QuotationTemplate(
        id: 't2',
        templateName: 'Legacy Room',
        roomType: 'Small',
        priceMonth: 4000,
        cd: 100,
        camera: 112,
        deposit: 1000,
        numberOfPayments: 1,
      );
      final json = template.toJson()
        ..remove('contractType')
        ..remove('vatPercent')
        ..remove('includeCd')
        ..remove('includeCamera')
        ..remove('contractMonths');

      final restored = QuotationTemplate.fromJson(json);

      expect(restored.contractType, 'residential');
      expect(restored.vatPercent, 5);
      expect(restored.includeCd, isTrue);
      expect(restored.includeCamera, isTrue);
      expect(restored.contractMonths, 12);
    });
  });

  group('SavedQuotation model', () {
    test('round-trips through JSON including createdAt', () {
      final quotation = SavedQuotation(
        id: 'q1',
        quotaNumber: 'QT-2026-001',
        customerName: 'Ahmed',
        createdAt: DateTime(2026, 7, 30, 10, 30),
        roomType: 'Small',
        quantity: 2,
        priceMonth: 4500,
        vat: 6240,
        cd: 200,
        camera: 212,
        service: 100,
        managementPercent: 8,
        deposit: 1500,
        contractMonths: 6,
        numberOfPayments: 2,
        yearlyPrice: 108000,
        finalPrice: 116152,
      );

      final restored = SavedQuotation.fromJson(quotation.toJson());

      expect(restored.id, quotation.id);
      expect(restored.quotaNumber, quotation.quotaNumber);
      expect(restored.customerName, quotation.customerName);
      expect(restored.createdAt, quotation.createdAt);
      expect(restored.service, quotation.service);
      expect(restored.managementPercent, quotation.managementPercent);
      expect(restored.contractMonths, quotation.contractMonths);
      expect(restored.finalPrice, quotation.finalPrice);
    });

    test('defaults contractMonths to 12 when absent from JSON (quotations saved before this feature)', () {
      final quotation = SavedQuotation(
        id: 'q-legacy',
        quotaNumber: 'QT-2026-050',
        customerName: 'Legacy Customer',
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
      final json = quotation.toJson()..remove('contractMonths');

      final restored = SavedQuotation.fromJson(json);

      expect(restored.contractMonths, 12);
    });
  });

  group('TemplateStore', () {
    setUp(() {
      SharedPreferences.setMockInitialValues({});
    });

    test('seeds default templates on first load', () async {
      final store = await TemplateStore.load();
      expect(store.templates.length, TemplateStore.defaultTemplates().length);
    });

    test('a newly saved template survives a simulated app restart', () async {
      // First "app session": load the store and save a custom template.
      final firstSession = await TemplateStore.load();
      await firstSession.upsert(const QuotationTemplate(
        id: 'restart-test',
        templateName: 'Survives Restart',
        roomType: 'Medium',
        priceMonth: 6000,
        cd: 100,
        camera: 80,
        deposit: 1200,
        numberOfPayments: 2,
      ));

      // Second "app session": a brand-new TemplateStore.load() call, exactly
      // what happens when the app is closed and reopened. It must see the
      // template saved above via the underlying shared_preferences storage,
      // not just in the first instance's in-memory list.
      final secondSession = await TemplateStore.load();
      expect(
        secondSession.templates.any((t) => t.id == 'restart-test' && t.templateName == 'Survives Restart'),
        isTrue,
      );
    });

    test('upsert adds a new template and delete removes it', () async {
      final store = TemplateStore.withTemplates(const []);
      const template = QuotationTemplate(
        id: 'a',
        templateName: 'Custom',
        roomType: 'Medium',
        priceMonth: 5000,
        cd: 50,
        camera: 50,
        deposit: 1000,
        numberOfPayments: 1,
      );

      await store.upsert(template);
      expect(store.templates.length, 1);
      expect(store.templates.single.templateName, 'Custom');

      await store.upsert(template.copyWith(templateName: 'Renamed'));
      expect(store.templates.length, 1);
      expect(store.templates.single.templateName, 'Renamed');

      await store.delete('a');
      expect(store.templates, isEmpty);
    });
  });

  group('ArchiveStore', () {
    setUp(() {
      SharedPreferences.setMockInitialValues({});
    });

    test('starts empty when nothing has been saved before', () async {
      final store = await ArchiveStore.load();
      expect(store.quotations, isEmpty);
    });

    test('a newly saved quotation survives a simulated app restart', () async {
      final firstSession = await ArchiveStore.load();
      await firstSession.add(SavedQuotation(
        id: 'restart-test',
        quotaNumber: firstSession.nextQuotaNumber(),
        customerName: 'Restart Customer',
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
      ));

      final secondSession = await ArchiveStore.load();
      expect(secondSession.quotations.any((q) => q.id == 'restart-test'), isTrue);
    });

    test('nextQuotaNumber increments sequentially per year', () {
      final store = ArchiveStore.withQuotations(const []);
      final now = DateTime(2026, 1, 1);
      expect(store.nextQuotaNumber(now: now), 'QT-2026-001');
      expect(store.nextQuotaNumber(now: now), 'QT-2026-002');
      expect(store.nextQuotaNumber(now: now), 'QT-2026-003');
    });

    test('add stores newest-first and delete removes by id', () async {
      final store = ArchiveStore.withQuotations(const []);
      final older = SavedQuotation(
        id: '1',
        quotaNumber: 'QT-2026-001',
        customerName: 'First',
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
      final newer = SavedQuotation(
        id: '2',
        quotaNumber: 'QT-2026-002',
        customerName: 'Second',
        createdAt: DateTime(2026, 2, 1),
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

      await store.add(older);
      await store.add(newer);

      expect(store.quotations.map((q) => q.id).toList(), ['2', '1']);

      await store.delete('2');
      expect(store.quotations.map((q) => q.id).toList(), ['1']);
    });
  });

  group('AppSettings persistence', () {
    setUp(() {
      SharedPreferences.setMockInitialValues({});
    });

    test('company info, language and logo survive a simulated app restart', () async {
      final firstSession = await AppSettings.load();
      await firstSession.updateCompanySettings(
        name: 'Al-Noor Rentals',
        phone: '0599999999',
        email: 'info@alnoor.example',
        website: 'www.alnoor.example',
      );
      firstSession.updateLocale(const Locale('en'));
      final logoBytes = Uint8List.fromList([1, 2, 3, 4, 5]);
      await firstSession.updateLogoBytes(logoBytes);

      final secondSession = await AppSettings.load();
      expect(secondSession.companyName, 'Al-Noor Rentals');
      expect(secondSession.companyPhone, '0599999999');
      expect(secondSession.companyEmail, 'info@alnoor.example');
      expect(secondSession.companyWebsite, 'www.alnoor.example');
      expect(secondSession.locale.languageCode, 'en');
      expect(secondSession.logoBytes, logoBytes);
    });

    test('custom notes survive a simulated app restart', () async {
      final firstSession = await AppSettings.load();
      await firstSession.updateCustomNotes(
        notesAr: 'ملاحظة عربية مخصصة',
        notesEn: 'Custom English note',
      );

      final secondSession = await AppSettings.load();
      expect(secondSession.customNotesAr, 'ملاحظة عربية مخصصة');
      expect(secondSession.customNotesEn, 'Custom English note');
    });

    test('resetting custom notes to null removes them on restart', () async {
      final firstSession = await AppSettings.load();
      await firstSession.updateCustomNotes(notesAr: 'temp', notesEn: 'temp');
      await firstSession.updateCustomNotes(notesAr: null, notesEn: null);

      final secondSession = await AppSettings.load();
      expect(secondSession.customNotesAr, isNull);
      expect(secondSession.customNotesEn, isNull);
    });
  });

  group('effectiveNotes', () {
    test('falls back to dynamicNotes when customNotes is null or blank', () {
      final strings = AppLocalizations(const Locale('en'));
      final fallback = strings.effectiveNotes(
        customNotes: null,
        deposit: 500,
        managementFee: 0,
        cd: 0,
        camera: 0,
        contractPeriodMonths: 12,
        roomQuantity: 1,
      );
      final dynamicOnly = strings.dynamicNotes(
        deposit: 500,
        managementFee: 0,
        cd: 0,
        camera: 0,
        contractPeriodMonths: 12,
        roomQuantity: 1,
      );
      expect(fallback, dynamicOnly);

      final blankFallback = strings.effectiveNotes(
        customNotes: '   ',
        deposit: 500,
        managementFee: 0,
        cd: 0,
        camera: 0,
        contractPeriodMonths: 12,
        roomQuantity: 1,
      );
      expect(blankFallback, dynamicOnly);
    });

    test('uses custom notes split by line when provided', () {
      final strings = AppLocalizations(const Locale('en'));
      final notes = strings.effectiveNotes(
        customNotes: 'First custom line\nSecond custom line\n\nThird line',
        deposit: 500,
        managementFee: 0,
        cd: 0,
        camera: 0,
        contractPeriodMonths: 12,
        roomQuantity: 1,
      );
      expect(notes, ['First custom line', 'Second custom line', 'Third line']);
    });
  });
}
