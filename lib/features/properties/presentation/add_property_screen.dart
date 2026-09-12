import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/widgets/inline_banner.dart';
import '../../auth/presentation/auth_controller.dart';
import '../domain/property.dart';
import 'property_providers.dart';

class AddPropertyScreen extends ConsumerStatefulWidget {
  /// When set, the form edits this property instead of creating a new one.
  final Property? existingProperty;

  const AddPropertyScreen({super.key, this.existingProperty});

  @override
  ConsumerState<AddPropertyScreen> createState() => _AddPropertyScreenState();
}

class _AddPropertyScreenState extends ConsumerState<AddPropertyScreen> {
  final _formKey = GlobalKey<FormState>();

  late final TextEditingController _propertyCodeController;
  late final TextEditingController _nameController;
  late final TextEditingController _propertyTypeController;
  late final TextEditingController _unitNumberController;
  late final TextEditingController _areaController;
  late final TextEditingController _emirateController;
  late final TextEditingController _cityController;
  late final TextEditingController _districtController;

  bool _submitting = false;
  String? _errorMessage;

  bool get _isEditing => widget.existingProperty != null;

  @override
  void initState() {
    super.initState();
    final existing = widget.existingProperty;
    _propertyCodeController = TextEditingController(text: existing?.propertyCode ?? '');
    _nameController = TextEditingController(text: existing?.name ?? '');
    _propertyTypeController = TextEditingController(text: existing?.propertyType ?? '');
    _unitNumberController = TextEditingController(text: existing?.unitNumber ?? '');
    _areaController = TextEditingController(text: existing == null ? '' : existing.area.toString());
    _emirateController = TextEditingController(text: existing?.location.emirate ?? '');
    _cityController = TextEditingController(text: existing?.location.city ?? '');
    _districtController = TextEditingController(text: existing?.location.district ?? '');
  }

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
      final existing = widget.existingProperty;
      final property = Property(
        id: existing?.id ?? '',
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
        status: existing?.status ?? PropertyStatus.active,
        createdBy: existing?.createdBy ?? currentUser.id,
      );
      if (_isEditing) {
        await ref.read(propertyRepositoryProvider).updateProperty(property);
      } else {
        await ref.read(propertyRepositoryProvider).createProperty(property);
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
      appBar: AppBar(title: Text(_isEditing ? 'Edit Property' : 'Add Property')),
      body: Form(
        key: _formKey,
        child: ListView(
          padding: const EdgeInsets.all(16),
          children: [
            if (_errorMessage != null) ...[
              InlineBanner(key: const Key('addPropertyErrorBanner'), message: _errorMessage!),
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
                  : Text(_isEditing ? 'Save Changes' : 'Save Property'),
            ),
          ],
        ),
      ),
    );
  }
}
