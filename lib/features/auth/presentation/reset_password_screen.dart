import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'auth_controller.dart';

class ResetPasswordScreen extends ConsumerStatefulWidget {
  const ResetPasswordScreen({super.key});

  @override
  ConsumerState<ResetPasswordScreen> createState() =>
      _ResetPasswordScreenState();
}

class _ResetPasswordScreenState extends ConsumerState<ResetPasswordScreen> {
  final _emailController = TextEditingController();
  final _formKey = GlobalKey<FormState>();
  bool _isSubmitting = false;
  String? _feedback;

  @override
  void dispose() {
    _emailController.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    if (!_formKey.currentState!.validate()) return;
    setState(() {
      _isSubmitting = true;
      _feedback = null;
    });
    try {
      await ref
          .read(authControllerProvider.notifier)
          .sendPasswordResetEmail(_emailController.text.trim());
      setState(() => _feedback = 'Password reset email sent.');
    } catch (e) {
      setState(() => _feedback = e.toString());
    } finally {
      setState(() => _isSubmitting = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Reset Password')),
      body: Center(
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 400),
          child: Padding(
            padding: const EdgeInsets.all(24),
            child: Form(
              key: _formKey,
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  TextFormField(
                    key: const Key('resetEmailField'),
                    controller: _emailController,
                    keyboardType: TextInputType.emailAddress,
                    decoration: const InputDecoration(labelText: 'Email'),
                    validator: (value) =>
                        (value == null || value.trim().isEmpty) ? 'Required' : null,
                  ),
                  const SizedBox(height: 20),
                  ElevatedButton(
                    key: const Key('resetSubmitButton'),
                    onPressed: _isSubmitting ? null : _submit,
                    child: const Text('Send Reset Email'),
                  ),
                  if (_feedback != null) ...[
                    const SizedBox(height: 16),
                    Text(_feedback!, key: const Key('resetFeedbackText')),
                  ],
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}
