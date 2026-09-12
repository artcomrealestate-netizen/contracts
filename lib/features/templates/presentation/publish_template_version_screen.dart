import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../auth/presentation/auth_controller.dart';
import '../domain/contract_template.dart';
import '../domain/template_clause.dart';
import 'clause_list_field.dart';
import 'template_providers.dart';

/// Starts from the current version's clauses (editable from here) and
/// publishes them as a brand-new, separately immutable version — never
/// edits the version it started from (TDD §15/§16).
class PublishTemplateVersionScreen extends ConsumerStatefulWidget {
  final ContractTemplate template;
  final List<TemplateClause> currentClauses;

  const PublishTemplateVersionScreen({
    super.key,
    required this.template,
    required this.currentClauses,
  });

  @override
  ConsumerState<PublishTemplateVersionScreen> createState() => _PublishTemplateVersionScreenState();
}

class _PublishTemplateVersionScreenState extends ConsumerState<PublishTemplateVersionScreen> {
  final _formKey = GlobalKey<FormState>();
  List<TemplateClause> _clauses = const [];

  bool _submitting = false;
  String? _errorMessage;

  Future<void> _submit() async {
    if (!_formKey.currentState!.validate()) return;
    final currentUser = ref.read(authControllerProvider).value;
    if (currentUser == null) return;

    setState(() {
      _submitting = true;
      _errorMessage = null;
    });
    try {
      await ref.read(templateRepositoryProvider).publishNewVersion(
            template: widget.template,
            clauses: _clauses,
            createdBy: currentUser.id,
          );
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
      appBar: AppBar(
        title: Text('Publish Version ${widget.template.currentVersion + 1}'),
      ),
      body: Form(
        key: _formKey,
        child: ListView(
          padding: const EdgeInsets.all(16),
          children: [
            if (_errorMessage != null) ...[
              Container(
                key: const Key('publishVersionErrorBanner'),
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
            Text(
              '${widget.template.name} (${widget.template.code})',
              style: Theme.of(context).textTheme.titleMedium,
            ),
            const SizedBox(height: 8),
            Text(
              'Editing starts from the clauses in version ${widget.template.currentVersion}. '
              'Saving creates a new version — it never changes the one you started from.',
              style: Theme.of(context).textTheme.bodySmall,
            ),
            const SizedBox(height: 16),
            ClauseListField(
              initialClauses: widget.currentClauses,
              onChanged: (clauses) => _clauses = clauses,
            ),
            const SizedBox(height: 24),
            ElevatedButton(
              key: const Key('submitPublishVersionButton'),
              onPressed: _submitting ? null : _submit,
              child: _submitting
                  ? const SizedBox(
                      height: 18,
                      width: 18,
                      child: CircularProgressIndicator(strokeWidth: 2),
                    )
                  : Text('Publish Version ${widget.template.currentVersion + 1}'),
            ),
          ],
        ),
      ),
    );
  }
}
