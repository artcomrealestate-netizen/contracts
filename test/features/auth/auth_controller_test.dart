import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:qouta_calculator/core/errors/app_exception.dart';
import 'package:qouta_calculator/features/auth/domain/app_user.dart';
import 'package:qouta_calculator/features/auth/domain/auth_repository.dart';
import 'package:qouta_calculator/features/auth/presentation/auth_controller.dart';
import 'package:qouta_calculator/features/auth/presentation/auth_providers.dart';

import '../../test_support/fake_auth_support.dart';

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

    test('a pending account signing in gets a distinct "pending approval" message', () async {
      final authRepo = FakeAuthRepository({
        'pending@b.com': (password: 'pw', uid: 'uid-pending'),
      });
      final container = ProviderContainer(overrides: [
        authRepositoryProvider.overrideWithValue(authRepo),
        userRepositoryProvider.overrideWithValue(FakeUserRepository({
          'uid-pending': _user('uid-pending', status: AccountStatus.pending),
        })),
      ]);
      addTearDown(container.dispose);
      addTearDown(authRepo.dispose);

      await container.read(authControllerProvider.future);
      await container.read(authControllerProvider.notifier).signIn(email: 'pending@b.com', password: 'pw');

      final state = container.read(authControllerProvider);
      expect(state.hasError, isTrue);
      final error = state.error as AppException;
      expect(error.code, AppErrorCode.permissionDenied);
      expect(error.message, contains('موافقة الأدمن'));
      expect(authRepo.signOutCalls, 1);
    });

    test('signUp creates a pending profile and surfaces the pending-approval message', () async {
      final authRepo = FakeAuthRepository({});
      final userRepo = FakeUserRepository({});
      final container = ProviderContainer(overrides: [
        authRepositoryProvider.overrideWithValue(authRepo),
        userRepositoryProvider.overrideWithValue(userRepo),
      ]);
      addTearDown(container.dispose);
      addTearDown(authRepo.dispose);

      await container.read(authControllerProvider.future);
      await container.read(authControllerProvider.notifier).signUp(
            email: 'new@b.com',
            password: 'pw123',
            displayName: 'New Person',
          );

      final state = container.read(authControllerProvider);
      expect(state.hasError, isTrue);
      final error = state.error as AppException;
      expect(error.code, AppErrorCode.permissionDenied);
      expect(error.message, contains('موافقة الأدمن'));
      // The Firestore profile was created with no access at all, and the
      // Auth session was signed back out (mirrors _loadActiveProfile).
      final created = userRepo.usersByUid.values.single;
      expect(created.status, AccountStatus.pending);
      expect(created.role, UserRole.employee);
      expect(created.permissions, isEmpty);
      expect(authRepo.signOutCalls, 1);
    });

    test('an approved (formerly pending) account can then sign in normally', () async {
      final authRepo = FakeAuthRepository({
        'approved@b.com': (password: 'pw', uid: 'uid-approved'),
      });
      final userRepo = FakeUserRepository({
        'uid-approved': _user('uid-approved', status: AccountStatus.pending),
      });
      final container = ProviderContainer(overrides: [
        authRepositoryProvider.overrideWithValue(authRepo),
        userRepositoryProvider.overrideWithValue(userRepo),
      ]);
      addTearDown(container.dispose);
      addTearDown(authRepo.dispose);

      await userRepo.approveUser('uid-approved', role: UserRole.employee, permissions: {'customer.read': true});

      await container.read(authControllerProvider.future);
      await container.read(authControllerProvider.notifier).signIn(email: 'approved@b.com', password: 'pw');

      final state = container.read(authControllerProvider);
      expect(state.hasError, isFalse);
      expect(state.value?.id, 'uid-approved');
      expect(state.value?.hasPermission('customer.read'), isTrue);
    });

    test('signInWithGoogle with an active profile resolves to that AppUser', () async {
      final authRepo = FakeAuthRepository({})
        ..nextGoogleIdentity = const AuthIdentity(uid: 'uid-google', email: 'g@example.com');
      final container = ProviderContainer(overrides: [
        authRepositoryProvider.overrideWithValue(authRepo),
        userRepositoryProvider.overrideWithValue(FakeUserRepository({'uid-google': _user('uid-google')})),
      ]);
      addTearDown(container.dispose);
      addTearDown(authRepo.dispose);

      await container.read(authControllerProvider.future);
      await container.read(authControllerProvider.notifier).signInWithGoogle();

      final state = container.read(authControllerProvider);
      expect(state.value?.id, 'uid-google');
      expect(state.hasError, isFalse);
    });

    test('signInWithGoogle returns to signed-out with no error when the user cancels', () async {
      final authRepo = FakeAuthRepository({}); // nextGoogleIdentity left null == cancelled
      final container = ProviderContainer(overrides: [
        authRepositoryProvider.overrideWithValue(authRepo),
        userRepositoryProvider.overrideWithValue(FakeUserRepository({})),
      ]);
      addTearDown(container.dispose);
      addTearDown(authRepo.dispose);

      await container.read(authControllerProvider.future);
      await container.read(authControllerProvider.notifier).signInWithGoogle();

      final state = container.read(authControllerProvider);
      expect(state.value, isNull);
      expect(state.hasError, isFalse);
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
