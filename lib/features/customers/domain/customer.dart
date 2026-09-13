enum CustomerType { individual, company }

enum CustomerStatus { active, inactive }

CustomerType customerTypeFromString(String value) {
  return CustomerType.values.firstWhere(
    (t) => t.name == value,
    orElse: () => CustomerType.individual,
  );
}

CustomerStatus customerStatusFromString(String value) {
  return CustomerStatus.values.firstWhere(
    (s) => s.name == value,
    orElse: () => CustomerStatus.active,
  );
}

class IndividualDetails {
  final String fullName;
  final String? emiratesId;
  final String? passportNumber;
  // A company customer already has `legalName` for this; an individual
  // tenant can still operate under a trade name (e.g. leasing as themself
  // but running a business from the unit) with nowhere else to record it.
  final String? tradeName;

  const IndividualDetails({
    required this.fullName,
    this.emiratesId,
    this.passportNumber,
    this.tradeName,
  });
}

class CompanyDetails {
  final String legalName;
  final String? tradeLicenseNumber;
  final String? licensingAuthority;

  const CompanyDetails({
    required this.legalName,
    this.tradeLicenseNumber,
    this.licensingAuthority,
  });
}

class CustomerContact {
  final String? phone;
  final String? email;

  const CustomerContact({this.phone, this.email});
}

/// Mirrors the `customers/{customerId}` document (TDD §13). Exactly one of
/// [individual] / [company] is set, matching [customerType].
class Customer {
  final String id;
  final CustomerType customerType;
  final IndividualDetails? individual;
  final CompanyDetails? company;
  final CustomerContact contact;
  final String? address;
  final CustomerStatus status;
  final String createdBy;
  final DateTime? createdAt;
  final DateTime? updatedAt;

  const Customer({
    required this.id,
    required this.customerType,
    required this.contact,
    required this.status,
    required this.createdBy,
    this.individual,
    this.company,
    this.address,
    this.createdAt,
    this.updatedAt,
  });

  String get displayName => switch (customerType) {
        CustomerType.individual => individual?.fullName ?? '',
        CustomerType.company => company?.legalName ?? '',
      };

  Customer copyWith({CustomerStatus? status}) => Customer(
        id: id,
        customerType: customerType,
        individual: individual,
        company: company,
        contact: contact,
        address: address,
        status: status ?? this.status,
        createdBy: createdBy,
        createdAt: createdAt,
        updatedAt: updatedAt,
      );
}
