import 'package:flutter/material.dart';
import 'package:flutter/services.dart' show rootBundle;
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:provider/provider.dart' as legacy_provider;

import '../../../core/theme/app_theme.dart';
import '../../../core/widgets/inline_banner.dart';
import '../../../main.dart';
import '../../../pdf/contract_pdf_builder.dart';
import '../../auth/domain/permission.dart';
import '../../auth/presentation/auth_controller.dart';
import '../../customers/presentation/customer_providers.dart';
import '../../properties/presentation/property_providers.dart';
import '../../quotations/presentation/quotation_providers.dart';
import '../domain/contract.dart';
import '../domain/contract_clause.dart';
import 'contract_providers.dart';
import 'reject_contract_dialog.dart';

class ContractDetailScreen extends ConsumerStatefulWidget {
  final String contractId;

  const ContractDetailScreen({super.key, required this.contractId});

  @override
  ConsumerState<ContractDetailScreen> createState() => _ContractDetailScreenState();
}

class _ContractDetailScreenState extends ConsumerState<ContractDetailScreen> {
  bool _busy = false;
  String? _errorMessage;

  // Draft-editing state: only built once per contract version so typed
  // edits aren't clobbered by every live-stream tick.
  String? _editingForContractId;
  DateTime? _editingForUpdatedAt;
  final Map<String, TextEditingController> _clauseControllers = {};
  String? _selectedCustomerId;
  String? _selectedPropertyId;

  void _ensureEditingControllers(Contract contract) {
    if (_editingForContractId == contract.id && _editingForUpdatedAt == contract.updatedAt) return;
    for (final controller in _clauseControllers.values) {
      controller.dispose();
    }
    _clauseControllers.clear();
    for (final clause in contract.clauses) {
      _clauseControllers[clause.id] = TextEditingController(text: clause.content);
    }
    _selectedCustomerId = contract.customerId;
    _selectedPropertyId = contract.propertyId;
    _editingForContractId = contract.id;
    _editingForUpdatedAt = contract.updatedAt;
  }

  @override
  void dispose() {
    for (final controller in _clauseControllers.values) {
      controller.dispose();
    }
    super.dispose();
  }

