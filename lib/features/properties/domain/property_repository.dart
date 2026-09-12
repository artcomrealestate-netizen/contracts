import 'property.dart';

abstract class PropertyRepository {
  Future<Property> createProperty(Property property);

  /// Overwrites every editable field of an existing property (id, createdBy,
  /// createdAt stay whatever they already were, regardless of what's on
  /// [property]).
  Future<void> updateProperty(Property property);

  Future<Property?> getProperty(String id);

  /// Newest-first. No pagination yet (TDD §36 pagination lands with
  /// Dashboard/Search, phase 10) — fine for the small lists this phase deals with.
  Stream<List<Property>> watchProperties();
}
