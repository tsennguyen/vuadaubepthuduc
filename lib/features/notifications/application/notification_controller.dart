import 'dart:developer' as dev;

import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../data/notification_model.dart';
import '../data/notification_repository.dart';

final notificationRepositoryProvider = Provider<NotificationRepository>((ref) {
  return NotificationRepositoryImpl();
});

final notificationListProvider =
    StreamProvider.autoDispose<List<AppNotification>>((ref) {
  final repo = ref.watch(notificationRepositoryProvider);
  final userId = FirebaseAuth.instance.currentUser?.uid;

  if (userId == null) {
    return Stream.value([]);
  }

  return repo.watchUserNotifications(userId);
});

final unreadCountProvider = StreamProvider.autoDispose<int>((ref) {
  final repo = ref.watch(notificationRepositoryProvider);
  final userId = FirebaseAuth.instance.currentUser?.uid;

  if (userId == null) {
    return Stream.value(0);
  }

  return repo.watchUnreadCount(userId);
});

class NotificationController extends StateNotifier<AsyncValue<void>> {
  NotificationController({
    required this.repository,
    required this.userId,
  }) : super(const AsyncValue.data(null));

  final NotificationRepository repository;
  final String userId;

  Future<void> markAsRead(String notificationId) async {
    if (!mounted) return;
    state = const AsyncValue.loading();
    final result = await AsyncValue.guard(() async {
      await repository.markAsRead(notificationId);
    });
    if (mounted) {
      state = result;
    }
  }

  Future<void> markAllAsRead() async {
    if (!mounted) return;
    
    dev.log('markAllAsRead: Starting for userId=$userId', name: 'NotificationController');
    
    state = const AsyncValue.loading();
    final result = await AsyncValue.guard(() async {
      await repository.markAllAsRead(userId);
      dev.log('markAllAsRead: Successfully marked all as read', name: 'NotificationController');
    });
    
    if (result.hasError) {
      dev.log('markAllAsRead: Error occurred - ${result.error}', name: 'NotificationController');
    }
    
    if (mounted) {
      state = result;
    }
  }

  Future<void> deleteNotification(String notificationId) async {
    // Fire-and-forget: delete immediately without waiting for mounted check
    // This ensures deletion happens even during page transitions
    repository.deleteNotification(notificationId).catchError((e) {
      dev.log('Error deleting notification: $e', name: 'NotificationController');
    });
  }
}

final notificationControllerProvider =
    StateNotifierProvider.autoDispose<NotificationController, AsyncValue<void>>(
        (ref) {
  final repo = ref.watch(notificationRepositoryProvider);
  final userId = FirebaseAuth.instance.currentUser?.uid ?? '';

  return NotificationController(
    repository: repo,
    userId: userId,
  );
});
