import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'auth_controller.dart';

/// Placeholder landing screen proving the auth+RBAC pipeline end-to-end.
/// The real dashboard (customers, properties, contracts, approvals) is
/// built in later phases per docs/Contract_System_TDD_v1.1_EN.md §74.
class ContractsHomeScreen extends ConsumerWidget {
  const ContractsHomeScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final user = ref.watch(authControllerProvider).value;

    return Scaffold(
      appBar: AppBar(
        title: const Text('Contract System'),
        actions: [
          IconButton(
            key: const Key('logoutButton'),
            icon: const Icon(Icons.logout),
            tooltip: 'Sign out',
            onPressed: () => ref.read(authControllerProvider.notifier).signOut(),
          ),
        ],
      ),
      body: Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text('Signed in as ${user?.displayName ?? user?.email ?? ''}'),
            const SizedBox(height: 8),
            Text('Role: ${user?.role.name ?? ''}'),
            const SizedBox(height: 24),
            const Text('Dashboard coming in Phase 2.'),
          ],
        ),
      ),
    );
  }
}
