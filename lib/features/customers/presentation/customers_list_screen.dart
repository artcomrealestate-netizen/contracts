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
    final canUpdate = user?.hasPermission(Permission.customerUpdate) ?? false;
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
              final isInactive = customer.status == CustomerStatus.inactive;
              return ListTile(
                key: Key('customerTile_${customer.id}'),
                title: Text(
                  customer.displayName,
                  style: isInactive ? const TextStyle(decoration: TextDecoration.lineThrough) : null,
                ),
                subtitle: Text([
                  if (subtitle.isNotEmpty) subtitle,
                  if (isInactive) 'Inactive',
                ].join(' • ')),
                trailing: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text(
                      customer.customerType == CustomerType.individual ? 'Individual' : 'Company',
                      style: Theme.of(context).textTheme.bodySmall,
                    ),
                    if (canUpdate)
                      IconButton(
                        key: Key('editCustomerButton_${customer.id}'),
                        icon: const Icon(Icons.edit_outlined, size: 20),
                        tooltip: 'Edit',
                        onPressed: () => Navigator.of(context).push(
                          MaterialPageRoute(builder: (_) => AddCustomerScreen(existingCustomer: customer)),
                        ),
                      ),
                    if (canUpdate)
                      IconButton(
                        key: Key('toggleCustomerStatusButton_${customer.id}'),
                        icon: Icon(isInactive ? Icons.unarchive_outlined : Icons.archive_outlined, size: 20),
                        tooltip: isInactive ? 'Reactivate' : 'Deactivate',
                        onPressed: () => ref.read(customerRepositoryProvider).updateCustomer(
                              customer.copyWith(
                                status: isInactive ? CustomerStatus.active : CustomerStatus.inactive,
                              ),
                            ),
                      ),
                  ],
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
