import 'dart:io';

import 'package:flutter/services.dart' show rootBundle;
import 'package:flutter/widgets.dart' show Locale;
import 'package:flutter_test/flutter_test.dart';
import 'package:qouta_calculator/features/company/domain/company_profile.dart';
import 'package:qouta_calculator/features/contracts/domain/contract.dart';
import 'package:qouta_calculator/features/contracts/domain/contract_clause.dart';
import 'package:qouta_calculator/features/contracts/domain/lease_terms.dart';
import 'package:qouta_calculator/features/customers/domain/customer.dart';
import 'package:qouta_calculator/features/properties/domain/property.dart';
import 'package:qouta_calculator/main.dart';
import 'package:qouta_calculator/pdf/contract_pdf_builder.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  test('buildContractPdfBytes renders a bilingual contract without throwing', () async {
    final settings = AppSettings(
      locale: const Locale('en'),
      companyName: 'AL-DAHHAN DEVELOPER',
      companyPhone: '0555439000',
      companyEmail: 'louai@aldahandeveloper.com',
      companyWebsite: 'www.aldahandeveloper.com',
    );

    const customer = Customer(
      id: 'cust1',
      customerType: CustomerType.individual,
      individual: IndividualDetails(
        fullName: 'Mohammed Zaid Saeed Alrahabi',
        emiratesId: '784-1987-6581686-7',
        tradeName: 'A Eye Aluminum Factory',
      ),
      contact: CustomerContact(phone: '+971-50-9998140', email: 'mohammed@aeye-aluminum.com'),
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
      location: PropertyLocation(emirate: 'Umm Al Quwain', city: 'Umm Al Thueub', district: 'Umm Al Thueub'),
      status: PropertyStatus.active,
      createdBy: 'u1',
    );
    final contract = Contract(
      id: 'c1',
      contractNumber: 'CTR-2026-000001',
      status: ContractStatus.draft,
      version: 1,
      customerId: 'cust1',
      propertyId: 'prop1',
      templateId: 't1',
      templateVersion: 1,
      leaseTerms: LeaseTerms(
        leasedPropertyType: LeasedPropertyType.room,
        buildingName: 'الدهان/1',
        commencementDate: DateTime(2025, 9, 19),
        expiryDate: DateTime(2026, 9, 18),
        yearlyRentAmount: 25740,
        purposeOfUsage: 'Staff Rooms for 12 H AC',
        paymentMode: PaymentMode.cheques,
        numberOfCheques: 2,
        insuranceAllowance: 1000,
        managementFeeAmount: 2574,
        vatAmount: 128.7,
        numberOfCoOccupants: 4,
      ),
      clauses: const [
        ContractClause(
          id: 'cl1',
          order: 1,
          titleEn: 'Inspection',
          titleAr: 'المعاينة',
          contentEn: 'The tenant {{tenantName}} has inspected unit {{propertyUnitNumber}} and agreed to lease it as-is.',
          contentAr: 'عاين المستأجر {{tenantName}} الوحدة {{propertyUnitNumber}} ووافق على استئجارها على حالتها.',
          isLocked: true,
        ),
        ContractClause(
          id: 'cl2',
          order: 2,
          titleEn: 'Bounced Cheque',
          titleAr: 'ارتجاع شيك',
          contentEn: 'A bounced cheque incurs a fine of 1000 AED payable by {{tenantName}}.',
          contentAr: 'في حال ارتجاع أي شيك يترتب غرامة مالية بقيمة 1000 درهم اماراتي على {{tenantName}}.',
        ),
      ],
      createdBy: 'u1',
    );
    const companyProfile = CompanyProfile(ownerName: 'Louai Adnan Dahhan', ownerEmiratesId: '784-1969-6357109-4');

    final bytes = await buildContractPdfBytes(
      settings: settings,
      companyProfile: companyProfile,
      bundle: rootBundle,
      contract: contract,
      customer: customer,
      property: property,
    );

    expect(bytes.length, greaterThan(1000));
    expect(bytes[0], '%'.codeUnitAt(0)); // PDF magic bytes: %PDF-

    // Written for manual visual inspection during development — not
    // asserted against, just saved alongside the test run.
    final outFile = File('build/contract_pdf_smoke_test_output.pdf');
    await outFile.create(recursive: true);
    await outFile.writeAsBytes(bytes);
  });
}
