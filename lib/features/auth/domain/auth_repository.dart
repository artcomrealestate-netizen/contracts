/// Minimal identity the rest of the app needs from Firebase Auth. Kept
/// separate from [AppUser] (the Firestore profile) so the domain layer never
/// depends on the `firebase_auth` package directly (TDD §42/§5.4).
class AuthIdentity {
  final String uid;
  final String? email;

  const AuthIdentity({required this.uid, this.email});
}

abstract class AuthRepository {
  Stream<AuthIdentity?> authStateChanges();

  AuthIdentity? get currentUser;

  Future<AuthIdentity> signIn({
    required String email,
    required String password,
  });

  /// Returns `null` if the user backs out of the Google sign-in flow before
  /// completing it — that's a no-op, not a failure worth surfacing as an
  /// error banner.
  Future<AuthIdentity?> signInWithGoogle();

  Future<void> signOut();

  Future<void> sendPasswordResetEmail(String email);
}
