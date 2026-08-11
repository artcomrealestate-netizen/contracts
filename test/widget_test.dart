import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:provider/provider.dart';
import 'package:qouta_calculator/main.dart';
import 'package:qouta_calculator/models/quotation_template.dart';
import 'package:qouta_calculator/models/saved_quotation.dart';
import 'package:qouta_calculator/screens/archive_screen.dart';
import 'package:qouta_calculator/services/archive_store.dart';
import 'package:qouta_calculator/services/template_store.dart';
import 'package:shared_preferences/shared_preferences.dart';

class FakePdfSharer implements PdfSharer {
  int callCount = 0;
  Object? lastBytes;
  Object? lastFilename;

  @override
  Future<void> sharePdf({required Object? bytes, required Object? filename}) async {
    callCount += 1;
    lastBytes = bytes;
    lastFilename = filename;
  }
}

class FakeLogoPicker implements LogoPicker {
  final Uint8List? bytesToReturn;

  FakeLogoPicker(this.bytesToReturn);

  @override
  Future<Uint8List?> pickLogo() async => bytesToReturn;
}

const List<int> tinyPngBytes = [
  0x89, 0x50, 0x4E, 0x47, 0x0D, 0x0A, 0x1A, 0x0A,
  0x00, 0x00, 0x00, 0x0D,
  0x49, 0x48, 0x44, 0x52,
  0x00, 0x00, 0x00, 0x01,
  0x00, 0x00, 0x00, 0x01,
  0x08, 0x02, 0x00, 0x00, 0x00, 0x90, 0x77, 0x53, 0xDE,
  0x00, 0x00, 0x00, 0x0A,
  0x49, 0x44, 0x41, 0x54,
  0x78, 0x9C, 0x63, 0x00, 0x01, 0x00, 0x00, 0x05, 0x00, 0x01,
  0x0D, 0x0A, 0x2D, 0xB4,
  0x00, 0x00, 0x00, 0x00,
  0x49, 0x45, 0x4E, 0x44,
  0xAE, 0x42, 0x60, 0x82,
];

class TestAssetBundle extends CachingAssetBundle {
  final Map<String, ByteData> _assets;

  TestAssetBundle(this._assets);

  @override
  Future<ByteData> load(String key) async {
    final asset = _assets[key];
    if (asset != null) return asset;
    throw FlutterError('Asset not found: $key');
  }
}

Widget wrapWithApp(
  Widget child, {
  Locale locale = const Locale('en'),
  AppSettings? settings,
  TemplateStore? templateStore,
  ArchiveStore? archiveStore,
}) {
  return MultiProvider(
    providers: [
      ChangeNotifierProvider<AppSettings>.value(
        value: settings ??
            AppSettings(
              locale: locale,
              companyName: 'Test Co',
              companyPhone: '0000000000',
              companyEmail: 'test@test.com',
              companyWebsite: '',
            ),
      ),
      ChangeNotifierProvider<TemplateStore>.value(
        value: templateStore ?? TemplateStore.withTemplates(TemplateStore.defaultTemplates()),
      ),
      ChangeNotifierProvider<ArchiveStore>.value(
        value: archiveStore ?? ArchiveStore.withQuotations(const []),
      ),
    ],
    child: MaterialApp(
      locale: locale,
      supportedLocales: const [Locale('en'), Locale('ar')],
      localizationsDelegates: const [
        GlobalMaterialLocalizations.delegate,
        GlobalWidgetsLocalizations.delegate,
        GlobalCupertinoLocalizations.delegate,
      ],
      home: child,
    ),
  );
}

