enum NotificationType { contractSubmitted, contractApproved, contractRejected, contractFinalized }

String notificationTypeToString(NotificationType type) => switch (type) {
      NotificationType.contractSubmitted => 'CONTRACT_SUBMITTED',
      NotificationType.contractApproved => 'CONTRACT_APPROVED',
      NotificationType.contractRejected => 'CONTRACT_REJECTED',
      NotificationType.contractFinalized => 'CONTRACT_FINALIZED',
    };

NotificationType notificationTypeFromString(String value) {
  return switch (value) {
    'CONTRACT_SUBMITTED' => NotificationType.contractSubmitted,
    'CONTRACT_APPROVED' => NotificationType.contractApproved,
    'CONTRACT_REJECTED' => NotificationType.contractRejected,
    'CONTRACT_FINALIZED' => NotificationType.contractFinalized,
    _ => NotificationType.contractSubmitted,
  };
}

/// Mirrors the `notifications/{notificationId}` document (TDD §32/§33) —
/// in-app only for this phase, no FCM push (that needs Firebase Console
/// setup — Cloud Messaging, a VAPID key, a web service worker — per environment,
/// the same kind of cost that was skipped for Storage/PDF-hash persistence).
///
/// Exactly one of [userId] / [audiencePermission] is set:
/// - [userId]: addressed to one specific person (e.g. the contract owner,
///   on Approved/Rejected/Finalized).
/// - [audiencePermission]: a role broadcast — anyone whose permission map
///   has this key granted (e.g. "contract.approve" for Submitted) — used
///   when the actor creating the notification (the contract owner,
///   submitting) has no way to look up individual approver accounts, since
///   that needs `user.read`, which owners don't have.
class AppNotification {
  final String id;
  final String? userId;
  final String? audiencePermission;
  final NotificationType type;
  final String title;
  final String body;
  final String entityType;
  final String entityId;
  final bool isRead;
  final DateTime? createdAt;

  const AppNotification({
    required this.id,
    required this.type,
    required this.title,
    required this.body,
    required this.entityType,
    required this.entityId,
    required this.isRead,
    this.userId,
    this.audiencePermission,
    this.createdAt,
  });
}
