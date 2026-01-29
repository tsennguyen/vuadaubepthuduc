import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import '../../../shared/widgets/modern_ui_components.dart';
import '../../../core/utils/cleanup_duplicate_notifications.dart';
import '../application/notification_controller.dart';
import '../data/notification_model.dart';
import '../../profile/application/user_cache_controller.dart';
import '../../../app/l10n.dart';
import '../../../app/language_controller.dart';

class NotificationsPage extends ConsumerStatefulWidget {
  const NotificationsPage({super.key});

  @override
  ConsumerState<NotificationsPage> createState() => _NotificationsPageState();
}

class _NotificationsPageState extends ConsumerState<NotificationsPage> {
  bool _hasCleanedUp = false;

  @override
  void initState() {
    super.initState();
    // Run cleanup once on page load
    _runCleanup();
  }

  Future<void> _runCleanup() async {
    if (_hasCleanedUp) return;
    _hasCleanedUp = true;
    
    final userId = FirebaseAuth.instance.currentUser?.uid;
    if (userId != null) {
      try {
        await NotificationCleanupHelper.cleanupDuplicateFriendRequests(userId);
      } catch (_) {
        // Ignore cleanup errors
      }
    }
  }


  @override
  Widget build(BuildContext context) {
    final s = S(ref.watch(localeProvider));
    final notificationsAsync = ref.watch(notificationListProvider);
    final controller = ref.read(notificationControllerProvider.notifier);

    return Scaffold(
      appBar: AppBar(
        title: Text(s.notifications),
        actions: [
          IconButton(
            icon: const Icon(Icons.check),
            tooltip: s.markAllRead,
            onPressed: () => _markAllAsRead(context),
          ),
        ],
      ),
      body: notificationsAsync.when(
        data: (notifications) {
          if (notifications.isEmpty) {
            return Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(
                    Icons.notifications_none,
                    size: 80,
                    color: Colors.grey.shade300,
                  ),
                  const SizedBox(height: 16),
                  Text(
                    s.noNotifications,
                    style: TextStyle(
                      fontSize: 18,
                      color: Colors.grey.shade600,
                    ),
                  ),
                ],
              ),
            );
          }

          // Preload actor data for all notifications
          final actorIds = notifications
              .map((n) => n.actorId)
              .where((id) => id.isNotEmpty)
              .toSet();
          if (actorIds.isNotEmpty) {
            WidgetsBinding.instance.addPostFrameCallback((_) {
              ref.read(userCacheProvider.notifier).preload(actorIds);
            });
          }

          return ListView.builder(
            itemCount: notifications.length,
            itemBuilder: (context, index) {
              final notification = notifications[index];
              return _NotificationCard(
                notification: notification,
                s: s,
                onTap: () {
                  // Mark as read without awaiting
                  if (!notification.isRead) {
                    controller.markAsRead(notification.id);
                  }
                  // Navigate to content
                  _navigateToContent(context, notification);
                },
                onDelete: () => controller.deleteNotification(notification.id),
              );
            },
          );
        },
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (error, stack) => Center(
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              const Icon(Icons.error, color: Colors.red, size: 48),
              const SizedBox(height: 16),
              Text('${s.error}: $error'),
              const SizedBox(height: 16),
              ModernButton(
                onPressed: () => ref.invalidate(notificationListProvider),
                child: Text(s.retry),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Future<void> _markAllAsRead(BuildContext context) async {
    final s = S(ref.read(localeProvider));
    final controller = ref.read(notificationControllerProvider.notifier);
    
    try {
      // Show loading indicator
      final scaffoldMessenger = ScaffoldMessenger.of(context);
      
      await controller.markAllAsRead();
      
      // Show success message
      if (context.mounted) {
        scaffoldMessenger.showSnackBar(
          SnackBar(
            content: Text(s.markAllReadSuccess),
            duration: const Duration(seconds: 2),
            backgroundColor: Colors.green,
          ),
        );
      }
    } catch (e) {
      // Show error message
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('${s.error}: $e'),
            duration: const Duration(seconds: 3),
            backgroundColor: Colors.red,
          ),
        );
      }
    }
  }

  void _navigateToContent(BuildContext context, AppNotification notification) {
    // Navigate based on notification type
    switch (notification.type) {
      case NotificationType.like:
      case NotificationType.follow:
      case NotificationType.friendRequest:
      case NotificationType.friendAccepted:
        // Navigate to profile
        if (notification.actorId.isNotEmpty) {
          context.push('/profile/${notification.actorId}');
        }
        break;
      case NotificationType.comment:
      case NotificationType.commentReply:
      case NotificationType.share:
      case NotificationType.save:
      case NotificationType.rating:
        // Navigate to post/recipe/reel detail
        if (notification.contentId != null && notification.contentType != null) {
          final String path;
          if (notification.contentType == 'post') {
            path = '/post/${notification.contentId}';
          } else if (notification.contentType == 'reel') {
            path = '/reels?id=${notification.contentId}';
          } else {
            path = '/recipe/${notification.contentId}';
          }
          context.push(path);
        }
        break;
    }
  }
}

