import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/errors/app_exception.dart';
import '../domain/app_user.dart';
import 'auth_providers.dart';

/// Drives the auth-gated section of the app. Emits:
/// - `AsyncData(null)`      -> signed out, show LoginScreen
/// - `AsyncData(AppUser)`   -> signed in with an active profile
/// - `AsyncError(AppException(permissionDenied), ...)` -> a Firebase Auth
///   session existed but the Firestore profile was missing/suspended/disabled;
///   the user has already been force-signed-out by the time this emits, so
///   the UI should show the error and fall back to LoginScreen (TDD §6:
///   account status is part of authorization, not just a UI flag).
class AuthController extends AsyncNotifier<AppUser?> {
  @override
  Future<AppUser?> build() {
    final authRepository = ref.watch(authRepositoryProvider);

    // authStateChanges() is the source of truth; resolving the initial
    // future from it also covers "already signed in on app start".
    return authRepository.authStateChanges().first.then((identity) async {
      if (identity == null) return null;
      return _loadActiveProfile(identity.uid);
    });
  }

  Future<AppUser?> _loadActiveProfile(String uid) async {
    final userRepository = ref.read(userRepositoryProvider);
    final authRepository = ref.read(authRepositoryProvider);
    final profile = await userRepository.getUser(uid);
    if (profile == null) {
      await authRepository.signOut();
      throw const AppException(
        AppErrorCode.permissionDenied,
        'No profile found for this account. Contact an administrator.',
      );
    }
    if (profile.status == AccountStatus.pending) {
      await authRepository.signOut();
      // Requested verbatim (see the self-signup feature request): this one
      // message is Arabic while every other AuthController message stays
      // English, matching the rest of the auth feature's convention.
      throw const AppException(
        AppErrorCode.permissionDenied,
        'حسابك بانتظار موافقة الأدمن.',
      );
    }
    if (!profile.isActive) {
      await authRepository.signOut();
      throw const AppException(
        AppErrorCode.permissionDenied,
        'This account is not active. Contact an administrator.',
      );
    }
    return profile;
  }

  Future<void> signIn({required String email, required String password}) async {
    state = const AsyncLoading();
    state = await AsyncValue.guard(() async {
      final authRepository = ref.read(authRepositoryProvider);
      final identity = await authRepository.signIn(
        email: email,
        password: password,
      );
      return _loadActiveProfile(identity.uid);
    });
  }

  /// Self-signup: creates the Firebase Auth account plus its Firestore
  /// profile, always landing on `status: pending` — `_loadActiveProfile`
  /// then immediately turns that into the "pending admin approval" error
  /// above, which the UI surfaces the same way a suspended/disabled account
  /// would be (see LoginScreen/SignUpScreen).
  Future<void> signUp({
    required String email,
    required String password,
    required String displayName,
  }) async {
    state = const AsyncLoading();
    state = await AsyncValue.guard(() async {
      final authRepository = ref.read(authRepositoryProvider);
      final userRepository = ref.read(userRepositoryProvider);
      final identity = await authRepository.signUp(
        email: email,
        password: password,
      );
      try {
        await userRepository.createPendingUser(
          uid: identity.uid,
          email: identity.email ?? email,
          displayName: displayName,
        );
      } catch (_) {
        // Don't leave a signed-in Auth session with no Firestore profile
        // behind if the profile write itself failed.
        await authRepository.signOut();
        rethrow;
      }
      return _loadActiveProfile(identity.uid);
    });
  }

  Future<void> signInWithGoogle() async {
    state = const AsyncLoading();
    state = await AsyncValue.guard(() async {
      final authRepository = ref.read(authRepositoryProvider);
      final identity = await authRepository.signInWithGoogle();
      // identity == null means the user backed out of the Google flow;
      // treat it the same as a fresh signed-out state, not an error.
      if (identity == null) return null;
      return _loadActiveProfile(identity.uid);
    });
  }

  Future<void> signOut() async {
    final authRepository = ref.read(authRepositoryProvider);
    await authRepository.signOut();
    state = const AsyncData(null);
  }

  Future<void> sendPasswordResetEmail(String email) async {
    final authRepository = ref.read(authRepositoryProvider);
    await authRepository.sendPasswordResetEmail(email);
  }
}

final authControllerProvider = AsyncNotifierProvider<AuthController, AppUser?>(
  AuthController.new,
);
