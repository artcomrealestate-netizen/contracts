import 'package:flutter/material.dart';

import '../domain/lease_terms.dart';

/// Lease-specific fields (property type, dates, rent, payment mode, fees...)
/// used identically from CreateContractScreen (before first save) and
/// ContractDetailScreen (post-creation, while still DRAFT) — see
/// LeaseTerms's doc comment for why these fields exist at all.
class LeaseTermsFormSection extends StatefulWidget {
  final LeaseTerms initial;
  final ValueChanged<LeaseTerms> onChanged;
  final bool enabled;

  const LeaseTermsFormSection({
    super.key,
    required this.initial,
    required this.onChanged,
    this.enabled = true,
  });

  @override
  State<LeaseTermsFormSection> createState() => _LeaseTermsFormSectionState();
}

class _LeaseTermsFormSectionState extends State<LeaseTermsFormSection> {
  late LeasedPropertyType _leasedPropertyType;
  late PaymentMode _paymentMode;
  late final TextEditingController _buildingNameController;
  DateTime? _commencementDate;
  DateTime? _expiryDate;
  late final TextEditingController _yearlyRentController;
  late final TextEditingController _purposeController;
  late final TextEditingController _numberOfChequesController;
  late final TextEditingController _insuranceController;
  late final TextEditingController _managementFeeController;
  late final TextEditingController _vatController;
  late final TextEditingController _coOccupantsController;

  @override
  void initState() {
    super.initState();
    final t = widget.initial;
    _leasedPropertyType = t.leasedPropertyType;
    _paymentMode = t.paymentMode;
    _buildingNameController = TextEditingController(text: t.buildingName ?? '');
    _commencementDate = t.commencementDate;
    _expiryDate = t.expiryDate;
    _yearlyRentController = TextEditingController(text: t.yearlyRentAmount?.toString() ?? '');
    _purposeController = TextEditingController(text: t.purposeOfUsage ?? '');
    _numberOfChequesController = TextEditingController(text: t.numberOfCheques?.toString() ?? '');
    _insuranceController = TextEditingController(text: t.insuranceAllowance?.toString() ?? '');
    _managementFeeController = TextEditingController(text: t.managementFeeAmount?.toString() ?? '');
    _vatController = TextEditingController(text: t.vatAmount?.toString() ?? '');
    _coOccupantsController = TextEditingController(text: t.numberOfCoOccupants?.toString() ?? '');
  }

  @override
  void dispose() {
    _buildingNameController.dispose();
    _yearlyRentController.dispose();
    _purposeController.dispose();
    _numberOfChequesController.dispose();
    _insuranceController.dispose();
    _managementFeeController.dispose();
    _vatController.dispose();
    _coOccupantsController.dispose();
    super.dispose();
  }

  double? _parseDouble(String text) => text.trim().isEmpty ? null : double.tryParse(text.trim());
  int? _parseInt(String text) => text.trim().isEmpty ? null : int.tryParse(text.trim());

  void _emit() {
    widget.onChanged(LeaseTerms(
      leasedPropertyType: _leasedPropertyType,
      buildingName: _buildingNameController.text.trim().isEmpty ? null : _buildingNameController.text.trim(),
      commencementDate: _commencementDate,
      expiryDate: _expiryDate,
      yearlyRentAmount: _parseDouble(_yearlyRentController.text),
      purposeOfUsage: _purposeController.text.trim().isEmpty ? null : _purposeController.text.trim(),
      paymentMode: _paymentMode,
      numberOfCheques: _parseInt(_numberOfChequesController.text),
      insuranceAllowance: _parseDouble(_insuranceController.text),
      managementFeeAmount: _parseDouble(_managementFeeController.text),
      vatAmount: _parseDouble(_vatController.text),
      numberOfCoOccupants: _parseInt(_coOccupantsController.text),
    ));
  }

  Future<void> _pickDate(bool isCommencement) async {
    final picked = await showDatePicker(
      context: context,
      initialDate: (isCommencement ? _commencementDate : _expiryDate) ?? DateTime.now(),
      firstDate: DateTime(2000),
      lastDate: DateTime(2100),
    );
    if (picked == null) return;
    setState(() {
      if (isCommencement) {
        _commencementDate = picked;
      } else {
        _expiryDate = picked;
      }
    });
    _emit();
  }

