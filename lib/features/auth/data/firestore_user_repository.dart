import 'package:cloud_firestore/cloud_firestore.dart';

import '../domain/app_user.dart';
import '../domain/user_repository.dart';

class FirestoreUserRepository implements UserRepository {
  final FirebaseFirestore _firestore;

  FirestoreUserRepository(this._firestore);

  CollectionReference<Map<String, dynamic>> get _users =>
      _firestore.collection('users');

  AppUser _fromDoc(DocumentSnapshot<Map<String, dynamic>> doc) {
    final data = doc.data()!;
    return AppUser(
      id: doc.id,
      email: data['email'] as String? ?? '',
      displayName: data['displayName'] as String? ?? '',
      role: userRoleFromString(data['role'] as String? ?? 'employee'),
      status: accountStatusFromString(data['status'] as String? ?? 'disabled'),
      permissions: Map<String, bool>.from(
        (data['permissions'] as Map?)?.cast<String, dynamic>() ?? {},
      ),
      createdAt: (data['createdAt'] as Timestamp?)?.toDate(),
      updatedAt: (data['updatedAt'] as Timestamp?)?.toDate(),
      lastLoginAt: (data['lastLoginAt'] as Timestamp?)?.toDate(),
    );
  }

  @override
  Future<AppUser?> getUser(String uid) async {
    final doc = await _users.doc(uid).get();
    if (!doc.exists) return null;
    return _fromDoc(doc);
  }

  @override
  Stream<AppUser?> watchUser(String uid) {
    return _users.doc(uid).snapshots().map((doc) {
      if (!doc.exists) return null;
      return _fromDoc(doc);
    });
  }

  @override
  Future<void> createPendingUser({
    required String uid,
    required String email,
    required String displayName,
  }) {
    return _users.doc(uid).set({
      'email': email,
      'displayName': displayName,
      'role': 'employee',
      'status': 'pending',
      'permissions': <String, bool>{},
      'createdAt': FieldValue.serverTimestamp(),
      'updatedAt': FieldValue.serverTimestamp(),
    });
  }

  @override
  Stream<List<AppUser>> watchPendingUsers() {
    return _users.where('status', isEqualTo: 'pending').snapshots().map(
          (snapshot) => snapshot.docs.map(_fromDoc).toList(),
        );
  }

  @override
  Future<void> approveUser(
    String uid, {
    required UserRole role,
    required Map<String, bool> permissions,
  }) {
    return _users.doc(uid).update({
      'status': 'active',
      'role': role.name,
      'permissions': permissions,
      'updatedAt': FieldValue.serverTimestamp(),
    });
  }

  @override
  Future<void> rejectUser(String uid) {
    return _users.doc(uid).update({
      'status': 'disabled',
      'updatedAt': FieldValue.serverTimestamp(),
    });
  }
}
