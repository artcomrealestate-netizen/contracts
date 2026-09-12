import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/providers/firebase_providers.dart';
import '../data/firestore_customer_repository.dart';
import '../domain/customer.dart';
import '../domain/customer_repository.dart';

final customerRepositoryProvider = Provider<CustomerRepository>((ref) {
  return FirestoreCustomerRepository(ref.watch(firestoreProvider));
});

final customersStreamProvider = StreamProvider<List<Customer>>((ref) {
  return ref.watch(customerRepositoryProvider).watchCustomers();
});

/// Single-customer lookup, e.g. to show a customer's name on a contract
/// that only stores its `customerId`.
final customerByIdProvider = FutureProvider.family<Customer?, String>((ref, id) {
  return ref.watch(customerRepositoryProvider).getCustomer(id);
});
