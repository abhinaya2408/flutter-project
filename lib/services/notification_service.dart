import 'package:cloud_firestore/cloud_firestore.dart';

import '../data/order_status.dart';
import '../models/app_notification.dart';
import 'firestore_paths.dart';

/// Notifications — the Firestore replacement for the notification helpers in
/// `college-bakery/js/app.js` (`createNotification`, `getNotifications`,
/// `markNotificationRead`, `markAllNotificationsRead`,
/// `unreadNotificationCount`) and `js/owner.js` which creates one every time a
/// bakery member changes a status.
class NotificationService {
  NotificationService({FirebaseFirestore? firestore})
      : _firestore = firestore ?? FirebaseFirestore.instance;

  final FirebaseFirestore _firestore;

  CollectionReference<Map<String, dynamic>> get _notifications =>
      _firestore.collection(FirestorePaths.notifications);

  /// `getNotifications(studentId)` — newest first.
  Stream<List<AppNotification>> watchForStudent(String studentId) =>
      _notifications
          .where('studentId', isEqualTo: studentId)
          .snapshots()
          .map((QuerySnapshot<Map<String, dynamic>> snapshot) {
        final List<AppNotification> items = snapshot.docs
            .map((QueryDocumentSnapshot<Map<String, dynamic>> doc) =>
                AppNotification.fromMap(<String, dynamic>{
                  ...doc.data(),
                  'id': doc.data()['id'] ?? doc.id,
                }))
            .toList();
        items.sort((AppNotification a, AppNotification b) =>
            _millis(b.createdAt).compareTo(_millis(a.createdAt)));
        return items;
      });

  /// `unreadNotificationCount(studentId)` — drives the nav badge.
  Stream<int> watchUnreadCount(String studentId) => watchForStudent(studentId)
      .map((List<AppNotification> items) =>
          items.where((AppNotification item) => !item.read).length);

  /// `createNotification({ studentId, orderId, message })`
  Future<AppNotification> createNotification({
    required String studentId,
    required String orderId,
    required String message,
  }) async {
    final AppNotification notification = AppNotification(
      id: AppNotification.generateId(),
      studentId: studentId,
      orderId: orderId,
      message: message,
      read: false,
      createdAt: DateTime.now().toUtc().toIso8601String(),
    );
    await _notifications.doc(notification.id).set(notification.toMap());
    return notification;
  }

  /// `advanceOrderStatus()` in `js/owner.js` — updates the order status and
  /// creates the matching notification in one go.
  Future<void> notifyStatusChange({
    required String studentId,
    required String orderId,
    required String status,
  }) async {
    final String message = OrderStatus.notificationMessage(status, orderId);
    if (message.isEmpty) return;
    await createNotification(
      studentId: studentId,
      orderId: orderId,
      message: message,
    );
  }

  /// `markNotificationRead(id)`
  Future<void> markRead(String id) =>
      _notifications.doc(id).update(<String, dynamic>{'read': true});

  /// `markAllNotificationsRead(studentId)`
  Future<void> markAllRead(String studentId) async {
    final QuerySnapshot<Map<String, dynamic>> snapshot = await _notifications
        .where('studentId', isEqualTo: studentId)
        .get();
    if (snapshot.docs.isEmpty) return;
    final WriteBatch batch = _firestore.batch();
    for (final QueryDocumentSnapshot<Map<String, dynamic>> doc
        in snapshot.docs) {
      if (doc.data()['read'] != true) {
        batch.update(doc.reference, <String, dynamic>{'read': true});
      }
    }
    await batch.commit();
  }

  /// "Clear Demo Data" — removes every notification.
  Future<void> deleteAllNotifications() async {
    final QuerySnapshot<Map<String, dynamic>> snapshot =
        await _notifications.limit(400).get();
    if (snapshot.docs.isEmpty) return;
    final WriteBatch batch = _firestore.batch();
    for (final QueryDocumentSnapshot<Map<String, dynamic>> doc
        in snapshot.docs) {
      batch.delete(doc.reference);
    }
    await batch.commit();
    if (snapshot.docs.length == 400) {
      await deleteAllNotifications();
    }
  }

  int _millis(String iso) =>
      DateTime.tryParse(iso)?.millisecondsSinceEpoch ?? 0;
}
