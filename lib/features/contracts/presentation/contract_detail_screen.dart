import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../customers/presentation/customer_providers.dart';
import '../../properties/presentation/property_providers.dart';
import '../domain/contract.dart';

class ContractDetailScreen extends ConsumerWidget {
  final Contract contract;

  const ContractDetailScreen({super.key, required this.contract});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final customerAsync = ref.watch(customerByIdProvider(contract.customerId));
    final propertyAsync = ref.watch(propertyByIdProvider(contract.propertyId));

    return Scaffold(
      appBar: AppBar(title: Text(contract.contractNumber)),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          _DetailRow(label: 'Status', value: contractStatusToString(contract.status)),
          _DetailRow(
            label: 'Customer',
            value: customerAsync.when(
              data: (customer) => customer?.displayName ?? contract.customerId,
              loading: () => '...',
              error: (_, _) => contract.customerId,
            ),
          ),
          _DetailRow(
            label: 'Property',
            value: propertyAsync.when(
              data: (property) => property?.name ?? contract.propertyId,
              loading: () => '...',
              error: (_, _) => contract.propertyId,
            ),
          ),
          if (contract.sourceQuotationId != null && contract.sourceQuotationId!.isNotEmpty)
            _DetailRow(label: 'Source Quotation', value: contract.sourceQuotationId!),
          _DetailRow(label: 'Template Version', value: 'v${contract.templateVersion}'),
          const SizedBox(height: 16),
          Text('Clauses', style: Theme.of(context).textTheme.titleMedium),
          const SizedBox(height: 8),
          for (final clause in contract.clauses)
            ListTile(
              key: Key('contractDetailClauseTile_${clause.id}'),
              title: Text(clause.title),
              subtitle: Text(clause.content),
              trailing: clause.isLocked ? const Icon(Icons.lock_outline, size: 18) : null,
            ),
        ],
      ),
    );
  }
}

class _DetailRow extends StatelessWidget {
  final String label;
  final String value;

  const _DetailRow({required this.label, required this.value});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(width: 140, child: Text(label, style: Theme.of(context).textTheme.bodySmall)),
          Expanded(child: Text(value)),
        ],
      ),
    );
  }
}
