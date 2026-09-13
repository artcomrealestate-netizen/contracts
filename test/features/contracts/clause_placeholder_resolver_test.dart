import 'package:flutter_test/flutter_test.dart';
import 'package:qouta_calculator/features/company/domain/company_profile.dart';
import 'package:qouta_calculator/features/contracts/domain/clause_placeholder_resolver.dart';
import 'package:qouta_calculator/features/contracts/domain/contract.dart';
import 'package:qouta_calculator/features/contracts/domain/lease_terms.dart';
import 'package:qouta_calculator/features/customers/domain/customer.dart';
import 'package:qouta_calculator/features/properties/domain/property.dart';

ContractMergeContext _context({LeaseTerms? leaseTerms}) {
  const customer = Customer(
    id: 'cust1',
    customerType: CustomerType.individual,
    individual: IndividualDetails(fullName: 'Mohammed Zaid', emiratesId: '784-1987-6581686-7'),
    contact: CustomerContact(phone: '+971-50-9998140', email: 'mohammed@example.com'),
    status: CustomerStatus.active,
    createdBy: 'u1',
  );
  const property = Property(
    id: 'prop1',
    propertyCode: 'P-1',
    name: 'Al Dahhan Building 1',
    propertyType: 'Room',
    unitNumber: '327',
    area: 200,
    location: PropertyLocation(emirate: 'Umm Al Quwain', city: 'Umm Al Thueub'),
    status: PropertyStatus.active,
    createdBy: 'u1',
  );
  const contract = Contract(
    id: 'c1',
    contractNumber: 'CTR-2026-000001',
    status: ContractStatus.draft,
    version: 1,
    customerId: 'cust1',
    propertyId: 'prop1',
    templateId: 't1',
    templateVersion: 1,
    clauses: [],
    createdBy: 'u1',
  );
  const companyProfile = CompanyProfile(ownerName: 'Louai Adnan Dahhan', ownerEmiratesId: '784-1969-6357109-4');

  return ContractMergeContext(
    customer: customer,
    property: property,
    contract: contract,
    leaseTerms: leaseTerms ?? LeaseTerms.empty(),
    companyProfile: companyProfile,
    companyName: 'AL-DAHHAN DEVELOPER',
    companyPhone: '0555439000',
    companyEmail: 'louai@aldahandeveloper.com',
  );
}

void main() {
  group('resolvePlaceholders', () {
    test('substitutes known tokens from customer/property/company data', () {
      final result = resolvePlaceholders(
        'Tenant {{tenantName}} ({{tenantEmiratesId}}) leases unit {{propertyUnitNumber}} from {{ownerName}}.',
        _context(),
      );
      expect(
        result,
        'Tenant Mohammed Zaid (784-1987-6581686-7) leases unit 327 from Louai Adnan Dahhan.',
      );
    });

    test('resolves lease-terms tokens', () {
      final result = resolvePlaceholders(
        'Rent is {{yearlyRentAmount}} for a {{leasedPropertyType}}, paid via {{modeOfPayment}}.',
        _context(
          leaseTerms: const LeaseTerms(
            leasedPropertyType: LeasedPropertyType.room,
            yearlyRentAmount: 25740,
            paymentMode: PaymentMode.cheques,
            numberOfCheques: 2,
          ),
        ),
      );
      expect(result, 'Rent is 25740 for a Room, paid via 2 Cheques.');
    });

    test('leaves an unknown/typo token exactly as written rather than blanking it', () {
      final result = resolvePlaceholders('Value: {{notARealToken}}', _context());
      expect(result, 'Value: {{notARealToken}}');
    });

    test('a missing/null field resolves to an empty string, not "null"', () {
      final result = resolvePlaceholders('Trade name: [{{tenantTradeName}}]', _context());
      expect(result, 'Trade name: []');
    });

    test('text with no tokens passes through unchanged', () {
      const plainText = 'This clause has no placeholders at all.';
      expect(resolvePlaceholders(plainText, _context()), plainText);
    });
  });
}
