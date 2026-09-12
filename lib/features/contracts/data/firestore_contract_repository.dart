import 'package:cloud_firestore/cloud_firestore.dart';

import '../domain/contract.dart';
import '../domain/contract_clause.dart';
import '../domain/contract_repository.dart';
import '../domain/rejection.dart';

class FirestoreContractRepository implements ContractRepository {
  final FirebaseFirestore _firestore;

  FirestoreContractRepository(this._firestore);

  CollectionReference<Map<String, dynamic>> get _contracts =>
      _firestore.collection('contracts');

  CollectionReference<Map<String, dynamic>> get _auditLogs =>
      _firestore.collection('auditLogs');

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

  Rejection? _rejectionFromMap(Map<String, dynamic>? map) {
    if (map == null) return null;
    return Rejection(
      generalNote: map['generalNote'] as String? ?? '',
      rejectedBy: map['rejectedBy'] as String? ?? '',
      rejectedAt: (map['rejectedAt'] as Timestamp?)?.toDate(),
      clauses: (map['clauses'] as List<dynamic>? ?? [])
          .map((c) => (c as Map).cast<String, dynamic>())
          .map((c) => ClauseRejectionNote(
                clauseId: c['clauseId'] as String? ?? '',
                note: c['note'] as String? ?? '',
              ))
          .toList(),
    );
  }

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
      submittedAt: (data['submittedAt'] as Timestamp?)?.toDate(),
      approvedAt: (data['approvedAt'] as Timestamp?)?.toDate(),
      approvedBy: data['approvedBy'] as String?,
      rejection: _rejectionFromMap((data['rejection'] as Map?)?.cast<String, dynamic>()),
    );
  }

  void _addAuditLog(
    Transaction transaction, {
    required String contractId,
    required String action,
    required String actorId,
    required String fromStatus,
    required String toStatus,
  }) {
    transaction.set(_auditLogs.doc(), {
      'entityType': 'contract',
      'entityId': contractId,
      'action': action,
      'actorId': actorId,
      'fromStatus': fromStatus,
      'toStatus': toStatus,
      'metadata': {},
      'timestamp': FieldValue.serverTimestamp(),
    });
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
        'rejection': null,
        'finalPdfUrl': null,
        'fileHash': null,
      });
      _addAuditLog(
        transaction,
        contractId: contractRef.id,
        action: 'CREATED',
        actorId: createdBy,
        fromStatus: 'NONE',
        toStatus: 'DRAFT',
      );

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
  Future<void> updateDraftClauses(String id, List<ContractClause> clauses) async {
    await _contracts.doc(id).update({
      'clauses': clauses.map(_clauseToMap).toList(),
      'updatedAt': FieldValue.serverTimestamp(),
    });
  }

  @override
  Future<void> submitContract(String id, {required String actorId}) async {
    final contractRef = _contracts.doc(id);
    await _firestore.runTransaction((transaction) async {
      transaction.update(contractRef, {
        'status': contractStatusToString(ContractStatus.pendingApproval),
        'submittedAt': FieldValue.serverTimestamp(),
        'updatedAt': FieldValue.serverTimestamp(),
      });
      _addAuditLog(
        transaction,
        contractId: id,
        action: 'SUBMITTED',
        actorId: actorId,
        fromStatus: 'DRAFT',
        toStatus: 'PENDING_APPROVAL',
      );
    });
  }

  @override
  Future<void> approveContract(String id, {required String actorId}) async {
    final contractRef = _contracts.doc(id);
    await _firestore.runTransaction((transaction) async {
      final snapshot = await transaction.get(contractRef);
      final rawClauses = (snapshot.data()?['clauses'] as List<dynamic>? ?? [])
          .map((c) => (c as Map).cast<String, dynamic>())
          .map((c) => {...c, 'reviewStatus': 'APPROVED', 'rejectionNote': null})
          .toList();

      transaction.update(contractRef, {
        'status': contractStatusToString(ContractStatus.approved),
        'approvedAt': FieldValue.serverTimestamp(),
        'approvedBy': actorId,
        'clauses': rawClauses,
        'updatedAt': FieldValue.serverTimestamp(),
      });
      _addAuditLog(
        transaction,
        contractId: id,
        action: 'APPROVED',
        actorId: actorId,
        fromStatus: 'PENDING_APPROVAL',
        toStatus: 'APPROVED',
      );
    });
  }

  @override
  Future<void> rejectContract(
    String id, {
    required String actorId,
    required String generalNote,
    required List<ClauseRejectionNote> clauseNotes,
  }) async {
    final contractRef = _contracts.doc(id);
    final noteByClauseId = {for (final n in clauseNotes) n.clauseId: n.note};

    await _firestore.runTransaction((transaction) async {
      final snapshot = await transaction.get(contractRef);
      final rawClauses = (snapshot.data()?['clauses'] as List<dynamic>? ?? [])
          .map((c) => (c as Map).cast<String, dynamic>())
          .map((c) {
            final note = noteByClauseId[c['id'] as String?];
            return {
              ...c,
              'reviewStatus': note != null ? 'NEEDS_REVISION' : 'APPROVED',
              'rejectionNote': note,
            };
          })
          .toList();

      transaction.update(contractRef, {
        'status': contractStatusToString(ContractStatus.rejected),
        'rejection': {
          'generalNote': generalNote,
          'rejectedBy': actorId,
          'rejectedAt': FieldValue.serverTimestamp(),
          'clauses': clauseNotes.map((n) => {'clauseId': n.clauseId, 'note': n.note}).toList(),
        },
        'clauses': rawClauses,
        'updatedAt': FieldValue.serverTimestamp(),
      });
      _addAuditLog(
        transaction,
        contractId: id,
        action: 'REJECTED',
        actorId: actorId,
        fromStatus: 'PENDING_APPROVAL',
        toStatus: 'REJECTED',
      );
    });
  }

  @override
  Future<void> reviseRejectedContract(String id, {required String actorId}) async {
    final contractRef = _contracts.doc(id);
    await _firestore.runTransaction((transaction) async {
      transaction.update(contractRef, {
        'status': contractStatusToString(ContractStatus.draft),
        'updatedAt': FieldValue.serverTimestamp(),
      });
      // Not one of TDD §31's listed action names (SUBMITTED/REJECTED/...) —
      // added for this specific REJECTED -> DRAFT transition so it's still
      // traceable in the audit log, not folded into a vaguer "UPDATED".
      _addAuditLog(
        transaction,
        contractId: id,
        action: 'REVISED',
        actorId: actorId,
        fromStatus: 'REJECTED',
        toStatus: 'DRAFT',
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
  Stream<Contract?> watchContract(String id) {
    return _contracts.doc(id).snapshots().map((doc) => doc.exists ? _fromDoc(doc) : null);
  }

  @override
  Stream<List<Contract>> watchContracts() {
    return _contracts.orderBy('createdAt', descending: true).snapshots().map(
          (snapshot) => snapshot.docs.map(_fromDoc).toList(),
        );
  }
}
