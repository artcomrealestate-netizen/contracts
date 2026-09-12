import 'package:flutter_test/flutter_test.dart';
import 'package:qouta_calculator/features/auth/domain/app_user.dart';
import 'package:qouta_calculator/features/auth/domain/permission.dart';

void main() {
  group('AppUser', () {
    test('isActive is true only when status is active', () {
      AppUser user(AccountStatus status) => AppUser(
            id: 'u1',
            email: 'a@b.com',
            displayName: 'A',
            role: UserRole.employee,
            status: status,
            permissions: const {},
          );

      expect(user(AccountStatus.active).isActive, isTrue);
      expect(user(AccountStatus.suspended).isActive, isFalse);
      expect(user(AccountStatus.disabled).isActive, isFalse);
    });

    test('hasPermission looks up the permission map and defaults to false', () {
      final user = AppUser(
        id: 'u1',
        email: 'a@b.com',
        displayName: 'A',
        role: UserRole.employee,
        status: AccountStatus.active,
        permissions: const {Permission.contractCreate: true, Permission.contractApprove: false},
      );

      expect(user.hasPermission(Permission.contractCreate), isTrue);
      expect(user.hasPermission(Permission.contractApprove), isFalse);
      expect(user.hasPermission('unknown.permission'), isFalse);
    });
  });

  group('userRoleFromString / accountStatusFromString', () {
    test('parses known values', () {
      expect(userRoleFromString('admin'), UserRole.admin);
      expect(userRoleFromString('employee'), UserRole.employee);
      expect(accountStatusFromString('active'), AccountStatus.active);
      expect(accountStatusFromString('suspended'), AccountStatus.suspended);
      expect(accountStatusFromString('disabled'), AccountStatus.disabled);
    });

    test('falls back safely on unknown/malformed values', () {
      // An unrecognized role must never silently become admin.
      expect(userRoleFromString('super-admin'), UserRole.employee);
      // An unrecognized status must never silently become active.
      expect(accountStatusFromString('archived'), AccountStatus.disabled);
    });
  });

  group('Permission.defaultsFor', () {
    test('employee defaults do not include approval/finalization permissions', () {
      final perms = Permission.defaultsFor(false);
      expect(perms[Permission.contractCreate], isTrue);
      expect(perms.containsKey(Permission.contractApprove), isFalse);
      expect(perms.containsKey(Permission.userManage), isFalse);
    });

    test('admin defaults are a superset of employee defaults', () {
      final employee = Permission.defaultsFor(false);
      final admin = Permission.defaultsFor(true);
      for (final entry in employee.entries) {
        expect(admin[entry.key], entry.value);
      }
      expect(admin[Permission.contractApprove], isTrue);
      expect(admin[Permission.contractFinalize], isTrue);
      expect(admin[Permission.userManage], isTrue);
    });
  });
}
