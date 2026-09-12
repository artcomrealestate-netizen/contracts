import 'notification.dart';

abstract class NotificationRepository {
  /// Notifications addressed directly to [userId] — newest first. No
  /// pagination yet (TDD §36 pagination lands with Dashboard/Search, phase
  /// 10) — fine for the small volume this phase deals with.
  Stream<List<AppNotification>> watchPersonalNotifications(String userId);

  /// Role-broadcast notifications anyone holding [permission] should see
  /// (see AppNotification's doc comment) — newest first.
  Stream<List<AppNotification>> watchBroadcastNotifications(String permission);

  /// Only valid for a personal notification the caller owns — a broadcast
  /// notification (no single userId) can never be individually marked read,
  /// see the notifications match block in firestore.rules.
  Future<void> markAsRead(String id);
}
