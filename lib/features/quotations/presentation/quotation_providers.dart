import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/providers/firebase_providers.dart';
import '../../../models/saved_quotation.dart';
import '../data/firestore_quotation_repository.dart';
import '../domain/quotation_repository.dart';

final quotationRepositoryProvider = Provider<QuotationRepository>((ref) {
  return FirestoreQuotationRepository(ref.watch(firestoreProvider));
});

final quotationsStreamProvider = StreamProvider<List<SavedQuotation>>((ref) {
  return ref.watch(quotationRepositoryProvider).watchQuotations();
});

/// Single-quotation lookup, e.g. to show a quotation's summary on a
/// contract that only stores its sourceQuotationId.
final quotationByIdProvider = FutureProvider.family<SavedQuotation?, String>((ref, id) {
  return ref.watch(quotationRepositoryProvider).getQuotation(id);
});
