import 'package:flutter/material.dart';

import '../../templates/presentation/clause_list_field.dart' show mergeFieldTokenGroups;
import '../domain/contract_clause.dart';

class _ContractClauseDraft {
  final String id;
  final TextEditingController titleArController;
  final TextEditingController titleEnController;
  final TextEditingController contentArController;
  final TextEditingController contentEnController;
  bool isLocked;
  final ClauseReviewStatus reviewStatus;
  final String? rejectionNote;

  _ContractClauseDraft({
    required this.id,
    required this.titleArController,
    required this.titleEnController,
    required this.contentArController,
    required this.contentEnController,
    required this.isLocked,
    required this.reviewStatus,
    required this.rejectionNote,
  });
}

/// Editable list of clauses on a live contract — add/remove/reorder plus
/// content editing, unlike lib/features/templates/presentation/
/// clause_list_field.dart's template-authoring version, which this
/// deliberately forks rather than shares: a contract clause also carries
/// [ClauseReviewStatus]/rejectionNote and a per-clause editability rule
/// ([isClauseEditable]) that a template clause has no equivalent of.
///
/// Reports the full clause list back via [onChanged] on every edit — the
/// caller is expected to persist it via ContractRepository.updateDraft,
/// which already accepts and wholesale-overwrites an arbitrary clause list
/// (no repository changes needed for add/remove/reorder).
class ContractClauseListField extends StatefulWidget {
  final List<ContractClause> initialClauses;
  final ValueChanged<List<ContractClause>> onChanged;

  /// Whether a given clause's content may currently be edited — the caller
  /// supplies this since the rule differs by screen (always true while
  /// still composing a brand-new contract; unlocked-or-flagged-needsRevision
  /// once a contract exists, per ContractDetailScreen's `_isClauseEditable`).
  final bool Function(ContractClause clause) isClauseEditable;

  const ContractClauseListField({
    super.key,
    required this.initialClauses,
    required this.onChanged,
    required this.isClauseEditable,
  });

  @override
  State<ContractClauseListField> createState() => _ContractClauseListFieldState();
}

class _ContractClauseListFieldState extends State<ContractClauseListField> {
  late final List<_ContractClauseDraft> _drafts;

  _ContractClauseDraft _newDraft() => _ContractClauseDraft(
        id: DateTime.now().microsecondsSinceEpoch.toString(),
        titleArController: TextEditingController(),
        titleEnController: TextEditingController(),
        contentArController: TextEditingController(),
        contentEnController: TextEditingController(),
        isLocked: false,
        reviewStatus: ClauseReviewStatus.pending,
        rejectionNote: null,
      );

  @override
  void initState() {
    super.initState();
    _drafts = widget.initialClauses
        .map((c) => _ContractClauseDraft(
              id: c.id,
              titleArController: TextEditingController(text: c.titleAr),
              titleEnController: TextEditingController(text: c.titleEn),
              contentArController: TextEditingController(text: c.contentAr),
              contentEnController: TextEditingController(text: c.contentEn),
              isLocked: c.isLocked,
              reviewStatus: c.reviewStatus,
              rejectionNote: c.rejectionNote,
            ))
        .toList();
    if (_drafts.isEmpty) _drafts.add(_newDraft());
  }

  @override
  void dispose() {
    for (final draft in _drafts) {
      draft.titleArController.dispose();
      draft.titleEnController.dispose();
      draft.contentArController.dispose();
      draft.contentEnController.dispose();
    }
    super.dispose();
  }

  void _emit() {
    widget.onChanged(_drafts.asMap().entries.map((entry) {
      final draft = entry.value;
      return ContractClause(
        id: draft.id,
        order: entry.key + 1,
        titleAr: draft.titleArController.text.trim(),
        titleEn: draft.titleEnController.text.trim(),
        contentAr: draft.contentArController.text.trim(),
        contentEn: draft.contentEnController.text.trim(),
        isLocked: draft.isLocked,
        reviewStatus: draft.reviewStatus,
        rejectionNote: draft.rejectionNote,
      );
    }).toList());
  }

  void _addDraft() {
    setState(() => _drafts.add(_newDraft()));
    _emit();
  }

  void _removeDraft(int index) {
    setState(() {
      final removed = _drafts.removeAt(index);
      removed.titleArController.dispose();
      removed.titleEnController.dispose();
      removed.contentArController.dispose();
      removed.contentEnController.dispose();
    });
    _emit();
  }

  void _moveUp(int index) {
    setState(() {
      final draft = _drafts.removeAt(index);
      _drafts.insert(index - 1, draft);
    });
    _emit();
  }

  void _moveDown(int index) {
    setState(() {
      final draft = _drafts.removeAt(index);
      _drafts.insert(index + 1, draft);
    });
    _emit();
  }

  void _insertToken(TextEditingController controller, String token) {
    final selection = controller.selection;
    final text = controller.text;
    final insertAt = selection.isValid ? selection.start : text.length;
    final newText = text.replaceRange(insertAt, selection.isValid ? selection.end : text.length, token);
    controller.value = TextEditingValue(
      text: newText,
      selection: TextSelection.collapsed(offset: insertAt + token.length),
    );
    _emit();
  }

