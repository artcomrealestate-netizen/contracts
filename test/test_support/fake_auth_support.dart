import 'dart:async';

import 'package:qouta_calculator/core/errors/app_exception.dart';
import 'package:qouta_calculator/features/auth/domain/app_user.dart';
import 'package:qouta_calculator/features/auth/domain/auth_repository.dart';
import 'package:qouta_calculator/features/auth/domain/user_repository.dart';

/// Shared across test/features/auth/auth_controller_test.dart (which starts
/// every scenario signed out and drives signIn() explicitly) and
/// test/widget_test.dart (which needs an already-signed-in session before
/// the first frame, since it pumps QuotaCalculatorScreen directly rather
/// than through the app's login-gated root).
class FakeAuthRepository implements AuthRepository {
  AuthIdentity? _current;
  final _controller = StreamController<AuthIdentity?>.broadcast();
  int signOutCalls = 0;

  /// Maps email -> (password, uid). A wrong password throws like the real
  /// FirebaseAuthException path does.
  final Map<String, ({String password, String uid})> credentials;

  /// Set by a test to control what the next signInWithGoogle() call does:
  /// an identity to "sign in" as, `null` to simulate the user cancelling,
  /// or leave unset and set [googleSignInError] to simulate a failure.
  AuthIdentity? nextGoogleIdentity;
  Object? googleSignInError;

  FakeAuthRepository(this.credentials, {AuthIdentity? initialIdentity}) : _current = initialIdentity;

  @override
  AuthIdentity? get currentUser => _current;

  // Real FirebaseAuth.authStateChanges() replays the current state to every
  // new subscriber immediately, then forwards future changes — that's what
  // `AuthController.build()` relies on via `.first`. A plain broadcast
  // stream doesn't replay, so this fake has to do it explicitly.
  @override
  Stream<AuthIdentity?> authStateChanges() async* {
    yield _current;
    yield* _controller.stream;
  }

  @override
  Future<AuthIdentity> signIn({required String email, required String password}) async {
    final match = credentials[email];
    if (match == null || match.password != password) {
      throw const AppException(AppErrorCode.authRequired, 'Invalid email or password.');
    }
    final identity = AuthIdentity(uid: match.uid, email: email);
    _current = identity;
    _controller.add(identity);
    return identity;
  }

  @override
  Future<AuthIdentity?> signInWithGoogle() async {
    if (googleSignInError != null) throw googleSignInError!;
    final identity = nextGoogleIdentity;
    if (identity == null) return null;
    _current = identity;
    _controller.add(identity);
    return identity;
  }

  @override
  Future<void> signOut() async {
    signOutCalls++;
    _current = null;
    _controller.add(null);
  }

  @override
  Future<void> sendPasswordResetEmail(String email) async {}

  void dispose() => _controller.close();
}

class FakeUserRepository implements UserRepository {
  final Map<String, AppUser> usersByUid;

  FakeUserRepository(this.usersByUid);

  @override
  Future<AppUser?> getUser(String uid) async => usersByUid[uid];

  @override
  Stream<AppUser?> watchUser(String uid) => Stream.value(usersByUid[uid]);
}
