import 'package:flutter_test/flutter_test.dart';
import 'package:qouta_calculator/features/customers/domain/customer.dart';

void main() {
  group('Customer', () {
    test('displayName resolves from individual.fullName for an individual customer', () {
      const customer = Customer(
        id: 'c1',
        customerType: CustomerType.individual,
        individual: IndividualDetails(fullName: 'Jane Doe'),
        contact: CustomerContact(),
        status: CustomerStatus.active,
        createdBy: 'u1',
      );
      expect(customer.displayName, 'Jane Doe');
    });

    test('displayName resolves from company.legalName for a company customer', () {
      const customer = Customer(
        id: 'c2',
        customerType: CustomerType.company,
        company: CompanyDetails(legalName: 'Acme LLC'),
        contact: CustomerContact(),
        status: CustomerStatus.active,
        createdBy: 'u1',
      );
      expect(customer.displayName, 'Acme LLC');
    });

    test('displayName is empty when the matching detail object is missing', () {
      const customer = Customer(
        id: 'c3',
        customerType: CustomerType.individual,
        contact: CustomerContact(),
        status: CustomerStatus.active,
        createdBy: 'u1',
      );
      expect(customer.displayName, '');
    });
  });

  group('customerTypeFromString / customerStatusFromString', () {
    test('parses known values', () {
      expect(customerTypeFromString('individual'), CustomerType.individual);
      expect(customerTypeFromString('company'), CustomerType.company);
      expect(customerStatusFromString('active'), CustomerStatus.active);
      expect(customerStatusFromString('inactive'), CustomerStatus.inactive);
    });

    test('falls back safely on unknown/malformed values', () {
      expect(customerTypeFromString('bogus'), CustomerType.individual);
      expect(customerStatusFromString('bogus'), CustomerStatus.active);
    });
  });
}
