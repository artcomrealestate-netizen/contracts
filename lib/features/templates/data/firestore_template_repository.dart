import 'package:cloud_firestore/cloud_firestore.dart';

import '../domain/contract_template.dart';
import '../domain/contract_template_version.dart';
import '../domain/template_clause.dart';
import '../domain/template_repository.dart';

class FirestoreTemplateRepository implements TemplateRepository {
  final FirebaseFirestore _firestore;

  FirestoreTemplateRepository(this._firestore);

  CollectionReference<Map<String, dynamic>> get _templates =>
      _firestore.collection('contractTemplates');

  CollectionReference<Map<String, dynamic>> get _versions =>
      _firestore.collection('contractTemplateVersions');

  Map<String, dynamic> _clauseToMap(TemplateClause clause) => {
        'id': clause.id,
        'order': clause.order,
        'title': clause.title,
        'content': clause.content,
        'isLocked': clause.isLocked,
      };

  TemplateClause _clauseFromMap(Map<String, dynamic> map) => TemplateClause(
        id: map['id'] as String? ?? '',
        order: (map['order'] as num?)?.toInt() ?? 0,
        title: map['title'] as String? ?? '',
        content: map['content'] as String? ?? '',
        isLocked: map['isLocked'] as bool? ?? false,
      );

  ContractTemplate _templateFromDoc(DocumentSnapshot<Map<String, dynamic>> doc) {
    final data = doc.data()!;
    return ContractTemplate(
      id: doc.id,
      name: data['name'] as String? ?? '',
      code: data['code'] as String? ?? '',
      status: templateStatusFromString(data['status'] as String? ?? 'active'),
      currentVersion: (data['currentVersion'] as num?)?.toInt() ?? 0,
      createdBy: data['createdBy'] as String? ?? '',
      createdAt: (data['createdAt'] as Timestamp?)?.toDate(),
      updatedAt: (data['updatedAt'] as Timestamp?)?.toDate(),
    );
  }

  ContractTemplateVersion _versionFromDoc(DocumentSnapshot<Map<String, dynamic>> doc) {
    final data = doc.data()!;
    final clauses = (data['clauses'] as List<dynamic>? ?? [])
        .map((c) => _clauseFromMap((c as Map).cast<String, dynamic>()))
        .toList()
      ..sort((a, b) => a.order.compareTo(b.order));
    return ContractTemplateVersion(
      id: doc.id,
      templateId: data['templateId'] as String? ?? '',
      version: (data['version'] as num?)?.toInt() ?? 0,
      clauses: clauses,
      createdBy: data['createdBy'] as String? ?? '',
      createdAt: (data['createdAt'] as Timestamp?)?.toDate(),
    );
  }

  @override
  Future<ContractTemplate> createTemplate({
    required String name,
    required String code,
    required List<TemplateClause> clauses,
    required String createdBy,
  }) async {
    final templateRef = _templates.doc();
    final versionRef = _versions.doc();
    final batch = _firestore.batch();
    batch.set(templateRef, {
      'name': name,
      'code': code,
      'status': TemplateStatus.active.name,
      'currentVersion': 1,
      'createdBy': createdBy,
      'createdAt': FieldValue.serverTimestamp(),
      'updatedAt': FieldValue.serverTimestamp(),
    });
    batch.set(versionRef, {
      'templateId': templateRef.id,
      'version': 1,
      'clauses': clauses.map(_clauseToMap).toList(),
      'createdBy': createdBy,
      'createdAt': FieldValue.serverTimestamp(),
    });
    await batch.commit();
    final saved = await templateRef.get();
    return _templateFromDoc(saved);
  }

  @override
  Future<ContractTemplateVersion> publishNewVersion({
    required ContractTemplate template,
    required List<TemplateClause> clauses,
    required String createdBy,
  }) async {
    final newVersionNumber = template.currentVersion + 1;
    final versionRef = _versions.doc();
    final templateRef = _templates.doc(template.id);
    final batch = _firestore.batch();
    batch.set(versionRef, {
      'templateId': template.id,
      'version': newVersionNumber,
      'clauses': clauses.map(_clauseToMap).toList(),
      'createdBy': createdBy,
      'createdAt': FieldValue.serverTimestamp(),
    });
    batch.update(templateRef, {
      'currentVersion': newVersionNumber,
      'updatedAt': FieldValue.serverTimestamp(),
    });
    await batch.commit();
    final saved = await versionRef.get();
    return _versionFromDoc(saved);
  }

  @override
  Future<ContractTemplate?> getTemplate(String id) async {
    final doc = await _templates.doc(id).get();
    if (!doc.exists) return null;
    return _templateFromDoc(doc);
  }

  @override
  Stream<List<ContractTemplate>> watchTemplates() {
    return _templates.orderBy('createdAt', descending: true).snapshots().map(
          (snapshot) => snapshot.docs.map(_templateFromDoc).toList(),
        );
  }

  @override
  Stream<List<ContractTemplateVersion>> watchVersions(String templateId) {
    return _versions
        .where('templateId', isEqualTo: templateId)
        .orderBy('version', descending: true)
        .snapshots()
        .map((snapshot) => snapshot.docs.map(_versionFromDoc).toList());
  }
}
