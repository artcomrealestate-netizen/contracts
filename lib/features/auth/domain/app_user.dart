enum UserRole { employee, admin }

enum AccountStatus { pending, active, suspended, disabled }

UserRole userRoleFromString(String value) {
  return UserRole.values.firstWhere(
    (r) => r.name == value,
    orElse: () => UserRole.employee,
  );
}

AccountStatus accountStatusFromString(String value) {
  return AccountStatus.values.firstWhere(
    (s) => s.name == value,
    orElse: () => AccountStatus.disabled,
  );
}

/// Mirrors the `users/{userId}` document (TDD §11). This is the
/// authorization-relevant profile loaded after Firebase Auth sign-in; it is
/// distinct from the Firebase Auth user record itself.
class AppUser {
  final String id;
  final String email;
  final String displayName;
  final UserRole role;
  final AccountStatus status;
  final Map<String, bool> permissions;
  final DateTime? createdAt;
  final DateTime? updatedAt;
  final DateTime? lastLoginAt;

  const AppUser({
    required this.id,
    required this.email,
    required this.displayName,
    required this.role,
    required this.status,
    required this.permissions,
    this.createdAt,
    this.updatedAt,
    this.lastLoginAt,
  });

  bool get isActive => status == AccountStatus.active;

  bool hasPermission(String key) => permissions[key] ?? false;
}