void main() {
  setUpAll(() {
    SharedPreferences.setMockInitialValues({});
  });

  testWidgets('Financial results update when input changes', (WidgetTester tester) async {
    await tester.pumpWidget(wrapWithApp(const QuotaCalculatorScreen()));

    final priceMonthField = find.byKey(const Key('priceMonth'));
    final roomQuantityField = find.byKey(const Key('roomQuantity'));
    final vatField = find.byKey(const Key('vatPercent'));
    final cdField = find.byKey(const Key('cd'));
    final cameraField = find.byKey(const Key('camera'));
    final depositField = find.byKey(const Key('deposit'));

    await tester.enterText(priceMonthField, '1000');
    await tester.enterText(roomQuantityField, '2');
    await tester.enterText(vatField, '0');
    await tester.enterText(cdField, '0');
    await tester.enterText(cameraField, '0');
    await tester.enterText(depositField, '0');
    await tester.pumpAndSettle();

    expect(find.text('24,000 \$'), findsNWidgets(2));
    expect(find.text('12,000 \$'), findsWidgets);
    expect(find.text('Payment 1:'), findsOneWidget);
    expect(find.text('Payment 2:'), findsOneWidget);
  });

  testWidgets('Entering a monthly service charge is folded into the annualized price', (WidgetTester tester) async {
    await tester.pumpWidget(wrapWithApp(const QuotaCalculatorScreen()));

    await tester.enterText(find.byKey(const Key('priceMonth')), '1000');
    await tester.enterText(find.byKey(const Key('roomQuantity')), '1');
    await tester.enterText(find.byKey(const Key('vatPercent')), '0');
    await tester.enterText(find.byKey(const Key('cd')), '0');
    await tester.enterText(find.byKey(const Key('camera')), '0');
    await tester.enterText(find.byKey(const Key('service')), '500');
    await tester.enterText(find.byKey(const Key('deposit')), '0');
    await tester.pumpAndSettle();

    // Yearly = (1000 rent + 500 service) * 12 * 1 room = 18000. No management % set, so final = yearly.
    expect(find.text('18,000 \$'), findsWidgets);
  });

  testWidgets('Payment split updates when two payments selected', (WidgetTester tester) async {
    await tester.pumpWidget(wrapWithApp(const QuotaCalculatorScreen()));

    final priceMonthField = find.byKey(const Key('priceMonth'));
    final roomQuantityField = find.byKey(const Key('roomQuantity'));
    final vatField = find.byKey(const Key('vatPercent'));
    final cdField = find.byKey(const Key('cd'));
    final cameraField = find.byKey(const Key('camera'));
    final depositField = find.byKey(const Key('deposit'));

    await tester.enterText(priceMonthField, '1001');
    await tester.enterText(roomQuantityField, '1');
    await tester.enterText(vatField, '0');
    await tester.enterText(cdField, '0');
    await tester.enterText(cameraField, '0');
    await tester.enterText(depositField, '0');
    await tester.pumpAndSettle();

    expect(find.text('12,012 \$'), findsWidgets);
    expect(find.text('6,006 \$'), findsNWidgets(2));
  });

  testWidgets('Selecting a different number of payments splits the total into that many rows', (WidgetTester tester) async {
    await tester.pumpWidget(wrapWithApp(const QuotaCalculatorScreen()));

    await tester.enterText(find.byKey(const Key('priceMonth')), '1000');
    await tester.enterText(find.byKey(const Key('roomQuantity')), '1');
    await tester.enterText(find.byKey(const Key('vatPercent')), '0');
    await tester.enterText(find.byKey(const Key('cd')), '0');
    await tester.enterText(find.byKey(const Key('camera')), '0');
    await tester.enterText(find.byKey(const Key('deposit')), '0');
    await tester.pumpAndSettle();

    // Base yearly price = 12000, default is 2 equal payments of 6000 each.
    expect(find.text('6,000 \$'), findsNWidgets(2));

    await tester.ensureVisible(find.byKey(const Key('numberOfPaymentsDropdown')));
    await tester.tap(find.byKey(const Key('numberOfPaymentsDropdown')));
    await tester.pumpAndSettle();
    await tester.tap(find.text('3 Payments').last);
    await tester.pumpAndSettle();

    expect(find.text('Payment 1:'), findsOneWidget);
    expect(find.text('Payment 2:'), findsOneWidget);
    expect(find.text('Payment 3:'), findsOneWidget);
    expect(find.text('4,000 \$'), findsNWidgets(3));
  });

  testWidgets(
    'The C.D and Camera checkboxes are independent - unchecking one leaves the other field visible',
    (WidgetTester tester) async {
      await tester.pumpWidget(wrapWithApp(const QuotaCalculatorScreen()));

      await tester.enterText(find.byKey(const Key('priceMonth')), '1000');
      await tester.enterText(find.byKey(const Key('roomQuantity')), '1');
      await tester.enterText(find.byKey(const Key('vatPercent')), '0');
      await tester.enterText(find.byKey(const Key('cd')), '100');
      await tester.enterText(find.byKey(const Key('camera')), '50');
      await tester.enterText(find.byKey(const Key('deposit')), '0');
      await tester.pumpAndSettle();

      // Yearly = 1000 * 12 * 1 = 12000; plus C.D 100 + Camera 50 = 12150.
      expect(find.text('12,150 \$'), findsOneWidget);
      expect(find.byKey(const Key('cd')), findsOneWidget);
      expect(find.byKey(const Key('camera')), findsOneWidget);

      // Uncheck only the C.D checkbox - the Camera field and its amount stay.
      await tester.ensureVisible(find.byKey(const Key('includeCdCheckbox')));
      await tester.tap(find.byKey(const Key('includeCdCheckbox')));
      await tester.pumpAndSettle();

      expect(find.byKey(const Key('cd')), findsNothing);
      expect(find.byKey(const Key('camera')), findsOneWidget);
      // Yearly 12000 + Camera 50 = 12050.
      expect(find.text('12,050 \$'), findsOneWidget);

      // Now also uncheck Camera - both fields gone, total back to base yearly.
      await tester.ensureVisible(find.byKey(const Key('includeCameraCheckbox')));
      await tester.tap(find.byKey(const Key('includeCameraCheckbox')));
      await tester.pumpAndSettle();

      expect(find.byKey(const Key('cd')), findsNothing);
      expect(find.byKey(const Key('camera')), findsNothing);
      expect(find.text('12,000 \$'), findsNWidgets(2));
    },
  );

  testWidgets('Refundable deposit is treated as per-room and multiplied by quantity', (WidgetTester tester) async {
    await tester.pumpWidget(wrapWithApp(const QuotaCalculatorScreen()));

    await tester.enterText(find.byKey(const Key('priceMonth')), '1000');
    await tester.enterText(find.byKey(const Key('roomQuantity')), '2');
    await tester.enterText(find.byKey(const Key('vatPercent')), '0');
    await tester.enterText(find.byKey(const Key('cd')), '0');
    await tester.enterText(find.byKey(const Key('camera')), '0');
    await tester.enterText(find.byKey(const Key('deposit')), '1500');
    await tester.pumpAndSettle();

    // Yearly = 1000 * 12 * 2 = 24000; deposit is per-room: 1500 * 2 rooms = 3000.
    expect(find.text('3,000 \$'), findsOneWidget);
    expect(find.text('27,000 \$'), findsOneWidget);
  });

  testWidgets('New Quotation button clears the form for the next customer', (WidgetTester tester) async {
    await tester.pumpWidget(wrapWithApp(const QuotaCalculatorScreen()));

    await tester.enterText(find.byKey(const Key('customerName')), 'Someone');
    await tester.enterText(find.byKey(const Key('priceMonth')), '1000');
    await tester.enterText(find.byKey(const Key('roomQuantity')), '2');
    await tester.enterText(find.byKey(const Key('vatPercent')), '15');
    await tester.pumpAndSettle();

    await tester.tap(find.byKey(const Key('newQuotationButton')));
    await tester.pumpAndSettle();

    final nameField = tester.widget<TextField>(find.byKey(const Key('customerName')));
    expect(nameField.controller!.text, isEmpty);
    final priceField = tester.widget<TextField>(find.byKey(const Key('priceMonth')));
    expect(priceField.controller!.text, isEmpty);
    // The VAT % field resets to its 5% default rather than being cleared,
    // since it's meant to be a sensible starting point, not a blank input.
    final vatField = tester.widget<TextField>(find.byKey(const Key('vatPercent')));
    expect(vatField.controller!.text, '5');

    expect(find.text('0 \$'), findsWidgets);
  });

  testWidgets('PDF share is invoked when export button is tapped', (WidgetTester tester) async {
    final fakeSharer = FakePdfSharer();

    final logoBytes = Uint8List.fromList(tinyPngBytes);
    final regularFontBytes = File('assets/fonts/Tajawal-Regular.ttf').readAsBytesSync();
    final boldFontBytes = File('assets/fonts/Tajawal-Bold.ttf').readAsBytesSync();
    final assetBundle = TestAssetBundle({
      'assets/logo.png': logoBytes.buffer.asByteData(),
      'assets/fonts/Tajawal-Regular.ttf': regularFontBytes.buffer.asByteData(),
      'assets/fonts/Tajawal-Bold.ttf': boldFontBytes.buffer.asByteData(),
    });

    await tester.pumpWidget(wrapWithApp(
      QuotaCalculatorScreen(pdfSharer: fakeSharer, assetBundle: assetBundle),
    ));

    await tester.enterText(find.byKey(const Key('customerName')), 'أحمد محمود');
    await tester.ensureVisible(find.text('Export PDF and Share'));
    await tester.tap(find.text('Export PDF and Share'));
    await tester.pumpAndSettle();

    expect(fakeSharer.callCount, 1);
    expect(fakeSharer.lastFilename, 'Quotation_أحمد محمود.pdf');
    expect(fakeSharer.lastBytes, isNotNull);
  });

  testWidgets('Choosing a logo updates the preview and can be reset', (WidgetTester tester) async {
    final logoBytes = Uint8List.fromList(tinyPngBytes);

    final settings = AppSettings(
      locale: const Locale('en'),
      companyName: 'Test Co',
      companyPhone: '0000000000',
      companyEmail: 'test@test.com',
      companyWebsite: '',
    );

    await tester.pumpWidget(
      ChangeNotifierProvider<AppSettings>.value(
        value: settings,
        child: MaterialApp(
          locale: const Locale('en'),
          supportedLocales: const [Locale('en'), Locale('ar')],
          localizationsDelegates: const [
            GlobalMaterialLocalizations.delegate,
            GlobalWidgetsLocalizations.delegate,
            GlobalCupertinoLocalizations.delegate,
          ],
          home: SettingsScreen(logoPicker: FakeLogoPicker(logoBytes)),
        ),
      ),
    );

    expect(find.byKey(const Key('resetLogoButton')), findsNothing);
    expect(settings.logoBytes, isNull);

    await tester.tap(find.byKey(const Key('chooseLogoButton')));
    await tester.pumpAndSettle();

    expect(settings.logoBytes, logoBytes);
    expect(find.byKey(const Key('resetLogoButton')), findsOneWidget);

    await tester.tap(find.byKey(const Key('resetLogoButton')));
    await tester.pumpAndSettle();

    expect(settings.logoBytes, isNull);
    expect(find.byKey(const Key('resetLogoButton')), findsNothing);
  });

  testWidgets('Selecting a template fills the price fields', (WidgetTester tester) async {
    const template = QuotationTemplate(
      id: 'vip',
      templateName: 'VIP Room Test',
      roomType: 'Large',
      priceMonth: 9000,
      vatPercent: 6,
      cd: 100,
      camera: 50,
      deposit: 2000,
      numberOfPayments: 1,
    );

    await tester.pumpWidget(wrapWithApp(
      const QuotaCalculatorScreen(),
      templateStore: TemplateStore.withTemplates(const [template]),
    ));

    await tester.tap(find.byKey(const Key('templateDropdown')));
    await tester.pumpAndSettle();
    await tester.tap(find.text('VIP Room Test').last);
    await tester.pumpAndSettle();

    final priceField = tester.widget<TextField>(find.byKey(const Key('priceMonth')));
    expect(priceField.controller!.text, '9000');
    final vatField = tester.widget<TextField>(find.byKey(const Key('vatPercent')));
    expect(vatField.controller!.text, '6');
    final depositField = tester.widget<TextField>(find.byKey(const Key('deposit')));
    expect(depositField.controller!.text, '2000');

    // numberOfPayments: 1 from the template collapses the payment schedule to one row.
    expect(find.text('Single Payment:'), findsOneWidget);
    expect(find.text('Payment 1:'), findsNothing);
  });

  testWidgets('Saving a brand-new template enables the Save button and adds it to the dropdown', (WidgetTester tester) async {
    final templateStore = TemplateStore.withTemplates(const []);

    await tester.pumpWidget(wrapWithApp(
      const QuotaCalculatorScreen(),
      templateStore: templateStore,
    ));

    await tester.enterText(find.byKey(const Key('priceMonth')), '3000');
    await tester.pumpAndSettle();

    await tester.tap(find.byKey(const Key('saveTemplateButton')));
    await tester.pumpAndSettle();

    // The Save button starts disabled until a name is typed.
    var saveButton = tester.widget<TextButton>(find.byKey(const Key('confirmSaveTemplateButton')));
    expect(saveButton.onPressed, isNull);

    await tester.enterText(find.byKey(const Key('templateNameField')), 'My New Template');
    await tester.pumpAndSettle();

    saveButton = tester.widget<TextButton>(find.byKey(const Key('confirmSaveTemplateButton')));
    expect(saveButton.onPressed, isNotNull);

    await tester.tap(find.byKey(const Key('confirmSaveTemplateButton')));
    await tester.pumpAndSettle();

    expect(templateStore.templates.length, 1);
    expect(templateStore.templates.single.templateName, 'My New Template');
    expect(find.text('My New Template'), findsOneWidget);
  });

  testWidgets('Exporting a PDF also saves an entry to the archive', (WidgetTester tester) async {
    final fakeSharer = FakePdfSharer();
    final archiveStore = ArchiveStore.withQuotations(const []);

    final logoBytes = Uint8List.fromList(tinyPngBytes);
    final regularFontBytes = File('assets/fonts/Tajawal-Regular.ttf').readAsBytesSync();
    final boldFontBytes = File('assets/fonts/Tajawal-Bold.ttf').readAsBytesSync();
    final assetBundle = TestAssetBundle({
      'assets/logo.png': logoBytes.buffer.asByteData(),
      'assets/fonts/Tajawal-Regular.ttf': regularFontBytes.buffer.asByteData(),
      'assets/fonts/Tajawal-Bold.ttf': boldFontBytes.buffer.asByteData(),
    });

    await tester.pumpWidget(wrapWithApp(
      QuotaCalculatorScreen(pdfSharer: fakeSharer, assetBundle: assetBundle),
      archiveStore: archiveStore,
    ));

    await tester.enterText(find.byKey(const Key('customerName')), 'أحمد محمود');
    await tester.ensureVisible(find.text('Export PDF and Share'));
    await tester.tap(find.text('Export PDF and Share'));
    await tester.pumpAndSettle();

    expect(archiveStore.quotations.length, 1);
    expect(archiveStore.quotations.single.customerName, 'أحمد محمود');
    expect(archiveStore.quotations.single.quotaNumber, startsWith('QT-'));
  });

  testWidgets('Loading a quotation from the archive populates the form', (WidgetTester tester) async {
    final savedQuotation = SavedQuotation(
      id: 'q1',
      quotaNumber: 'QT-2026-005',
      customerName: 'Sara Ali',
      createdAt: DateTime(2026, 5, 1),
      roomType: 'Medium',
      quantity: 3,
      priceMonth: 6000,
      vat: 700,
      cd: 150,
      camera: 90,
      deposit: 1800,
      numberOfPayments: 1,
      yearlyPrice: 216000,
      finalPrice: 218740,
    );
    final archiveStore = ArchiveStore.withQuotations([savedQuotation]);

    await tester.pumpWidget(wrapWithApp(
      const QuotaCalculatorScreen(),
      archiveStore: archiveStore,
    ));

    await tester.tap(find.byKey(const Key('archiveButton')));
    await tester.pumpAndSettle();

    expect(find.text('QT-2026-005'), findsOneWidget);
    expect(find.text('Sara Ali'), findsOneWidget);

    await tester.tap(find.byKey(Key('loadButton_${savedQuotation.id}')));
    await tester.pumpAndSettle();

    final nameField = tester.widget<TextField>(find.byKey(const Key('customerName')));
    expect(nameField.controller!.text, 'Sara Ali');
    final qtyField = tester.widget<TextField>(find.byKey(const Key('roomQuantity')));
    expect(qtyField.controller!.text, '3');
  });

  testWidgets('Deleting a quotation from the archive removes it after confirmation', (WidgetTester tester) async {
    final quotation = SavedQuotation(
      id: 'q9',
      quotaNumber: 'QT-2026-009',
      customerName: 'Delete Me',
      createdAt: DateTime(2026, 3, 1),
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
    final archiveStore = ArchiveStore.withQuotations([quotation]);

    await tester.pumpWidget(wrapWithApp(
      const ArchiveScreen(),
      archiveStore: archiveStore,
    ));

    expect(find.text('QT-2026-009'), findsOneWidget);

    await tester.tap(find.byKey(Key('deleteButton_${quotation.id}')));
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const Key('confirmDeleteButton')));
    await tester.pumpAndSettle();

    expect(find.text('QT-2026-009'), findsNothing);
    expect(archiveStore.quotations, isEmpty);
  });

  testWidgets('Notes fields are pre-filled with the default template when no custom notes are saved', (WidgetTester tester) async {
    final settings = AppSettings(
      locale: const Locale('en'),
      companyName: 'Test Co',
      companyPhone: '0000000000',
      companyEmail: 'test@test.com',
      companyWebsite: '',
    );

    await tester.pumpWidget(
      ChangeNotifierProvider<AppSettings>.value(
        value: settings,
        child: MaterialApp(
          locale: const Locale('en'),
          supportedLocales: const [Locale('en'), Locale('ar')],
          localizationsDelegates: const [
            GlobalMaterialLocalizations.delegate,
            GlobalWidgetsLocalizations.delegate,
            GlobalCupertinoLocalizations.delegate,
          ],
          home: const SettingsScreen(),
        ),
      ),
    );

    final notesEnField = tester.widget<TextField>(find.byKey(const Key('notesEnField')));
    expect(notesEnField.controller!.text, AppLocalizations.defaultNotesTemplateEn);
    final notesArField = tester.widget<TextField>(find.byKey(const Key('notesArField')));
    expect(notesArField.controller!.text, AppLocalizations.defaultNotesTemplateAr);
  });

  testWidgets('Editing and resetting custom notes in Settings persists to AppSettings', (WidgetTester tester) async {
    final settings = AppSettings(
      locale: const Locale('en'),
      companyName: 'Test Co',
      companyPhone: '0000000000',
      companyEmail: 'test@test.com',
      companyWebsite: '',
    );

    await tester.pumpWidget(
      ChangeNotifierProvider<AppSettings>.value(
        value: settings,
        child: MaterialApp(
          locale: const Locale('en'),
          supportedLocales: const [Locale('en'), Locale('ar')],
          localizationsDelegates: const [
            GlobalMaterialLocalizations.delegate,
            GlobalWidgetsLocalizations.delegate,
            GlobalCupertinoLocalizations.delegate,
          ],
          home: const SettingsScreen(),
        ),
      ),
    );

    await tester.enterText(find.byKey(const Key('notesEnField')), 'Custom note line one\nCustom note line two');
    await tester.ensureVisible(find.text('Save Settings'));
    await tester.tap(find.text('Save Settings'));
    await tester.pumpAndSettle();

    expect(settings.customNotesEn, 'Custom note line one\nCustom note line two');

    await tester.ensureVisible(find.byKey(const Key('resetNotesEnButton')));
    await tester.tap(find.byKey(const Key('resetNotesEnButton')));
    await tester.pumpAndSettle();
    await tester.ensureVisible(find.text('Save Settings'));
    await tester.tap(find.text('Save Settings'));
    await tester.pumpAndSettle();

    expect(settings.customNotesEn, AppLocalizations.defaultNotesTemplateEn);
  });

  testWidgets('Settings screen saves company info and switches language to Arabic', (WidgetTester tester) async {
    final settings = AppSettings(
      locale: const Locale('en'),
      companyName: 'Old Co',
      companyPhone: '111',
      companyEmail: 'old@test.com',
      companyWebsite: 'old.example.com',
    );

    await tester.pumpWidget(
      ChangeNotifierProvider<AppSettings>.value(
        value: settings,
        child: MaterialApp(
          locale: const Locale('en'),
          supportedLocales: const [Locale('en'), Locale('ar')],
          localizationsDelegates: const [
            GlobalMaterialLocalizations.delegate,
            GlobalWidgetsLocalizations.delegate,
            GlobalCupertinoLocalizations.delegate,
          ],
          home: const SettingsScreen(),
        ),
      ),
    );

    await tester.enterText(find.byKey(const Key('companyNameField')), 'New Rentals Co');
    await tester.enterText(find.byKey(const Key('companyPhoneField')), '0599123456');
    await tester.enterText(find.byKey(const Key('companyEmailField')), 'new@rentals.com');
    await tester.enterText(find.byKey(const Key('companyWebsiteField')), 'www.new-rentals.com');

    await tester.ensureVisible(find.byKey(const Key('languageArabicRadio')));
    await tester.tap(find.byKey(const Key('languageArabicRadio')));
    await tester.pumpAndSettle();

    await tester.ensureVisible(find.text('Save Settings'));
    await tester.tap(find.text('Save Settings'));
    await tester.pumpAndSettle();

    expect(settings.companyName, 'New Rentals Co');
    expect(settings.companyPhone, '0599123456');
    expect(settings.companyEmail, 'new@rentals.com');
    expect(settings.companyWebsite, 'www.new-rentals.com');
    expect(settings.locale.languageCode, 'ar');
  });

  testWidgets('Archive search filters quotations by customer name', (WidgetTester tester) async {
    final first = SavedQuotation(
      id: 'a1',
      quotaNumber: 'QT-2026-101',
      customerName: 'Ahmed Khaled',
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
    final second = SavedQuotation(
      id: 'a2',
      quotaNumber: 'QT-2026-102',
      customerName: 'Sara Ali',
      createdAt: DateTime(2026, 1, 2),
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
    final archiveStore = ArchiveStore.withQuotations([first, second]);

    await tester.pumpWidget(wrapWithApp(
      const ArchiveScreen(),
      archiveStore: archiveStore,
    ));

    expect(find.text('Ahmed Khaled'), findsOneWidget);
    expect(find.text('Sara Ali'), findsOneWidget);

    await tester.enterText(find.byKey(const Key('archiveSearchField')), 'Sara');
    await tester.pumpAndSettle();

    expect(find.text('Sara Ali'), findsOneWidget);
    expect(find.text('Ahmed Khaled'), findsNothing);

    await tester.enterText(find.byKey(const Key('archiveSearchField')), 'QT-2026-101');
    await tester.pumpAndSettle();

    expect(find.text('Ahmed Khaled'), findsOneWidget);
    expect(find.text('Sara Ali'), findsNothing);
  });

  testWidgets(
    'Full flow: select template -> edit customer name -> generate quota -> saved to archive + PDF produced',
    (WidgetTester tester) async {
      const template = QuotationTemplate(
        id: 'vip',
        templateName: 'VIP Room',
        roomType: 'Large',
        priceMonth: 7500,
        cd: 100,
        camera: 50,
        deposit: 2000,
        numberOfPayments: 2,
      );
      final templateStore = TemplateStore.withTemplates(const [template]);
      final archiveStore = ArchiveStore.withQuotations(const []);
      final fakeSharer = FakePdfSharer();

      final logoBytes = Uint8List.fromList(tinyPngBytes);
      final regularFontBytes = File('assets/fonts/Tajawal-Regular.ttf').readAsBytesSync();
      final boldFontBytes = File('assets/fonts/Tajawal-Bold.ttf').readAsBytesSync();
      final assetBundle = TestAssetBundle({
        'assets/logo.png': logoBytes.buffer.asByteData(),
        'assets/fonts/Tajawal-Regular.ttf': regularFontBytes.buffer.asByteData(),
        'assets/fonts/Tajawal-Bold.ttf': boldFontBytes.buffer.asByteData(),
      });

      await tester.pumpWidget(wrapWithApp(
        QuotaCalculatorScreen(pdfSharer: fakeSharer, assetBundle: assetBundle),
        templateStore: templateStore,
        archiveStore: archiveStore,
      ));

      // 1. Select the ready-made template from the dropdown.
      await tester.tap(find.byKey(const Key('templateDropdown')));
      await tester.pumpAndSettle();
      await tester.tap(find.text('VIP Room').last);
      await tester.pumpAndSettle();

      final priceField = tester.widget<TextField>(find.byKey(const Key('priceMonth')));
      expect(priceField.controller!.text, '7500');

      // 2. Edit the customer name.
      await tester.enterText(find.byKey(const Key('customerName')), 'Flow Test Customer');
      await tester.pumpAndSettle();

      // 3. Generate the quotation (export PDF + save to archive).
      await tester.ensureVisible(find.text('Export PDF and Share'));
      await tester.tap(find.text('Export PDF and Share'));
      await tester.pumpAndSettle();

      // 4. Confirm it was saved to the archive and a PDF was produced.
      expect(archiveStore.quotations.length, 1);
      expect(archiveStore.quotations.single.customerName, 'Flow Test Customer');
      expect(archiveStore.quotations.single.quotaNumber, startsWith('QT-'));
      expect(fakeSharer.callCount, 1);
      expect(fakeSharer.lastBytes, isNotNull);
    },
  );
}
