import 'dart:async';
import 'dart:developer' as dev;

import 'package:cloud_firestore/cloud_firestore.dart';
import 'notification_model.dart';

abstract class NotificationRepository {
  Stream<List<AppNotification>> watchUserNotifications(String userId);
  Stream<int> watchUnreadCount(String userId);
  Future<int> getUnreadCount(String userId);
  Future<void> markAsRead(String notificationId);
  Future<void> markAllAsRead(String userId);
  Future<void> deleteNotification(String notificationId);
  Future<void> createNotification(AppNotification notification);
  Future<void> deleteNotificationsByCondition({
    required String userId,
    required String actorId,
    required NotificationType type,
  });
}

class NotificationRepositoryImpl implements NotificationRepository {
  NotificationRepositoryImpl({FirebaseFirestore? firestore})
      : _firestore = firestore ?? FirebaseFirestore.instance;

  final FirebaseFirestore _firestore;

  CollectionReference<Map<String, dynamic>> get _notifications =>
      _firestore.collection('notifications');

  @override
  Stream<List<AppNotification>> watchUserNotifications(String userId) {
    // Try primary query with index
    final primary = _notifications
        .where('userId', isEqualTo: userId)
        .orderBy('createdAt', descending: true)
        .limit(50);
        
    // Fallback if index missing
    final fallback = _notifications
        .where('userId', isEqualTo: userId)
        .limit(50);

    return _listenWithFallback<AppNotification>(
      primary: primary,
      fallback: fallback,
      mapper: (snapshot) {
        final notifications = snapshot.docs
            .map((doc) => AppNotification.fromDoc(doc))
            .toList();
        
        // Sort client-side for fallback or safety
        notifications.sort((a, b) => b.createdAt.compareTo(a.createdAt));
        return notifications;
      },
    );
  }

  Stream<List<T>> _listenWithFallback<T>({
    required Query<Map<String, dynamic>> primary,
    required Query<Map<String, dynamic>> fallback,
    required List<T> Function(QuerySnapshot<Map<String, dynamic>>) mapper,
  }) {
    // Local implementation of the fallback listener to avoid index errors
    final controller = StreamController<List<T>>();
    StreamSubscription? sub;

    void listen(Query<Map<String, dynamic>> query, {required bool isFallback}) {
      sub = query.snapshots().listen(
        (snap) => controller.add(mapper(snap)),
        onError: (e) {
          if (e is FirebaseException && (e.code == 'failed-precondition')) {
            if (!isFallback) {
              sub?.cancel();
              listen(fallback, isFallback: true);
              return;
            }
          }
          if (!controller.isClosed) controller.addError(e);
        },
      );
    }

    controller.onListen = () => listen(primary, isFallback: false);
    controller.onCancel = () => sub?.cancel();

    return controller.stream;
  }

  @override
  Stream<int> watchUnreadCount(String userId) {
    return _notifications
        .where('userId', isEqualTo: userId)
        .where('isRead', isEqualTo: false)
        .snapshots()
        .map((snapshot) => snapshot.docs.length);
  }

  @override
  Future<int> getUnreadCount(String userId) async {
    final snapshot = await _notifications
        .where('userId', isEqualTo: userId)
        .where('isRead', isEqualTo: false)
        .count()
        .get();
    return snapshot.count ?? 0;
  }

  @override
  Future<void> markAsRead(String notificationId) async {
    await _notifications.doc(notificationId).update({'isRead': true});
  }

  @override
  Future<void> markAllAsRead(String userId) async {
    dev.log('markAllAsRead: Querying unread notifications for userId=$userId', 
            name: 'NotificationRepository');
    
    final batch = _firestore.batch();
    final snapshot = await _notifications
        .where('userId', isEqualTo: userId)
        .where('isRead', isEqualTo: false)
        .get();

    dev.log('markAllAsRead: Found ${snapshot.docs.length} unread notifications', 
            name: 'NotificationRepository');

    for (final doc in snapshot.docs) {
      batch.update(doc.reference, {'isRead': true});
    }

    await batch.commit();
    
    dev.log('markAllAsRead: Successfully updated ${snapshot.docs.length} notifications', 
            name: 'NotificationRepository');
  }

  @override
  Future<void> deleteNotification(String notificationId) async {
    await _notifications.doc(notificationId).delete();
  }

  @override
  Future<void> createNotification(AppNotification notification) async {
    // Don't notify yourself
    if (notification.userId == notification.actorId) {
      return;
    }

    // For friend requests/accepts: use deterministic ID to prevent duplicates
    // This prevents duplicate notifications when user cancels and resends
    final isFriendNotification = notification.type == NotificationType.friendRequest || 
                                   notification.type == NotificationType.friendAccepted;
    
    if (isFriendNotification) {
      // Use deterministic document ID: userId_actorId_type
      // This ensures only ONE notification exists per user-actor-type combination
      final docId = '${notification.userId}_${notification.actorId}_${notification.type.name}';
      
      dev.log('Creating friend notification with deterministic ID: $docId', 
              name: 'NotificationRepository');
      
      // Use set() with merge to upsert (update if exists, create if not)
      await _notifications.doc(docId).set(
        notification.toMap(),
        SetOptions(merge: false), // Replace entirely, no merge
      );
      
      dev.log('Friend notification created/updated successfully', 
              name: 'NotificationRepository');
      return;
    }

    // Check if similar notification exists recently (for other types)
    try {
      var query = _notifications
          .where('userId', isEqualTo: notification.userId)
          .where('actorId', isEqualTo: notification.actorId)
          .where('type', isEqualTo: notification.type.name);
      
      // Only filter by contentId if it's not null
      if (notification.contentId != null) {
        query = query.where('contentId', isEqualTo: notification.contentId);
      }
      
      final recentSnapshot = await query
          .where('createdAt',
              isGreaterThan: DateTime.now().subtract(const Duration(hours: 1)))
          .limit(1)
          .get();

      if (recentSnapshot.docs.isNotEmpty) {
        await recentSnapshot.docs.first.reference.update({
          'isRead': false,
          'createdAt': FieldValue.serverTimestamp(),
        });
      } else {
        await _notifications.add(notification.toMap());
      }
    } catch (_) {
      rethrow;
    }
  }

  @override
  Future<void> deleteNotificationsByCondition({
    required String userId,
    required String actorId,
    required NotificationType type,
  }) async {
    try {
      dev.log('deleteNotificationsByCondition: userId=$userId, actorId=$actorId, type=${type.name}', 
              name: 'NotificationRepository');
      
      final snapshot = await _notifications
          .where('userId', isEqualTo: userId)
          .where('actorId', isEqualTo: actorId)
          .where('type', isEqualTo: type.name)
          .get();

      dev.log('deleteNotificationsByCondition: Found ${snapshot.docs.length} notifications to delete', 
              name: 'NotificationRepository');

      if (snapshot.docs.isEmpty) return;

      final batch = _firestore.batch();
      for (final doc in snapshot.docs) {
        batch.delete(doc.reference);
      }
      await batch.commit();
      
      dev.log('deleteNotificationsByCondition: Successfully deleted ${snapshot.docs.length} notifications', 
              name: 'NotificationRepository');
    } catch (e) {
      dev.log('deleteNotificationsByCondition: Error - $e', name: 'NotificationRepository');
      // Ignore errors in cleanup
    }
  }
}
