import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/providers/firebase_providers.dart';
import '../../auth/domain/permission.dart';
import '../../auth/presentation/auth_controller.dart';
import '../data/firestore_notification_repository.dart';
import '../domain/notification.dart';
import '../domain/notification_repository.dart';

final notificationRepositoryProvider = Provider<NotificationRepository>((ref) {
  return FirestoreNotificationRepository(ref.watch(firestoreProvider));
});

final personalNotificationsProvider = StreamProvider.autoDispose<List<AppNotification>>((ref) {
  final user = ref.watch(authControllerProvider).value;
  if (user == null) return const Stream.empty();
  return ref.watch(notificationRepositoryProvider).watchPersonalNotifications(user.id);
});

/// Empty unless the signed-in user holds contract.approve — the only
/// broadcast audience this phase creates notifications for (Submitted).
final broadcastNotificationsProvider = StreamProvider.autoDispose<List<AppNotification>>((ref) {
  final user = ref.watch(authControllerProvider).value;
  if (user == null || !user.hasPermission(Permission.contractApprove)) {
    return const Stream.empty();
  }
  return ref.watch(notificationRepositoryProvider).watchBroadcastNotifications(Permission.contractApprove);
});
