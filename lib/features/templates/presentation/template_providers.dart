import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/providers/firebase_providers.dart';
import '../data/firestore_template_repository.dart';
import '../domain/contract_template.dart';
import '../domain/contract_template_version.dart';
import '../domain/template_repository.dart';

final templateRepositoryProvider = Provider<TemplateRepository>((ref) {
  return FirestoreTemplateRepository(ref.watch(firestoreProvider));
});

final templatesStreamProvider = StreamProvider<List<ContractTemplate>>((ref) {
  return ref.watch(templateRepositoryProvider).watchTemplates();
});

final templateVersionsStreamProvider =
    StreamProvider.family<List<ContractTemplateVersion>, String>((ref, templateId) {
  return ref.watch(templateRepositoryProvider).watchVersions(templateId);
});
