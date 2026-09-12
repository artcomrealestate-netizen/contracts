import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'auth_controller.dart';
import 'contracts_home_screen.dart';
import 'login_screen.dart';

/// Root of the auth-gated contract-system module (TDD §44: Splash -> Login).
/// Pushed from the existing calculator's AppBar; does not affect the
/// calculator's own navigation or state.
class ContractSystemRoot extends ConsumerWidget {
  const ContractSystemRoot({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final authState = ref.watch(authControllerProvider);

    return authState.when(
      loading: () => const _SplashBody(),
      error: (error, _) => LoginScreen(errorMessage: error.toString()),
      data: (user) {
        if (user == null) return const LoginScreen();
        return const ContractsHomeScreen();
      },
    );
  }
}

class _SplashBody extends StatelessWidget {
  const _SplashBody();

  @override
  Widget build(BuildContext context) {
    return const Scaffold(
      body: Center(child: CircularProgressIndicator()),
    );
  }
}
