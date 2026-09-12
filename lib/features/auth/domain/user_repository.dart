import 'app_user.dart';

abstract class UserRepository {
  Future<AppUser?> getUser(String uid);

  Stream<AppUser?> watchUser(String uid);

  /// Creates the initial `users/{uid}` profile for a newly self-registered
  /// account. Always written as `role: employee`, `status: pending`,
  /// `permissions: {}` — matching firestore.rules' self-signup `allow
  /// create`, so the account is powerless until an admin approves it.
  Future<void> createPendingUser({
    required String uid,
    required String email,
    required String displayName,
  });

  /// Accounts awaiting admin approval, for the Pending Users screen.
  Stream<List<AppUser>> watchPendingUsers();

  /// Approves a pending account: assigns [role]/[permissions] and flips
  /// `status` to `active`.
  Future<void> approveUser(
    String uid, {
    required UserRole role,
    required Map<String, bool> permissions,
  });

  /// Rejects a pending account by disabling it (its Firebase Auth
  /// credentials still exist, but it can never load an active profile again
  /// — see AuthController._loadActiveProfile).
  Future<void> rejectUser(String uid);
}
