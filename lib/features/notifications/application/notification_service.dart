import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import '../data/notification_model.dart';
import '../data/notification_repository.dart';

/// Service to handle automatic notification creation for user interactions
class NotificationService {
  NotificationService({
    NotificationRepository? notificationRepository,
    FirebaseFirestore? firestore,
    FirebaseAuth? auth,
  })  : _notificationRepo =
            notificationRepository ?? NotificationRepositoryImpl(),
        _firestore = firestore ?? FirebaseFirestore.instance,
        _auth = auth ?? FirebaseAuth.instance;

  final NotificationRepository _notificationRepo;
  final FirebaseFirestore _firestore;
  final FirebaseAuth _auth;

  /// Notify when someone likes a post/recipe
  Future<void> notifyLike({
    required String contentId,
    required String contentType, // 'post' or 'recipe'
    required String contentAuthorId,
    String? contentTitle,
  }) async {
    final currentUser = _auth.currentUser;
    if (currentUser == null || currentUser.uid == contentAuthorId) return;

    final userName = await _getUserName(currentUser.uid);
    final userPhoto = currentUser.photoURL;

    await _notificationRepo.createNotification(
      AppNotification(
        id: '', // Will be auto-generated
        userId: contentAuthorId,
        type: NotificationType.like,
        actorId: currentUser.uid,
        actorName: userName,
        actorPhotoUrl: userPhoto,
        contentId: contentId,
        contentType: contentType,
        contentTitle: contentTitle,
        isRead: false,
        createdAt: DateTime.now(), // Will be replaced by serverTimestamp in toMap
      ),
    );
  }

  /// Notify when someone comments on a post/recipe
  Future<void> notifyComment({
    required String contentId,
    required String contentType,
    required String contentAuthorId,
    required String commentText,
    String? contentTitle,
  }) async {
    final currentUser = _auth.currentUser;
    if (currentUser == null || currentUser.uid == contentAuthorId) return;

    final userName = await _getUserName(currentUser.uid);
    final userPhoto = currentUser.photoURL;

    await _notificationRepo.createNotification(
      AppNotification(
        id: '',
        userId: contentAuthorId,
        type: NotificationType.comment,
        actorId: currentUser.uid,
        actorName: userName,
        actorPhotoUrl: userPhoto,
        contentId: contentId,
        contentType: contentType,
        contentTitle: contentTitle,
        commentText: commentText.length > 50
            ? '${commentText.substring(0, 50)}...'
            : commentText,
        isRead: false,
        createdAt: DateTime.now(),
      ),
    );
  }

  /// Notify when someone shares a post/recipe
  Future<void> notifyShare({
    required String contentId,
    required String contentType,
    required String contentAuthorId,
    String? contentTitle,
  }) async {
    final currentUser = _auth.currentUser;
    if (currentUser == null || currentUser.uid == contentAuthorId) return;

    final userName = await _getUserName(currentUser.uid);
    final userPhoto = currentUser.photoURL;

    await _notificationRepo.createNotification(
      AppNotification(
        id: '',
        userId: contentAuthorId,
        type: NotificationType.share,
        actorId: currentUser.uid,
        actorName: userName,
        actorPhotoUrl: userPhoto,
        contentId: contentId,
        contentType: contentType,
        contentTitle: contentTitle,
        isRead: false,
        createdAt: DateTime.now(),
      ),
    );
  }

  /// Notify when someone saves a recipe
  Future<void> notifySave({
    required String recipeId,
    required String recipeAuthorId,
    String? recipeTitle,
  }) async {
    final currentUser = _auth.currentUser;
    if (currentUser == null || currentUser.uid == recipeAuthorId) return;

    final userName = await _getUserName(currentUser.uid);
    final userPhoto = currentUser.photoURL;

    await _notificationRepo.createNotification(
      AppNotification(
        id: '',
        userId: recipeAuthorId,
        type: NotificationType.save,
        actorId: currentUser.uid,
        actorName: userName,
        actorPhotoUrl: userPhoto,
        contentId: recipeId,
        contentType: 'recipe',
        contentTitle: recipeTitle,
        isRead: false,
        createdAt: DateTime.now(),
      ),
    );
  }

