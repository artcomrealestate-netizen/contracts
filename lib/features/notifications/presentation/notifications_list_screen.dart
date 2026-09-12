import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../contracts/presentation/contract_detail_screen.dart';
import '../domain/notification.dart';
import 'notification_providers.dart';

class NotificationsListScreen extends ConsumerWidget {
  const NotificationsListScreen({super.key});

  void _open(BuildContext context, WidgetRef ref, AppNotification notification) {
    // Only a personal notification has a single owner it's safe to mark
    // read for — see NotificationRepository.markAsRead's doc comment.
    if (notification.userId != null && !notification.isRead) {
      ref.read(notificationRepositoryProvider).markAsRead(notification.id);
    }
    if (notification.entityType == 'contract') {
      Navigator.of(context).push(
        MaterialPageRoute(builder: (_) => ContractDetailScreen(contractId: notification.entityId)),
      );
    }
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final personalAsync = ref.watch(personalNotificationsProvider);
    final broadcastAsync = ref.watch(broadcastNotificationsProvider);

    return Scaffold(
      appBar: AppBar(title: const Text('Notifications')),
      body: personalAsync.when(
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (error, _) => Center(child: Text('Failed to load notifications: $error')),
        data: (personal) => broadcastAsync.when(
          loading: () => const Center(child: CircularProgressIndicator()),
          error: (error, _) => Center(child: Text('Failed to load notifications: $error')),
          data: (broadcast) {
            final all = [...personal, ...broadcast]
              ..sort((a, b) => (b.createdAt ?? DateTime(0)).compareTo(a.createdAt ?? DateTime(0)));
            if (all.isEmpty) {
              return const Center(child: Text('No notifications yet.'));
            }
            return ListView.separated(
              itemCount: all.length,
              separatorBuilder: (_, _) => const Divider(height: 1),
              itemBuilder: (context, index) {
                final notification = all[index];
                final isUnread = notification.userId != null && !notification.isRead;
                return ListTile(
                  key: Key('notificationTile_${notification.id}'),
                  leading: Icon(
                    isUnread ? Icons.circle : Icons.circle_outlined,
                    size: 12,
                    color: isUnread
                        ? Theme.of(context).colorScheme.primary
                        : Theme.of(context).colorScheme.outlineVariant,
                  ),
                  title: Text(
                    notification.title,
                    style: TextStyle(fontWeight: isUnread ? FontWeight.bold : FontWeight.normal),
                  ),
                  subtitle: Text(notification.body),
                  onTap: () => _open(context, ref, notification),
                );
              },
            );
          },
        ),
      ),
    );
  }
}
