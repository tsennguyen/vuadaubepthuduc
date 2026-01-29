import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

final reelInteractionRepositoryProvider =
    Provider<ReelInteractionRepository>((ref) {
  return ReelInteractionRepository(
    firestore: FirebaseFirestore.instance,
    auth: FirebaseAuth.instance,
  );
});

class ReelInteractionRepository {
  ReelInteractionRepository({
    required FirebaseFirestore firestore,
    required FirebaseAuth auth,
  })  : _firestore = firestore,
        _auth = auth;

  final FirebaseFirestore _firestore;
  final FirebaseAuth _auth;

  CollectionReference<Map<String, dynamic>> get _reelsCollection =>
      _firestore.collection('reels');

  /// Check if current user has liked a reel
  Stream<bool> hasLiked(String reelId) {
    final user = _auth.currentUser;
    if (user == null) return Stream.value(false);

    return _reelsCollection
        .doc(reelId)
        .collection('likes')
        .doc(user.uid)
        .snapshots()
        .map((doc) => doc.exists);
  }

  /// Toggle like on a reel
  Future<void> toggleLike(String reelId) async {
    final user = _auth.currentUser;
    if (user == null) throw Exception('User not authenticated');

    final likeRef =
        _reelsCollection.doc(reelId).collection('likes').doc(user.uid);
    final likeDoc = await likeRef.get();

    final batch = _firestore.batch();

    if (likeDoc.exists) {
      // Unlike
      batch.delete(likeRef);
      batch.update(_reelsCollection.doc(reelId), {
        'likesCount': FieldValue.increment(-1),
      });
    } else {
      // Like
      batch.set(likeRef, {
        'userId': user.uid,
        'createdAt': FieldValue.serverTimestamp(),
      });
      batch.update(_reelsCollection.doc(reelId), {
        'likesCount': FieldValue.increment(1),
      });

      // Create notification for reel author
      final reelDoc = await _reelsCollection.doc(reelId).get();
      if (reelDoc.exists) {
        final reelData = reelDoc.data()!;
        final authorId = reelData['authorId'] as String?;
        final reelTitle = reelData['title'] as String? ?? 'Reel';

        if (authorId != null && authorId != user.uid) {
          final actorDoc =
              await _firestore.collection('users').doc(user.uid).get();
          final actorData = actorDoc.data() ?? {};
          final actorName = (actorData['displayName'] ??
              actorData['fullName'] ??
              'User') as String;
          final actorPhotoUrl = actorData['photoURL'] as String?;

          batch.set(
            _firestore.collection('notifications').doc(),
            {
              'userId': authorId,
              'type': 'like',
              'actorId': user.uid,
              'actorName': actorName,
              'actorPhotoUrl': actorPhotoUrl,
              'contentId': reelId,
              'contentType': 'reel',
              'contentTitle': reelTitle,
              'isRead': false,
              'createdAt': FieldValue.serverTimestamp(),
            },
          );
        }
      }
    }

    await batch.commit();
  }

  /// Check if current user has saved a reel
  Stream<bool> hasSaved(String reelId) {
    final user = _auth.currentUser;
    if (user == null) return Stream.value(false);

    return _firestore
        .collection('users')
        .doc(user.uid)
        .collection('bookmarks')
        .doc(reelId)
        .snapshots()
        .map((doc) => doc.exists);
  }

  /// Toggle save on a reel
  Future<void> toggleSave(String reelId) async {
    final user = _auth.currentUser;
    if (user == null) throw Exception('User not authenticated');

    final saveRef = _firestore
        .collection('users')
        .doc(user.uid)
        .collection('bookmarks')
        .doc(reelId);
    final saveDoc = await saveRef.get();

    if (saveDoc.exists) {
      // Unsave
      await saveRef.delete();
    } else {
      // Save
      await saveRef.set({
        'targetId': reelId,
        'targetType': 'reel',
        'bookmarkedAt': FieldValue.serverTimestamp(),
      });
    }
  }

  /// Get saved reels for current user
  Stream<List<String>> getSavedReelIds() {
    final user = _auth.currentUser;
    if (user == null) return Stream.value([]);

    return _firestore
        .collection('users')
        .doc(user.uid)
        .collection('bookmarks')
        .where('targetType', isEqualTo: 'reel')
        .orderBy('bookmarkedAt', descending: true)
        .snapshots()
        .map((snapshot) {
      return snapshot.docs.map((doc) => doc.id).toList();
    });
  }

