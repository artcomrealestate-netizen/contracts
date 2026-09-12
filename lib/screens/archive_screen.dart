import 'dart:typed_data';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart' show rootBundle;
import 'package:flutter_riverpod/flutter_riverpod.dart' hide Provider;
import 'package:provider/provider.dart';

import '../features/quotations/presentation/quotation_providers.dart';
import '../main.dart';
import '../models/saved_quotation.dart';
import '../pdf/quotation_pdf_builder.dart';

String _twoDigits(int n) => n.toString().padLeft(2, '0');

String formatQuotationDate(DateTime date) => '${date.year}-${_twoDigits(date.month)}-${_twoDigits(date.day)}';

class ArchiveScreen extends ConsumerStatefulWidget {
  final PdfSharer? pdfSharer;
  final AssetBundle? assetBundle;

  const ArchiveScreen({super.key, this.pdfSharer, this.assetBundle});

  @override
  ConsumerState<ArchiveScreen> createState() => _ArchiveScreenState();
}

class _ArchiveScreenState extends ConsumerState<ArchiveScreen> {
  final _searchController = TextEditingController();
  String _query = '';

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  Future<void> _shareQuotation(SavedQuotation quotation) async {
    final settings = Provider.of<AppSettings>(context, listen: false);
    final bundle = widget.assetBundle ?? rootBundle;

    final Uint8List bytes;
    if (quotation.contractType == 'warehouse') {
      // Warehouse fields are stored as raw rates, so every total is
      // recomputed fresh from them (mirroring the room quotation's
      // recompute-on-share pattern below), rather than trusting a frozen
      // cd/camera/deposit total the way room quotations do.
      final totalRent = calculateWarehouseRent(quotation.pricePerSqft, quotation.area);
      final managementFee = calculateManagementFee(totalRent, quotation.managementPercent);
      final civilDefense = calculateWarehouseCivilDefense(quotation.civilDefensePerShabraRate, quotation.quantity);
      final hemayaInsurance = calculateHemayaInsurance(quotation.hemayaInsuranceRate, quotation.quantity);
      final hemayaContractFee = calculateHemayaContractFee(quotation.hemayaContractFeeRate, quotation.quantity);
      final deposit = calculatePercentOfRent(totalRent, quotation.warehouseDepositPercent);
      final vat = calculateWarehouseVat(totalRent, quotation.contractCertFee, managementFee, quotation.vatPercent);
      final firstPaymentExtra =
          managementFee + civilDefense + quotation.contractCertFee + hemayaInsurance + hemayaContractFee + deposit + vat;
      final payments = splitPayments(totalRent, numberOfPayments: quotation.numberOfPayments, firstPaymentExtra: firstPaymentExtra);
      final finalPrice = calculateWarehouseFinalPrice(
        totalRent: totalRent,
        managementFee: managementFee,
        civilDefense: civilDefense,
        contractCertFee: quotation.contractCertFee,
        hemayaInsurance: hemayaInsurance,
        hemayaContractFee: hemayaContractFee,
        deposit: deposit,
        vat: vat,
      );

      bytes = await buildQuotationPdfBytes(
        settings: settings,
        bundle: bundle,
        customerName: quotation.customerName,
        roomType: quotation.roomType,
        quantity: quotation.quantity,
        vat: vat,
        vatPercent: quotation.vatPercent,
        cd: civilDefense,
        camera: 0,
        managementPercent: quotation.managementPercent,
        managementFee: managementFee,
        deposit: deposit,
        contractMonths: quotation.contractMonths,
        yearlyPrice: totalRent,
        finalPrice: finalPrice,
        payments: payments,
        isWarehouse: true,
        contractCertFee: quotation.contractCertFee,
        hemayaInsurance: hemayaInsurance,
        hemayaContractFee: hemayaContractFee,
        khana: quotation.khana,
        shabraNumbers: quotation.shabraNumbers,
      );
    } else {
      final managementFee = calculateManagementFee(quotation.yearlyPrice, quotation.managementPercent);
      // Same rule as a freshly generated quotation: deposit, C.D, camera,
      // management fee, and its VAT are bundled into the first installment;
      // only the rent total is split evenly across the rest.
      final firstPaymentExtra = quotation.vat + quotation.cd + quotation.camera + managementFee + quotation.deposit;
      final payments = splitPayments(
        quotation.yearlyPrice,
        numberOfPayments: quotation.numberOfPayments,
        firstPaymentExtra: firstPaymentExtra,
      );

      bytes = await buildQuotationPdfBytes(
        settings: settings,
        bundle: bundle,
        customerName: quotation.customerName,
        roomType: quotation.roomType,
        quantity: quotation.quantity,
        vat: quotation.vat,
        vatPercent: quotation.vatPercent,
        cd: quotation.cd,
        camera: quotation.camera,
        managementPercent: quotation.managementPercent,
        managementFee: managementFee,
        deposit: quotation.deposit,
        contractMonths: quotation.contractMonths,
        yearlyPrice: quotation.yearlyPrice,
        finalPrice: quotation.finalPrice,
        payments: payments,
      );
    }

    final sharer = widget.pdfSharer ?? PrintingPdfSharer();
    await sharer.sharePdf(bytes: bytes, filename: 'Quotation_${quotation.customerName}.pdf');
  }

