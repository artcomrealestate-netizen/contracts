import 'package:flutter_test/flutter_test.dart';
import 'package:qouta_calculator/features/properties/domain/property.dart';

void main() {
  group('propertyStatusFromString', () {
    test('parses known values', () {
      expect(propertyStatusFromString('active'), PropertyStatus.active);
      expect(propertyStatusFromString('inactive'), PropertyStatus.inactive);
    });

    test('falls back safely on unknown/malformed values', () {
      expect(propertyStatusFromString('bogus'), PropertyStatus.active);
    });
  });

  group('Property', () {
    test('stores location and area fields as given', () {
      const property = Property(
        id: 'p1',
        propertyCode: 'P-001',
        name: 'Marina Tower',
        propertyType: 'Apartment',
        area: 1200,
        location: PropertyLocation(emirate: 'Dubai', city: 'Dubai', district: 'Marina'),
        status: PropertyStatus.active,
        createdBy: 'u1',
      );
      expect(property.location.emirate, 'Dubai');
      expect(property.location.city, 'Dubai');
      expect(property.area, 1200);
    });
  });
}
