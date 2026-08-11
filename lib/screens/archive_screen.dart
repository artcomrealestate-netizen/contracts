import 'package:flutter/material.dart';
import 'package:flutter/services.dart' show rootBundle;
import 'package:provider/provider.dart';

import '../main.dart';
import '../models/saved_quotation.dart';
import '../pdf/quotation_pdf_builder.dart';
import '../services/archive_store.dart';

String _twoDigits(int n) => n.toString().padLeft(2, '0');

String formatQuotationDate(DateTime date) => '${date.year}-${_twoDigits(date.month)}-${_twoDigits(date.day)}';

class ArchiveScreen extends StatefulWidget {
  final PdfSharer? pdfSharer;
  final AssetBundle? assetBundle;

  const ArchiveScreen({super.key, this.pdfSharer, this.assetBundle});

  @override
  State<ArchiveScreen> createState() => _ArchiveScreenState();
}

class _ArchiveScreenState extends State<ArchiveScreen> {
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
    final payments = splitPayments(quotation.finalPrice, numberOfPayments: quotation.numberOfPayments);

    final bytes = await buildQuotationPdfBytes(
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
      managementFee: calculateManagementFee(quotation.yearlyPrice, quotation.managementPercent),
      deposit: quotation.deposit,
      yearlyPrice: quotation.yearlyPrice,
      finalPrice: quotation.finalPrice,
      payments: payments,
    );

    final sharer = widget.pdfSharer ?? PrintingPdfSharer();
    await sharer.sharePdf(bytes: bytes, filename: 'Quotation_${quotation.customerName}.pdf');
  }

  Future<void> _confirmDelete(SavedQuotation quotation) async {
    final strings = AppLocalizations.of(context);
    final archive = Provider.of<ArchiveStore>(context, listen: false);
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
      await archive.delete(quotation.id);
    }
  }

  @override
  Widget build(BuildContext context) {
    final strings = AppLocalizations.of(context);
    final archive = Provider.of<ArchiveStore>(context);
    final query = _query.trim().toLowerCase();
    final quotations = archive.quotations.where((q) {
      if (query.isEmpty) return true;
      return q.customerName.toLowerCase().contains(query) || q.quotaNumber.toLowerCase().contains(query);
    }).toList();

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
              child: quotations.isEmpty
                  ? Center(child: Text(strings.noQuotations))
                  : ListView.builder(
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
                                    Text(quotation.quotaNumber, style: const TextStyle(fontWeight: FontWeight.bold)),
                                    Text(formatQuotationDate(quotation.createdAt)),
                                  ],
                                ),
                                const SizedBox(height: 4),
                                Text(quotation.customerName, style: const TextStyle(fontSize: 16)),
                                const SizedBox(height: 4),
                                Text(
                                  '${strings.finalPrice}: ${formatAmount(quotation.finalPrice)} \$',
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
                    ),
            ),
          ],
        ),
      ),
    );
  }
}
