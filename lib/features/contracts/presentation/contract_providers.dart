import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/providers/firebase_providers.dart';
import '../data/firestore_contract_repository.dart';
import '../domain/contract.dart';
import '../domain/contract_repository.dart';

final contractRepositoryProvider = Provider<ContractRepository>((ref) {
  return FirestoreContractRepository(ref.watch(firestoreProvider));
});

final contractsStreamProvider = StreamProvider<List<Contract>>((ref) {
  return ref.watch(contractRepositoryProvider).watchContracts();
});

final contractByIdProvider = StreamProvider.family<Contract?, String>((ref, id) {
  return ref.watch(contractRepositoryProvider).watchContract(id);
});
