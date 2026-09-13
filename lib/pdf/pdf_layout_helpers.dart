import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;

import 'quotation_pdf_builder.dart' show richText;

/// A colored bilingual section header bar (e.g. "Tenant Information /
/// معلومات المستأجر"), matching the sample tenancy-contract's banded section
/// headers. Shared by lib/pdf/contract_pdf_builder.dart; kept generic enough
/// for a future quotation-PDF redesign to reuse without forcing one now.
pw.Widget sectionHeaderBar(String labelEn, String labelAr, {PdfColor color = PdfColors.teal700}) {
  return pw.Container(
    width: double.infinity,
    color: color,
    padding: const pw.EdgeInsets.symmetric(horizontal: 8, vertical: 6),
    child: pw.Row(
      mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
      children: [
        richText(labelEn, style: const pw.TextStyle(fontSize: 11, color: PdfColors.white, fontWeight: pw.FontWeight.bold)),
        richText(labelAr, style: const pw.TextStyle(fontSize: 11, color: PdfColors.white, fontWeight: pw.FontWeight.bold)),
      ],
    ),
  );
}

/// One row of a [bilingualInfoTable]: English label/value on the left,
/// Arabic value/label on the right — matching the sample's column order
/// (English reads left-to-right in its own block; the Arabic block mirrors
/// it, value then label, so the label still lands nearest the page's right
/// edge for RTL reading).
typedef BilingualRow = ({String labelEn, String valueEn, String valueAr, String labelAr});

/// A 4-column bordered table: EN label | EN value | AR value | AR label —
/// see [BilingualRow]. Used for the sample's Owner/Tenant/Contract info
/// tables (three per contract, each under its own [sectionHeaderBar]).
pw.Widget bilingualInfoTable(List<BilingualRow> rows) {
  return pw.Table(
    border: pw.TableBorder.all(color: PdfColors.grey300),
    columnWidths: const {
      0: pw.FlexColumnWidth(22),
      1: pw.FlexColumnWidth(28),
      2: pw.FlexColumnWidth(28),
      3: pw.FlexColumnWidth(22),
    },
    children: rows.map((row) {
      pw.Widget cell(String text, {required bool bold, required pw.Alignment align}) => pw.Container(
            padding: const pw.EdgeInsets.symmetric(horizontal: 6, vertical: 5),
            alignment: align,
            child: richText(
              text,
              style: pw.TextStyle(fontSize: 9.5, fontWeight: bold ? pw.FontWeight.bold : pw.FontWeight.normal),
              alignment: align == pw.Alignment.centerRight ? pw.WrapAlignment.end : pw.WrapAlignment.start,
            ),
          );
      return pw.TableRow(children: [
        cell(row.labelEn, bold: true, align: pw.Alignment.centerLeft),
        cell(row.valueEn, bold: false, align: pw.Alignment.centerLeft),
        cell(row.valueAr, bold: false, align: pw.Alignment.centerRight),
        cell(row.labelAr, bold: true, align: pw.Alignment.centerRight),
      ]);
    }).toList(),
  );
}

/// A manual checkbox glyph — the `pdf` package has no native checkbox
/// widget. Used for the sample's Room/Warehouse/Shop leased-property-type
/// selection.
pw.Widget checkboxWithLabel(String label, {required bool checked}) {
  return pw.Row(
    mainAxisSize: pw.MainAxisSize.min,
    children: [
      pw.Container(
        width: 12,
        height: 12,
        alignment: pw.Alignment.center,
        decoration: pw.BoxDecoration(border: pw.Border.all(color: PdfColors.black, width: 0.8)),
        child: checked ? pw.Text('X', style: const pw.TextStyle(fontSize: 9)) : null,
      ),
      pw.SizedBox(width: 4),
      richText(label, style: const pw.TextStyle(fontSize: 9.5)),
    ],
  );
}