  Future<void> _run(Future<void> Function() action) async {
    setState(() {
      _busy = true;
      _errorMessage = null;
    });
    try {
      await action();
    } catch (e) {
      if (mounted) setState(() => _errorMessage = e.toString());
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  // Locked normally means "can't be touched while creating/editing a
  // contract" (it's protected boilerplate from the template) — but if an
  // admin specifically flagged it as needing revision, leaving it locked
  // would make the contract permanently unapprovable: the owner could never
  // act on the one piece of feedback that mattered. Being flagged unlocks
  // it, only for this contract, only until it's re-reviewed.
  bool _isClauseEditable(ContractClause clause) =>
      !clause.isLocked || clause.reviewStatus == ClauseReviewStatus.needsRevision;

  Future<void> _exportPdf(Contract contract, String customerName, String propertyName) async {
    final settings = legacy_provider.Provider.of<AppSettings>(context, listen: false);
    final bytes = await buildContractPdfBytes(
      settings: settings,
      bundle: rootBundle,
      contractNumber: contract.contractNumber,
      statusLabel: contractStatusToString(contract.status),
      customerName: customerName,
      propertyName: propertyName,
      templateVersion: contract.templateVersion,
      clauses: contract.clauses,
      createdAt: contract.createdAt,
      submittedAt: contract.submittedAt,
      approvedAt: contract.approvedAt,
    );
    await PrintingPdfSharer().sharePdf(bytes: bytes, filename: '${contract.contractNumber}.pdf');
  }

  Future<void> _saveDraftClauses(Contract contract) async {
    final updated = contract.clauses
        .map((c) => ContractClause(
              id: c.id,
              order: c.order,
              title: c.title,
              content: _isClauseEditable(c) ? _clauseControllers[c.id]!.text.trim() : c.content,
              isLocked: c.isLocked,
              reviewStatus: c.reviewStatus,
              rejectionNote: c.rejectionNote,
            ))
        .toList();
    await ref.read(contractRepositoryProvider).updateDraft(
          contract.id,
          updated,
          customerId: _selectedCustomerId != contract.customerId ? _selectedCustomerId : null,
          propertyId: _selectedPropertyId != contract.propertyId ? _selectedPropertyId : null,
        );
  }

  @override
  Widget build(BuildContext context) {
    final contractAsync = ref.watch(contractByIdProvider(widget.contractId));
    final user = ref.watch(authControllerProvider).value;

    return contractAsync.when(
      loading: () => const Scaffold(
        body: Center(child: CircularProgressIndicator()),
      ),
      error: (error, _) => Scaffold(
        appBar: AppBar(title: const Text('Contract')),
        body: Center(child: Text('Failed to load contract: $error')),
      ),
      data: (contract) {
        if (contract == null) {
          return Scaffold(
            appBar: AppBar(title: const Text('Contract')),
            body: const Center(child: Text('Contract not found.')),
          );
        }

        final isOwner = user != null && user.id == contract.createdBy;
        final canSubmit = isOwner && contract.status == ContractStatus.draft && user.hasPermission(Permission.contractSubmit);
        final canEditDraft = isOwner && contract.status == ContractStatus.draft && user.hasPermission(Permission.contractEditOwn);
        final canRevise = isOwner && contract.status == ContractStatus.rejected && user.hasPermission(Permission.contractEditOwn);
        final canApprove = contract.status == ContractStatus.pendingApproval && (user?.hasPermission(Permission.contractApprove) ?? false);
        final canReject = contract.status == ContractStatus.pendingApproval && (user?.hasPermission(Permission.contractReject) ?? false);
        final canFinalize = contract.status == ContractStatus.approved && (user?.hasPermission(Permission.contractFinalize) ?? false);

        if (canEditDraft) _ensureEditingControllers(contract);

        final customerAsync = ref.watch(customerByIdProvider(contract.customerId));
        final propertyAsync = ref.watch(propertyByIdProvider(contract.propertyId));
        final customerName = customerAsync.value?.displayName ?? contract.customerId;
        final propertyName = propertyAsync.value?.name ?? contract.propertyId;

        return Scaffold(
          appBar: AppBar(
            title: const Text('Contract'),
            actions: [
              IconButton(
                key: const Key('exportContractPdfButton'),
                icon: const Icon(Icons.picture_as_pdf_outlined),
                tooltip: 'Export PDF',
                onPressed: _busy ? null : () => _run(() => _exportPdf(contract, customerName, propertyName)),
              ),
            ],
          ),
          body: ListView(
            padding: const EdgeInsets.all(16),
            children: [
              if (_errorMessage != null) ...[
                InlineBanner(key: const Key('contractActionErrorBanner'), message: _errorMessage!),
                const SizedBox(height: 16),
              ],
              Text(contract.contractNumber, style: Theme.of(context).textTheme.titleLarge),
              const SizedBox(height: 4),
              _DetailRow(label: 'Status', value: contractStatusToString(contract.status)),
              if (canEditDraft) ...[
                const SizedBox(height: 8),
                ref.watch(customersStreamProvider).when(
                      data: (customers) => DropdownButtonFormField<String>(
                        key: const Key('contractDetailCustomerDropdown'),
                        initialValue: _selectedCustomerId,
                        isExpanded: true,
                        decoration: const InputDecoration(labelText: 'Customer'),
                        items: customers
                            .map((c) => DropdownMenuItem(
                                  value: c.id,
                                  child: Text(c.displayName, overflow: TextOverflow.ellipsis),
                                ))
                            .toList(),
                        onChanged: (value) => setState(() => _selectedCustomerId = value),
                        validator: (value) => value == null ? 'Required' : null,
                      ),
                      loading: () => const LinearProgressIndicator(),
                      error: (error, _) => Text('Failed to load customers: $error'),
                    ),
                const SizedBox(height: 8),
                ref.watch(propertiesStreamProvider).when(
                      data: (properties) => DropdownButtonFormField<String>(
                        key: const Key('contractDetailPropertyDropdown'),
                        initialValue: _selectedPropertyId,
                        isExpanded: true,
                        decoration: const InputDecoration(labelText: 'Property'),
                        items: properties
                            .map((p) => DropdownMenuItem(
                                  value: p.id,
                                  child: Text(p.name, overflow: TextOverflow.ellipsis),
                                ))
                            .toList(),
                        onChanged: (value) => setState(() => _selectedPropertyId = value),
                        validator: (value) => value == null ? 'Required' : null,
                      ),
                      loading: () => const LinearProgressIndicator(),
                      error: (error, _) => Text('Failed to load properties: $error'),
                    ),
              ] else ...[
                _DetailRow(
                  label: 'Customer',
                  value: customerAsync.when(
                    data: (c) => c?.displayName ?? contract.customerId,
                    loading: () => '...',
                    error: (_, _) => contract.customerId,
                  ),
                ),
                _DetailRow(
                  label: 'Property',
                  value: propertyAsync.when(
                    data: (p) => p?.name ?? contract.propertyId,
                    loading: () => '...',
                    error: (_, _) => contract.propertyId,
                  ),
                ),
              ],
              if (contract.sourceQuotationId != null && contract.sourceQuotationId!.isNotEmpty)
                _DetailRow(
                  label: 'Source Quotation',
                  value: ref.watch(quotationByIdProvider(contract.sourceQuotationId!)).when(
                        data: (q) => q == null
                            ? '${contract.sourceQuotationId} (not found)'
                            : '${q.quotaNumber} — ${q.customerName} — ${formatAmount(q.finalPrice)} AED',
                        loading: () => '...',
                        error: (_, _) => contract.sourceQuotationId!,
                      ),
                ),
              _DetailRow(label: 'Template Version', value: 'v${contract.templateVersion}'),
              if (contract.status == ContractStatus.rejected && contract.rejection != null) ...[
                const SizedBox(height: 12),
                InlineBanner.content(
                  key: const Key('rejectionInfoBanner'),
                  severity: BannerSeverity.warning,
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text('Rejected: ${contract.rejection!.generalNote}',
                          style: const TextStyle(fontWeight: FontWeight.bold)),
                      for (final note in contract.rejection!.clauses)
                        Padding(
                          padding: const EdgeInsets.only(top: 4),
                          child: Text('• ${note.note}'),
                        ),
                    ],
                  ),
                ),
              ],
              const SizedBox(height: 16),
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text('Clauses', style: Theme.of(context).textTheme.titleMedium),
                  if (canRevise)
                    TextButton(
                      key: const Key('reviseContractButton'),
                      onPressed: _busy
                          ? null
                          : () => _run(() => ref
                              .read(contractRepositoryProvider)
                              .reviseRejectedContract(contract.id, actorId: user.id)),
                      child: const Text('Revise'),
                    ),
                ],
              ),
              const SizedBox(height: 8),
              for (final clause in contract.clauses)
                Card(
                  key: Key('contractDetailClauseCard_${clause.id}'),
                  margin: const EdgeInsets.only(bottom: 12),
                  child: Padding(
                    padding: const EdgeInsets.all(12),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          children: [
                            Expanded(
                                child: Text(clause.title, style: Theme.of(context).textTheme.titleSmall)),
                            if (clause.isLocked)
                              Icon(
                                Icons.lock_outline,
                                size: 16,
                                // Still shows locked, but a flagged clause is
                                // editable below despite the icon — greyed
                                // out to hint it's not really blocking here.
                                color: _isClauseEditable(clause)
                                    ? Theme.of(context).colorScheme.onSurfaceVariant
                                    : null,
                              ),
                            if (clause.reviewStatus == ClauseReviewStatus.needsRevision)
                              Padding(
                                padding: const EdgeInsets.only(left: 6),
                                child: Icon(
                                  Icons.flag,
                                  size: 16,
                                  color: AppStatusColors.of(context).onWarningContainer,
                                ),
                              ),
                          ],
                        ),
                        const SizedBox(height: 8),
                        if (canEditDraft && _isClauseEditable(clause))
                          TextFormField(
                            key: Key('contractDetailClauseField_${clause.id}'),
                            controller: _clauseControllers[clause.id],
                            maxLines: 3,
                            decoration: const InputDecoration(labelText: 'Content'),
                          )
                        else
                          Text(clause.content),
                        if (clause.reviewStatus == ClauseReviewStatus.needsRevision &&
                            clause.rejectionNote != null) ...[
                          const SizedBox(height: 4),
                          Text(
                            'Needs revision: ${clause.rejectionNote}',
                            style: TextStyle(
                              color: AppStatusColors.of(context).onWarningContainer,
                              fontStyle: FontStyle.italic,
                            ),
                          ),
                        ],
                      ],
                    ),
                  ),
                ),
              const SizedBox(height: 16),
              if (canEditDraft)
                OutlinedButton(
                  key: const Key('saveDraftChangesButton'),
                  onPressed: _busy ? null : () => _run(() => _saveDraftClauses(contract)),
                  child: const Text('Save Changes'),
                ),
              if (canSubmit) ...[
                const SizedBox(height: 8),
                ElevatedButton(
                  key: const Key('submitForApprovalButton'),
                  onPressed: _busy
                      ? null
                      : () => _run(() async {
                            if (canEditDraft) await _saveDraftClauses(contract);
                            await ref
                                .read(contractRepositoryProvider)
                                .submitContract(contract.id, actorId: user.id);
                          }),
                  child: _busy
                      ? const SizedBox(
                          height: 18, width: 18, child: CircularProgressIndicator(strokeWidth: 2))
                      : const Text('Submit for Approval'),
                ),
              ],
              if (canApprove || canReject) ...[
                const SizedBox(height: 8),
                Row(
                  children: [
                    if (canApprove)
                      Expanded(
                        child: ElevatedButton(
                          key: const Key('approveContractButton'),
                          onPressed: _busy
                              ? null
                              : () => _run(() => ref
                                  .read(contractRepositoryProvider)
                                  .approveContract(contract.id, actorId: user!.id)),
                          child: const Text('Approve'),
                        ),
                      ),
                    if (canApprove && canReject) const SizedBox(width: 8),
                    if (canReject)
                      Expanded(
                        child: OutlinedButton(
                          key: const Key('rejectContractButton'),
                          onPressed: _busy
                              ? null
                              : () async {
                                  final result = await showRejectContractDialog(context, clauses: contract.clauses);
                                  if (result == null) return;
                                  await _run(() => ref.read(contractRepositoryProvider).rejectContract(
                                        contract.id,
                                        actorId: user!.id,
                                        generalNote: result.generalNote,
                                        clauseNotes: result.clauseNotes,
                                      ));
                                },
                          child: const Text('Reject'),
                        ),
                      ),
                  ],
                ),
              ],
              if (canFinalize) ...[
                const SizedBox(height: 8),
                ElevatedButton.icon(
                  key: const Key('finalizeContractButton'),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: AppStatusColors.of(context).success,
                    foregroundColor: AppStatusColors.of(context).onSuccess,
                  ),
                  onPressed: _busy
                      ? null
                      : () => _run(() => ref
                          .read(contractRepositoryProvider)
                          .finalizeContract(contract.id, actorId: user!.id)),
                  icon: const Icon(Icons.lock_outline),
                  label: const Text('Finalize (locks the contract permanently)'),
                ),
              ],
            ],
          ),
        );
      },
    );
  }
}

class _DetailRow extends StatelessWidget {
  final String label;
  final String value;

  const _DetailRow({required this.label, required this.value});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(width: 140, child: Text(label, style: Theme.of(context).textTheme.bodySmall)),
          Expanded(child: Text(value)),
        ],
      ),
    );
  }
}
