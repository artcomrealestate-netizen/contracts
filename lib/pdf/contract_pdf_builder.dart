import 'dart:typed_data';

import 'package:flutter/widgets.dart' show AssetBundle;
import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;

import '../features/company/domain/company_profile.dart';
import '../features/contracts/domain/clause_placeholder_resolver.dart';
import '../features/contracts/domain/contract.dart';
import '../features/contracts/domain/lease_terms.dart';
import '../features/customers/domain/customer.dart';
import '../features/properties/domain/property.dart';
import '../main.dart';
import 'pdf_layout_helpers.dart';
import 'quotation_pdf_builder.dart' show richText;

Future<Uint8List> _loadLogoBytes(
  CompanyProfile companyProfile,
  AppSettings settings,
  AssetBundle bundle,
) async {
  if (companyProfile.logoBytes != null) return companyProfile.logoBytes!;
  if (settings.logoBytes != null) return settings.logoBytes!;
  final logoData = await bundle.load('assets/logo.png');
  return logoData.buffer.asUint8List();
}

String _twoDigits(int n) => n.toString().padLeft(2, '0');

String _formatDate(DateTime? date) =>
    date == null ? '' : '${date.year}-${_twoDigits(date.month)}-${_twoDigits(date.day)}';

String _formatAedAmount(double? amount) {
  if (amount == null) return '';
  final formatted = amount.truncateToDouble() == amount ? amount.toStringAsFixed(0) : amount.toStringAsFixed(2);
  return '$formatted AED';
}

