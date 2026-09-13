import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../domain/app_user.dart';
import '../domain/permission.dart';
import 'auth_providers.dart';

/// Admin-only screen (callers gate visibility on Permission.userManage —
/// see ContractsHomeScreen) listing self-signup accounts awaiting approval.
///
/// This screen (and its dialogs) is presented in Arabic with an explicit
/// RTL Directionality wrapper — unlike the rest of the auth feature
/// (Login/ContractsHome/...), which stays English to match its existing
/// convention. A dialog opened via showDialog() is inserted into the app's
/// Overlay, not as a descendant of this screen's widget tree, so it does
/// NOT inherit this Directionality — each dialog wraps itself again.
class PendingUsersScreen extends ConsumerWidget {
  const PendingUsersScreen({super.key});

  Future<void> _approve(BuildContext context, WidgetRef ref, AppUser user) async {
    final result = await showDialog<(UserRole, Map<String, bool>)>(
      context: context,
      builder: (_) => _ApproveDialog(user: user),
    );
    if (result == null) return;
    final (role, permissions) = result;
    await ref.read(userRepositoryProvider).approveUser(
          user.id,
          role: role,
          permissions: permissions,
        );
  }

  Future<void> _reject(BuildContext context, WidgetRef ref, AppUser user) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => Directionality(
        textDirection: TextDirection.rtl,
        child: AlertDialog(
          title: const Text('رفض الحساب؟'),
          content: Text(
            'سيتم تعطيل حساب ${user.displayName} (${user.email}) ولن يتمكن من تسجيل الدخول.',
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(dialogContext).pop(false),
              child: const Text('إلغاء'),
            ),
            TextButton(
              key: const Key('confirmRejectButton'),
              onPressed: () => Navigator.of(dialogContext).pop(true),
              child: const Text('رفض'),
            ),
          ],
        ),
      ),
    );
    if (confirmed != true) return;
    await ref.read(userRepositoryProvider).rejectUser(user.id);
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final pendingAsync = ref.watch(pendingUsersStreamProvider);

    return Directionality(
      textDirection: TextDirection.rtl,
      child: Scaffold(
        appBar: AppBar(title: const Text('الحسابات بانتظار الموافقة')),
        body: pendingAsync.when(
          data: (users) {
            if (users.isEmpty) {
              return const Center(child: Text('لا توجد حسابات بانتظار الموافقة.'));
            }
            return ListView.separated(
              itemCount: users.length,
              separatorBuilder: (_, _) => const Divider(height: 1),
              itemBuilder: (context, index) {
                final user = users[index];
                return ListTile(
                  key: Key('pendingUserTile_${user.id}'),
                  title: Text(user.displayName.isEmpty ? user.email : user.displayName),
                  subtitle: Text(user.email),
                  trailing: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      IconButton(
                        key: Key('approveUserButton_${user.id}'),
                        icon: const Icon(Icons.check_circle_outline),
                        tooltip: 'موافقة',
                        color: Colors.green,
                        onPressed: () => _approve(context, ref, user),
                      ),
                      IconButton(
                        key: Key('rejectUserButton_${user.id}'),
                        icon: const Icon(Icons.cancel_outlined),
                        tooltip: 'رفض',
                        color: Theme.of(context).colorScheme.error,
                        onPressed: () => _reject(context, ref, user),
                      ),
                    ],
                  ),
                );
              },
            );
          },
          loading: () => const Center(child: CircularProgressIndicator()),
          error: (error, _) => Center(child: Text('تعذّر تحميل الحسابات: $error')),
        ),
      ),
    );
  }
}

class _PermissionGroup {
  final String label;
  final List<String> keys;
  const _PermissionGroup(this.label, this.keys);
}

const _permissionGroups = [
  _PermissionGroup('العملاء والعقارات', [
    Permission.customerRead,
    Permission.customerCreate,
    Permission.customerUpdate,
    Permission.propertyRead,
    Permission.propertyCreate,
    Permission.propertyUpdate,
  ]),
  _PermissionGroup('العقود', [
    Permission.contractCreate,
    Permission.contractRead,
    Permission.contractEditOwn,
    Permission.contractEditAny,
    Permission.contractSubmit,
    Permission.contractApprove,
    Permission.contractReject,
    Permission.contractFinalize,
    Permission.contractArchive,
    Permission.contractClone,
  ]),
  _PermissionGroup('القوالب', [
    Permission.templateRead,
    Permission.templateCreate,
    Permission.templateEdit,
    Permission.templatePublish,
  ]),
  _PermissionGroup('المستندات', [Permission.documentUpload, Permission.documentRead]),
  _PermissionGroup('الإدارة', [
    Permission.userRead,
    Permission.userManage,
    Permission.auditRead,
    Permission.dashboardRead,
    Permission.notificationRead,
  ]),
];

