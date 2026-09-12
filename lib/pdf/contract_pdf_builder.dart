import 'dart:typed_data';

import 'package:flutter/widgets.dart' show AssetBundle;
import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;

import '../features/contracts/domain/contract_clause.dart';
import '../main.dart';
import 'quotation_pdf_builder.dart' show richText;

Future<Uint8List> _loadLogoBytes(AppSettings settings, AssetBundle bundle) async {
  if (settings.logoBytes != null) return settings.logoBytes!;
  final logoData = await bundle.load('assets/logo.png');
  return logoData.buffer.asUint8List();
}

String _twoDigits(int n) => n.toString().padLeft(2, '0');

String _formatDate(DateTime? date) =>
    date == null ? '' : '${date.year}-${_twoDigits(date.month)}-${_twoDigits(date.day)}';

/// Renders a contract as a PDF — customer/property/template summary plus
/// every clause, numbered, in the same visual style as the quotation PDF
/// (TDD §28 describes a fuller Final Contract Data -> PDF -> Storage
/// pipeline for a FINALIZED contract specifically; this covers the export/
/// share need on its own, at any status, without that Storage/hash step).
Future<Uint8List> buildContractPdfBytes({
  required AppSettings settings,
  required AssetBundle bundle,
  required String contractNumber,
  required String statusLabel,
  required String customerName,
  required String propertyName,
  required int templateVersion,
  required List<ContractClause> clauses,
  DateTime? createdAt,
  DateTime? submittedAt,
  DateTime? approvedAt,
}) async {
  final logoBytes = await _loadLogoBytes(settings, bundle);
  final logoImage = pw.MemoryImage(logoBytes);
  final regularFontData = await bundle.load('assets/fonts/Tajawal-Regular.ttf');
  final boldFontData = await bundle.load('assets/fonts/Tajawal-Bold.ttf');
  final regularFont = pw.Font.ttf(regularFontData);
  final boldFont = pw.Font.ttf(boldFontData);
  final isArabic = settings.locale.languageCode == 'ar';
  final pdf = pw.Document(
    theme: pw.ThemeData.withFont(base: regularFont, bold: boldFont),
  );

  String t(String en, String ar) => isArabic ? ar : en;

  final infoRows = <List<String>>[
    [t('Customer', 'العميل'), customerName],
    [t('Property', 'العقار'), propertyName],
    [t('Template Version', 'نسخة القالب'), 'v$templateVersion'],
    if (createdAt != null) [t('Created', 'تاريخ الإنشاء'), _formatDate(createdAt)],
    if (submittedAt != null) [t('Submitted', 'تاريخ الإرسال'), _formatDate(submittedAt)],
    if (approvedAt != null) [t('Approved', 'تاريخ الموافقة'), _formatDate(approvedAt)],
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
        return [
          pw.Directionality(
            textDirection: isArabic ? pw.TextDirection.rtl : pw.TextDirection.ltr,
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
                    richText(
                      contractNumber,
                      style: pw.TextStyle(fontSize: 22, fontWeight: pw.FontWeight.bold, color: PdfColors.grey800),
                    ),
                    pw.Container(
                      padding: const pw.EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                      decoration: pw.BoxDecoration(
                        color: PdfColors.blue50,
                        border: pw.Border.all(color: PdfColors.blue800),
                      ),
                      child: richText(statusLabel, style: const pw.TextStyle(fontSize: 12, color: PdfColors.blue900)),
                    ),
                  ],
                ),
                pw.SizedBox(height: 15),
                pw.Table(
                  border: pw.TableBorder.all(color: PdfColors.grey300),
                  columnWidths: const {0: pw.FlexColumnWidth(35), 1: pw.FlexColumnWidth(65)},
                  children: infoRows.map((row) {
                    final cells = isArabic ? row.reversed.toList() : row;
                    return pw.TableRow(
                      children: cells.asMap().entries.map((entry) {
                        final isLabelColumn = isArabic ? entry.key == 1 : entry.key == 0;
                        return pw.Container(
                          padding: const pw.EdgeInsets.symmetric(horizontal: 8, vertical: 6),
                          child: pw.Align(
                            alignment: isArabic ? pw.Alignment.centerRight : pw.Alignment.centerLeft,
                            child: richText(
                              entry.value,
                              style: pw.TextStyle(
                                fontSize: 11,
                                fontWeight: isLabelColumn ? pw.FontWeight.bold : pw.FontWeight.normal,
                              ),
                              alignment: isArabic ? pw.WrapAlignment.end : pw.WrapAlignment.start,
                            ),
                          ),
                        );
                      }).toList(),
                    );
                  }).toList(),
                ),
                pw.SizedBox(height: 20),
                richText(
                  t('Clauses', 'البنود'),
                  style: pw.TextStyle(fontSize: 14, fontWeight: pw.FontWeight.bold),
                ),
                pw.SizedBox(height: 8),
                ...clauses.asMap().entries.map((entry) {
                  final index = entry.key + 1;
                  final clause = entry.value;
                  return pw.Padding(
                    padding: const pw.EdgeInsets.only(bottom: 12),
                    child: pw.Column(
                      crossAxisAlignment: pw.CrossAxisAlignment.start,
                      children: [
                        richText(
                          '$index. ${clause.title}',
                          style: const pw.TextStyle(fontSize: 12, fontWeight: pw.FontWeight.bold),
                          alignment: isArabic ? pw.WrapAlignment.end : pw.WrapAlignment.start,
                        ),
                        pw.SizedBox(height: 3),
                        richText(
                          clause.content,
                          style: const pw.TextStyle(fontSize: 10.5),
                          alignment: isArabic ? pw.WrapAlignment.end : pw.WrapAlignment.start,
                        ),
                      ],
                    ),
                  );
                }),
                pw.SizedBox(height: 30),
                pw.Row(
                  mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
                  children: [
                    pw.Column(
                      children: [
                        pw.Text(
                          t('Company Representative', 'ممثل الشركة'),
                          style: pw.TextStyle(fontSize: 11, fontWeight: pw.FontWeight.bold),
                        ),
                        pw.SizedBox(height: 30),
                        pw.Text('____________________', style: const pw.TextStyle(fontSize: 11)),
                      ],
                    ),
                    pw.Column(
                      children: [
                        pw.Text(
                          t('Customer Acceptance', 'موافقة العميل'),
                          style: pw.TextStyle(fontSize: 11, fontWeight: pw.FontWeight.bold),
                        ),
                        pw.SizedBox(height: 30),
                        pw.Text('____________________', style: const pw.TextStyle(fontSize: 11)),
                      ],
                    ),
                  ],
                ),
              ],
            ),
          ),
        ];
      },
    ),
  );

  return pdf.save();
}
