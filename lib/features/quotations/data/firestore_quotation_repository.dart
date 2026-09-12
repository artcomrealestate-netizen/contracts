import 'package:cloud_firestore/cloud_firestore.dart';

import '../../../models/saved_quotation.dart';
import '../domain/quotation_repository.dart';

class FirestoreQuotationRepository implements QuotationRepository {
  final FirebaseFirestore _firestore;

  FirestoreQuotationRepository(this._firestore);

  CollectionReference<Map<String, dynamic>> get _quotations =>
      _firestore.collection('quotations');

  // Reuses SavedQuotation's own toJson/fromJson (already covers every field
  // and every legacy-default fallback) rather than re-listing all of them
  // here — only createdAt/id need translating between Firestore's native
  // types and the ISO-string/plain-map shape those methods expect.
  SavedQuotation _fromDoc(DocumentSnapshot<Map<String, dynamic>> doc) {
    final data = Map<String, dynamic>.from(doc.data()!);
    final createdAt = data['createdAt'];
    data['createdAt'] =
        createdAt is Timestamp ? createdAt.toDate().toIso8601String() : createdAt;
    data['id'] = doc.id;
    return SavedQuotation.fromJson(data);
  }

  @override
  Future<String> reserveNextQuotaNumber() {
    final year = DateTime.now().year;
    final counterRef = _firestore.collection('counters').doc('quotations_$year');
    return _firestore.runTransaction<String>((transaction) async {
      final snapshot = await transaction.get(counterRef);
      final next = ((snapshot.data()?['count'] as num?)?.toInt() ?? 0) + 1;
      transaction.set(counterRef, {'count': next}, SetOptions(merge: true));
      return 'QT-$year-${next.toString().padLeft(3, '0')}';
    });
  }

  @override
  Future<void> add(SavedQuotation quotation, {required String createdBy}) async {
    final data = quotation.toJson();
    data['createdBy'] = createdBy;
    data['createdAt'] = Timestamp.fromDate(quotation.createdAt);
    await _quotations.doc(quotation.id).set(data);
  }

  @override
  Future<bool> quotaNumberExists(String quotaNumber) async {
    final snapshot = await _quotations.where('quotaNumber', isEqualTo: quotaNumber).limit(1).get();
    return snapshot.docs.isNotEmpty;
  }

  @override
  Future<void> delete(String id) => _quotations.doc(id).delete();

  @override
  Stream<List<SavedQuotation>> watchQuotations() {
    return _quotations.orderBy('createdAt', descending: true).snapshots().map(
          (snapshot) => snapshot.docs.map(_fromDoc).toList(),
        );
  }
}
