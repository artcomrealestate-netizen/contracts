import 'package:flutter/material.dart';

import '../domain/contract_clause.dart';
import '../domain/rejection.dart';

class RejectContractResult {
  final String generalNote;
  final List<ClauseRejectionNote> clauseNotes;

  const RejectContractResult({required this.generalNote, required this.clauseNotes});
}

/// Collects a general rejection reason plus optional clause-level feedback
/// (TDD §24). Returns null if the admin cancels.
Future<RejectContractResult?> showRejectContractDialog(
  BuildContext context, {
  required List<ContractClause> clauses,
}) {
  return showDialog<RejectContractResult>(
    context: context,
    builder: (context) => _RejectContractDialog(clauses: clauses),
  );
}

class _RejectContractDialog extends StatefulWidget {
  final List<ContractClause> clauses;

  const _RejectContractDialog({required this.clauses});

  @override
  State<_RejectContractDialog> createState() => _RejectContractDialogState();
}

class _RejectContractDialogState extends State<_RejectContractDialog> {
  final _generalNoteController = TextEditingController();
  final _formKey = GlobalKey<FormState>();
  final Map<String, bool> _flagged = {};
  final Map<String, TextEditingController> _noteControllers = {};

  @override
  void initState() {
    super.initState();
    for (final clause in widget.clauses) {
      _flagged[clause.id] = false;
      _noteControllers[clause.id] = TextEditingController();
    }
  }

  @override
  void dispose() {
    _generalNoteController.dispose();
    for (final controller in _noteControllers.values) {
      controller.dispose();
    }
    super.dispose();
  }

  void _submit() {
    if (!_formKey.currentState!.validate()) return;
    final clauseNotes = widget.clauses
        .where((c) => _flagged[c.id] == true)
        .map((c) => ClauseRejectionNote(clauseId: c.id, note: _noteControllers[c.id]!.text.trim()))
        .toList();
    Navigator.of(context).pop(RejectContractResult(
      generalNote: _generalNoteController.text.trim(),
      clauseNotes: clauseNotes,
    ));
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: const Text('Reject Contract'),
      content: Form(
        key: _formKey,
        child: SizedBox(
          width: 400,
          child: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                TextFormField(
                  key: const Key('rejectGeneralNoteField'),
                  controller: _generalNoteController,
                  decoration: const InputDecoration(labelText: 'Reason for rejection'),
                  maxLines: 2,
                  validator: (value) => (value == null || value.trim().isEmpty) ? 'Required' : null,
                ),
                if (widget.clauses.isNotEmpty) ...[
                  const SizedBox(height: 16),
                  const Text('Flag specific clauses (optional)', style: TextStyle(fontWeight: FontWeight.bold)),
                  for (final clause in widget.clauses)
                    Column(
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [
                        CheckboxListTile(
                          key: Key('flagClauseCheckbox_${clause.id}'),
                          contentPadding: EdgeInsets.zero,
                          controlAffinity: ListTileControlAffinity.leading,
                          title: Text(clause.title),
                          value: _flagged[clause.id],
                          onChanged: (checked) => setState(() => _flagged[clause.id] = checked ?? false),
                        ),
                        if (_flagged[clause.id] == true)
                          TextFormField(
                            key: Key('clauseRejectionNoteField_${clause.id}'),
                            controller: _noteControllers[clause.id],
                            decoration: const InputDecoration(labelText: 'What needs to change?'),
                            validator: (value) =>
                                (_flagged[clause.id] == true && (value == null || value.trim().isEmpty))
                                    ? 'Required'
                                    : null,
                          ),
                      ],
                    ),
                ],
              ],
            ),
          ),
        ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.of(context).pop(),
          child: const Text('Cancel'),
        ),
        TextButton(
          key: const Key('confirmRejectButton'),
          onPressed: _submit,
          child: const Text('Reject'),
        ),
      ],
    );
  }
}