const _permissionLabels = <String, String>{
  Permission.customerRead: 'قراءة بيانات العملاء',
  Permission.customerCreate: 'إضافة عميل',
  Permission.customerUpdate: 'تعديل بيانات عميل',
  Permission.propertyRead: 'قراءة بيانات العقارات',
  Permission.propertyCreate: 'إضافة عقار',
  Permission.propertyUpdate: 'تعديل بيانات عقار',
  Permission.contractCreate: 'إنشاء عقد',
  Permission.contractRead: 'قراءة العقود',
  Permission.contractEditOwn: 'تعديل عقوده الخاصة',
  Permission.contractEditAny: 'تعديل أي عقد',
  Permission.contractSubmit: 'إرسال العقد للموافقة',
  Permission.contractApprove: 'الموافقة على العقود',
  Permission.contractReject: 'رفض العقود',
  Permission.contractFinalize: 'اعتماد العقد نهائيًا',
  Permission.contractArchive: 'أرشفة العقود',
  Permission.contractClone: 'نسخ العقود',
  Permission.templateRead: 'قراءة القوالب',
  Permission.templateCreate: 'إنشاء قالب',
  Permission.templateEdit: 'تعديل قالب',
  Permission.templatePublish: 'نشر نسخة قالب',
  Permission.documentUpload: 'رفع مستندات',
  Permission.documentRead: 'قراءة المستندات',
  Permission.userRead: 'قراءة بيانات المستخدمين',
  Permission.userManage: 'إدارة المستخدمين (موافقة/رفض الحسابات)',
  Permission.auditRead: 'قراءة سجل التدقيق',
  Permission.dashboardRead: 'عرض لوحة التحكم',
  Permission.notificationRead: 'استقبال الإشعارات',
};

class _ApproveDialog extends StatefulWidget {
  final AppUser user;

  const _ApproveDialog({required this.user});

  @override
  State<_ApproveDialog> createState() => _ApproveDialogState();
}

class _ApproveDialogState extends State<_ApproveDialog> {
  UserRole _role = UserRole.employee;
  late Map<String, bool> _permissions = Map.of(Permission.defaultsFor(false));

  void _applyPreset(bool isAdmin) {
    setState(() {
      _role = isAdmin ? UserRole.admin : UserRole.employee;
      _permissions = Map.of(Permission.defaultsFor(isAdmin));
    });
  }

  @override
  Widget build(BuildContext context) {
    return Directionality(
      textDirection: TextDirection.rtl,
      child: AlertDialog(
        title: const Text('الموافقة على الحساب'),
        content: SizedBox(
          width: 420,
          child: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text('${widget.user.displayName} (${widget.user.email})'),
                const SizedBox(height: 12),
                Wrap(
                  spacing: 8,
                  runSpacing: 8,
                  children: [
                    OutlinedButton(
                      key: const Key('applyEmployeeDefaultsButton'),
                      onPressed: () => _applyPreset(false),
                      child: const Text('الافتراضي: موظف'),
                    ),
                    OutlinedButton(
                      key: const Key('applyAdminDefaultsButton'),
                      onPressed: () => _applyPreset(true),
                      child: const Text('الافتراضي: أدمن'),
                    ),
                  ],
                ),
                const SizedBox(height: 8),
                SwitchListTile(
                  key: const Key('approveAdminRoleSwitch'),
                  contentPadding: EdgeInsets.zero,
                  title: const Text('دور أدمن'),
                  subtitle: const Text('يمنح صلاحيات الأدمن الكاملة في قواعد الحماية، بمعزل عن قائمة الصلاحيات أدناه'),
                  value: _role == UserRole.admin,
                  onChanged: (value) => setState(() => _role = value ? UserRole.admin : UserRole.employee),
                ),
                const Divider(),
                for (final group in _permissionGroups) ...[
                  Padding(
                    padding: const EdgeInsets.symmetric(vertical: 4),
                    child: Text(group.label, style: Theme.of(context).textTheme.titleSmall),
                  ),
                  for (final key in group.keys)
                    CheckboxListTile(
                      key: Key('permissionCheckbox_$key'),
                      contentPadding: EdgeInsets.zero,
                      dense: true,
                      controlAffinity: ListTileControlAffinity.leading,
                      title: Text(_permissionLabels[key] ?? key),
                      value: _permissions[key] ?? false,
                      onChanged: (checked) => setState(() => _permissions[key] = checked ?? false),
                    ),
                ],
              ],
            ),
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(),
            child: const Text('إلغاء'),
          ),
          FilledButton(
            key: const Key('approveConfirmButton'),
            onPressed: () => Navigator.of(context).pop((_role, _permissions)),
            child: const Text('موافقة'),
          ),
        ],
      ),
    );
  }
}
