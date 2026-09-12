import 'dart:async';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:qouta_calculator/core/errors/app_exception.dart';
import 'package:qouta_calculator/features/auth/domain/app_user.dart';
import 'package:qouta_calculator/features/auth/domain/auth_repository.dart';
import 'package:qouta_calculator/features/auth/domain/user_repository.dart';
import 'package:qouta_calculator/features/auth/presentation/auth_controller.dart';
import 'package:qouta_calculator/features/auth/presentation/auth_providers.dart';

class FakeAuthRepository implements AuthRepository {
  AuthIdentity? _current;
  final _controller = StreamController<AuthIdentity?>.broadcast();
  int signOutCalls = 0;

  /// Maps email -> (password, uid). A wrong password throws like the real
  /// FirebaseAuthException path does.
  final Map<String, ({String password, String uid})> credentials;

  FakeAuthRepository(this.credentials);

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

AppUser _user(String id, {AccountStatus status = AccountStatus.active}) => AppUser(
      id: id,
      email: '$id@example.com',
      displayName: id,
      role: UserRole.employee,
      status: status,
      permissions: const {},
    );

void main() {
  group('AuthController', () {
    test('starts signed out when there is no existing Firebase session', () async {
      final authRepo = FakeAuthRepository({});
      final container = ProviderContainer(overrides: [
        authRepositoryProvider.overrideWithValue(authRepo),
        userRepositoryProvider.overrideWithValue(FakeUserRepository({})),
      ]);
      addTearDown(container.dispose);
      addTearDown(authRepo.dispose);

      final result = await container.read(authControllerProvider.future);
      expect(result, isNull);
    });

    test('signIn with an active profile resolves to that AppUser', () async {
      final authRepo = FakeAuthRepository({
        'a@b.com': (password: 'pw', uid: 'uid-1'),
      });
      final container = ProviderContainer(overrides: [
        authRepositoryProvider.overrideWithValue(authRepo),
        userRepositoryProvider.overrideWithValue(FakeUserRepository({'uid-1': _user('uid-1')})),
      ]);
      addTearDown(container.dispose);
      addTearDown(authRepo.dispose);

      await container.read(authControllerProvider.future); // resolve initial build()
      await container.read(authControllerProvider.notifier).signIn(email: 'a@b.com', password: 'pw');

      final state = container.read(authControllerProvider);
      expect(state.value?.id, 'uid-1');
      expect(state.hasError, isFalse);
    });

    test('a Firebase session with no Firestore profile is force-signed-out and surfaces permissionDenied', () async {
      final authRepo = FakeAuthRepository({
        'nouser@b.com': (password: 'pw', uid: 'uid-missing'),
      });
      final container = ProviderContainer(overrides: [
        authRepositoryProvider.overrideWithValue(authRepo),
        userRepositoryProvider.overrideWithValue(FakeUserRepository({})),
      ]);
      addTearDown(container.dispose);
      addTearDown(authRepo.dispose);

      await container.read(authControllerProvider.future);
      await container.read(authControllerProvider.notifier).signIn(email: 'nouser@b.com', password: 'pw');

      final state = container.read(authControllerProvider);
      expect(state.hasError, isTrue);
      expect(state.error, isA<AppException>());
      expect((state.error as AppException).code, AppErrorCode.permissionDenied);
      expect(authRepo.signOutCalls, 1);
    });

    test('a suspended/disabled account is force-signed-out and surfaces permissionDenied', () async {
      final authRepo = FakeAuthRepository({
        'suspended@b.com': (password: 'pw', uid: 'uid-suspended'),
      });
      final container = ProviderContainer(overrides: [
        authRepositoryProvider.overrideWithValue(authRepo),
        userRepositoryProvider.overrideWithValue(FakeUserRepository({
          'uid-suspended': _user('uid-suspended', status: AccountStatus.suspended),
        })),
      ]);
      addTearDown(container.dispose);
      addTearDown(authRepo.dispose);

      await container.read(authControllerProvider.future);
      await container.read(authControllerProvider.notifier).signIn(email: 'suspended@b.com', password: 'pw');

      final state = container.read(authControllerProvider);
      expect(state.hasError, isTrue);
      expect((state.error as AppException).code, AppErrorCode.permissionDenied);
      expect(authRepo.signOutCalls, 1);
    });

    test('signOut clears state back to signed-out', () async {
      final authRepo = FakeAuthRepository({
        'a@b.com': (password: 'pw', uid: 'uid-1'),
      });
      final container = ProviderContainer(overrides: [
        authRepositoryProvider.overrideWithValue(authRepo),
        userRepositoryProvider.overrideWithValue(FakeUserRepository({'uid-1': _user('uid-1')})),
      ]);
      addTearDown(container.dispose);
      addTearDown(authRepo.dispose);

      await container.read(authControllerProvider.future);
      await container.read(authControllerProvider.notifier).signIn(email: 'a@b.com', password: 'pw');
      await container.read(authControllerProvider.notifier).signOut();

      expect(container.read(authControllerProvider).value, isNull);
    });
  });
}
