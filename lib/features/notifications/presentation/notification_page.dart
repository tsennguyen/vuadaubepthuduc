import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:firebase_auth/firebase_auth.dart';

import '../data/notification_model.dart';
import '../data/notification_repository.dart';

class NotificationPage extends StatefulWidget {
  const NotificationPage({super.key});

  @override
  State<NotificationPage> createState() => _NotificationPageState();
}

class _NotificationPageState extends State<NotificationPage> {
  late final NotificationRepository _repository;
  late Stream<List<AppNotification>> _stream;
  String? _userId;

  @override
  void initState() {
    super.initState();
    _repository = NotificationRepositoryImpl();
    _userId = FirebaseAuth.instance.currentUser?.uid;
    _stream = _userId != null
        ? _repository.watchUserNotifications(_userId!)
        : Stream<List<AppNotification>>.value(const []);
  }

  IconData _iconForType(NotificationType type) {
    switch (type) {
      case NotificationType.comment:
        return Icons.comment_outlined;
      case NotificationType.commentReply:
        return Icons.reply_outlined;
      case NotificationType.like:
        return Icons.favorite_border;
      case NotificationType.share:
        return Icons.share_outlined;
      case NotificationType.save:
        return Icons.bookmark_outline;
      case NotificationType.rating:
        return Icons.star_border;
      case NotificationType.friendRequest:
        return Icons.person_add_alt_1;
      case NotificationType.friendAccepted:
        return Icons.group;
    }
  }

  void _handleTap(BuildContext context, AppNotification noti) {
    switch (noti.contentType) {
      case 'post':
        if (noti.contentId != null) {
          context.push('/post/${noti.contentId}');
        }
        break;
      case 'recipe':
        if (noti.contentId != null) {
          context.push('/recipe/${noti.contentId}');
        }
        break;
      default:
        break;
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Thông báo'),
        actions: [
          IconButton(
            onPressed: _userId == null ? null : () => _repository.markAllAsRead(_userId!),
            icon: const Icon(Icons.done_all),
            tooltip: 'Đánh dấu đã đọc',
          ),
        ],
      ),
      body: StreamBuilder<List<AppNotification>>(
        stream: _stream,
        builder: (context, snapshot) {
          if (snapshot.hasError) {
            return _ErrorView(
              message: snapshot.error.toString(),
              onRetry: () => setState(() {
                _stream = _userId != null
                    ? _repository.watchUserNotifications(_userId!)
                    : Stream<List<AppNotification>>.value(const []);
              }),
            );
          }
          if (!snapshot.hasData) {
            return const Center(child: CircularProgressIndicator());
          }
          final items = snapshot.data!;
          if (items.isEmpty) return const _EmptyView();

          return ListView.separated(
            padding: const EdgeInsets.symmetric(vertical: 8),
            itemBuilder: (context, index) {
              final noti = items[index];
              final time = _formatTimeAgo(noti.createdAt);
               return ListTile(
                 onTap: () {
                  _repository.markAsRead(noti.id);
                  _handleTap(context, noti);
                },
                leading: Stack(
                  children: [
                    CircleAvatar(
                      child: Icon(_iconForType(noti.type)),
                    ),
                     if (!noti.isRead)
                      const Positioned(
                        right: -1,
                        top: -1,
                        child: CircleAvatar(
                          radius: 6,
                          backgroundColor: Colors.red,
                        ),
                      ),
                  ],
                ),
                 title: Text(noti.message),
                 subtitle: Column(
                   crossAxisAlignment: CrossAxisAlignment.start,
                   children: [
                     if (noti.contentTitle != null && noti.contentTitle!.isNotEmpty)
                       Text(
                         noti.contentTitle!,
                         style: Theme.of(context).textTheme.bodyMedium,
                         maxLines: 1,
                         overflow: TextOverflow.ellipsis,
                       ),
                     const SizedBox(height: 4),
                     Text(time, style: Theme.of(context).textTheme.bodySmall),
                   ],
                 ),
              );
            },
            separatorBuilder: (_, __) => const Divider(height: 1),
            itemCount: items.length,
          );
        },
      ),
    );
  }
}

class NotificationsBell extends StatelessWidget {
  const NotificationsBell({super.key, this.onTap});

  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    final userId = FirebaseAuth.instance.currentUser?.uid;
    final repo = NotificationRepositoryImpl();
    return StreamBuilder<int>(
      stream: userId == null
          ? const Stream<int>.empty()
          : repo.watchUserNotifications(userId).map(
              (items) => items.where((n) => !n.isRead).length,
            ),
      builder: (context, snapshot) {
        final count = snapshot.data ?? 0;
        final showBadge = count > 0;
        return Stack(
          clipBehavior: Clip.none,
          children: [
            IconButton(
              onPressed: onTap,
              icon: const Icon(Icons.notifications_none),
              tooltip: 'Thông báo',
            ),
            if (showBadge)
              Positioned(
                right: 6,
                top: 6,
                child: CircleAvatar(
                  radius: 8,
                  backgroundColor: Colors.red,
                  child: Text(
                    count > 9 ? '9+' : '$count',
                    style: const TextStyle(fontSize: 10, color: Colors.white),
                  ),
                ),
              ),
          ],
        );
      },
    );
  }
}

class _EmptyView extends StatelessWidget {
  const _EmptyView();

  @override
  Widget build(BuildContext context) {
    return const Center(
      child: Padding(
        padding: EdgeInsets.all(24),
        child: Text(
          'Chưa có thông báo.',
          textAlign: TextAlign.center,
        ),
      ),
    );
  }
}

class _ErrorView extends StatelessWidget {
  const _ErrorView({required this.message, required this.onRetry});

  final String message;
  final VoidCallback onRetry;

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(
              'Không tải được thông báo.\n$message',
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 12),
            FilledButton.icon(
              onPressed: onRetry,
              icon: const Icon(Icons.refresh),
              label: const Text('Thử lại'),
            ),
          ],
        ),
      ),
    );
  }
}

String _formatTimeAgo(DateTime dateTime) {
  final diff = DateTime.now().difference(dateTime);
  if (diff.inSeconds < 60) return '${diff.inSeconds}s trước';
  if (diff.inMinutes < 60) return '${diff.inMinutes}m trước';
  if (diff.inHours < 24) return '${diff.inHours}h trước';
  if (diff.inDays < 7) return '${diff.inDays}d trước';
  return '${dateTime.day}/${dateTime.month}';
}
