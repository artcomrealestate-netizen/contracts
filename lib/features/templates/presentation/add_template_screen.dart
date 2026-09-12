import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/widgets/inline_banner.dart';
import '../../auth/presentation/auth_controller.dart';
import '../domain/template_clause.dart';
import 'clause_list_field.dart';
import 'template_providers.dart';

class AddTemplateScreen extends ConsumerStatefulWidget {
  const AddTemplateScreen({super.key});

  @override
  ConsumerState<AddTemplateScreen> createState() => _AddTemplateScreenState();
}

class _AddTemplateScreenState extends ConsumerState<AddTemplateScreen> {
  final _formKey = GlobalKey<FormState>();
  final _nameController = TextEditingController();
  final _codeController = TextEditingController();
  List<TemplateClause> _clauses = const [];

  bool _submitting = false;
  String? _errorMessage;

  @override
  void dispose() {
    _nameController.dispose();
    _codeController.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    if (!_formKey.currentState!.validate()) return;
    final currentUser = ref.read(authControllerProvider).value;
    if (currentUser == null) return;

    setState(() {
      _submitting = true;
      _errorMessage = null;
    });
    try {
      await ref.read(templateRepositoryProvider).createTemplate(
            name: _nameController.text.trim(),
            code: _codeController.text.trim(),
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
      appBar: AppBar(title: const Text('New Contract Template')),
      body: Form(
        key: _formKey,
        child: ListView(
          padding: const EdgeInsets.all(16),
          children: [
            if (_errorMessage != null) ...[
              InlineBanner(key: const Key('addTemplateErrorBanner'), message: _errorMessage!),
              const SizedBox(height: 16),
            ],
            TextFormField(
              key: const Key('templateNameField'),
              controller: _nameController,
              decoration: const InputDecoration(labelText: 'Name'),
              validator: (value) => (value == null || value.trim().isEmpty) ? 'Required' : null,
            ),
            const SizedBox(height: 12),
            TextFormField(
              key: const Key('templateCodeField'),
              controller: _codeController,
              decoration: const InputDecoration(labelText: 'Code'),
              validator: (value) => (value == null || value.trim().isEmpty) ? 'Required' : null,
            ),
            const SizedBox(height: 20),
            Text('Clauses (version 1)', style: Theme.of(context).textTheme.titleMedium),
            const SizedBox(height: 8),
            ClauseListField(initialClauses: const [], onChanged: (clauses) => _clauses = clauses),
            const SizedBox(height: 24),
            ElevatedButton(
              key: const Key('submitTemplateButton'),
              onPressed: _submitting ? null : _submit,
              child: _submitting
                  ? const SizedBox(
                      height: 18,
                      width: 18,
                      child: CircularProgressIndicator(strokeWidth: 2),
                    )
                  : const Text('Create Template'),
            ),
          ],
        ),
      ),
    );
  }
}
