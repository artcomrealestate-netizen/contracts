import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/providers/firebase_providers.dart';
import '../data/firebase_auth_repository.dart';
import '../data/firestore_user_repository.dart';
import '../domain/app_user.dart';
import '../domain/auth_repository.dart';
import '../domain/user_repository.dart';

final authRepositoryProvider = Provider<AuthRepository>((ref) {
  return FirebaseAuthRepository(ref.watch(firebaseAuthProvider));
});

final userRepositoryProvider = Provider<UserRepository>((ref) {
  return FirestoreUserRepository(ref.watch(firestoreProvider));
});

/// Backs the Pending Users screen (Permission.userManage-gated).
final pendingUsersStreamProvider = StreamProvider<List<AppUser>>((ref) {
  return ref.watch(userRepositoryProvider).watchPendingUsers();
});
