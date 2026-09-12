import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/providers/firebase_providers.dart';
import '../data/firestore_contract_repository.dart';
import '../domain/contract.dart';
import '../domain/contract_repository.dart';

final contractRepositoryProvider = Provider<ContractRepository>((ref) {
  return FirestoreContractRepository(ref.watch(firestoreProvider));
});

/// Family key is the owner scope: null sees every contract (contract.edit_any
/// — an admin-level scope), a uid restricts to that user's own contracts.
final contractsStreamProvider = StreamProvider.family<List<Contract>, String?>((ref, ownerId) {
  return ref.watch(contractRepositoryProvider).watchContracts(ownerId: ownerId);
});

final contractByIdProvider = StreamProvider.family<Contract?, String>((ref, id) {
  return ref.watch(contractRepositoryProvider).watchContract(id);
});
