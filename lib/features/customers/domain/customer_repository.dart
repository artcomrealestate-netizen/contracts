import 'customer.dart';

abstract class CustomerRepository {
  Future<Customer> createCustomer(Customer customer);

  Future<Customer?> getCustomer(String id);

  /// Newest-first. No pagination yet (TDD §36 pagination lands with
  /// Dashboard/Search, phase 10) — fine for the small lists this phase deals with.
  Stream<List<Customer>> watchCustomers();
}
