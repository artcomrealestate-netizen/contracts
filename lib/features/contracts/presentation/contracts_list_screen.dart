import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../auth/domain/permission.dart';
import '../../auth/presentation/auth_controller.dart';
import '../domain/contract.dart';
import 'contract_detail_screen.dart';
import 'contract_providers.dart';
import 'create_contract_screen.dart';

class ContractsListScreen extends ConsumerWidget {
  const ContractsListScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final user = ref.watch(authControllerProvider).value;
    final canCreate = user?.hasPermission(Permission.contractCreate) ?? false;
    final contractsAsync = ref.watch(contractsStreamProvider);

    return Scaffold(
      appBar: AppBar(title: const Text('Contracts')),
      body: contractsAsync.when(
        data: (contracts) {
          if (contracts.isEmpty) {
            return const Center(child: Text('No contracts yet.'));
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
