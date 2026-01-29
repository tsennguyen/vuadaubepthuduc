import 'package:cloud_firestore/cloud_firestore.dart';
import '../../../app/l10n.dart';

enum NotificationType {
  like,           // Ai da thich bai viet/cong thuc
  comment,        // Ai da binh luan
  commentReply,   // Ai da tra loi binh luan
  share,          // Ai da chia se
  save,           // Ai da luu cong thuc
  rating,         // Ai da danh gia cong thuc
  follow,         // Ai da follow
  friendRequest,  // Loi moi ket ban
  friendAccepted, // Chap nhan ket ban
}

class AppNotification {
  AppNotification({
    required this.id,
    required this.userId,
    required this.type,
    required this.actorId,
    required this.actorName,
    this.actorPhotoUrl,
    this.contentId,
    this.contentType,
    this.contentTitle,
    this.commentText,
    required this.isRead,
    required this.createdAt,
  });

  final String id;
  final String userId; // nguoi nhan notification
  final NotificationType type;
  final String actorId; // nguoi thuc hien action
  final String actorName;
  final String? actorPhotoUrl;
  final String? contentId; // post/recipe ID
  final String? contentType; // 'post' or 'recipe'
  final String? contentTitle;
  final String? commentText;
  final bool isRead;
  final DateTime createdAt;

  factory AppNotification.fromDoc(DocumentSnapshot<Map<String, dynamic>> doc) {
    final data = doc.data() ?? {};
    return AppNotification(
      id: doc.id,
      userId: data['userId'] as String? ?? '',
      type: _parseType(data['type'] as String?),
      actorId: data['actorId'] as String? ?? '',
      actorName: data['actorName'] as String? ?? '',
      actorPhotoUrl: data['actorPhotoUrl'] as String?,
      contentId: data['contentId'] as String?,
      contentType: data['contentType'] as String?,
      contentTitle: data['contentTitle'] as String?,
      commentText: data['commentText'] as String?,
      isRead: data['isRead'] as bool? ?? false,
      createdAt: (data['createdAt'] as Timestamp?)?.toDate() ?? DateTime.now(),
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'userId': userId,
      'type': type.name,
      'actorId': actorId,
      'actorName': actorName,
      'actorPhotoUrl': actorPhotoUrl,
      'contentId': contentId,
      'contentType': contentType,
      'contentTitle': contentTitle,
      'commentText': commentText,
      'isRead': isRead,
      'createdAt': FieldValue.serverTimestamp(),
    };
  }

  static NotificationType _parseType(String? type) {
    switch (type) {
      case 'like':
        return NotificationType.like;
      case 'comment':
        return NotificationType.comment;
      case 'commentReply':
        return NotificationType.commentReply;
      case 'share':
        return NotificationType.share;
      case 'save':
        return NotificationType.save;
      case 'rating':
        return NotificationType.rating;
      case 'follow':
        return NotificationType.follow;
      case 'friendRequest':
        return NotificationType.friendRequest;
      case 'friendAccepted':
        return NotificationType.friendAccepted;
      default:
        return NotificationType.like;
    }
  }

  String getMessage(S s) {
    final name = actorName.isNotEmpty ? actorName : s.user;
    switch (type) {
      case NotificationType.like:
        if (contentType == 'reel') {
          return '$name ${s.isVi ? 'đã thích thước phim của bạn' : 'liked your reel'}';
        }
        return '$name ${contentType == 'post' ? s.notificationLikedPost : s.notificationLikedRecipe}';
      case NotificationType.comment:
        if (contentType == 'reel') {
          return '$name ${s.isVi ? 'đã bình luận thước phim:' : 'commented on your reel:'} "${commentText ?? ''}"';
        }
        return '$name ${s.notificationCommented} "${commentText ?? ''}"';
      case NotificationType.commentReply:
        return '$name ${s.notificationReplied} "${commentText ?? ''}"';
      case NotificationType.share:
        if (contentType == 'reel') {
          return '$name ${s.isVi ? 'đã chia sẻ thước phim của bạn' : 'shared your reel'}';
        }
        return '$name ${contentType == 'post' ? s.notificationSharedPost : s.notificationSharedRecipe}';
      case NotificationType.save:
        if (contentType == 'reel') {
          return '$name ${s.isVi ? 'đã lưu thước phim của bạn' : 'saved your reel'}';
        }
        return '$name ${s.notificationSavedRecipe}';
      case NotificationType.rating:
        return '$name ${contentType == 'post' ? s.notificationRatedPost : s.notificationRatedRecipe}';
      case NotificationType.follow:
        return '$name ${s.notificationFollowed}';
      case NotificationType.friendRequest:
        return '$name ${s.notificationFriendRequest}';
      case NotificationType.friendAccepted:
        return '$name ${s.notificationFriendAccepted}';
    }
  }
}
