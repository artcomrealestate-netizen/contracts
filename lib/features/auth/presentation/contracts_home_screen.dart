import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../contracts/presentation/contracts_list_screen.dart';
import '../../customers/presentation/customers_list_screen.dart';
import '../../dashboard/presentation/dashboard_screen.dart';
import '../../notifications/presentation/notification_providers.dart';
import '../../notifications/presentation/notifications_list_screen.dart';
import '../../properties/presentation/properties_list_screen.dart';
import '../../templates/presentation/templates_list_screen.dart';
import '../domain/permission.dart';
import 'auth_controller.dart';

/// Landing screen for the auth-gated Contract System module — see
/// docs/Contract_System_TDD_v1.1_EN.md §68 for the phase order this grew in.
class ContractsHomeScreen extends ConsumerWidget {
  const ContractsHomeScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final user = ref.watch(authControllerProvider).value;

    return Scaffold(
      appBar: AppBar(
        title: const Text('Contract System'),
        actions: [
          if (user?.hasPermission(Permission.notificationRead) ?? false)
            Builder(builder: (context) {
              // Badge counts unread personal notifications only — broadcast
              // ones (Submitted) have no single-user read state to count,
              // see NotificationRepository.markAsRead's doc comment.
              final unreadCount = ref
                  .watch(personalNotificationsProvider)
                  .maybeWhen(data: (list) => list.where((n) => !n.isRead).length, orElse: () => 0);
              return IconButton(
                key: const Key('notificationsButton'),
                icon: Badge(
                  label: Text('$unreadCount'),
                  isLabelVisible: unreadCount > 0,
                  child: const Icon(Icons.notifications_outlined),
                ),
                tooltip: 'Notifications',
                onPressed: () => Navigator.of(context).push(
                  MaterialPageRoute(builder: (_) => const NotificationsListScreen()),
                ),
              );
            }),
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
                if (user?.hasPermission(Permission.dashboardRead) ?? false)
                  ListTile(
                    key: const Key('dashboardMenuTile'),
                    leading: const Icon(Icons.dashboard_outlined),
                    title: const Text('Dashboard'),
                    trailing: const Icon(Icons.chevron_right),
                    onTap: () => Navigator.of(context).push(
                      MaterialPageRoute(builder: (_) => const DashboardScreen()),
                    ),
                  ),
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
                if (user?.hasPermission(Permission.templateRead) ?? false)
                  ListTile(
                    key: const Key('templatesMenuTile'),
                    leading: const Icon(Icons.article_outlined),
                    title: const Text('Contract Templates'),
                    trailing: const Icon(Icons.chevron_right),
                    onTap: () => Navigator.of(context).push(
                      MaterialPageRoute(builder: (_) => const TemplatesListScreen()),
                    ),
                  ),
                if (user?.hasPermission(Permission.contractRead) ?? false)
                  ListTile(
                    key: const Key('contractsMenuTile'),
                    leading: const Icon(Icons.description_outlined),
                    title: const Text('Contracts'),
                    trailing: const Icon(Icons.chevron_right),
                    onTap: () => Navigator.of(context).push(
                      MaterialPageRoute(builder: (_) => const ContractsListScreen()),
                    ),
                  ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
