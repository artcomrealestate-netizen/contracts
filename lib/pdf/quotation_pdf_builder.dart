import 'dart:typed_data';

import 'package:flutter/widgets.dart' show AssetBundle;
import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;

import '../main.dart';

final _arabicRange = RegExp(r'[؀-ۿ]');

bool _looksArabic(String text) => _arabicRange.hasMatch(text);

/// Renders [text] as a row of individually-measured word widgets rather than
/// one shaped string. This works around a rendering bug in the `pdf`
/// package where certain Arabic word-boundary spaces collapse visually,
/// gluing adjacent words together. It also fixes Arabic content rendering
/// correctly even when the surrounding document direction is LTR (e.g. an
/// Arabic customer name typed while the app language is English), since the
/// direction is chosen per string based on its own content rather than the
/// document-wide locale.
pw.Widget richText(
  String text, {
  pw.TextStyle? style,
  pw.WrapAlignment alignment = pw.WrapAlignment.start,
}) {
  final isArabic = _looksArabic(text);
  final words = text.split(' ').where((w) => w.isNotEmpty).toList();
  final fontSize = style?.fontSize ?? 12;
  return pw.Directionality(
    textDirection: isArabic ? pw.TextDirection.rtl : pw.TextDirection.ltr,
    child: pw.Wrap(
      alignment: alignment,
      spacing: fontSize * 0.6,
      runSpacing: fontSize * 0.3,
      children: words.map((w) => pw.Text(w, style: style)).toList(),
    ),
  );
}

Future<Uint8List> _loadLogoBytes(
  AppSettings settings,
  AssetBundle bundle,
) async {
  if (settings.logoBytes != null) {
    return settings.logoBytes!;
  }
  final logoData = await bundle.load('assets/logo.png');
  return logoData.buffer.asUint8List();
}

pw.Widget _tableCell(pw.Widget child, {bool header = false}) {
  return pw.Container(
    padding: const pw.EdgeInsets.symmetric(horizontal: 8, vertical: 8),
    decoration: header ? const pw.BoxDecoration(color: PdfColors.blue800) : null,
    child: child,
  );
}

