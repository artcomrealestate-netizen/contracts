import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../auth/domain/permission.dart';
import '../../auth/presentation/auth_controller.dart';
import 'add_property_screen.dart';
import 'property_providers.dart';

class PropertiesListScreen extends ConsumerWidget {
  const PropertiesListScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final user = ref.watch(authControllerProvider).value;
    final canCreate = user?.hasPermission(Permission.propertyCreate) ?? false;
    final canUpdate = user?.hasPermission(Permission.propertyUpdate) ?? false;
    final propertiesAsync = ref.watch(propertiesStreamProvider);

    return Scaffold(
      appBar: AppBar(title: const Text('Properties')),
      body: propertiesAsync.when(
        data: (properties) {
          if (properties.isEmpty) {
            return const Center(child: Text('No properties yet.'));
          }
          return ListView.separated(
            itemCount: properties.length,
            separatorBuilder: (_, _) => const Divider(height: 1),
            itemBuilder: (context, index) {
              final property = properties[index];
              final subtitleParts = [
                if (property.unitNumber != null) 'Unit ${property.unitNumber}',
                property.propertyType,
              ].where((s) => s.isNotEmpty).join(' • ');
              return ListTile(
                key: Key('propertyTile_${property.id}'),
                title: Text(property.name),
                subtitle: Text(subtitleParts),
                trailing: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text(
                      property.propertyCode,
                      style: Theme.of(context).textTheme.bodySmall,
                    ),
                    if (canUpdate)
                      IconButton(
                        key: Key('editPropertyButton_${property.id}'),
                        icon: const Icon(Icons.edit_outlined, size: 20),
                        tooltip: 'Edit',
                        onPressed: () => Navigator.of(context).push(
                          MaterialPageRoute(builder: (_) => AddPropertyScreen(existingProperty: property)),
                        ),
                      ),
                  ],
                ),
              );
            },
          );
        },
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (error, _) => Center(child: Text('Failed to load properties: $error')),
      ),
      floatingActionButton: canCreate
          ? FloatingActionButton(
              key: const Key('addPropertyButton'),
              onPressed: () => Navigator.of(context).push(
                MaterialPageRoute(builder: (_) => const AddPropertyScreen()),
              ),
              child: const Icon(Icons.add),
            )
          : null,
    );
  }
}
