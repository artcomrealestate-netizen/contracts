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