Future<Uint8List> buildQuotationPdfBytes({
  required AppSettings settings,
  required AssetBundle bundle,
  required String customerName,
  required String roomType,
  required int quantity,
  required double vat,
  required double vatPercent,
  required double cd,
  required double camera,
  required double managementPercent,
  required double managementFee,
  required double deposit,
  required double yearlyPrice,
  required double finalPrice,
  required List<double> payments,
}) async {
  final logoBytes = await _loadLogoBytes(settings, bundle);
  final logoImage = pw.MemoryImage(logoBytes);
  final regularFontData = await bundle.load('assets/fonts/Tajawal-Regular.ttf');
  final boldFontData = await bundle.load('assets/fonts/Tajawal-Bold.ttf');
  final regularFont = pw.Font.ttf(regularFontData);
  final boldFont = pw.Font.ttf(boldFontData);
  final strings = AppLocalizations(settings.locale);
  final pdf = pw.Document(
    theme: pw.ThemeData.withFont(base: regularFont, bold: boldFont),
  );

  const headerStyle = pw.TextStyle(fontWeight: pw.FontWeight.bold, color: PdfColors.white, fontSize: 12);
  const cellLabelStyle = pw.TextStyle(fontSize: 12);
  const cellAmountStyle = pw.TextStyle(fontSize: 13);

  final managementRowLabel = strings.isArabic
      ? 'الإدارة (${formatAmount(managementPercent)}%)'
      : 'Management (${formatAmount(managementPercent)}%)';
  final vatRowLabel = strings.isArabic
      ? '${strings.managementVat} (${formatAmount(vatPercent)}%)'
      : '${strings.managementVat} (${formatAmount(vatPercent)}%)';

  final tableRows = <List<String>>[
    [strings.yearlyRent, formatAmount(yearlyPrice)],
    [managementRowLabel, formatAmount(managementFee)],
    if (vat > 0) [vatRowLabel, formatAmount(vat)],
    if (cd > 0) [strings.cdCharge, formatAmount(cd)],
    if (camera > 0) [strings.cameraFee, formatAmount(camera)],
    [strings.refundableDeposit, formatAmount(deposit)],
    [strings.finalPrice, formatAmount(finalPrice)],
  ];

  pdf.addPage(
    pw.MultiPage(
      pageFormat: PdfPageFormat.a4,
      margin: const pw.EdgeInsets.all(32),
      footer: (pw.Context context) {
        return pw.Align(
          alignment: pw.Alignment.bottomCenter,
          child: pw.Text(
            '${context.pageNumber} / ${context.pagesCount}',
            style: const pw.TextStyle(fontSize: 9, color: PdfColors.grey600),
          ),
        );
      },
      build: (pw.Context context) {
        return [pw.Directionality(
          textDirection: strings.isArabic
              ? pw.TextDirection.rtl
              : pw.TextDirection.ltr,
          child: pw.Column(
            crossAxisAlignment: pw.CrossAxisAlignment.start,
            children: [
              pw.Row(
                mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
                crossAxisAlignment: pw.CrossAxisAlignment.start,
                children: [
                  pw.Column(
                    crossAxisAlignment: pw.CrossAxisAlignment.start,
                    children: [
                      richText(
                        settings.companyName,
                        style: const pw.TextStyle(
                          fontSize: 18,
                          fontWeight: pw.FontWeight.bold,
                          color: PdfColors.blue900,
                        ),
                      ),
                      pw.Text('TEL: ${settings.companyPhone}', style: const pw.TextStyle(fontSize: 12)),
                      pw.Text('EMAIL: ${settings.companyEmail}', style: const pw.TextStyle(fontSize: 12)),
                      if (settings.companyWebsite.isNotEmpty)
                        pw.Text('WEB: ${settings.companyWebsite}', style: const pw.TextStyle(fontSize: 12)),
                    ],
                  ),
                  pw.Container(
                    height: 135,
                    width: 270,
                    child: pw.Image(logoImage, fit: pw.BoxFit.contain),
                  ),
                ],
              ),
              pw.SizedBox(height: 15),
              pw.Divider(thickness: 1.5, color: PdfColors.blue900),
              pw.SizedBox(height: 15),
              pw.Row(
                mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
                children: [
                  pw.Text(
                    strings.quotationOffer,
                    style: pw.TextStyle(
                      fontSize: 22,
                      fontWeight: pw.FontWeight.bold,
                      color: PdfColors.grey800,
                    ),
                  ),
                  pw.Text(
                    '${strings.dateLabel}: ${DateTime.now().toString().split(' ')[0]}',
                    style: const pw.TextStyle(fontSize: 12),
                  ),
                ],
              ),
              pw.SizedBox(height: 10),
              pw.Row(
                children: [
                  pw.Text('${strings.customerName}: ', style: const pw.TextStyle(fontSize: 14, fontWeight: pw.FontWeight.bold)),
                  richText(customerName, style: const pw.TextStyle(fontSize: 14, fontWeight: pw.FontWeight.bold)),
                ],
              ),
              pw.SizedBox(height: 4),
              pw.Text('${strings.propertyType}: $roomType (Qty: $quantity)', style: const pw.TextStyle(fontSize: 12)),
              pw.SizedBox(height: 15),
              pw.Table(
                border: pw.TableBorder.all(color: PdfColors.grey300),
                columnWidths: const {0: pw.FlexColumnWidth(35), 1: pw.FlexColumnWidth(65)},
                children: [
                  pw.TableRow(
                    decoration: const pw.BoxDecoration(color: PdfColors.blue800),
                    children: (strings.isArabic
                            ? [strings.tableAmount, strings.tableDescription]
                            : [strings.tableDescription, strings.tableAmount])
                        .map((h) => _tableCell(
                              pw.Align(
                                alignment: strings.isArabic ? pw.Alignment.centerRight : pw.Alignment.centerLeft,
                                child: richText(h, style: headerStyle, alignment: strings.isArabic ? pw.WrapAlignment.end : pw.WrapAlignment.start),
                              ),
                              header: true,
                            ))
                        .toList(),
                  ),
                  ...tableRows.map((row) {
                    final cells = strings.isArabic ? row.reversed.toList() : row;
                    return pw.TableRow(
                      children: cells.asMap().entries.map((entry) {
                        final isAmountColumn = strings.isArabic ? entry.key == 0 : entry.key == 1;
                        return _tableCell(
                          pw.Align(
                            alignment: strings.isArabic ? pw.Alignment.centerRight : pw.Alignment.centerLeft,
                            child: isAmountColumn
                                ? pw.Text(entry.value, style: cellAmountStyle)
                                : richText(entry.value, style: cellLabelStyle, alignment: strings.isArabic ? pw.WrapAlignment.end : pw.WrapAlignment.start),
                          ),
                        );
                      }).toList(),
                    );
                  }),
                ],
              ),
              pw.SizedBox(height: 15),
              pw.Container(
                padding: const pw.EdgeInsets.all(10),
                decoration: pw.BoxDecoration(
                  color: PdfColors.grey100,
                  border: pw.Border.all(color: PdfColors.grey300),
                ),
                child: pw.Column(
                  crossAxisAlignment: pw.CrossAxisAlignment.start,
                  children: [
                    richText(
                      payments.length == 1 ? '${strings.paymentSchedule} (${strings.singlePayment})' : strings.paymentSchedule,
                      style: const pw.TextStyle(fontWeight: pw.FontWeight.bold, fontSize: 12),
                    ),
                    pw.SizedBox(height: 5),
                    ...payments.asMap().entries.map(
                          (entry) => pw.Padding(
                            padding: const pw.EdgeInsets.only(bottom: 2),
                            child: pw.Row(
                              children: [
                                pw.Text('• ', style: const pw.TextStyle(fontSize: 12)),
                                richText(
                                  '${payments.length == 1 ? strings.singlePayment : strings.paymentLabel(entry.key)}:',
                                  style: const pw.TextStyle(fontSize: 12),
                                ),
                                pw.SizedBox(width: 4),
                                pw.Text('${formatAmount(entry.value)} \$', style: const pw.TextStyle(fontSize: 13)),
                              ],
                            ),
                          ),
                        ),
                  ],
                ),
              ),
              pw.SizedBox(height: 20),
              pw.Text(
                strings.notesAndConditions,
                style: pw.TextStyle(
                  fontWeight: pw.FontWeight.bold,
                  fontSize: 12,
                ),
              ),
              pw.SizedBox(height: 5),
              ...strings
                  .effectiveNotes(
                    customNotes: strings.isArabic ? settings.customNotesAr : settings.customNotesEn,
                    deposit: deposit,
                    managementFee: managementFee,
                    cd: cd,
                    camera: camera,
                    contractPeriodMonths: 12,
                    roomQuantity: quantity,
                  )
                  .map(
                    (note) => pw.Padding(
                      padding: const pw.EdgeInsets.only(bottom: 4),
                      child: richText(
                        note,
                        style: const pw.TextStyle(fontSize: 9.5),
                        alignment: strings.isArabic ? pw.WrapAlignment.end : pw.WrapAlignment.start,
                      ),
                    ),
                  ),
              pw.SizedBox(height: 20),
              pw.Row(
                mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
                children: [
                  pw.Column(
                    children: [
                      pw.Text(
                        strings.companyRepresentative,
                        style: pw.TextStyle(
                          fontSize: 11,
                          fontWeight: pw.FontWeight.bold,
                        ),
                      ),
                      pw.SizedBox(height: 30),
                      pw.Text(
                        '____________________',
                        style: const pw.TextStyle(fontSize: 11),
                      ),
                    ],
                  ),
                  pw.Column(
                    children: [
                      pw.Text(
                        strings.customerAcceptance,
                        style: pw.TextStyle(
                          fontSize: 11,
                          fontWeight: pw.FontWeight.bold,
                        ),
                      ),
                      pw.SizedBox(height: 30),
                      pw.Text(
                        '____________________',
                        style: const pw.TextStyle(fontSize: 11),
                      ),
                    ],
                  ),
                ],
              ),
            ],
          ),
        )];
      },
    ),
  );

  return pdf.save();
}
