import 'dart:io' show Platform;

import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/theme/app_theme.dart';
import '../../../core/widgets/inline_banner.dart';
import 'auth_controller.dart';
import 'reset_password_screen.dart';
import 'signup_screen.dart';

/// google_sign_in has no Windows implementation; Windows users sign in with
/// email/password only until a desktop-capable flow is added.
bool get _googleSignInSupported =>
    kIsWeb || Platform.isAndroid || Platform.isIOS;

class LoginScreen extends ConsumerStatefulWidget {
  final String? errorMessage;

  const LoginScreen({super.key, this.errorMessage});

  @override
  ConsumerState<LoginScreen> createState() => _LoginScreenState();
}

class _LoginScreenState extends ConsumerState<LoginScreen> {
  final _emailController = TextEditingController();
  final _passwordController = TextEditingController();
  final _formKey = GlobalKey<FormState>();

  @override
  void dispose() {
    _emailController.dispose();
    _passwordController.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    if (!_formKey.currentState!.validate()) return;
    await ref.read(authControllerProvider.notifier).signIn(
          email: _emailController.text.trim(),
          password: _passwordController.text,
        );
  }

  Future<void> _submitGoogle() async {
    await ref.read(authControllerProvider.notifier).signInWithGoogle();
  }

  @override
  Widget build(BuildContext context) {
    final authState = ref.watch(authControllerProvider);
    final isLoading = authState.isLoading;

    final colorScheme = Theme.of(context).colorScheme;

    return Scaffold(
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
                    Icon(Icons.description_outlined, size: 48, color: colorScheme.primary),
                    const SizedBox(height: AppSpacing.md),
                    Text(
                      'Contract System',
                      textAlign: TextAlign.center,
                      style: Theme.of(context).textTheme.headlineSmall?.copyWith(fontWeight: FontWeight.w700),
                    ),
                    const SizedBox(height: AppSpacing.xxl),
                    if (widget.errorMessage != null) ...[
                      InlineBanner(key: const Key('loginErrorBanner'), message: widget.errorMessage!),
                      const SizedBox(height: AppSpacing.lg),
                    ],
                    TextFormField(
                      key: const Key('loginEmailField'),
                      controller: _emailController,
                      keyboardType: TextInputType.emailAddress,
                      decoration: const InputDecoration(labelText: 'Email'),
                      validator: (value) =>
                          (value == null || value.trim().isEmpty) ? 'Required' : null,
                    ),
                    const SizedBox(height: AppSpacing.md),
                    TextFormField(
                      key: const Key('loginPasswordField'),
                      controller: _passwordController,
                      obscureText: true,
                      decoration: const InputDecoration(labelText: 'Password'),
                      validator: (value) =>
                          (value == null || value.isEmpty) ? 'Required' : null,
                    ),
                    const SizedBox(height: AppSpacing.xl),
                    ElevatedButton(
                      key: const Key('loginSubmitButton'),
                      onPressed: isLoading ? null : _submit,
                      child: isLoading
                          ? const SizedBox(
                              height: 18,
                              width: 18,
                              child: CircularProgressIndicator(strokeWidth: 2),
                            )
                          : const Text('Sign In'),
                    ),
                    TextButton(
                      key: const Key('forgotPasswordButton'),
                      onPressed: isLoading
                          ? null
                          : () => Navigator.of(context).push(
                                MaterialPageRoute(
                                  builder: (_) => const ResetPasswordScreen(),
                                ),
                              ),
                      child: const Text('Forgot password?'),
                    ),
                    TextButton(
                      key: const Key('goToSignUpButton'),
                      onPressed: isLoading
                          ? null
                          : () => Navigator.of(context).push(
                                MaterialPageRoute(
                                  builder: (_) => const SignUpScreen(),
                                ),
                              ),
                      child: const Text("Don't have an account? Sign Up"),
                    ),
                    if (_googleSignInSupported) ...[
                      const SizedBox(height: AppSpacing.sm),
                      Row(
                        children: [
                          const Expanded(child: Divider()),
                          Padding(
                            padding: const EdgeInsets.symmetric(horizontal: AppSpacing.sm),
                            child: Text('or', style: TextStyle(color: colorScheme.onSurfaceVariant)),
                          ),
                          const Expanded(child: Divider()),
                        ],
                      ),
                      const SizedBox(height: AppSpacing.sm),
                      OutlinedButton.icon(
                        key: const Key('googleSignInButton'),
                        onPressed: isLoading ? null : _submitGoogle,
                        icon: const Icon(Icons.g_mobiledata, size: 28),
                        label: const Text('Sign in with Google'),
                      ),
                    ] else ...[
                      const SizedBox(height: AppSpacing.sm),
                      Text(
                        'Google sign-in is available on the web and mobile apps.',
                        textAlign: TextAlign.center,
                        style: Theme.of(context)
                            .textTheme
                            .bodySmall
                            ?.copyWith(color: colorScheme.onSurfaceVariant),
                      ),
                    ],
                  ],
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}
