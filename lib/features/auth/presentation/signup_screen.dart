import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/theme/app_theme.dart';
import 'auth_controller.dart';

/// Self-service account creation. A new account always lands on
/// `status: pending` (AuthController.signUp / FirestoreUserRepository.
/// createPendingUser) — an admin must approve it from the Pending Users
/// screen before it can sign in.
///
/// Presented in Arabic with an explicit RTL Directionality wrapper, unlike
/// the rest of the auth feature (Login/ContractsHome/...) which stays
/// English to match its existing convention — this is a new, self-
/// contained screen so it doesn't inherit that constraint.
class SignUpScreen extends ConsumerStatefulWidget {
  const SignUpScreen({super.key});

  @override
  ConsumerState<SignUpScreen> createState() => _SignUpScreenState();
}

class _SignUpScreenState extends ConsumerState<SignUpScreen> {
  final _nameController = TextEditingController();
  final _emailController = TextEditingController();
  final _passwordController = TextEditingController();
  final _confirmPasswordController = TextEditingController();
  final _formKey = GlobalKey<FormState>();

  @override
  void dispose() {
    _nameController.dispose();
    _emailController.dispose();
    _passwordController.dispose();
    _confirmPasswordController.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    if (!_formKey.currentState!.validate()) return;
    await ref.read(authControllerProvider.notifier).signUp(
          email: _emailController.text.trim(),
          password: _passwordController.text,
          displayName: _nameController.text.trim(),
        );
    // A successful signup always resolves to AsyncError("...بانتظار موافقة
    // الأدمن...") — see AuthController.signUp/_loadActiveProfile. Popping
    // back reveals LoginScreen underneath, which _AppRoot has already
    // rebuilt with that message.
    if (mounted && ref.read(authControllerProvider).hasError) {
      Navigator.of(context).pop();
    }
  }

  @override
  Widget build(BuildContext context) {
    final authState = ref.watch(authControllerProvider);
    final isLoading = authState.isLoading;

    return Directionality(
      textDirection: TextDirection.rtl,
      child: Scaffold(
        appBar: AppBar(title: const Text('إنشاء حساب')),
        body: SafeArea(
          child: Center(
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 420),
              child: SingleChildScrollView(
                padding: const EdgeInsets.all(AppSpacing.xl),
                child: Form(
                  key: _formKey,
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      Text(
                        'حسابك الجديد سيبقى بانتظار موافقة الأدمن قبل ما تقدر تسجّل الدخول.',
                        textAlign: TextAlign.center,
                        style: Theme.of(context)
                            .textTheme
                            .bodySmall
                            ?.copyWith(color: Theme.of(context).colorScheme.onSurfaceVariant),
                      ),
                      const SizedBox(height: AppSpacing.lg),
                      TextFormField(
                        key: const Key('signUpNameField'),
                        controller: _nameController,
                        decoration: const InputDecoration(labelText: 'الاسم الكامل'),
                        validator: (value) =>
                            (value == null || value.trim().isEmpty) ? 'هذا الحقل مطلوب' : null,
                      ),
                      const SizedBox(height: AppSpacing.md),
                      TextFormField(
                        key: const Key('signUpEmailField'),
                        controller: _emailController,
                        keyboardType: TextInputType.emailAddress,
                        decoration: const InputDecoration(labelText: 'البريد الإلكتروني'),
                        validator: (value) =>
                            (value == null || value.trim().isEmpty) ? 'هذا الحقل مطلوب' : null,
                      ),
                      const SizedBox(height: AppSpacing.md),
                      TextFormField(
                        key: const Key('signUpPasswordField'),
                        controller: _passwordController,
                        obscureText: true,
                        decoration: const InputDecoration(labelText: 'كلمة السر'),
                        validator: (value) {
                          if (value == null || value.isEmpty) return 'هذا الحقل مطلوب';
                          if (value.length < 6) return 'يجب أن تكون 6 أحرف على الأقل';
                          return null;
                        },
                      ),
                      const SizedBox(height: AppSpacing.md),
                      TextFormField(
                        key: const Key('signUpConfirmPasswordField'),
                        controller: _confirmPasswordController,
                        obscureText: true,
                        decoration: const InputDecoration(labelText: 'تأكيد كلمة السر'),
                        validator: (value) =>
                            value != _passwordController.text ? 'كلمتا السر غير متطابقتين' : null,
                      ),
                      const SizedBox(height: AppSpacing.xl),
                      ElevatedButton(
                        key: const Key('signUpSubmitButton'),
                        onPressed: isLoading ? null : _submit,
                        child: isLoading
                            ? const SizedBox(
                                height: 18,
                                width: 18,
                                child: CircularProgressIndicator(strokeWidth: 2),
                              )
                            : const Text('إنشاء الحساب'),
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}
