import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../auth/domain/permission.dart';
import '../../auth/presentation/auth_controller.dart';
import '../domain/customer.dart';
import 'add_customer_screen.dart';
import 'customer_providers.dart';

class CustomersListScreen extends ConsumerWidget {
  const CustomersListScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final user = ref.watch(authControllerProvider).value;
    final canCreate = user?.hasPermission(Permission.customerCreate) ?? false;
    final customersAsync = ref.watch(customersStreamProvider);

    return Scaffold(
      appBar: AppBar(title: const Text('Customers')),
      body: customersAsync.when(
        data: (customers) {
          if (customers.isEmpty) {
            return const Center(child: Text('No customers yet.'));
          }
          return ListView.separated(
            itemCount: customers.length,
            separatorBuilder: (_, _) => const Divider(height: 1),
            itemBuilder: (context, index) {
              final customer = customers[index];
              final subtitle = customer.contact.phone ?? customer.contact.email ?? '';
              return ListTile(
                key: Key('customerTile_${customer.id}'),
                title: Text(customer.displayName),
                subtitle: subtitle.isEmpty ? null : Text(subtitle),
                trailing: Text(
                  customer.customerType == CustomerType.individual ? 'Individual' : 'Company',
                  style: Theme.of(context).textTheme.bodySmall,
                ),
              );
            },
          );
        },
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (error, _) => Center(child: Text('Failed to load customers: $error')),
      ),
      floatingActionButton: canCreate
          ? FloatingActionButton(
              key: const Key('addCustomerButton'),
              onPressed: () => Navigator.of(context).push(
                MaterialPageRoute(builder: (_) => const AddCustomerScreen()),
              ),
              child: const Icon(Icons.add),
            )
          : null,
    );
  }
}
