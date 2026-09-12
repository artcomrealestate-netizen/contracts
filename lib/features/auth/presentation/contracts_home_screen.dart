import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../customers/presentation/customers_list_screen.dart';
import '../../properties/presentation/properties_list_screen.dart';
import '../domain/permission.dart';
import 'auth_controller.dart';

/// Landing screen for the auth-gated Contract System module. Customers and
/// Properties (TDD §13/§14) are the first real features on top of the auth
/// foundation; the rest (templates, contracts, approvals, dashboard) are
/// built in later phases per docs/Contract_System_TDD_v1.1_EN.md §68.
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
      body: Column(
        children: [
          Padding(
            padding: const EdgeInsets.all(16),
            child: Column(
              children: [
                Text('Signed in as ${user?.displayName ?? user?.email ?? ''}'),
                const SizedBox(height: 4),
                Text('Role: ${user?.role.name ?? ''}', style: Theme.of(context).textTheme.bodySmall),
              ],
            ),
          ),
          const Divider(height: 1),
          Expanded(
            child: ListView(
              children: [
                if (user?.hasPermission(Permission.customerRead) ?? false)
                  ListTile(
                    key: const Key('customersMenuTile'),
                    leading: const Icon(Icons.people_outline),
                    title: const Text('Customers'),
                    trailing: const Icon(Icons.chevron_right),
                    onTap: () => Navigator.of(context).push(
                      MaterialPageRoute(builder: (_) => const CustomersListScreen()),
                    ),
                  ),
                if (user?.hasPermission(Permission.propertyRead) ?? false)
                  ListTile(
                    key: const Key('propertiesMenuTile'),
                    leading: const Icon(Icons.apartment_outlined),
                    title: const Text('Properties'),
                    trailing: const Icon(Icons.chevron_right),
                    onTap: () => Navigator.of(context).push(
                      MaterialPageRoute(builder: (_) => const PropertiesListScreen()),
                    ),
                  ),
                const ListTile(
                  leading: Icon(Icons.description_outlined, color: Colors.grey),
                  title: Text('Contracts', style: TextStyle(color: Colors.grey)),
                  subtitle: Text('Coming in a later phase'),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