  String _formatDate(DateTime? date) =>
      date == null ? 'Not set' : '${date.day.toString().padLeft(2, '0')}/${date.month.toString().padLeft(2, '0')}/${date.year}';

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Text('Lease Terms', style: Theme.of(context).textTheme.titleMedium),
        const SizedBox(height: 8),
        Text('Leased Property Type', style: Theme.of(context).textTheme.bodySmall),
        SegmentedButton<LeasedPropertyType>(
          key: const Key('leasedPropertyTypeSegment'),
          segments: const [
            ButtonSegment(value: LeasedPropertyType.room, label: Text('Room')),
            ButtonSegment(value: LeasedPropertyType.warehouse, label: Text('Warehouse')),
            ButtonSegment(value: LeasedPropertyType.shop, label: Text('Shop')),
          ],
          selected: {_leasedPropertyType},
          onSelectionChanged: widget.enabled
              ? (selection) {
                  setState(() => _leasedPropertyType = selection.first);
                  _emit();
                }
              : null,
        ),
        const SizedBox(height: 12),
        TextFormField(
          key: const Key('buildingNameField'),
          controller: _buildingNameController,
          enabled: widget.enabled,
          decoration: const InputDecoration(labelText: 'Building Name'),
          onChanged: (_) => _emit(),
        ),
        const SizedBox(height: 12),
        Row(
          children: [
            Expanded(
              child: OutlinedButton(
                key: const Key('commencementDateButton'),
                onPressed: widget.enabled ? () => _pickDate(true) : null,
                child: Text('Commencement: ${_formatDate(_commencementDate)}'),
              ),
            ),
            const SizedBox(width: 8),
            Expanded(
              child: OutlinedButton(
                key: const Key('expiryDateButton'),
                onPressed: widget.enabled ? () => _pickDate(false) : null,
                child: Text('Expiry: ${_formatDate(_expiryDate)}'),
              ),
            ),
          ],
        ),
        const SizedBox(height: 12),
        TextFormField(
          key: const Key('yearlyRentField'),
          controller: _yearlyRentController,
          enabled: widget.enabled,
          keyboardType: const TextInputType.numberWithOptions(decimal: true),
          decoration: const InputDecoration(labelText: 'Rent Amount (Yearly, AED)'),
          onChanged: (_) => _emit(),
        ),
        const SizedBox(height: 12),
        TextFormField(
          key: const Key('purposeOfUsageField'),
          controller: _purposeController,
          enabled: widget.enabled,
          decoration: const InputDecoration(labelText: 'Purpose of Usage'),
          onChanged: (_) => _emit(),
        ),
        const SizedBox(height: 12),
        DropdownButtonFormField<PaymentMode>(
          key: const Key('paymentModeDropdown'),
          initialValue: _paymentMode,
          decoration: const InputDecoration(labelText: 'Mode of Payment'),
          items: const [
            DropdownMenuItem(value: PaymentMode.cheques, child: Text('Cheques')),
            DropdownMenuItem(value: PaymentMode.bankTransfer, child: Text('Bank Transfer')),
          ],
          onChanged: widget.enabled
              ? (value) {
                  if (value == null) return;
                  setState(() => _paymentMode = value);
                  _emit();
                }
              : null,
        ),
        if (_paymentMode == PaymentMode.cheques) ...[
          const SizedBox(height: 12),
          TextFormField(
            key: const Key('numberOfChequesField'),
            controller: _numberOfChequesController,
            enabled: widget.enabled,
            keyboardType: TextInputType.number,
            decoration: const InputDecoration(labelText: 'Number of Cheques'),
            onChanged: (_) => _emit(),
          ),
        ],
        const SizedBox(height: 12),
        TextFormField(
          key: const Key('insuranceAllowanceField'),
          controller: _insuranceController,
          enabled: widget.enabled,
          keyboardType: const TextInputType.numberWithOptions(decimal: true),
          decoration: const InputDecoration(labelText: 'Insurance Allowance (AED)'),
          onChanged: (_) => _emit(),
        ),
        const SizedBox(height: 12),
        TextFormField(
          key: const Key('managementFeeAmountField'),
          controller: _managementFeeController,
          enabled: widget.enabled,
          keyboardType: const TextInputType.numberWithOptions(decimal: true),
          decoration: const InputDecoration(labelText: 'Management Fee Amount (AED)'),
          onChanged: (_) => _emit(),
        ),
        const SizedBox(height: 12),
        TextFormField(
          key: const Key('vatAmountField'),
          controller: _vatController,
          enabled: widget.enabled,
          keyboardType: const TextInputType.numberWithOptions(decimal: true),
          decoration: const InputDecoration(labelText: 'VAT Amount (AED)'),
          onChanged: (_) => _emit(),
        ),
        const SizedBox(height: 12),
        TextFormField(
          key: const Key('numberOfCoOccupantsField'),
          controller: _coOccupantsController,
          enabled: widget.enabled,
          keyboardType: TextInputType.number,
          decoration: const InputDecoration(labelText: 'Number of Co-Occupants'),
          onChanged: (_) => _emit(),
        ),
      ],
    );
  }
}
