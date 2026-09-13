import 'package:flutter/material.dart';

import '../domain/template_clause.dart';

class _ClauseDraft {
  final String id;
  final TextEditingController titleArController;
  final TextEditingController titleEnController;
  final TextEditingController contentArController;
  final TextEditingController contentEnController;
  bool isLocked;

  _ClauseDraft({
    required this.id,
    required this.titleArController,
    required this.titleEnController,
    required this.contentArController,
    required this.contentEnController,
    this.isLocked = false,
  });
}

/// Editable list of clauses shared by the "create template" and "publish new
/// version" screens. Reports the current draft back via [onChanged] on every
/// edit so the parent form can submit whatever is currently on screen.
///
/// Title/content are bilingual (Ar/En) — see TemplateClause's doc comment.
/// Content fields may contain `{{token}}` placeholders (see
/// lib/features/contracts/domain/clause_placeholder_resolver.dart); the
/// "insert token" menu next to each content field helps avoid typos.
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
        titleArController: TextEditingController(),
        titleEnController: TextEditingController(),
        contentArController: TextEditingController(),
        contentEnController: TextEditingController(),
      );

  @override
  void initState() {
    super.initState();
    _drafts = widget.initialClauses
        .map((c) => _ClauseDraft(
              id: c.id,
              titleArController: TextEditingController(text: c.titleAr),
              titleEnController: TextEditingController(text: c.titleEn),
              contentArController: TextEditingController(text: c.contentAr),
              contentEnController: TextEditingController(text: c.contentEn),
              isLocked: c.isLocked,
            ))
        .toList();
    if (_drafts.isEmpty) _drafts.add(_newDraft());
    _emit();
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
      return TemplateClause(
        id: draft.id,
        order: entry.key + 1,
        titleAr: draft.titleArController.text.trim(),
        titleEn: draft.titleEnController.text.trim(),
        contentAr: draft.contentArController.text.trim(),
        contentEn: draft.contentEnController.text.trim(),
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
      removed.titleArController.dispose();
      removed.titleEnController.dispose();
      removed.contentArController.dispose();
      removed.contentEnController.dispose();
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
      key: Key('insertTokenButton_$i'),
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
                          key: Key('clauseTitleEnField_$i'),
                          controller: _drafts[i].titleEnController,
                          decoration: const InputDecoration(labelText: 'Clause Title (EN)'),
                          validator: (v) => (v == null || v.trim().isEmpty) ? 'Required' : null,
                          onChanged: (_) => _emit(),
                        ),
                      ),
                      const SizedBox(width: 8),
                      Expanded(
                        child: TextFormField(
                          key: Key('clauseTitleArField_$i'),
                          controller: _drafts[i].titleArController,
                          textDirection: TextDirection.rtl,
                          decoration: const InputDecoration(labelText: 'عنوان البند (AR)'),
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
                  const SizedBox(height: 8),
                  Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Expanded(
                        child: TextFormField(
                          key: Key('clauseContentEnField_$i'),
                          controller: _drafts[i].contentEnController,
                          decoration: const InputDecoration(labelText: 'Content (EN)'),
                          maxLines: 3,
                          validator: (v) => (v == null || v.trim().isEmpty) ? 'Required' : null,
                          onChanged: (_) => _emit(),
                        ),
                      ),
                      _insertTokenButton(i, _drafts[i].contentEnController),
                    ],
                  ),
                  const SizedBox(height: 8),
                  Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Expanded(
                        child: TextFormField(
                          key: Key('clauseContentArField_$i'),
                          controller: _drafts[i].contentArController,
                          textDirection: TextDirection.rtl,
                          decoration: const InputDecoration(labelText: 'المحتوى (AR)'),
                          maxLines: 3,
                          validator: (v) => (v == null || v.trim().isEmpty) ? 'Required' : null,
                          onChanged: (_) => _emit(),
                        ),
                      ),
                      _insertTokenButton(i, _drafts[i].contentArController),
                    ],
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

/// Grouped catalog backing the "insert token" menu — kept here (rather than
/// alongside the resolver) since it's a presentation-layer concern (human
/// labels for a menu), while the resolver itself only needs the bare token
/// names. Token names here MUST match `_tokenValues`' keys in
/// lib/features/contracts/domain/clause_placeholder_resolver.dart exactly.
class MergeFieldTokenGroup {
  final String label;
  final List<({String token, String label})> tokens;
  const MergeFieldTokenGroup(this.label, this.tokens);
}

const mergeFieldTokenGroups = [
  MergeFieldTokenGroup('Tenant', [
    (token: 'tenantName', label: 'Tenant Name'),
    (token: 'tenantTradeName', label: 'Tenant Trade Name'),
    (token: 'tenantPhone', label: 'Tenant Phone'),
    (token: 'tenantEmail', label: 'Tenant Email'),
    (token: 'tenantEmiratesId', label: 'Tenant Emirates ID'),
    (token: 'tenantPassportNumber', label: 'Tenant Passport Number'),
    (token: 'tenantTradeLicenseNumber', label: 'Tenant Trade License No.'),
    (token: 'tenantLicensingAuthority', label: 'Tenant Licensing Authority'),
  ]),
  MergeFieldTokenGroup('Property', [
    (token: 'propertyName', label: 'Property Name'),
    (token: 'propertyCode', label: 'Property Code'),
    (token: 'propertyType', label: 'Property Type'),
    (token: 'propertyUnitNumber', label: 'Unit Number'),
    (token: 'propertyArea', label: 'Area'),
    (token: 'propertyEmirate', label: 'Emirate'),
    (token: 'propertyCity', label: 'City'),
  ]),
  MergeFieldTokenGroup('Lease Terms', [
    (token: 'leasedPropertyType', label: 'Leased Property Type'),
    (token: 'buildingName', label: 'Building Name'),
    (token: 'commencementDate', label: 'Commencement Date'),
    (token: 'expiryDate', label: 'Expiry Date'),
    (token: 'yearlyRentAmount', label: 'Yearly Rent Amount'),
    (token: 'purposeOfUsage', label: 'Purpose of Usage'),
    (token: 'modeOfPayment', label: 'Mode of Payment'),
    (token: 'insuranceAllowance', label: 'Insurance Allowance'),
    (token: 'managementFeeAmount', label: 'Management Fee Amount'),
    (token: 'vatAmount', label: 'VAT Amount'),
    (token: 'numberOfCoOccupants', label: 'Number of Co-Occupants'),
  ]),
  MergeFieldTokenGroup('Company', [
    (token: 'contractNumber', label: 'Contract Number'),
    (token: 'companyName', label: 'Company Name'),
    (token: 'companyPhone', label: 'Company Phone'),
    (token: 'companyEmail', label: 'Company Email'),
    (token: 'ownerName', label: "Owner/Lessor's Name"),
    (token: 'ownerEmiratesId', label: "Owner's Emirates ID"),
    (token: 'today', label: "Today's Date"),
  ]),
];
