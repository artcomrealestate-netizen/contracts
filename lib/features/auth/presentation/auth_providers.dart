import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart' as fb;
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../data/firebase_auth_repository.dart';
import '../data/firestore_user_repository.dart';
import '../domain/auth_repository.dart';
import '../domain/user_repository.dart';

final firebaseAuthProvider = Provider<fb.FirebaseAuth>((ref) {
  return fb.FirebaseAuth.instance;
});

final firestoreProvider = Provider<FirebaseFirestore>((ref) {
  return FirebaseFirestore.instance;
});

final authRepositoryProvider = Provider<AuthRepository>((ref) {
  return FirebaseAuthRepository(ref.watch(firebaseAuthProvider));
});

final userRepositoryProvider = Provider<UserRepository>((ref) {
  return FirestoreUserRepository(ref.watch(firestoreProvider));
});