class _NotificationCard extends ConsumerWidget {
  const _NotificationCard({
    required this.notification,
    required this.s,
    required this.onTap,
    required this.onDelete,
  });

  final AppNotification notification;
  final S s;
  final VoidCallback onTap;
  final VoidCallback onDelete;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final scheme = Theme.of(context).colorScheme;
    final isDark = scheme.brightness == Brightness.dark;
    
    // Watch user cache for live data
    final userCache = ref.watch(userCacheProvider);
    final actor = userCache[notification.actorId];
    final liveName = actor?.displayName ?? notification.actorName;
    final livePhoto = actor?.photoUrl ?? notification.actorPhotoUrl;

    return Dismissible(
      key: Key(notification.id),
      direction: DismissDirection.endToStart,
      background: Container(
        color: Colors.red,
        alignment: Alignment.centerRight,
        padding: const EdgeInsets.only(right: 16),
        child: const Icon(Icons.delete, color: Colors.white),
      ),
      onDismissed: (_) => onDelete(),
      child: InkWell(
        onTap: onTap,
        child: Container(
          decoration: BoxDecoration(
            color: notification.isRead
                ? Colors.transparent
                : scheme.primary.withOpacity(isDark ? 0.15 : 0.1),
            border: Border(
              bottom: BorderSide(
                color: scheme.outlineVariant.withOpacity(0.4),
                width: 0.5,
              ),
            ),
          ),
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Unread indicator dot
              if (!notification.isRead)
                Container(
                  margin: const EdgeInsets.only(top: 18, right: 8),
                  width: 8,
                  height: 8,
                  decoration: BoxDecoration(
                    color: scheme.primary,
                    shape: BoxShape.circle,
                  ),
                )
              else
                const SizedBox(width: 16), // Maintain alignment

              GestureDetector(
                onTap: () {
                  if (notification.actorId.isNotEmpty) {
                    context.push('/profile/${notification.actorId}');
                  }
                },
                child: GradientAvatar(
                  imageUrl: livePhoto ?? '',
                  radius: 24,
                  child: (livePhoto == null || livePhoto.isEmpty)
                      ? Text(
                          liveName.isNotEmpty
                              ? liveName[0].toUpperCase()
                              : '?',
                          style: const TextStyle(
                            fontWeight: FontWeight.bold,
                            fontSize: 18,
                          ),
                        )
                      : null,
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    RichText(
                      text: TextSpan(
                        style: TextStyle(
                          fontSize: 14,
                          color: notification.isRead 
                              ? scheme.onSurface.withOpacity(0.8) 
                              : scheme.onSurface,
                          fontFamily: scheme.brightness == Brightness.dark ? null : 'Lexend',
                        ),
                        children: [
                          WidgetSpan(
                            alignment: PlaceholderAlignment.middle,
                            child: GestureDetector(
                              onTap: () {
                                if (notification.actorId.isNotEmpty) {
                                  context.push('/profile/${notification.actorId}');
                                }
                              },
                              child: Text(
                                liveName.isNotEmpty ? liveName : s.user,
                                style: TextStyle(
                                  fontWeight: notification.isRead 
                                      ? FontWeight.w600 
                                      : FontWeight.w800,
                                ),
                              ),
                            ),
                          ),
                          const TextSpan(text: ' '),
                          TextSpan(
                            text: _getActionMessage(notification, s),
                            style: TextStyle(
                              fontWeight: notification.isRead
                                  ? FontWeight.normal
                                  : FontWeight.w500,
                            ),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      _formatTime(notification.createdAt, s),
                      style: TextStyle(
                        fontSize: 12,
                        color: scheme.onSurfaceVariant.withOpacity(0.6),
                      ),
                    ),
                    if (notification.contentTitle != null) ...[
                      const SizedBox(height: 4),
                      Text(
                        notification.contentTitle!,
                        style: TextStyle(
                          fontSize: 13,
                          color: notification.isRead 
                              ? scheme.primary.withOpacity(0.7) 
                              : scheme.primary,
                          fontWeight: FontWeight.w600,
                        ),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ],
                  ],
                ),
              ),
              const SizedBox(width: 8),
              Opacity(
                opacity: notification.isRead ? 0.6 : 1.0,
                child: _getIcon(notification.type),
              ),
            ],
          ),
        ),
      ),
    );
  }

