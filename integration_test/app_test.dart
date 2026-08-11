// End-to-end flow test driven through the real widget tree:
// pick a template -> edit the customer name -> generate the quotation ->
// confirm it lands in the archive and a PDF was produced.
//
// Run with: flutter test integration_test/app_test.dart

import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:integration_test/integration_test.dart';
import 'package:provider/provider.dart';
import 'package:qouta_calculator/main.dart';
import 'package:qouta_calculator/models/quotation_template.dart';
import 'package:qouta_calculator/services/archive_store.dart';
import 'package:qouta_calculator/services/template_store.dart';
import 'package:shared_preferences/shared_preferences.dart';

class _FakePdfSharer implements PdfSharer {
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

const List<int> _tinyPngBytes = [
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

class _TestAssetBundle extends CachingAssetBundle {
  final Map<String, ByteData> _assets;

  _TestAssetBundle(this._assets);

  @override
  Future<ByteData> load(String key) async {
    final asset = _assets[key];
    if (asset != null) return asset;
    throw FlutterError('Asset not found: $key');
  }
}

void main() {
  IntegrationTestWidgetsFlutterBinding.ensureInitialized();

  testWidgets(
    'Full flow: select template -> edit customer name -> generate quota -> saved to archive + PDF produced',
    (WidgetTester tester) async {
      SharedPreferences.setMockInitialValues({});

      const template = QuotationTemplate(
        id: 'vip',
        templateName: 'VIP Room',
        roomType: 'Large',
        priceMonth: 7500,
        cd: 100,
        camera: 50,
        service: 0,
        managementPercent: 0,
        deposit: 2000,
        numberOfPayments: 2,
      );

      final settings = AppSettings(
        locale: const Locale('en'),
        companyName: 'Integration Test Co',
        companyPhone: '0000000000',
        companyEmail: 'test@test.com',
        companyWebsite: '',
      );
      final templateStore = TemplateStore.withTemplates(const [template]);
      final archiveStore = ArchiveStore.withQuotations(const []);
      final fakeSharer = _FakePdfSharer();

      final logoBytes = Uint8List.fromList(_tinyPngBytes);
      final regularFontBytes = File('assets/fonts/Tajawal-Regular.ttf').readAsBytesSync();
      final boldFontBytes = File('assets/fonts/Tajawal-Bold.ttf').readAsBytesSync();
      final assetBundle = _TestAssetBundle({
        'assets/logo.png': logoBytes.buffer.asByteData(),
        'assets/fonts/Tajawal-Regular.ttf': regularFontBytes.buffer.asByteData(),
        'assets/fonts/Tajawal-Bold.ttf': boldFontBytes.buffer.asByteData(),
      });

      await tester.pumpWidget(
        MultiProvider(
          providers: [
            ChangeNotifierProvider<AppSettings>.value(value: settings),
            ChangeNotifierProvider<TemplateStore>.value(value: templateStore),
            ChangeNotifierProvider<ArchiveStore>.value(value: archiveStore),
          ],
          child: MaterialApp(
            debugShowCheckedModeBanner: false,
            locale: const Locale('en'),
            supportedLocales: const [Locale('en'), Locale('ar')],
            localizationsDelegates: const [
              GlobalMaterialLocalizations.delegate,
              GlobalWidgetsLocalizations.delegate,
              GlobalCupertinoLocalizations.delegate,
            ],
            home: QuotaCalculatorScreen(pdfSharer: fakeSharer, assetBundle: assetBundle),
          ),
        ),
      );
      await tester.pumpAndSettle();

      // 1. Select the ready-made template from the dropdown.
      await tester.tap(find.byKey(const Key('templateDropdown')));
      await tester.pumpAndSettle();
      await tester.tap(find.text('VIP Room').last);
      await tester.pumpAndSettle();

      final priceField = tester.widget<TextField>(find.byKey(const Key('priceMonth')));
      expect(priceField.controller!.text, '7500');

      // 2. Edit the customer name.
      await tester.enterText(find.byKey(const Key('customerName')), 'Integration Test Customer');
      await tester.pumpAndSettle();

      // 3. Generate the quotation (export PDF + save to archive).
      await tester.ensureVisible(find.text('Export PDF and Share'));
      await tester.tap(find.text('Export PDF and Share'));
      await tester.pumpAndSettle();

      // 4. Confirm it was saved to the archive and a PDF was produced.
      expect(archiveStore.quotations.length, 1);
      expect(archiveStore.quotations.single.customerName, 'Integration Test Customer');
      expect(archiveStore.quotations.single.quotaNumber, startsWith('QT-'));

      expect(fakeSharer.callCount, 1);
      expect(fakeSharer.lastFilename, 'Quotation_Integration Test Customer.pdf');
      expect(fakeSharer.lastBytes, isNotNull);
      expect((fakeSharer.lastBytes as Uint8List).isNotEmpty, isTrue);
    },
  );
}
