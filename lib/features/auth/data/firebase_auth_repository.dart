import 'package:firebase_auth/firebase_auth.dart' as fb;

import '../../../core/errors/app_exception.dart';
import '../domain/auth_repository.dart';

class FirebaseAuthRepository implements AuthRepository {
  final fb.FirebaseAuth _auth;

  FirebaseAuthRepository(this._auth);

  AuthIdentity? _toIdentity(fb.User? user) {
    if (user == null) return null;
    return AuthIdentity(uid: user.uid, email: user.email);
  }

  @override
  Stream<AuthIdentity?> authStateChanges() =>
      _auth.authStateChanges().map(_toIdentity);

  @override
  AuthIdentity? get currentUser => _toIdentity(_auth.currentUser);

  @override
  Future<AuthIdentity> signIn({
    required String email,
    required String password,
  }) async {
    try {
      final credential = await _auth.signInWithEmailAndPassword(
        email: email,
        password: password,
      );
      final identity = _toIdentity(credential.user);
      if (identity == null) {
        throw const AppException(
          AppErrorCode.internalError,
          'Sign-in succeeded but returned no user.',
        );
      }
      return identity;
    } on fb.FirebaseAuthException catch (e) {
      throw AppException(
        AppErrorCode.authRequired,
        _messageFor(e.code),
        cause: e,
      );
    }
  }

  @override
  Future<void> signOut() => _auth.signOut();

  @override
  Future<void> sendPasswordResetEmail(String email) async {
    try {
      await _auth.sendPasswordResetEmail(email: email);
    } on fb.FirebaseAuthException catch (e) {
      throw AppException(
        AppErrorCode.validationError,
        _messageFor(e.code),
        cause: e,
      );
    }
  }

  String _messageFor(String code) {
    switch (code) {
      case 'user-not-found':
      case 'wrong-password':
      case 'invalid-credential':
        return 'Invalid email or password.';
      case 'invalid-email':
        return 'Invalid email address.';
      case 'too-many-requests':
        return 'Too many attempts. Please try again later.';
      default:
        return 'Authentication failed ($code).';
    }
  }
}
