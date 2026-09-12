import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../auth/presentation/auth_controller.dart';
import '../domain/property.dart';
import 'property_providers.dart';

class AddPropertyScreen extends ConsumerStatefulWidget {
  const AddPropertyScreen({super.key});

  @override
  ConsumerState<AddPropertyScreen> createState() => _AddPropertyScreenState();
}

class _AddPropertyScreenState extends ConsumerState<AddPropertyScreen> {
  final _formKey = GlobalKey<FormState>();

  final _propertyCodeController = TextEditingController();
  final _nameController = TextEditingController();
  final _propertyTypeController = TextEditingController();
  final _unitNumberController = TextEditingController();
  final _areaController = TextEditingController();
  final _emirateController = TextEditingController();
  final _cityController = TextEditingController();
  final _districtController = TextEditingController();

  bool _submitting = false;
  String? _errorMessage;

  @override
  void dispose() {
    _propertyCodeController.dispose();
    _nameController.dispose();
    _propertyTypeController.dispose();
    _unitNumberController.dispose();
    _areaController.dispose();
    _emirateController.dispose();
    _cityController.dispose();
    _districtController.dispose();
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
      final property = Property(
        id: '',
        propertyCode: _propertyCodeController.text.trim(),
        name: _nameController.text.trim(),
        propertyType: _propertyTypeController.text.trim(),
        unitNumber: _emptyToNull(_unitNumberController.text),
        area: double.tryParse(_areaController.text.trim()) ?? 0,
        location: PropertyLocation(
          emirate: _emptyToNull(_emirateController.text),
          city: _emptyToNull(_cityController.text),
          district: _emptyToNull(_districtController.text),
        ),
        status: PropertyStatus.active,
        createdBy: currentUser.id,
      );
      await ref.read(propertyRepositoryProvider).createProperty(property);
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
      appBar: AppBar(title: const Text('Add Property')),
      body: Form(
        key: _formKey,
        child: ListView(
          padding: const EdgeInsets.all(16),
          children: [
            if (_errorMessage != null) ...[
              Container(
                key: const Key('addPropertyErrorBanner'),
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
            TextFormField(
              key: const Key('propertyCodeField'),
              controller: _propertyCodeController,
              decoration: const InputDecoration(labelText: 'Property Code'),
              validator: (value) => (value == null || value.trim().isEmpty) ? 'Required' : null,
            ),
            const SizedBox(height: 12),
            TextFormField(
              key: const Key('propertyNameField'),
              controller: _nameController,
              decoration: const InputDecoration(labelText: 'Name'),
              validator: (value) => (value == null || value.trim().isEmpty) ? 'Required' : null,
            ),
            const SizedBox(height: 12),
            TextFormField(
              key: const Key('propertyTypeField'),
              controller: _propertyTypeController,
              decoration: const InputDecoration(labelText: 'Property Type'),
              validator: (value) => (value == null || value.trim().isEmpty) ? 'Required' : null,
            ),
            const SizedBox(height: 12),
            TextFormField(
              key: const Key('unitNumberField'),
              controller: _unitNumberController,
              decoration: const InputDecoration(labelText: 'Unit Number'),
            ),
            const SizedBox(height: 12),
            TextFormField(
              key: const Key('areaField'),
              controller: _areaController,
              decoration: const InputDecoration(labelText: 'Area'),
              keyboardType: TextInputType.number,
            ),
            const SizedBox(height: 12),
            TextFormField(
              key: const Key('emirateField'),
              controller: _emirateController,
              decoration: const InputDecoration(labelText: 'Emirate'),
            ),
            const SizedBox(height: 12),
            TextFormField(
              key: const Key('cityField'),
              controller: _cityController,
              decoration: const InputDecoration(labelText: 'City'),
            ),
            const SizedBox(height: 12),
            TextFormField(
              key: const Key('districtField'),
              controller: _districtController,
              decoration: const InputDecoration(labelText: 'District'),
            ),
            const SizedBox(height: 24),
            ElevatedButton(
              key: const Key('submitPropertyButton'),
              onPressed: _submitting ? null : _submit,
              child: _submitting
                  ? const SizedBox(
                      height: 18,
                      width: 18,
                      child: CircularProgressIndicator(strokeWidth: 2),
                    )
                  : const Text('Save Property'),
            ),
          ],
        ),
      ),
    );
  }
}
