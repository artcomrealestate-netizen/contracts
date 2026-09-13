import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/widgets/inline_banner.dart';
import '../../auth/presentation/auth_controller.dart';
import '../../customers/presentation/customer_providers.dart';
import '../../properties/presentation/property_providers.dart';
import '../../quotations/presentation/quotation_providers.dart';
import '../../templates/presentation/template_providers.dart';
import '../domain/contract_clause.dart';
import '../domain/lease_terms.dart';
import 'contract_clause_list_field.dart';
import 'contract_providers.dart';
import 'lease_terms_form_section.dart';

class CreateContractScreen extends ConsumerStatefulWidget {
  const CreateContractScreen({super.key});

  @override
  ConsumerState<CreateContractScreen> createState() => _CreateContractScreenState();
}

class _CreateContractScreenState extends ConsumerState<CreateContractScreen> {
  final _formKey = GlobalKey<FormState>();

  String? _customerId;
  String? _propertyId;
  String? _templateId;
  int? _templateVersion;
  String? _sourceQuotationId;
  List<ContractClause> _clauses = [];
  LeaseTerms _leaseTerms = const LeaseTerms();
  bool _loadingClauses = false;

  bool _submitting = false;
  String? _errorMessage;

  Future<void> _onTemplateSelected(String? templateId) async {
    setState(() {
      _templateId = templateId;
      _templateVersion = null;
      _clauses = [];
      _loadingClauses = templateId != null;
    });
    if (templateId == null) return;

    final versions = await ref.read(templateRepositoryProvider).watchVersions(templateId).first;
    if (!mounted || _templateId != templateId) return; // selection changed while awaiting
    final current = versions.isNotEmpty ? versions.first : null;
    setState(() {
      _loadingClauses = false;
      _templateVersion = current?.version;
      _clauses = (current?.clauses ?? [])
          .map((c) => ContractClause(
                id: c.id,
                order: c.order,
                titleAr: c.titleAr,
                titleEn: c.titleEn,
                contentAr: c.contentAr,
                contentEn: c.contentEn,
                isLocked: c.isLocked,
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
      await ref.read(contractRepositoryProvider).createDraftContract(
            customerId: _customerId!,
            propertyId: _propertyId!,
            templateId: _templateId!,
            templateVersion: _templateVersion!,
            clauses: _clauses,
            createdBy: currentUser.id,
            sourceQuotationId: _sourceQuotationId,
            leaseTerms: _leaseTerms,
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
              InlineBanner(key: const Key('createContractErrorBanner'), message: _errorMessage!),
              const SizedBox(height: 16),
            ],
            customersAsync.when(
              data: (customers) => DropdownButtonFormField<String>(
                key: const Key('contractCustomerDropdown'),
                initialValue: _customerId,
                isExpanded: true,
                decoration: const InputDecoration(labelText: 'Customer'),
                items: customers
                    .map((c) => DropdownMenuItem(
                          value: c.id,
                          child: Text(c.displayName, overflow: TextOverflow.ellipsis),
                        ))
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
                isExpanded: true,
                decoration: const InputDecoration(labelText: 'Property'),
                items: properties
                    .map((p) => DropdownMenuItem(
                          value: p.id,
                          child: Text(p.name, overflow: TextOverflow.ellipsis),
                        ))
                    .toList(),
                onChanged: (value) => setState(() => _propertyId = value),
                validator: (value) => value == null ? 'Required' : null,
              ),
              loading: () => const LinearProgressIndicator(),
              error: (error, _) => Text('Failed to load properties: $error'),
            ),
            const SizedBox(height: 12),
            Consumer(
              builder: (context, ref, _) {
                final quotationsAsync = ref.watch(quotationsStreamProvider);
                return quotationsAsync.when(
                  data: (quotations) => DropdownButtonFormField<String?>(
                    key: const Key('sourceQuotationDropdown'),
                    initialValue: _sourceQuotationId,
                    isExpanded: true,
                    decoration: const InputDecoration(labelText: 'Source Quotation (optional)'),
                    items: [
                      const DropdownMenuItem<String?>(value: null, child: Text('None')),
                      ...quotations.map((q) => DropdownMenuItem<String?>(
                            value: q.id,
                            child: Text('${q.quotaNumber} — ${q.customerName}', overflow: TextOverflow.ellipsis),
                          )),
                    ],
                    onChanged: (value) => setState(() => _sourceQuotationId = value),
                  ),
                  loading: () => const LinearProgressIndicator(),
                  error: (error, _) => Text('Failed to load quotations: $error'),
                );
              },
            ),
            const SizedBox(height: 12),
            templatesAsync.when(
              data: (templates) => DropdownButtonFormField<String>(
                key: const Key('contractTemplateDropdown'),
                initialValue: _templateId,
                isExpanded: true,
                decoration: const InputDecoration(labelText: 'Contract Template'),
                items: templates
                    .map((t) => DropdownMenuItem(
                          value: t.id,
                          child: Text('${t.name} (v${t.currentVersion})', overflow: TextOverflow.ellipsis),
                        ))
                    .toList(),
                onChanged: _onTemplateSelected,
                validator: (value) => value == null ? 'Required' : null,
              ),
              loading: () => const LinearProgressIndicator(),
              error: (error, _) => Text('Failed to load templates: $error'),
            ),
            const SizedBox(height: 20),
            LeaseTermsFormSection(
              initial: _leaseTerms,
              onChanged: (terms) => _leaseTerms = terms,
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
                ContractClauseListField(
                  key: ValueKey('contract-clauses-$_templateId'),
                  initialClauses: _clauses,
                  onChanged: (clauses) => _clauses = clauses,
                  isClauseEditable: (_) => true,
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
