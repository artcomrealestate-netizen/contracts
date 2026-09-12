import 'package:cloud_firestore/cloud_firestore.dart';

import '../domain/contract.dart';
import '../domain/contract_clause.dart';
import '../domain/contract_repository.dart';

class FirestoreContractRepository implements ContractRepository {
  final FirebaseFirestore _firestore;

  FirestoreContractRepository(this._firestore);

  CollectionReference<Map<String, dynamic>> get _contracts =>
      _firestore.collection('contracts');

  Map<String, dynamic> _clauseToMap(ContractClause clause) => {
        'id': clause.id,
        'order': clause.order,
        'title': clause.title,
        'content': clause.content,
        'isLocked': clause.isLocked,
        'reviewStatus': clauseReviewStatusToString(clause.reviewStatus),
        'rejectionNote': clause.rejectionNote,
      };

  ContractClause _clauseFromMap(Map<String, dynamic> map) => ContractClause(
        id: map['id'] as String? ?? '',
        order: (map['order'] as num?)?.toInt() ?? 0,
        title: map['title'] as String? ?? '',
        content: map['content'] as String? ?? '',
        isLocked: map['isLocked'] as bool? ?? false,
        reviewStatus: clauseReviewStatusFromString(map['reviewStatus'] as String? ?? 'PENDING'),
        rejectionNote: map['rejectionNote'] as String?,
      );

  Contract _fromDoc(DocumentSnapshot<Map<String, dynamic>> doc) {
    final data = doc.data()!;
    final clauses = (data['clauses'] as List<dynamic>? ?? [])
        .map((c) => _clauseFromMap((c as Map).cast<String, dynamic>()))
        .toList()
      ..sort((a, b) => a.order.compareTo(b.order));
    return Contract(
      id: doc.id,
      contractNumber: data['contractNumber'] as String? ?? '',
      status: contractStatusFromString(data['status'] as String? ?? 'DRAFT'),
      version: (data['version'] as num?)?.toInt() ?? 1,
      customerId: data['customerId'] as String? ?? '',
      propertyId: data['propertyId'] as String? ?? '',
      sourceQuotationId: data['sourceQuotationId'] as String?,
      templateId: data['templateId'] as String? ?? '',
      templateVersion: (data['templateVersion'] as num?)?.toInt() ?? 1,
      clauses: clauses,
      createdBy: data['createdBy'] as String? ?? '',
      createdAt: (data['createdAt'] as Timestamp?)?.toDate(),
      updatedAt: (data['updatedAt'] as Timestamp?)?.toDate(),
    );
  }

  @override
  Future<Contract> createDraftContract({
    required String customerId,
    required String propertyId,
    required String templateId,
    required int templateVersion,
    required List<ContractClause> clauses,
    required String createdBy,
    String? sourceQuotationId,
  }) {
    final year = DateTime.now().year;
    final counterRef = _firestore.collection('counters').doc('contracts_$year');
    final contractRef = _contracts.doc();

    return _firestore.runTransaction<Contract>((transaction) async {
      // All reads before writes — Firestore transactions require it.
      final counterSnapshot = await transaction.get(counterRef);
      final nextCount = ((counterSnapshot.data()?['count'] as num?)?.toInt() ?? 0) + 1;
      final contractNumber = 'CTR-$year-${nextCount.toString().padLeft(6, '0')}';

      transaction.set(counterRef, {'count': nextCount}, SetOptions(merge: true));
      transaction.set(contractRef, {
        'contractNumber': contractNumber,
        'status': contractStatusToString(ContractStatus.draft),
        'version': 1,
        'customerId': customerId,
        'propertyId': propertyId,
        'sourceQuotationId': sourceQuotationId,
        'invoiceId': null,
        'templateId': templateId,
        'templateVersion': templateVersion,
        'customerSnapshot': null,
        'propertySnapshot': null,
        'financialSnapshot': null,
        'clauses': clauses.map(_clauseToMap).toList(),
        'createdBy': createdBy,
        'createdAt': FieldValue.serverTimestamp(),
        'updatedAt': FieldValue.serverTimestamp(),
        'submittedAt': null,
        'approvedAt': null,
        'finalizedAt': null,
        'approvedBy': null,
        'finalizedBy': null,
        'finalPdfUrl': null,
        'fileHash': null,
      });

      // Firestore transactions don't support reading back a document just
      // written within the same transaction, so the returned Contract is
      // built from what was just sent rather than a get().
      return Contract(
        id: contractRef.id,
        contractNumber: contractNumber,
        status: ContractStatus.draft,
        version: 1,
        customerId: customerId,
        propertyId: propertyId,
        sourceQuotationId: sourceQuotationId,
        templateId: templateId,
        templateVersion: templateVersion,
        clauses: clauses,
        createdBy: createdBy,
      );
    });
  }

  @override
  Future<Contract?> getContract(String id) async {
    final doc = await _contracts.doc(id).get();
    if (!doc.exists) return null;
    return _fromDoc(doc);
  }

  @override
  Stream<List<Contract>> watchContracts() {
    return _contracts.orderBy('createdAt', descending: true).snapshots().map(
          (snapshot) => snapshot.docs.map(_fromDoc).toList(),
        );
  }
}