  Future<void> _confirmDelete(SavedQuotation quotation) async {
    final strings = AppLocalizations.of(context);
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: Text(strings.confirmDeleteTitle),
        content: Text(strings.confirmDeleteMessage),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(dialogContext).pop(false),
            child: Text(strings.cancel),
          ),
          TextButton(
            key: const Key('confirmDeleteButton'),
            onPressed: () => Navigator.of(dialogContext).pop(true),
            child: Text(strings.delete),
          ),
        ],
      ),
    );
    if (confirmed == true) {
      await ref.read(quotationRepositoryProvider).delete(quotation.id);
    }
  }

  @override
  Widget build(BuildContext context) {
    final strings = AppLocalizations.of(context);
    final quotationsAsync = ref.watch(quotationsStreamProvider);
    final query = _query.trim().toLowerCase();

    return Directionality(
      textDirection: strings.isArabic ? TextDirection.rtl : TextDirection.ltr,
      child: Scaffold(
        appBar: AppBar(
          title: Text(strings.archiveTitle),
          backgroundColor: Colors.blue.shade700,
          foregroundColor: Colors.white,
        ),
        body: Column(
          children: [
            Padding(
              padding: const EdgeInsets.all(12.0),
              child: TextField(
                key: const Key('archiveSearchField'),
                controller: _searchController,
                decoration: InputDecoration(
                  hintText: strings.searchHint,
                  prefixIcon: const Icon(Icons.search),
                  border: OutlineInputBorder(borderRadius: BorderRadius.circular(8)),
                ),
                onChanged: (value) => setState(() => _query = value),
              ),
            ),
            Expanded(
              child: quotationsAsync.when(
                loading: () => const Center(child: CircularProgressIndicator()),
                error: (error, _) => Center(child: Text('Failed to load: $error')),
                data: (allQuotations) {
                  final quotations = allQuotations.where((q) {
                    if (query.isEmpty) return true;
                    return q.customerName.toLowerCase().contains(query) ||
                        q.quotaNumber.toLowerCase().contains(query) ||
                        (q.renumberedFrom?.toLowerCase().contains(query) ?? false);
                  }).toList();

                  if (quotations.isEmpty) {
                    return Center(child: Text(strings.noQuotations));
                  }
                  return ListView.builder(
                    padding: const EdgeInsets.symmetric(horizontal: 12),
                    itemCount: quotations.length,
                    itemBuilder: (context, index) {
                      final quotation = quotations[index];
                      return Card(
                        key: Key('quotationCard_${quotation.id}'),
                        margin: const EdgeInsets.only(bottom: 10),
                        child: Padding(
                          padding: const EdgeInsets.all(12.0),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.stretch,
                            children: [
                              Row(
                                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                children: [
                                  Column(
                                    crossAxisAlignment: CrossAxisAlignment.start,
                                    children: [
                                      Text(quotation.quotaNumber, style: const TextStyle(fontWeight: FontWeight.bold)),
                                      if (quotation.renumberedFrom != null)
                                        Text(
                                          'Originally ${quotation.renumberedFrom} — renumbered on migration',
                                          style: TextStyle(fontSize: 11, color: Colors.grey.shade600),
                                        ),
                                    ],
                                  ),
                                  Text(formatQuotationDate(quotation.createdAt)),
                                ],
                              ),
                              const SizedBox(height: 4),
                              Text(quotation.customerName, style: const TextStyle(fontSize: 16)),
                              const SizedBox(height: 4),
                              Text(
                                '${strings.finalPrice}: ${formatAmount(quotation.finalPrice)} ${strings.currencySymbol}',
                                style: TextStyle(fontWeight: FontWeight.bold, color: Colors.blue.shade900),
                              ),
                              const SizedBox(height: 4),
                              Row(
                                mainAxisAlignment: MainAxisAlignment.end,
                                children: [
                                  IconButton(
                                    key: Key('shareButton_${quotation.id}'),
                                    icon: const Icon(Icons.ios_share),
                                    tooltip: strings.shareQuotation,
                                    onPressed: () => _shareQuotation(quotation),
                                  ),
                                  IconButton(
                                    key: Key('loadButton_${quotation.id}'),
                                    icon: const Icon(Icons.edit_document),
                                    tooltip: strings.loadQuotation,
                                    onPressed: () => Navigator.of(context).pop(quotation),
                                  ),
                                  IconButton(
                                    key: Key('deleteButton_${quotation.id}'),
                                    icon: const Icon(Icons.delete_outline),
                                    tooltip: strings.delete,
                                    onPressed: () => _confirmDelete(quotation),
                                  ),
                                ],
                              ),
                            ],
                          ),
                        ),
                      );
                    },
                  );
                },
              ),
            ),
          ],
        ),
      ),
    );
  }
}
