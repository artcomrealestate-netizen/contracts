import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../auth/domain/permission.dart';
import '../../auth/presentation/auth_controller.dart';
import '../domain/contract.dart';
import 'contract_detail_screen.dart';
import 'contract_providers.dart';
import 'create_contract_screen.dart';

class ContractsListScreen extends ConsumerStatefulWidget {
  const ContractsListScreen({super.key});

  @override
  ConsumerState<ContractsListScreen> createState() => _ContractsListScreenState();
}

class _ContractsListScreenState extends ConsumerState<ContractsListScreen> {
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
    final canCreate = user?.hasPermission(Permission.contractCreate) ?? false;
    // contract.edit_any is the existing "admin-level, not just own" scope
    // (already used to gate editing someone else's contract) — reused here
    // for visibility too: without it, only your own contracts are listed.
    final seesAllContracts = user?.hasPermission(Permission.contractEditAny) ?? false;
    final ownerId = seesAllContracts ? null : user?.id;
    final contractsAsync = ref.watch(contractsStreamProvider(ownerId));
    final query = _query.trim().toLowerCase();

    return Scaffold(
      appBar: AppBar(title: Text(seesAllContracts ? 'All Contracts' : 'My Contracts')),
      body: Column(
        children: [
          Padding(
            padding: const EdgeInsets.all(12),
            child: TextField(
              key: const Key('contractSearchField'),
              controller: _searchController,
              decoration: InputDecoration(
                hintText: 'Search by contract number or status',
                prefixIcon: const Icon(Icons.search),
                border: OutlineInputBorder(borderRadius: BorderRadius.circular(8)),
              ),
              onChanged: (value) => setState(() => _query = value),
            ),
          ),
          Expanded(
            child: contractsAsync.when(
              data: (allContracts) {
                final contracts = allContracts.where((c) {
                  if (query.isEmpty) return true;
                  return c.contractNumber.toLowerCase().contains(query) ||
                      contractStatusToString(c.status).toLowerCase().contains(query);
                }).toList();

                if (contracts.isEmpty) {
                  return Center(child: Text(allContracts.isEmpty ? 'No contracts yet.' : 'No matches.'));
                }
                return ListView.separated(
                  itemCount: contracts.length,
                  separatorBuilder: (_, _) => const Divider(height: 1),
                  itemBuilder: (context, index) {
                    final contract = contracts[index];
                    return ListTile(
                      key: Key('contractTile_${contract.id}'),
                      title: Text(contract.contractNumber),
                      subtitle: Text(contractStatusToString(contract.status)),
                      trailing: const Icon(Icons.chevron_right),
                      onTap: () => Navigator.of(context).push(
                        MaterialPageRoute(builder: (_) => ContractDetailScreen(contractId: contract.id)),
                      ),
                    );
                  },
                );
              },
              loading: () => const Center(child: CircularProgressIndicator()),
              error: (error, _) => Center(child: Text('Failed to load contracts: $error')),
            ),
          ),
        ],
      ),
      floatingActionButton: canCreate
          ? FloatingActionButton(
              key: const Key('addContractButton'),
              onPressed: () => Navigator.of(context).push(
                MaterialPageRoute(builder: (_) => const CreateContractScreen()),
              ),
              child: const Icon(Icons.add),
            )
          : null,
    );
  }
}
