import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../auth/presentation/auth_controller.dart';
import '../../customers/presentation/customer_providers.dart';
import '../../properties/presentation/property_providers.dart';
import '../../templates/presentation/template_providers.dart';
import '../domain/contract_clause.dart';
import 'contract_providers.dart';

class _ContractClauseDraft {
  final String id;
  final int order;
  final String title;
  final bool isLocked;
  final TextEditingController contentController;

  _ContractClauseDraft({
    required this.id,
    required this.order,
    required this.title,
    required this.isLocked,
    required String content,
  }) : contentController = TextEditingController(text: content);
}

class CreateContractScreen extends ConsumerStatefulWidget {
  const CreateContractScreen({super.key});

  @override
  ConsumerState<CreateContractScreen> createState() => _CreateContractScreenState();
}

class _CreateContractScreenState extends ConsumerState<CreateContractScreen> {
  final _formKey = GlobalKey<FormState>();
  final _sourceQuotationController = TextEditingController();

  String? _customerId;
  String? _propertyId;
  String? _templateId;
  int? _templateVersion;
  List<_ContractClauseDraft> _clauseDrafts = [];
  bool _loadingClauses = false;

  bool _submitting = false;
  String? _errorMessage;

  @override
  void dispose() {
    _sourceQuotationController.dispose();
    for (final draft in _clauseDrafts) {
      draft.contentController.dispose();
    }
    super.dispose();
  }

  Future<void> _onTemplateSelected(String? templateId) async {
    for (final draft in _clauseDrafts) {
      draft.contentController.dispose();
    }
    setState(() {
      _templateId = templateId;
      _templateVersion = null;
      _clauseDrafts = [];
      _loadingClauses = templateId != null;
    });
    if (templateId == null) return;

    final versions = await ref.read(templateRepositoryProvider).watchVersions(templateId).first;
    if (!mounted || _templateId != templateId) return; // selection changed while awaiting
    final current = versions.isNotEmpty ? versions.first : null;
    setState(() {
      _loadingClauses = false;
      _templateVersion = current?.version;
      _clauseDrafts = (current?.clauses ?? [])
          .map((c) => _ContractClauseDraft(
                id: c.id,
                order: c.order,
                title: c.title,
                isLocked: c.isLocked,
                content: c.content,
              ))
          .toList();
    });
  }