  Widget _insertTokenButton(int i, TextEditingController targetController) {
    return PopupMenuButton<String>(
      key: Key('insertContractTokenButton_$i'),
      icon: const Icon(Icons.data_object, size: 20),
      tooltip: 'Insert placeholder',
      onSelected: (token) => _insertToken(targetController, token),
      itemBuilder: (context) => [
        for (final group in mergeFieldTokenGroups)
          PopupMenuItem<String>(
            enabled: false,
            height: 28,
            child: Text(group.label, style: Theme.of(context).textTheme.labelSmall),
          ),
        for (final group in mergeFieldTokenGroups)
          for (final entry in group.tokens)
            PopupMenuItem<String>(
              value: '{{${entry.token}}}',
              child: Text('${entry.label}  {{${entry.token}}}'),
            ),
      ],
    );
  }

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        for (var i = 0; i < _drafts.length; i++)
          Builder(builder: (context) {
            final draft = _drafts[i];
            // isClauseEditable is evaluated against the CURRENT contract
            // clause this draft represents, matching ContractDetailScreen's
            // _isClauseEditable behavior for pre-existing clauses; a
            // brand-new draft (just added, not yet an existing clause) is
            // always editable.
            final asClause = ContractClause(
              id: draft.id,
              order: i + 1,
              titleAr: draft.titleArController.text,
              titleEn: draft.titleEnController.text,
              contentAr: draft.contentArController.text,
              contentEn: draft.contentEnController.text,
              isLocked: draft.isLocked,
              reviewStatus: draft.reviewStatus,
              rejectionNote: draft.rejectionNote,
            );
            final editable = widget.isClauseEditable(asClause);
            final blockRemoval = draft.reviewStatus == ClauseReviewStatus.needsRevision;

            return Card(
              key: Key('contractClauseCard_$i'),
              margin: const EdgeInsets.only(bottom: 12),
              child: Padding(
                padding: const EdgeInsets.all(12),
                child: Column(
                  children: [
                    Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Expanded(
                          child: TextFormField(
                            key: Key('contractClauseTitleEnField_$i'),
                            controller: draft.titleEnController,
                            enabled: editable,
                            decoration: const InputDecoration(labelText: 'Title (EN)'),
                            onChanged: (_) => _emit(),
                          ),
                        ),
                        const SizedBox(width: 8),
                        Expanded(
                          child: TextFormField(
                            key: Key('contractClauseTitleArField_$i'),
                            controller: draft.titleArController,
                            enabled: editable,
                            textDirection: TextDirection.rtl,
                            decoration: const InputDecoration(labelText: 'العنوان (AR)'),
                            onChanged: (_) => _emit(),
                          ),
                        ),
                        if (draft.isLocked)
                          const Padding(
                            padding: EdgeInsets.only(left: 4),
                            child: Icon(Icons.lock_outline, size: 16),
                          ),
                        IconButton(
                          key: Key('moveClauseUpButton_$i'),
                          icon: const Icon(Icons.arrow_upward),
                          tooltip: 'Move up',
                          onPressed: i > 0 ? () => _moveUp(i) : null,
                        ),
                        IconButton(
                          key: Key('moveClauseDownButton_$i'),
                          icon: const Icon(Icons.arrow_downward),
                          tooltip: 'Move down',
                          onPressed: i < _drafts.length - 1 ? () => _moveDown(i) : null,
                        ),
                        IconButton(
                          key: Key('removeContractClauseButton_$i'),
                          icon: const Icon(Icons.delete_outline),
                          tooltip: blockRemoval
                              ? 'Cannot remove a clause flagged for revision'
                              : 'Remove clause',
                          onPressed: (_drafts.length > 1 && !blockRemoval) ? () => _removeDraft(i) : null,
                        ),
                      ],
                    ),
                    if (draft.reviewStatus == ClauseReviewStatus.needsRevision &&
                        draft.rejectionNote != null) ...[
                      const SizedBox(height: 4),
                      Align(
                        alignment: Alignment.centerLeft,
                        child: Text(
                          'Needs revision: ${draft.rejectionNote}',
                          style: const TextStyle(fontStyle: FontStyle.italic),
                        ),
                      ),
                    ],
                    const SizedBox(height: 8),
                    Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Expanded(
                          child: TextFormField(
                            key: Key('contractClauseContentEnField_$i'),
                            controller: draft.contentEnController,
                            enabled: editable,
                            maxLines: 3,
                            decoration: const InputDecoration(labelText: 'Content (EN)'),
                            onChanged: (_) => _emit(),
                          ),
                        ),
                        if (editable) _insertTokenButton(i, draft.contentEnController),
                      ],
                    ),
                    const SizedBox(height: 8),
                    Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Expanded(
                          child: TextFormField(
                            key: Key('contractClauseContentArField_$i'),
                            controller: draft.contentArController,
                            enabled: editable,
                            textDirection: TextDirection.rtl,
                            maxLines: 3,
                            decoration: const InputDecoration(labelText: 'المحتوى (AR)'),
                            onChanged: (_) => _emit(),
                          ),
                        ),
                        if (editable) _insertTokenButton(i, draft.contentArController),
                      ],
                    ),
                  ],
                ),
              ),
            );
          }),
        OutlinedButton.icon(
          key: const Key('addContractClauseButton'),
          onPressed: _addDraft,
          icon: const Icon(Icons.add),
          label: const Text('Add Clause'),
        ),
      ],
    );
  }
}
