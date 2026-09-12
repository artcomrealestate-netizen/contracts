enum PropertyStatus { active, inactive }

PropertyStatus propertyStatusFromString(String value) {
  return PropertyStatus.values.firstWhere(
    (s) => s.name == value,
    orElse: () => PropertyStatus.active,
  );
}

class PropertyLocation {
  final String? emirate;
  final String? city;
  final String? district;

  const PropertyLocation({this.emirate, this.city, this.district});
}

/// Mirrors the `properties/{propertyId}` document (TDD §14).
class Property {
  final String id;
  final String propertyCode;
  final String name;
  final String propertyType;
  final String? unitNumber;
  final double area;
  final PropertyLocation location;
  final PropertyStatus status;
  final String createdBy;
  final DateTime? createdAt;
  final DateTime? updatedAt;

  const Property({
    required this.id,
    required this.propertyCode,
    required this.name,
    required this.propertyType,
    required this.area,
    required this.location,
    required this.status,
    required this.createdBy,
    this.unitNumber,
    this.createdAt,
    this.updatedAt,
  });

  Property copyWith({PropertyStatus? status}) => Property(
        id: id,
        propertyCode: propertyCode,
        name: name,
        propertyType: propertyType,
        unitNumber: unitNumber,
        area: area,
        location: location,
        status: status ?? this.status,
        createdBy: createdBy,
        createdAt: createdAt,
        updatedAt: updatedAt,
      );
}