/// Renders a contract as a bilingual (Arabic + English, side by side) PDF
/// matching a real tenancy-contract layout: three colored-header info tables
/// (Owner/Lessor, Tenant, Contract/Property with leased-property-type
/// checkboxes), a signature block repeated on every page, and Terms &
/// Conditions as two full separate pages (Arabic, then English — same
/// clauses, same order), each clause resolved through
/// [resolvePlaceholders]. (TDD §28 describes a fuller Final Contract Data ->
/// PDF -> Storage pipeline for a FINALIZED contract specifically; this
/// covers the export/share need on its own, at any status, without that
/// Storage/hash step.)
Future<Uint8List> buildContractPdfBytes({
  required AppSettings settings,
  required CompanyProfile companyProfile,
  required AssetBundle bundle,
  required Contract contract,
  required Customer customer,
  required Property property,
}) async {
  final logoBytes = await _loadLogoBytes(companyProfile, settings, bundle);
  final logoImage = pw.MemoryImage(logoBytes);
  final regularFontData = await bundle.load('assets/fonts/Tajawal-Regular.ttf');
  final boldFontData = await bundle.load('assets/fonts/Tajawal-Bold.ttf');
  final regularFont = pw.Font.ttf(regularFontData);
  final boldFont = pw.Font.ttf(boldFontData);
  final pdf = pw.Document(
    theme: pw.ThemeData.withFont(base: regularFont, bold: boldFont),
  );

  final terms = contract.leaseTerms;
  final ctx = ContractMergeContext(
    customer: customer,
    property: property,
    contract: contract,
    leaseTerms: terms,
    companyProfile: companyProfile,
    companyName: settings.companyName,
    companyPhone: settings.companyPhone,
    companyEmail: settings.companyEmail,
  );

  final ownerRows = <BilingualRow>[
    (
      labelEn: "Owner's & Lessor Name",
      valueEn: companyProfile.ownerName ?? '',
      valueAr: companyProfile.ownerName ?? '',
      labelAr: 'أسم المالك / المؤجر',
    ),
    (
      labelEn: "Lessor's Emirates ID",
      valueEn: companyProfile.ownerEmiratesId ?? '',
      valueAr: companyProfile.ownerEmiratesId ?? '',
      labelAr: 'الهوية الإماراتية للمؤجر',
    ),
    (
      labelEn: "Lessor's Email",
      valueEn: settings.companyEmail,
      valueAr: settings.companyEmail,
      labelAr: 'البريد الإلكتروني للمؤجر',
    ),
  ];

  final tenantRows = <BilingualRow>[
    (labelEn: "Tenant's Name", valueEn: customer.displayName, valueAr: customer.displayName, labelAr: 'أسم المستأجر'),
    if ((customer.individual?.tradeName ?? '').isNotEmpty)
      (
        labelEn: 'Trade Name',
        valueEn: customer.individual!.tradeName!,
        valueAr: customer.individual!.tradeName!,
        labelAr: 'الأسم التجاري',
      ),
    (
      labelEn: "Tenant's Emirates ID",
      valueEn: customer.individual?.emiratesId ?? '',
      valueAr: customer.individual?.emiratesId ?? '',
      labelAr: 'الهوية الإماراتية للمستأجر',
    ),
    if (customer.company?.tradeLicenseNumber != null)
      (
        labelEn: 'Licensing No.',
        valueEn: customer.company!.tradeLicenseNumber!,
        valueAr: customer.company!.tradeLicenseNumber!,
        labelAr: 'رقم الترخيص',
      ),
    if (customer.company?.licensingAuthority != null)
      (
        labelEn: 'Licensing Authority',
        valueEn: customer.company!.licensingAuthority!,
        valueAr: customer.company!.licensingAuthority!,
        labelAr: 'سلطة الترخيص',
      ),
    (
      labelEn: "Tenant's Email",
      valueEn: customer.contact.email ?? '',
      valueAr: customer.contact.email ?? '',
      labelAr: 'البريد الإلكتروني للمستأجر',
    ),
    (
      labelEn: "Tenant's Phone",
      valueEn: customer.contact.phone ?? '',
      valueAr: customer.contact.phone ?? '',
      labelAr: 'رقم هاتف المستأجر',
    ),
    if (terms.numberOfCoOccupants != null)
      (
        labelEn: 'Number of Co-Occupants',
        valueEn: '${terms.numberOfCoOccupants}',
        valueAr: '${terms.numberOfCoOccupants}',
        labelAr: 'عدد القاطنين',
      ),
  ];

  String paymentModeLabel() => switch (terms.paymentMode) {
        PaymentMode.cheques => terms.numberOfCheques != null ? '${terms.numberOfCheques} Cheques' : 'Cheques',
        PaymentMode.bankTransfer => 'Bank Transfer',
      };

  final contractRows = <BilingualRow>[
    (labelEn: 'Building Name', valueEn: terms.buildingName ?? '', valueAr: terms.buildingName ?? '', labelAr: 'أسم المبنى'),
    (labelEn: 'Unit Number', valueEn: property.unitNumber ?? '', valueAr: property.unitNumber ?? '', labelAr: 'رقم الوحدة'),
    (
      labelEn: 'Area',
      valueEn: property.location.district ?? property.location.city ?? '',
      valueAr: property.location.district ?? property.location.city ?? '',
      labelAr: 'المنطقة',
    ),
    (
      labelEn: 'Commencement Date',
      valueEn: _formatDate(terms.commencementDate),
      valueAr: _formatDate(terms.commencementDate),
      labelAr: 'تاريخ بدء الإيجار',
    ),
    (
      labelEn: 'Expiry Date',
      valueEn: _formatDate(terms.expiryDate),
      valueAr: _formatDate(terms.expiryDate),
      labelAr: 'تاريخ إنتهاء الإيجار',
    ),
    (
      labelEn: 'Rent Amount Yearly',
      valueEn: _formatAedAmount(terms.yearlyRentAmount),
      valueAr: _formatAedAmount(terms.yearlyRentAmount),
      labelAr: 'مقدار بدل الإيجار السنوي',
    ),
    (
      labelEn: 'Purpose of Usage',
      valueEn: terms.purposeOfUsage ?? '',
      valueAr: terms.purposeOfUsage ?? '',
      labelAr: 'أغراض الإستعمال',
    ),
    (labelEn: 'Mode of Payment', valueEn: paymentModeLabel(), valueAr: paymentModeLabel(), labelAr: 'طريقة الدفع'),
    (
      labelEn: 'Insurance Allowance',
      valueEn: _formatAedAmount(terms.insuranceAllowance),
      valueAr: _formatAedAmount(terms.insuranceAllowance),
      labelAr: 'بدل تأمين',
    ),
    (
      labelEn: 'Management Fee & VAT',
      valueEn: [
        if (terms.managementFeeAmount != null) _formatAedAmount(terms.managementFeeAmount),
        if (terms.vatAmount != null) 'VAT ${_formatAedAmount(terms.vatAmount)}',
      ].join(' + '),
      valueAr: [
        if (terms.managementFeeAmount != null) _formatAedAmount(terms.managementFeeAmount),
        if (terms.vatAmount != null) 'VAT ${_formatAedAmount(terms.vatAmount)}',
      ].join(' + '),
      labelAr: 'رسم إدارة وضريبة القيمة المضافة',
    ),
  ];

  pw.Widget signatureBlock() => pw.Padding(
        padding: const pw.EdgeInsets.only(top: 8),
        child: pw.Table(
          border: const pw.TableBorder(top: pw.BorderSide(color: PdfColors.grey400, width: 0.5)),
          children: [
            pw.TableRow(children: [
              pw.Padding(
                padding: const pw.EdgeInsets.all(6),
                child: pw.Column(crossAxisAlignment: pw.CrossAxisAlignment.start, children: [
                  richText('Tenant Signature / توقيع المستأجر', style: const pw.TextStyle(fontSize: 8)),
                  pw.SizedBox(height: 10),
                  richText('Date / التاريخ: ____________', style: const pw.TextStyle(fontSize: 8)),
                ]),
              ),
              pw.Padding(
                padding: const pw.EdgeInsets.all(6),
                child: pw.Column(crossAxisAlignment: pw.CrossAxisAlignment.start, children: [
                  richText("Lessor's Signature / توقيع المؤجر", style: const pw.TextStyle(fontSize: 8)),
                  pw.SizedBox(height: 10),
                  richText('Date / التاريخ: ____________', style: const pw.TextStyle(fontSize: 8)),
                ]),
              ),
            ]),
          ],
        ),
      );

  pdf.addPage(
    pw.MultiPage(
      pageFormat: PdfPageFormat.a4,
      margin: const pw.EdgeInsets.all(28),
      footer: (pw.Context context) {
        return pw.Column(
          mainAxisSize: pw.MainAxisSize.min,
          children: [
            signatureBlock(),
            pw.SizedBox(height: 4),
            pw.Align(
              alignment: pw.Alignment.bottomCenter,
              child: pw.Text(
                '${context.pageNumber} / ${context.pagesCount}',
                style: const pw.TextStyle(fontSize: 9, color: PdfColors.grey600),
              ),
            ),
          ],
        );
      },
      build: (pw.Context context) {
        return [
          // Header banner — logo + company name prominent at the top,
          // matching the sample's branded header (logo-loading itself is
          // unchanged from before this rewrite, only its position/size).
          pw.Row(
            mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
            crossAxisAlignment: pw.CrossAxisAlignment.center,
            children: [
              pw.Container(height: 70, width: 140, child: pw.Image(logoImage, fit: pw.BoxFit.contain)),
              pw.Column(
                crossAxisAlignment: pw.CrossAxisAlignment.end,
                children: [
                  richText(settings.companyName,
                      style: const pw.TextStyle(fontSize: 20, fontWeight: pw.FontWeight.bold, color: PdfColors.teal900)),
                  pw.Text('${settings.companyPhone}  |  ${settings.companyEmail}',
                      style: const pw.TextStyle(fontSize: 10)),
                ],
              ),
            ],
          ),
          pw.SizedBox(height: 8),
          pw.Center(
            child: richText(
              'Tenancy Contract / عقد إيجار',
              style: pw.TextStyle(fontSize: 16, fontWeight: pw.FontWeight.bold, color: PdfColors.grey800),
            ),
          ),
          pw.SizedBox(height: 4),
          richText('Contract No: ${contract.contractNumber}', style: const pw.TextStyle(fontSize: 10)),
          pw.SizedBox(height: 12),

          sectionHeaderBar('Owner / Lessor Information', 'معلومات المالك/ المؤجر'),
          bilingualInfoTable(ownerRows),
          pw.SizedBox(height: 12),

          sectionHeaderBar('Tenant Information', 'معلومات المستأجر'),
          bilingualInfoTable(tenantRows),
          pw.SizedBox(height: 12),

          sectionHeaderBar('Contract / Property Information', 'معلومات العقد/العقار'),
          pw.Container(
            padding: const pw.EdgeInsets.symmetric(horizontal: 6, vertical: 6),
            decoration: const pw.BoxDecoration(border: pw.Border(bottom: pw.BorderSide(color: PdfColors.grey300))),
            child: pw.Row(
              mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
              children: [
                richText('Leased Property / العين المؤجرة:', style: const pw.TextStyle(fontSize: 9.5)),
                checkboxWithLabel('Room / غرفة', checked: terms.leasedPropertyType == LeasedPropertyType.room),
                checkboxWithLabel('Warehouse / شبرة', checked: terms.leasedPropertyType == LeasedPropertyType.warehouse),
                checkboxWithLabel('Shop / محل', checked: terms.leasedPropertyType == LeasedPropertyType.shop),
              ],
            ),
          ),
          bilingualInfoTable(contractRows),

          // Terms & Conditions — two full separate pages, Arabic then
          // English, same clauses/order, each resolved through
          // resolvePlaceholders. richText() (not bare pw.Text) for every
          // string here — see this function's doc comment on why.
          pw.NewPage(),
          pw.Directionality(
            textDirection: pw.TextDirection.rtl,
            child: pw.Column(
              crossAxisAlignment: pw.CrossAxisAlignment.start,
              children: [
                richText('الأحكام والشروط', style: pw.TextStyle(fontSize: 14, fontWeight: pw.FontWeight.bold)),
                pw.SizedBox(height: 8),
                ...contract.clauses.asMap().entries.map((entry) {
                  final clause = entry.value;
                  return pw.Padding(
                    padding: const pw.EdgeInsets.only(bottom: 10),
                    child: pw.Column(
                      crossAxisAlignment: pw.CrossAxisAlignment.start,
                      children: [
                        richText(
                          '${entry.key + 1}. ${resolvePlaceholders(clause.titleAr, ctx)}',
                          style: const pw.TextStyle(fontSize: 11, fontWeight: pw.FontWeight.bold),
                          alignment: pw.WrapAlignment.end,
                        ),
                        pw.SizedBox(height: 3),
                        richText(
                          resolvePlaceholders(clause.contentAr, ctx),
                          style: const pw.TextStyle(fontSize: 10),
                          alignment: pw.WrapAlignment.end,
                        ),
                      ],
                    ),
                  );
                }),
              ],
            ),
          ),

          pw.NewPage(),
          pw.Directionality(
            textDirection: pw.TextDirection.ltr,
            child: pw.Column(
              crossAxisAlignment: pw.CrossAxisAlignment.start,
              children: [
                richText('Terms and Conditions', style: pw.TextStyle(fontSize: 14, fontWeight: pw.FontWeight.bold)),
                pw.SizedBox(height: 8),
                ...contract.clauses.asMap().entries.map((entry) {
                  final clause = entry.value;
                  return pw.Padding(
                    padding: const pw.EdgeInsets.only(bottom: 10),
                    child: pw.Column(
                      crossAxisAlignment: pw.CrossAxisAlignment.start,
                      children: [
                        richText(
                          '${entry.key + 1}. ${resolvePlaceholders(clause.titleEn, ctx)}',
                          style: const pw.TextStyle(fontSize: 11, fontWeight: pw.FontWeight.bold),
                        ),
                        pw.SizedBox(height: 3),
                        richText(
                          resolvePlaceholders(clause.contentEn, ctx),
                          style: const pw.TextStyle(fontSize: 10),
                        ),
                      ],
                    ),
                  );
                }),
              ],
            ),
          ),
        ];
      },
    ),
  );

  return pdf.save();
}
