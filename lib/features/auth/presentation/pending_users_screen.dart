import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../domain/app_user.dart';
import '../domain/permission.dart';
import 'auth_providers.dart';

/// Admin-only screen (callers gate visibility on Permission.userManage —
/// see ContractsHomeScreen) listing self-signup accounts awaiting approval.
class PendingUsersScreen extends ConsumerWidget {
  const PendingUsersScreen({super.key});

  Future<void> _approve(BuildContext context, WidgetRef ref, AppUser user) async {
    final grantAdmin = await showDialog<bool>(
      context: context,
      builder: (_) => _ApproveDialog(user: user),
    );
    if (grantAdmin == null) return;
    await ref.read(userRepositoryProvider).approveUser(
          user.id,
          role: grantAdmin ? UserRole.admin : UserRole.employee,
          permissions: Permission.defaultsFor(grantAdmin),
        );
  }

  Future<void> _reject(BuildContext context, WidgetRef ref, AppUser user) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: const Text('Reject account?'),
        content: Text(
          '${user.displayName} (${user.email}) will be disabled and unable to sign in.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(dialogContext).pop(false),
            child: const Text('Cancel'),
          ),
          TextButton(
            key: const Key('confirmRejectButton'),
            onPressed: () => Navigator.of(dialogContext).pop(true),
            child: const Text('Reject'),
          ),
        ],
      ),
    );
    if (confirmed != true) return;
    await ref.read(userRepositoryProvider).rejectUser(user.id);
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final pendingAsync = ref.watch(pendingUsersStreamProvider);

    return Scaffold(
      appBar: AppBar(title: const Text('Pending Users')),
      body: pendingAsync.when(
        data: (users) {
          if (users.isEmpty) {
            return const Center(child: Text('No accounts awaiting approval.'));
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
                      tooltip: 'Approve',
                      color: Colors.green,
                      onPressed: () => _approve(context, ref, user),
                    ),
                    IconButton(
                      key: Key('rejectUserButton_${user.id}'),
                      icon: const Icon(Icons.cancel_outlined),
                      tooltip: 'Reject',
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
        error: (error, _) => Center(child: Text('Failed to load pending users: $error')),
      ),
    );
  }
}

class _ApproveDialog extends StatefulWidget {
  final AppUser user;

  const _ApproveDialog({required this.user});

  @override
  State<_ApproveDialog> createState() => _ApproveDialogState();
}

class _ApproveDialogState extends State<_ApproveDialog> {
  bool _grantAdmin = false;

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: const Text('Approve account'),
      content: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text('${widget.user.displayName} (${widget.user.email})'),
          const SizedBox(height: 12),
          SwitchListTile(
            key: const Key('approveGrantAdminSwitch'),
            contentPadding: EdgeInsets.zero,
            title: const Text('Grant admin permissions'),
            subtitle: const Text('Off approves as a regular employee (Permission.defaultsFor(false)).'),
            value: _grantAdmin,
            onChanged: (value) => setState(() => _grantAdmin = value),
          ),
        ],
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.of(context).pop(),
          child: const Text('Cancel'),
        ),
        FilledButton(
          key: const Key('approveConfirmButton'),
          onPressed: () => Navigator.of(context).pop(_grantAdmin),
          child: const Text('Approve'),
        ),
      ],
    );
  }
}
