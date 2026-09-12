import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/providers/firebase_providers.dart';
import '../data/firestore_property_repository.dart';
import '../domain/property.dart';
import '../domain/property_repository.dart';

final propertyRepositoryProvider = Provider<PropertyRepository>((ref) {
  return FirestorePropertyRepository(ref.watch(firestoreProvider));
});

final propertiesStreamProvider = StreamProvider<List<Property>>((ref) {
  return ref.watch(propertyRepositoryProvider).watchProperties();
});

/// Single-property lookup, e.g. to show a property's name on a contract
/// that only stores its `propertyId`.
final propertyByIdProvider = FutureProvider.family<Property?, String>((ref, id) {
  return ref.watch(propertyRepositoryProvider).getProperty(id);
});