  // The inline banner sits at the top of a ListView that can scroll well
  // past it (customer/property/template + a full clause list) — a SnackBar
  // guarantees the message is seen immediately regardless of scroll position.
  void _showError(String message) {
    setState(() => _errorMessage = message);
    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(message)));
    }
  }

  Future<void> _submit() async {
    if (!_formKey.currentState!.validate()) {
      _showError('Some fields need attention — scroll up to find the ones marked "Required".');
      return;
    }
    if (_customerId == null || _propertyId == null || _templateId == null || _templateVersion == null) {
      _showError('Select a customer, property, and template.');
      return;
    }

    setState(() {
      _submitting = true;
      _errorMessage = null;
    });
    try {
      // .future (not .value!) so this doesn't silently no-op if
      // AuthController hasn't resolved its very first read yet.
      final currentUser = await ref.read(authControllerProvider.future);
      if (currentUser == null) {
        _showError('Not signed in — please sign in again.');
        return;
      }
      final clauses = _clauseDrafts
          .map((draft) => ContractClause(
                id: draft.id,
                order: draft.order,
                title: draft.title,
                content: draft.contentController.text.trim(),
                isLocked: draft.isLocked,
              ))
          .toList();
      await ref.read(contractRepositoryProvider).createDraftContract(
            customerId: _customerId!,
            propertyId: _propertyId!,
            templateId: _templateId!,
            templateVersion: _templateVersion!,
            clauses: clauses,
            createdBy: currentUser.id,
            sourceQuotationId:
                _sourceQuotationController.text.trim().isEmpty ? null : _sourceQuotationController.text.trim(),
          );
      if (mounted) Navigator.of(context).pop();
    } catch (e) {
      if (mounted) _showError(e.toString());
    } finally {
      if (mounted) setState(() => _submitting = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final customersAsync = ref.watch(customersStreamProvider);
    final propertiesAsync = ref.watch(propertiesStreamProvider);
    final templatesAsync = ref.watch(templatesStreamProvider);

    return Scaffold(
      appBar: AppBar(title: const Text('New Contract (Draft)')),
      body: Form(
        key: _formKey,
        child: ListView(
          padding: const EdgeInsets.all(16),
          children: [
            if (_errorMessage != null) ...[
              Container(
                key: const Key('createContractErrorBanner'),
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
            customersAsync.when(
              data: (customers) => DropdownButtonFormField<String>(
                key: const Key('contractCustomerDropdown'),
                initialValue: _customerId,
                decoration: const InputDecoration(labelText: 'Customer'),
                items: customers
                    .map((c) => DropdownMenuItem(value: c.id, child: Text(c.displayName)))
                    .toList(),
                onChanged: (value) => setState(() => _customerId = value),
                validator: (value) => value == null ? 'Required' : null,
              ),
              loading: () => const LinearProgressIndicator(),
              error: (error, _) => Text('Failed to load customers: $error'),
            ),
            const SizedBox(height: 12),
            propertiesAsync.when(
              data: (properties) => DropdownButtonFormField<String>(
                key: const Key('contractPropertyDropdown'),
                initialValue: _propertyId,
                decoration: const InputDecoration(labelText: 'Property'),
                items: properties.map((p) => DropdownMenuItem(value: p.id, child: Text(p.name))).toList(),
                onChanged: (value) => setState(() => _propertyId = value),
                validator: (value) => value == null ? 'Required' : null,
              ),
              loading: () => const LinearProgressIndicator(),
              error: (error, _) => Text('Failed to load properties: $error'),
            ),
            const SizedBox(height: 12),
            TextFormField(
              key: const Key('sourceQuotationField'),
              controller: _sourceQuotationController,
              decoration: const InputDecoration(
                labelText: 'Source Quotation Reference (optional)',
                helperText: 'Free text for now — not yet linked to a live quotation record (TDD phase 7).',
                helperMaxLines: 2,
              ),
            ),
            const SizedBox(height: 12),
            templatesAsync.when(
              data: (templates) => DropdownButtonFormField<String>(
                key: const Key('contractTemplateDropdown'),
                initialValue: _templateId,
                decoration: const InputDecoration(labelText: 'Contract Template'),
                items: templates
                    .map((t) => DropdownMenuItem(value: t.id, child: Text('${t.name} (v${t.currentVersion})')))
                    .toList(),
                onChanged: _onTemplateSelected,
                validator: (value) => value == null ? 'Required' : null,
              ),
              loading: () => const LinearProgressIndicator(),
              error: (error, _) => Text('Failed to load templates: $error'),
            ),
            const SizedBox(height: 20),
            if (_templateId != null) ...[
              Text('Clauses', style: Theme.of(context).textTheme.titleMedium),
              const SizedBox(height: 8),
              if (_loadingClauses)
                const Padding(
                  padding: EdgeInsets.symmetric(vertical: 12),
                  child: LinearProgressIndicator(),
                )
              else
                for (var i = 0; i < _clauseDrafts.length; i++)
                  Card(
                    key: Key('contractClauseCard_$i'),
                    margin: const EdgeInsets.only(bottom: 12),
                    child: Padding(
                      padding: const EdgeInsets.all(12),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Row(
                            children: [
                              Expanded(
                                child: Text(_clauseDrafts[i].title, style: Theme.of(context).textTheme.titleSmall),
                              ),
                              if (_clauseDrafts[i].isLocked) const Icon(Icons.lock_outline, size: 16),
                            ],
                          ),
                          const SizedBox(height: 8),
                          TextFormField(
                            key: Key('contractClauseContentField_$i'),
                            controller: _clauseDrafts[i].contentController,
                            maxLines: 3,
                            enabled: !_clauseDrafts[i].isLocked,
                            decoration: const InputDecoration(labelText: 'Content'),
                          ),
                        ],
                      ),
                    ),
                  ),
            ],
            const SizedBox(height: 24),
            ElevatedButton(
              key: const Key('submitContractButton'),
              onPressed: _submitting ? null : _submit,
              child: _submitting
                  ? const SizedBox(
                      height: 18,
                      width: 18,
                      child: CircularProgressIndicator(strokeWidth: 2),
                    )
                  : const Text('Save Draft'),
            ),
          ],
        ),
      ),
    );
  }
}