  String _getActionMessage(AppNotification notification, S s) {
    switch (notification.type) {
      case NotificationType.like:
        if (notification.contentType == 'reel') {
          return s.isVi ? 'đã thích thước phim của bạn' : 'liked your reel';
        }
        return notification.contentType == 'post'
            ? s.notificationLikedPost
            : s.notificationLikedRecipe;
      case NotificationType.comment:
        if (notification.contentType == 'reel') {
          return s.isVi
              ? 'đã bình luận thước phim: "${notification.commentText ?? ''}"'
              : 'commented on your reel: "${notification.commentText ?? ''}"';
        }
        return '${s.notificationCommented} "${notification.commentText ?? ''}"';
      case NotificationType.commentReply:
        return '${s.notificationReplied} "${notification.commentText ?? ''}"';
      case NotificationType.share:
        if (notification.contentType == 'reel') {
          return s.isVi ? 'đã chia sẻ thước phim của bạn' : 'shared your reel';
        }
        return notification.contentType == 'post'
            ? s.notificationSharedPost
            : s.notificationSharedRecipe;
      case NotificationType.save:
        if (notification.contentType == 'reel') {
          return s.isVi ? 'đã lưu thước phim của bạn' : 'saved your reel';
        }
        return s.notificationSavedRecipe;
      case NotificationType.rating:
        return notification.contentType == 'post'
            ? s.notificationRatedPost
            : s.notificationRatedRecipe;
      case NotificationType.follow:
        return s.notificationFollowed;
      case NotificationType.friendRequest:
        return s.notificationFriendRequest;
      case NotificationType.friendAccepted:
        return s.notificationFriendAccepted;
    }
  }

  Widget _getIcon(NotificationType type) {
    IconData iconData;
    Color color;

    switch (type) {
      case NotificationType.like:
        iconData = Icons.favorite;
        color = Colors.red;
        break;
      case NotificationType.comment:
        iconData = Icons.comment;
        color = Colors.blue;
        break;
      case NotificationType.commentReply:
        iconData = Icons.reply;
        color = Colors.blueGrey;
        break;
      case NotificationType.share:
        iconData = Icons.share;
        color = Colors.green;
        break;
      case NotificationType.save:
        iconData = Icons.bookmark;
        color = Colors.amber;
        break;
      case NotificationType.rating:
        iconData = Icons.star;
        color = Colors.orange;
        break;
      case NotificationType.follow:
        iconData = Icons.person_add_outlined;
        color = Colors.indigo;
        break;
      case NotificationType.friendRequest:
        iconData = Icons.person_add;
        color = Colors.purple;
        break;
      case NotificationType.friendAccepted:
        iconData = Icons.group;
        color = Colors.teal;
        break;
    }

    return Icon(iconData, color: color, size: 20);
  }

  String _formatTime(DateTime time, S s) {
    final now = DateTime.now();
    final diff = now.difference(time);

    if (diff.inDays > 7) {
      return '${time.day}/${time.month}/${time.year}';
    } else if (diff.inDays > 0) {
      return '${diff.inDays} ${s.daysAgo}';
    } else if (diff.inHours > 0) {
      return '${diff.inHours} ${s.hoursAgo}';
    } else if (diff.inMinutes > 0) {
      return '${diff.inMinutes} ${s.minutesAgo}';
    } else {
      return s.justNow;
    }
  }
}
