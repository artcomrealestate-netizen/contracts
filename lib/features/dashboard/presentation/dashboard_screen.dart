import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../auth/domain/permission.dart';
import '../../auth/presentation/auth_controller.dart';
import '../../contracts/domain/contract.dart';
import '../../contracts/presentation/contract_detail_screen.dart';
import '../../contracts/presentation/contract_providers.dart';
import 'dashboard_providers.dart';

class DashboardScreen extends ConsumerWidget {
  const DashboardScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final user = ref.watch(authControllerProvider).value;
    // Same admin-level scope already used to decide contract visibility
    // (contracts_list_screen.dart) — reused here to pick which of TDD §34's
    // two dashboards to show.
    final isAdminScope = user?.hasPermission(Permission.contractEditAny) ?? false;

    return Scaffold(
      appBar: AppBar(title: const Text('Dashboard')),
      body: isAdminScope ? const _AdminDashboardBody() : const _EmployeeDashboardBody(),
    );
  }
}

class _AdminDashboardBody extends ConsumerWidget {
  const _AdminDashboardBody();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final summaryAsync = ref.watch(adminDashboardSummaryProvider);
    return summaryAsync.when(
      loading: () => const Center(child: CircularProgressIndicator()),
      error: (error, _) => Center(child: Text('Failed to load dashboard: $error')),
      data: (summary) => GridView.count(
        padding: const EdgeInsets.all(16),
        crossAxisCount: 2,
        mainAxisSpacing: 12,
        crossAxisSpacing: 12,
        childAspectRatio: 1.4,
        children: [
          _DashboardTile(key: const Key('tile_pendingApprovals'), label: 'Pending Approvals', value: summary.pendingApprovals),
          _DashboardTile(key: const Key('tile_rejectedContracts'), label: 'Rejected Contracts', value: summary.rejectedContracts),
          _DashboardTile(key: const Key('tile_approvedThisMonth'), label: 'Approved This Month', value: summary.approvedThisMonth),
          _DashboardTile(key: const Key('tile_finalizedThisMonth'), label: 'Finalized This Month', value: summary.finalizedThisMonth),
        ],
      ),
    );
  }
}

class _EmployeeDashboardBody extends ConsumerWidget {
  const _EmployeeDashboardBody();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final summaryAsync = ref.watch(employeeDashboardSummaryProvider);
    final user = ref.watch(authControllerProvider).value;
    final recentAsync = user == null
        ? const AsyncValue<List<Contract>>.data([])
        : ref.watch(contractsStreamProvider(user.id));

    return summaryAsync.when(
      loading: () => const Center(child: CircularProgressIndicator()),
      error: (error, _) => Center(child: Text('Failed to load dashboard: $error')),
      data: (summary) => ListView(
        padding: const EdgeInsets.all(16),
        children: [
          GridView.count(
            shrinkWrap: true,
            physics: const NeverScrollableScrollPhysics(),
            crossAxisCount: 2,
            mainAxisSpacing: 12,
            crossAxisSpacing: 12,
            childAspectRatio: 1.4,
            children: [
              _DashboardTile(key: const Key('tile_myDrafts'), label: 'My Drafts', value: summary.myDrafts),
              _DashboardTile(key: const Key('tile_pendingApproval'), label: 'Pending Approval', value: summary.pendingApproval),
              _DashboardTile(key: const Key('tile_rejectedContracts'), label: 'Rejected Contracts', value: summary.rejectedContracts),
              _DashboardTile(key: const Key('tile_approvedContracts'), label: 'Approved Contracts', value: summary.approvedContracts),
            ],
          ),
          const SizedBox(height: 24),
          Text('Recent Contracts', style: Theme.of(context).textTheme.titleMedium),
          const SizedBox(height: 8),
          recentAsync.when(
            loading: () => const Center(child: CircularProgressIndicator()),
            error: (error, _) => Text('Failed to load recent contracts: $error'),
            data: (contracts) {
              final recent = contracts.take(5).toList();
              if (recent.isEmpty) {
                return const Text('No contracts yet.');
              }
              return Column(
                children: recent
                    .map((contract) => Card(
                          key: Key('recentContractTile_${contract.id}'),
                          child: ListTile(
                            title: Text(contract.contractNumber),
                            subtitle: Text(contractStatusToString(contract.status)),
                            trailing: const Icon(Icons.chevron_right),
                            onTap: () => Navigator.of(context).push(
                              MaterialPageRoute(builder: (_) => ContractDetailScreen(contractId: contract.id)),
                            ),
                          ),
                        ))
                    .toList(),
              );
            },
          ),
        ],
      ),
    );
  }
}

class _DashboardTile extends StatelessWidget {
  final String label;
  final int value;

  const _DashboardTile({super.key, required this.label, required this.value});

  @override
  Widget build(BuildContext context) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('$value', style: Theme.of(context).textTheme.headlineMedium),
            const SizedBox(height: 4),
            Text(label, style: Theme.of(context).textTheme.bodySmall),
          ],
        ),
      ),
    );
  }
}
