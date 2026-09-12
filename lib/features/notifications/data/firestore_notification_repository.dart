import 'package:cloud_firestore/cloud_firestore.dart';

import '../domain/notification.dart';
import '../domain/notification_repository.dart';

class FirestoreNotificationRepository implements NotificationRepository {
  final FirebaseFirestore _firestore;

  FirestoreNotificationRepository(this._firestore);

  CollectionReference<Map<String, dynamic>> get _notifications =>
      _firestore.collection('notifications');

  AppNotification _fromDoc(QueryDocumentSnapshot<Map<String, dynamic>> doc) {
    final data = doc.data();
    return AppNotification(
      id: doc.id,
      userId: data['userId'] as String?,
      audiencePermission: data['audiencePermission'] as String?,
      type: notificationTypeFromString(data['type'] as String? ?? ''),
      title: data['title'] as String? ?? '',
      body: data['body'] as String? ?? '',
      entityType: data['entityType'] as String? ?? '',
      entityId: data['entityId'] as String? ?? '',
      isRead: data['isRead'] as bool? ?? false,
      createdAt: (data['createdAt'] as Timestamp?)?.toDate(),
    );
  }

  @override
  Stream<List<AppNotification>> watchPersonalNotifications(String userId) {
    return _notifications
        .where('userId', isEqualTo: userId)
        .orderBy('createdAt', descending: true)
        .snapshots()
        .map((snapshot) => snapshot.docs.map(_fromDoc).toList());
  }

  @override
  Stream<List<AppNotification>> watchBroadcastNotifications(String permission) {
    // The rule's broadcast branch requires resource.data.userId == null as
    // well as the audiencePermission match — for a list()/count() query
    // (unlike a single get()), Firestore can only prove a rule's data
    // comparisons hold for every possible result if the query itself pins
    // that same field, so userId == null has to be an explicit filter here,
    // not just true of every document this code happens to write.
    return _notifications
        .where('userId', isEqualTo: null)
        .where('audiencePermission', isEqualTo: permission)
        .orderBy('createdAt', descending: true)
        .snapshots()
        .map((snapshot) => snapshot.docs.map(_fromDoc).toList());
  }

  @override
  Future<void> markAsRead(String id) async {
    await _notifications.doc(id).update({'isRead': true});
  }
}