  /// Add a comment to a reel
  Future<void> addComment(
    String reelId,
    String text, {
    String? replyTo,
    String? replyToName,
  }) async {
    final user = _auth.currentUser;
    if (user == null) throw Exception('User not authenticated');

    final batch = _firestore.batch();

    // Add comment
    final commentRef =
        _reelsCollection.doc(reelId).collection('comments').doc();
    batch.set(commentRef, {
      'userId': user.uid,
      'text': text,
      'createdAt': FieldValue.serverTimestamp(),
      'replyTo': replyTo,
      'replyToName': replyToName,
    });

    // Increment comment count
    batch.update(_reelsCollection.doc(reelId), {
      'commentsCount': FieldValue.increment(1),
    });

    // Create notification for reel author
    final reelDoc = await _reelsCollection.doc(reelId).get();
    if (reelDoc.exists) {
      final reelData = reelDoc.data()!;
      final authorId = reelData['authorId'] as String?;
      final reelTitle = reelData['title'] as String? ?? 'Reel';

      if (authorId != null && authorId != user.uid) {
        final actorDoc =
            await _firestore.collection('users').doc(user.uid).get();
        final actorData = actorDoc.data() ?? {};
        final actorName = (actorData['displayName'] ??
            actorData['fullName'] ??
            'User') as String;
        final actorPhotoUrl = actorData['photoURL'] as String?;

        final isReply = replyTo != null;

        batch.set(
          _firestore.collection('notifications').doc(),
          {
            'userId': authorId,
            'type': isReply ? 'comment_reply' : 'comment',
            'actorId': user.uid,
            'actorName': actorName,
            'actorPhotoUrl': actorPhotoUrl,
            'contentId': reelId,
            'contentType': 'reel',
            'contentTitle': reelTitle,
            'commentText': text,
            'isRead': false,
            'createdAt': FieldValue.serverTimestamp(),
          },
        );

        // If it's a reply, also notify the original commenter if they are not the reel author
        if (isReply) {
          try {
            final parentCommentDoc = await _reelsCollection
                .doc(reelId)
                .collection('comments')
                .doc(replyTo)
                .get();
            if (parentCommentDoc.exists) {
              final parentCommentData = parentCommentDoc.data()!;
              final originalCommenterId =
                  parentCommentData['userId'] as String?;
              if (originalCommenterId != null &&
                  originalCommenterId != user.uid &&
                  originalCommenterId != authorId) {
                batch.set(
                  _firestore.collection('notifications').doc(),
                  {
                    'userId': originalCommenterId,
                    'type': 'comment_reply',
                    'actorId': user.uid,
                    'actorName': actorName,
                    'actorPhotoUrl': actorPhotoUrl,
                    'contentId': reelId,
                    'contentType': 'reel',
                    'contentTitle': reelTitle,
                    'commentText': text,
                    'isRead': false,
                    'createdAt': FieldValue.serverTimestamp(),
                  },
                );
              }
            }
          } catch (e) {
            debugPrint('Error sending reply notification: $e');
          }
        }
      }
    }

    await batch.commit();
  }

  /// Delete a comment from a reel
  Future<void> deleteComment(String reelId, String commentId) async {
    final user = _auth.currentUser;
    if (user == null) throw Exception('User not authenticated');

    final commentRef =
        _reelsCollection.doc(reelId).collection('comments').doc(commentId);
    final commentDoc = await commentRef.get();

    if (!commentDoc.exists) return;

    if (commentDoc.data()?['userId'] != user.uid) {
      throw Exception('Not authorized to delete this comment');
    }

    final batch = _firestore.batch();
    batch.delete(commentRef);

    // Decrement comment count
    batch.update(_reelsCollection.doc(reelId), {
      'commentsCount': FieldValue.increment(-1),
    });

    await batch.commit();
  }

  /// Get comments for a reel
  Stream<List<Map<String, dynamic>>> getComments(String reelId) {
    return _reelsCollection
        .doc(reelId)
        .collection('comments')
        .orderBy('createdAt', descending: true)
        .limit(50)
        .snapshots()
        .map((snapshot) {
      return snapshot.docs.map((doc) {
        final data = doc.data();
        return {
          'id': doc.id,
          ...data,
        };
      }).toList();
    });
  }
}
