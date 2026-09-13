enum LeasedPropertyType { room, warehouse, shop }

LeasedPropertyType leasedPropertyTypeFromString(String value) {
  return LeasedPropertyType.values.firstWhere(
    (t) => t.name == value,
    orElse: () => LeasedPropertyType.room,
  );
}

enum PaymentMode { cheques, bankTransfer }

PaymentMode paymentModeFromString(String value) {
  return PaymentMode.values.firstWhere(
    (m) => m.name == value,
    orElse: () => PaymentMode.cheques,
  );
}

/// Lease-specific fields a real tenancy contract needs that have no home
/// anywhere else in the domain model — not on Property (varies per deal, not
/// per physical unit) and not on the linked Quotation (a contract need not
/// have one; `Contract.sourceQuotationId` is optional). Embedded on Contract,
/// not its own collection: always 1:1 with a contract, never queried
/// independently.
class LeaseTerms {
  final LeasedPropertyType leasedPropertyType;
  final String? buildingName;
  final DateTime? commencementDate;
  final DateTime? expiryDate;
  final double? yearlyRentAmount;
  final String? purposeOfUsage;
  final PaymentMode paymentMode;
  final int? numberOfCheques;
  final double? insuranceAllowance;
  final double? managementFeeAmount;
  final double? vatAmount;
  final int? numberOfCoOccupants;

  const LeaseTerms({
    this.leasedPropertyType = LeasedPropertyType.room,
    this.buildingName,
    this.commencementDate,
    this.expiryDate,
    this.yearlyRentAmount,
    this.purposeOfUsage,
    this.paymentMode = PaymentMode.cheques,
    this.numberOfCheques,
    this.insuranceAllowance,
    this.managementFeeAmount,
    this.vatAmount,
    this.numberOfCoOccupants,
  });

  factory LeaseTerms.empty() => const LeaseTerms();
}