  /// Notify when someone rates a recipe
  Future<void> notifyRating({
    required String recipeId,
    required String recipeAuthorId,
    String? recipeTitle,
  }) async {
    final currentUser = _auth.currentUser;
    if (currentUser == null || currentUser.uid == recipeAuthorId) return;

    final userName = await _getUserName(currentUser.uid);
    final userPhoto = currentUser.photoURL;

    await _notificationRepo.createNotification(
      AppNotification(
        id: '',
        userId: recipeAuthorId,
        type: NotificationType.rating,
        actorId: currentUser.uid,
        actorName: userName,
        actorPhotoUrl: userPhoto,
        contentId: recipeId,
        contentType: 'recipe',
        contentTitle: recipeTitle,
        isRead: false,
        createdAt: DateTime.now(),
      ),
    );
  }

  /// Notify when someone replies to a comment
  Future<void> notifyCommentReply({
    required String contentId,
    required String contentType,
    required String commentAuthorId,
    String? contentTitle,
    String? replyText,
  }) async {
    final currentUser = _auth.currentUser;
    if (currentUser == null || currentUser.uid == commentAuthorId) return;

    final userName = await _getUserName(currentUser.uid);
    final userPhoto = currentUser.photoURL;

    await _notificationRepo.createNotification(
      AppNotification(
        id: '',
        userId: commentAuthorId,
        type: NotificationType.commentReply,
        actorId: currentUser.uid,
        actorName: userName,
        actorPhotoUrl: userPhoto,
        contentId: contentId,
        contentType: contentType,
        contentTitle: contentTitle,
        commentText: replyText != null && replyText.length > 50
            ? '${replyText.substring(0, 50)}...'
            : replyText,
        isRead: false,
        createdAt: DateTime.now(),
      ),
    );
  }

  /// Notify when someone follows you
  Future<void> notifyFollow({required String targetUserId}) async {
    final currentUser = _auth.currentUser;
    if (currentUser == null || currentUser.uid == targetUserId) return;

    final userName = await _getUserName(currentUser.uid);
    final userPhoto = currentUser.photoURL;

    await _notificationRepo.createNotification(
      AppNotification(
        id: '',
        userId: targetUserId,
        type: NotificationType.follow,
        actorId: currentUser.uid,
        actorName: userName,
        actorPhotoUrl: userPhoto,
        isRead: false,
        createdAt: DateTime.now(),
      ),
    );
  }

  /// Notify when someone sends a friend request
  Future<void> notifyFriendRequest({required String recipientId}) async {
    final currentUser = _auth.currentUser;
    if (currentUser == null || currentUser.uid == recipientId) return;

    final userName = await _getUserName(currentUser.uid);
    final userPhoto = currentUser.photoURL;

    await _notificationRepo.createNotification(
      AppNotification(
        id: '',
        userId: recipientId,
        type: NotificationType.friendRequest,
        actorId: currentUser.uid,
        actorName: userName,
        actorPhotoUrl: userPhoto,
        isRead: false,
        createdAt: DateTime.now(),
      ),
    );
  }

  /// Delete friend request notification when request is cancelled
  Future<void> deleteFriendRequestNotification({
    required String targetUserId,
    required String requesterId,
  }) async {
    await _notificationRepo.deleteNotificationsByCondition(
      userId: targetUserId,
      actorId: requesterId,
      type: NotificationType.friendRequest,
    );
  }

  /// Notify when someone accepts a friend request
  Future<void> notifyFriendAccepted({required String recipientId}) async {
    final currentUser = _auth.currentUser;
    if (currentUser == null || currentUser.uid == recipientId) return;

    final userName = await _getUserName(currentUser.uid);
    final userPhoto = currentUser.photoURL;

    await _notificationRepo.createNotification(
      AppNotification(
        id: '',
        userId: recipientId,
        type: NotificationType.friendAccepted,
        actorId: currentUser.uid,
        actorName: userName,
        actorPhotoUrl: userPhoto,
        isRead: false,
        createdAt: DateTime.now(),
      ),
    );
  }

  /// Get user's display name from Firestore
  Future<String> _getUserName(String userId) async {
    try {
      final doc = await _firestore.collection('users').doc(userId).get();
      final data = doc.data();
      return (data?['displayName'] ?? data?['fullName']) as String? ?? 'Người dùng';
    } catch (e) {
      return 'Người dùng';
    }
  }

  /// Get content info (author and title) for notification
  Future<Map<String, String?>> getContentInfo({
    required String contentId,
    required String contentType,
  }) async {
    try {
      final doc = await _firestore
          .collection(contentType == 'post' ? 'posts' : 'recipes')
          .doc(contentId)
          .get();

      final data = doc.data();
      return {
        'authorId': data?['authorId'] as String?,
        'title': data?['title'] as String?,
      };
    } catch (e) {
      return {'authorId': null, 'title': null};
    }
  }
}
