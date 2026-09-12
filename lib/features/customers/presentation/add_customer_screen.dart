import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../auth/presentation/auth_controller.dart';
import '../domain/customer.dart';
import 'customer_providers.dart';

class AddCustomerScreen extends ConsumerStatefulWidget {
  /// When set, the form edits this customer instead of creating a new one.
  final Customer? existingCustomer;

  const AddCustomerScreen({super.key, this.existingCustomer});

  @override
  ConsumerState<AddCustomerScreen> createState() => _AddCustomerScreenState();
}

class _AddCustomerScreenState extends ConsumerState<AddCustomerScreen> {
  final _formKey = GlobalKey<FormState>();
  late CustomerType _type;

  late final TextEditingController _nameController;
  late final TextEditingController _emiratesIdController;
  late final TextEditingController _passportController;
  late final TextEditingController _tradeLicenseController;
  late final TextEditingController _licensingAuthorityController;
  late final TextEditingController _phoneController;
  late final TextEditingController _emailController;
  late final TextEditingController _addressController;

  bool _submitting = false;
  String? _errorMessage;

  bool get _isEditing => widget.existingCustomer != null;

  @override
  void initState() {
    super.initState();
    final existing = widget.existingCustomer;
    _type = existing?.customerType ?? CustomerType.individual;
    _nameController = TextEditingController(
      text: existing == null ? '' : (existing.individual?.fullName ?? existing.company?.legalName ?? ''),
    );
    _emiratesIdController = TextEditingController(text: existing?.individual?.emiratesId ?? '');
    _passportController = TextEditingController(text: existing?.individual?.passportNumber ?? '');
    _tradeLicenseController = TextEditingController(text: existing?.company?.tradeLicenseNumber ?? '');
    _licensingAuthorityController = TextEditingController(text: existing?.company?.licensingAuthority ?? '');
    _phoneController = TextEditingController(text: existing?.contact.phone ?? '');
    _emailController = TextEditingController(text: existing?.contact.email ?? '');
    _addressController = TextEditingController(text: existing?.address ?? '');
  }

  @override
  void dispose() {
    _nameController.dispose();
    _emiratesIdController.dispose();
    _passportController.dispose();
    _tradeLicenseController.dispose();
    _licensingAuthorityController.dispose();
    _phoneController.dispose();
    _emailController.dispose();
    _addressController.dispose();
    super.dispose();
  }

  String? _emptyToNull(String text) => text.trim().isEmpty ? null : text.trim();

  Future<void> _submit() async {
    if (!_formKey.currentState!.validate()) return;
    final currentUser = ref.read(authControllerProvider).value;
    if (currentUser == null) return;

    setState(() {
      _submitting = true;
      _errorMessage = null;
    });
    try {
      final existing = widget.existingCustomer;
      final customer = Customer(
        id: existing?.id ?? '',
        customerType: _type,
        individual: _type == CustomerType.individual
            ? IndividualDetails(
                fullName: _nameController.text.trim(),
                emiratesId: _emptyToNull(_emiratesIdController.text),
                passportNumber: _emptyToNull(_passportController.text),
              )
            : null,
        company: _type == CustomerType.company
            ? CompanyDetails(
                legalName: _nameController.text.trim(),
                tradeLicenseNumber: _emptyToNull(_tradeLicenseController.text),
                licensingAuthority: _emptyToNull(_licensingAuthorityController.text),
              )
            : null,
        contact: CustomerContact(
          phone: _emptyToNull(_phoneController.text),
          email: _emptyToNull(_emailController.text),
        ),
        address: _emptyToNull(_addressController.text),
        status: existing?.status ?? CustomerStatus.active,
        createdBy: existing?.createdBy ?? currentUser.id,
      );
      if (_isEditing) {
        await ref.read(customerRepositoryProvider).updateCustomer(customer);
      } else {
        await ref.read(customerRepositoryProvider).createCustomer(customer);
      }
      if (mounted) Navigator.of(context).pop();
    } catch (e) {
      if (mounted) setState(() => _errorMessage = e.toString());
    } finally {
      if (mounted) setState(() => _submitting = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: Text(_isEditing ? 'Edit Customer' : 'Add Customer')),
      body: Form(
        key: _formKey,
        child: ListView(
          padding: const EdgeInsets.all(16),
          children: [
            if (_errorMessage != null) ...[
              Container(
                key: const Key('addCustomerErrorBanner'),
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: Colors.red.shade50,
                  borderRadius: BorderRadius.circular(8),
                  border: Border.all(color: Colors.red.shade200),
                ),
                child: Text(_errorMessage!, style: TextStyle(color: Colors.red.shade900)),
              ),
              const SizedBox(height: 16),
            ],
            SegmentedButton<CustomerType>(
              key: const Key('customerTypeSegment'),
              segments: const [
                ButtonSegment(value: CustomerType.individual, label: Text('Individual')),
                ButtonSegment(value: CustomerType.company, label: Text('Company')),
              ],
              selected: {_type},
              onSelectionChanged: (selection) => setState(() => _type = selection.first),
            ),
            const SizedBox(height: 16),
            TextFormField(
              key: const Key('customerNameField'),
              controller: _nameController,
              decoration: InputDecoration(
                labelText: _type == CustomerType.individual ? 'Full Name' : 'Legal Name',
              ),
              validator: (value) => (value == null || value.trim().isEmpty) ? 'Required' : null,
            ),
            const SizedBox(height: 12),
            if (_type == CustomerType.individual) ...[
              TextFormField(
                key: const Key('emiratesIdField'),
                controller: _emiratesIdController,
                decoration: const InputDecoration(labelText: 'Emirates ID'),
              ),
              const SizedBox(height: 12),
              TextFormField(
                key: const Key('passportField'),
                controller: _passportController,
                decoration: const InputDecoration(labelText: 'Passport Number'),
              ),
            ] else ...[
              TextFormField(
                key: const Key('tradeLicenseField'),
                controller: _tradeLicenseController,
                decoration: const InputDecoration(labelText: 'Trade License Number'),
              ),
              const SizedBox(height: 12),
              TextFormField(
                key: const Key('licensingAuthorityField'),
                controller: _licensingAuthorityController,
                decoration: const InputDecoration(labelText: 'Licensing Authority'),
              ),
            ],
            const SizedBox(height: 12),
            TextFormField(
              key: const Key('customerPhoneField'),
              controller: _phoneController,
              decoration: const InputDecoration(labelText: 'Phone'),
              keyboardType: TextInputType.phone,
            ),
            const SizedBox(height: 12),
            TextFormField(
              key: const Key('customerEmailField'),
              controller: _emailController,
              decoration: const InputDecoration(labelText: 'Email'),
              keyboardType: TextInputType.emailAddress,
            ),
            const SizedBox(height: 12),
            TextFormField(
              key: const Key('customerAddressField'),
              controller: _addressController,
              decoration: const InputDecoration(labelText: 'Address'),
            ),
            const SizedBox(height: 24),
            ElevatedButton(
              key: const Key('submitCustomerButton'),
              onPressed: _submitting ? null : _submit,
              child: _submitting
                  ? const SizedBox(
                      height: 18,
                      width: 18,
                      child: CircularProgressIndicator(strokeWidth: 2),
                    )
                  : Text(_isEditing ? 'Save Changes' : 'Save Customer'),
            ),
          ],
        ),
      ),
    );
  }
}
