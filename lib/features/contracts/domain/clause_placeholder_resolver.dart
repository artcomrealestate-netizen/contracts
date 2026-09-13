import '../../company/domain/company_profile.dart';
import '../../customers/domain/customer.dart';
import '../../properties/domain/property.dart';
import 'contract.dart';
import 'lease_terms.dart';

/// Everything a clause's `{{token}}` placeholders can resolve against.
/// Deliberately render-time-only: stored clause text always keeps its raw
/// tokens (see TemplateClause/ContractClause's doc comments) — nothing here
/// is ever written back to Firestore. Known limitation: if the underlying
/// customer/property/company data changes after a contract is approved or
/// finalized, a later re-export reflects the new data, not what was true at
/// approval time (no snapshot step — out of scope for this pass).
class ContractMergeContext {
  final Customer customer;
  final Property property;
  final Contract contract;
  final LeaseTerms leaseTerms;
  final CompanyProfile companyProfile;
  final String companyName;
  final String companyPhone;
  final String companyEmail;

  const ContractMergeContext({
    required this.customer,
    required this.property,
    required this.contract,
    required this.leaseTerms,
    required this.companyProfile,
    required this.companyName,
    required this.companyPhone,
    required this.companyEmail,
  });
}

final RegExp _tokenPattern = RegExp(r'\{\{(\w+)\}\}');

/// Replaces every `{{token}}` in [text] with its resolved value. A token not
/// in the catalog (typo, or a name that hasn't been wired up) is left
/// exactly as written rather than blanked out, so a mistake is visible and
/// doesn't silently erase text from a legal document.
String resolvePlaceholders(String text, ContractMergeContext ctx) {
  final values = _tokenValues(ctx);
  return text.replaceAllMapped(_tokenPattern, (match) {
    return values[match.group(1)] ?? match.group(0)!;
  });
}

String _formatDate(DateTime? date) {
  if (date == null) return '';
  return '${date.day.toString().padLeft(2, '0')}/${date.month.toString().padLeft(2, '0')}/${date.year}';
}

String _formatAmount(double? amount) {
  if (amount == null) return '';
  return amount.toStringAsFixed(amount.truncateToDouble() == amount ? 0 : 2);
}

String _leasedPropertyTypeLabel(LeasedPropertyType type) => switch (type) {
      LeasedPropertyType.room => 'Room',
      LeasedPropertyType.warehouse => 'Warehouse',
      LeasedPropertyType.shop => 'Shop',
    };

String _paymentModeLabel(LeaseTerms terms) => switch (terms.paymentMode) {
      PaymentMode.cheques => terms.numberOfCheques != null ? '${terms.numberOfCheques} Cheques' : 'Cheques',
      PaymentMode.bankTransfer => 'Bank Transfer',
    };

/// Token catalog. Keys here MUST match `mergeFieldTokenGroups` in
/// lib/features/templates/presentation/clause_list_field.dart exactly — that
/// file's "insert token" menu is what authors actually use to write these.
Map<String, String> _tokenValues(ContractMergeContext ctx) {
  final customer = ctx.customer;
  final property = ctx.property;
  final terms = ctx.leaseTerms;
  return {
    'tenantName': customer.displayName,
    'tenantTradeName': customer.individual?.tradeName ?? '',
    'tenantPhone': customer.contact.phone ?? '',
    'tenantEmail': customer.contact.email ?? '',
    'tenantEmiratesId': customer.individual?.emiratesId ?? '',
    'tenantPassportNumber': customer.individual?.passportNumber ?? '',
    'tenantTradeLicenseNumber': customer.company?.tradeLicenseNumber ?? '',
    'tenantLicensingAuthority': customer.company?.licensingAuthority ?? '',
    'propertyName': property.name,
    'propertyCode': property.propertyCode,
    'propertyType': property.propertyType,
    'propertyUnitNumber': property.unitNumber ?? '',
    'propertyArea': property.area.toStringAsFixed(0),
    'propertyEmirate': property.location.emirate ?? '',
    'propertyCity': property.location.city ?? '',
    'contractNumber': ctx.contract.contractNumber,
    'companyName': ctx.companyName,
    'companyPhone': ctx.companyPhone,
    'companyEmail': ctx.companyEmail,
    'ownerName': ctx.companyProfile.ownerName ?? '',
    'ownerEmiratesId': ctx.companyProfile.ownerEmiratesId ?? '',
    'leasedPropertyType': _leasedPropertyTypeLabel(terms.leasedPropertyType),
    'buildingName': terms.buildingName ?? '',
    'commencementDate': _formatDate(terms.commencementDate),
    'expiryDate': _formatDate(terms.expiryDate),
    'yearlyRentAmount': _formatAmount(terms.yearlyRentAmount),
    'purposeOfUsage': terms.purposeOfUsage ?? '',
    'modeOfPayment': _paymentModeLabel(terms),
    'insuranceAllowance': _formatAmount(terms.insuranceAllowance),
    'managementFeeAmount': _formatAmount(terms.managementFeeAmount),
    'vatAmount': _formatAmount(terms.vatAmount),
    'numberOfCoOccupants': terms.numberOfCoOccupants?.toString() ?? '',
    'today': _formatDate(DateTime.now()),
  };
}
