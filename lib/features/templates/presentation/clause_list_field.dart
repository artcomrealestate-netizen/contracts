import 'package:flutter/material.dart';

import '../domain/template_clause.dart';

class _ClauseDraft {
  final String id;
  final TextEditingController titleController;
  final TextEditingController contentController;
  bool isLocked;

  _ClauseDraft({
    required this.id,
    required this.titleController,
    required this.contentController,
    this.isLocked = false,
  });
}

/// Editable list of clauses shared by the "create template" and "publish new
/// version" screens. Reports the current draft back via [onChanged] on every
/// edit so the parent form can submit whatever is currently on screen.
class ClauseListField extends StatefulWidget {
  final List<TemplateClause> initialClauses;
  final ValueChanged<List<TemplateClause>> onChanged;

  const ClauseListField({super.key, required this.initialClauses, required this.onChanged});

  @override
  State<ClauseListField> createState() => _ClauseListFieldState();
}

class _ClauseListFieldState extends State<ClauseListField> {
  late final List<_ClauseDraft> _drafts;

  _ClauseDraft _newDraft() => _ClauseDraft(
        id: DateTime.now().microsecondsSinceEpoch.toString(),
        titleController: TextEditingController(),
        contentController: TextEditingController(),
      );

  @override
  void initState() {
    super.initState();
    _drafts = widget.initialClauses
        .map((c) => _ClauseDraft(
              id: c.id,
              titleController: TextEditingController(text: c.title),
              contentController: TextEditingController(text: c.content),
              isLocked: c.isLocked,
            ))
        .toList();
    if (_drafts.isEmpty) _drafts.add(_newDraft());
    _emit();
  }

  @override
  void dispose() {
    for (final draft in _drafts) {
      draft.titleController.dispose();
      draft.contentController.dispose();
    }
    super.dispose();
  }

  void _emit() {
    widget.onChanged(_drafts.asMap().entries.map((entry) {
      final draft = entry.value;
      return TemplateClause(
        id: draft.id,
        order: entry.key + 1,
        title: draft.titleController.text.trim(),
        content: draft.contentController.text.trim(),
        isLocked: draft.isLocked,
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
      removed.titleController.dispose();
      removed.contentController.dispose();
    });
    _emit();
  }

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        for (var i = 0; i < _drafts.length; i++)
          Card(
            key: Key('clauseCard_$i'),
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
                          key: Key('clauseTitleField_$i'),
                          controller: _drafts[i].titleController,
                          decoration: const InputDecoration(labelText: 'Clause Title'),
                          validator: (v) => (v == null || v.trim().isEmpty) ? 'Required' : null,
                          onChanged: (_) => _emit(),
                        ),
                      ),
                      IconButton(
                        key: Key('removeClauseButton_$i'),
                        icon: const Icon(Icons.delete_outline),
                        tooltip: 'Remove clause',
                        onPressed: _drafts.length > 1 ? () => _removeDraft(i) : null,
                      ),
                    ],
                  ),
                  TextFormField(
                    key: Key('clauseContentField_$i'),
                    controller: _drafts[i].contentController,
                    decoration: const InputDecoration(labelText: 'Content'),
                    maxLines: 3,
                    validator: (v) => (v == null || v.trim().isEmpty) ? 'Required' : null,
                    onChanged: (_) => _emit(),
                  ),
                  CheckboxListTile(
                    key: Key('clauseLockedCheckbox_$i'),
                    contentPadding: EdgeInsets.zero,
                    controlAffinity: ListTileControlAffinity.leading,
                    title: const Text('Locked (cannot be edited when reused on a contract)'),
                    value: _drafts[i].isLocked,
                    onChanged: (checked) {
                      setState(() => _drafts[i].isLocked = checked ?? false);
                      _emit();
                    },
                  ),
                ],
              ),
            ),
          ),
        OutlinedButton.icon(
          key: const Key('addClauseButton'),
          onPressed: _addDraft,
          icon: const Icon(Icons.add),
          label: const Text('Add Clause'),
        ),
      ],
    );
  }
}
