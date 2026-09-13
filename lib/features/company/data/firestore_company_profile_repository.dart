import 'dart:convert';
import 'dart:typed_data';

import 'package:cloud_firestore/cloud_firestore.dart';

import '../domain/company_profile.dart';
import '../domain/company_profile_repository.dart';

class FirestoreCompanyProfileRepository implements CompanyProfileRepository {
  final FirebaseFirestore _firestore;

  FirestoreCompanyProfileRepository(this._firestore);

  DocumentReference<Map<String, dynamic>> get _doc =>
      _firestore.collection('companyProfile').doc('main');

  CompanyProfile _fromDoc(DocumentSnapshot<Map<String, dynamic>> doc) {
    final data = doc.data();
    if (data == null) return CompanyProfile.empty();
    final logoBase64 = data['logoBase64'] as String?;
    return CompanyProfile(
      ownerName: data['ownerName'] as String?,
      ownerEmiratesId: data['ownerEmiratesId'] as String?,
      logoBytes: logoBase64 == null ? null : base64Decode(logoBase64),
      updatedAt: (data['updatedAt'] as Timestamp?)?.toDate(),
      updatedBy: data['updatedBy'] as String?,
    );
  }

  @override
  Future<CompanyProfile?> getProfile() async {
    final doc = await _doc.get();
    if (!doc.exists) return CompanyProfile.empty();
    return _fromDoc(doc);
  }

  @override
  Stream<CompanyProfile?> watchProfile() {
    return _doc.snapshots().map((doc) => doc.exists ? _fromDoc(doc) : CompanyProfile.empty());
  }

  @override
  Future<void> updateProfile({
    String? ownerName,
    String? ownerEmiratesId,
    Uint8List? logoBytes,
    required String updatedBy,
  }) async {
    await _doc.set({
      if (ownerName != null) 'ownerName': ownerName,
      if (ownerEmiratesId != null) 'ownerEmiratesId': ownerEmiratesId,
      if (logoBytes != null) 'logoBase64': base64Encode(logoBytes),
      'updatedBy': updatedBy,
      'updatedAt': FieldValue.serverTimestamp(),
    }, SetOptions(merge: true));
  }
}
