import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../auth/domain/permission.dart';
import '../../auth/presentation/auth_controller.dart';
import '../../customers/presentation/customer_providers.dart';
import '../../properties/presentation/property_providers.dart';
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

  void _ensureEditingControllers(Contract contract) {
    if (_editingForContractId == contract.id && _editingForUpdatedAt == contract.updatedAt) return;
    for (final controller in _clauseControllers.values) {
      controller.dispose();
    }
    _clauseControllers.clear();
    for (final clause in contract.clauses) {
      _clauseControllers[clause.id] = TextEditingController(text: clause.content);
    }
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

  Future<void> _saveDraftClauses(Contract contract) async {
    final updated = contract.clauses
        .map((c) => ContractClause(
              id: c.id,
              order: c.order,
              title: c.title,
              content: c.isLocked ? c.content : _clauseControllers[c.id]!.text.trim(),
              isLocked: c.isLocked,
            ))
        .toList();
    await ref.read(contractRepositoryProvider).updateDraftClauses(contract.id, updated);
  }

  @override
  Widget build(BuildContext context) {
    final contractAsync = ref.watch(contractByIdProvider(widget.contractId));
    final user = ref.watch(authControllerProvider).value;

    return Scaffold(
      appBar: AppBar(title: const Text('Contract')),
      body: contractAsync.when(
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (error, _) => Center(child: Text('Failed to load contract: $error')),
        data: (contract) {
          if (contract == null) return const Center(child: Text('Contract not found.'));

          final isOwner = user != null && user.id == contract.createdBy;
          final canSubmit = isOwner && contract.status == ContractStatus.draft && user.hasPermission(Permission.contractSubmit);
          final canEditDraft = isOwner && contract.status == ContractStatus.draft && user.hasPermission(Permission.contractEditOwn);
          final canRevise = isOwner && contract.status == ContractStatus.rejected && user.hasPermission(Permission.contractEditOwn);
          final canApprove = contract.status == ContractStatus.pendingApproval && (user?.hasPermission(Permission.contractApprove) ?? false);
          final canReject = contract.status == ContractStatus.pendingApproval && (user?.hasPermission(Permission.contractReject) ?? false);

          if (canEditDraft) _ensureEditingControllers(contract);

          final customerAsync = ref.watch(customerByIdProvider(contract.customerId));
          final propertyAsync = ref.watch(propertyByIdProvider(contract.propertyId));

          return ListView(
            padding: const EdgeInsets.all(16),
            children: [
              if (_errorMessage != null) ...[
                Container(
                  key: const Key('contractActionErrorBanner'),
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
              Text(contract.contractNumber, style: Theme.of(context).textTheme.titleLarge),
              const SizedBox(height: 4),
              _DetailRow(label: 'Status', value: contractStatusToString(contract.status)),
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
              if (contract.sourceQuotationId != null && contract.sourceQuotationId!.isNotEmpty)
                _DetailRow(label: 'Source Quotation', value: contract.sourceQuotationId!),
              _DetailRow(label: 'Template Version', value: 'v${contract.templateVersion}'),
              if (contract.status == ContractStatus.rejected && contract.rejection != null) ...[
                const SizedBox(height: 12),
                Container(
                  key: const Key('rejectionInfoBanner'),
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: Colors.orange.shade50,
                    borderRadius: BorderRadius.circular(8),
                    border: Border.all(color: Colors.orange.shade200),
                  ),
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
                            if (clause.isLocked) const Icon(Icons.lock_outline, size: 16),
                            if (clause.reviewStatus == ClauseReviewStatus.needsRevision)
                              const Padding(
                                padding: EdgeInsets.only(left: 6),
                                child: Icon(Icons.flag, size: 16, color: Colors.orange),
                              ),
                          ],
                        ),
                        const SizedBox(height: 8),
                        if (canEditDraft && !clause.isLocked)
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
                            style: const TextStyle(color: Colors.orange, fontStyle: FontStyle.italic),
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
            ],
          );
        },
      ),
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
