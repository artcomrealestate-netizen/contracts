import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../auth/domain/permission.dart';
import '../../auth/presentation/auth_controller.dart';
import '../domain/property.dart';
import 'add_property_screen.dart';
import 'property_providers.dart';

class PropertiesListScreen extends ConsumerStatefulWidget {
  const PropertiesListScreen({super.key});

  @override
  ConsumerState<PropertiesListScreen> createState() => _PropertiesListScreenState();
}

class _PropertiesListScreenState extends ConsumerState<PropertiesListScreen> {
  final _searchController = TextEditingController();
  String _query = '';

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final user = ref.watch(authControllerProvider).value;
    final canCreate = user?.hasPermission(Permission.propertyCreate) ?? false;
    final canUpdate = user?.hasPermission(Permission.propertyUpdate) ?? false;
    final propertiesAsync = ref.watch(propertiesStreamProvider);
    final query = _query.trim().toLowerCase();

    return Scaffold(
      appBar: AppBar(title: const Text('Properties')),
      body: Column(
        children: [
          Padding(
            padding: const EdgeInsets.all(12),
            child: TextField(
              key: const Key('propertySearchField'),
              controller: _searchController,
              decoration: InputDecoration(
                hintText: 'Search by name, code, or unit',
                prefixIcon: const Icon(Icons.search),
                border: OutlineInputBorder(borderRadius: BorderRadius.circular(8)),
              ),
              onChanged: (value) => setState(() => _query = value),
            ),
          ),
          Expanded(
            child: propertiesAsync.when(
              data: (allProperties) {
                final properties = allProperties.where((p) {
                  if (query.isEmpty) return true;
                  return p.name.toLowerCase().contains(query) ||
                      p.propertyCode.toLowerCase().contains(query) ||
                      (p.unitNumber?.toLowerCase().contains(query) ?? false);
                }).toList();

                if (properties.isEmpty) {
                  return Center(child: Text(allProperties.isEmpty ? 'No properties yet.' : 'No matches.'));
                }
                return ListView.separated(
                  itemCount: properties.length,
                  separatorBuilder: (_, _) => const Divider(height: 1),
                  itemBuilder: (context, index) {
                    final property = properties[index];
                    final isInactive = property.status == PropertyStatus.inactive;
                    final subtitleParts = [
                      if (property.unitNumber != null) 'Unit ${property.unitNumber}',
                      property.propertyType,
                      if (isInactive) 'Inactive',
                    ].where((s) => s.isNotEmpty).join(' • ');
                    return ListTile(
                      key: Key('propertyTile_${property.id}'),
                      title: Text(
                        property.name,
                        style: isInactive ? const TextStyle(decoration: TextDecoration.lineThrough) : null,
                      ),
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
                          if (canUpdate)
                            IconButton(
                              key: Key('togglePropertyStatusButton_${property.id}'),
                              icon: Icon(isInactive ? Icons.unarchive_outlined : Icons.archive_outlined, size: 20),
                              tooltip: isInactive ? 'Reactivate' : 'Deactivate',
                              onPressed: () => ref.read(propertyRepositoryProvider).updateProperty(
                                    property.copyWith(
                                      status: isInactive ? PropertyStatus.active : PropertyStatus.inactive,
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
              error: (error, _) => Center(child: Text('Failed to load properties: $error')),
            ),
          ),
        ],
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
