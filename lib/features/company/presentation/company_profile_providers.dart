import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/providers/firebase_providers.dart';
import '../data/firestore_company_profile_repository.dart';
import '../domain/company_profile.dart';
import '../domain/company_profile_repository.dart';

final companyProfileRepositoryProvider = Provider<CompanyProfileRepository>((ref) {
  return FirestoreCompanyProfileRepository(ref.watch(firestoreProvider));
});

final companyProfileProvider = StreamProvider<CompanyProfile?>((ref) {
  return ref.watch(companyProfileRepositoryProvider).watchProfile();
});
