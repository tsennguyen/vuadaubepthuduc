import 'package:cloud_firestore/cloud_firestore.dart';

import 'comment_model.dart';

enum ContentType { post, recipe }

abstract class PostInteractionRepository {
  Future<void> toggleLike({
    required ContentType type,
    required String contentId,
    required String userId,
  });

  Stream<List<Comment>> watchComments({
    required ContentType type,
    required String contentId,
  });

  Future<void> addComment({
    required ContentType type,
    required String contentId,
    required String userId,
    required String content,
    String? imageUrl,
  });

  Future<void> addShare({
    required ContentType type,
    required String contentId,
    required String userId,
  });

  Future<bool> isLiked({
    required ContentType type,
    required String contentId,
    required String userId,
  });
}

class PostInteractionRepositoryImpl implements PostInteractionRepository {
  PostInteractionRepositoryImpl({FirebaseFirestore? firestore})
      : _firestore = firestore ?? FirebaseFirestore.instance;

  final FirebaseFirestore _firestore;

  CollectionReference<Map<String, dynamic>> _collection(ContentType type) {
    return _firestore.collection(
      type == ContentType.post ? 'posts' : 'recipes',
    );
  }

  @override
  Future<void> toggleLike({
    required ContentType type,
    required String contentId,
    required String userId,
  }) async {
    final doc =
        _collection(type).doc(contentId).collection('reactions').doc(userId);
    final snap = await doc.get();
    if (snap.exists) {
      await doc.delete();
    } else {
      await doc.set({
        'type': 'like',
        'createdAt': FieldValue.serverTimestamp(),
      });
    }
  }

  @override
  Stream<List<Comment>> watchComments({
    required ContentType type,
    required String contentId,
  }) {
    return _collection(type)
        .doc(contentId)
        .collection('comments')
        // .orderBy('createdAt', descending: false) // Temporarily disabled for debugging
        .snapshots()
        .map((snap) => snap.docs.map(Comment.fromDoc).toList());
  }

  @override
  Future<void> addComment({
    required ContentType type,
    required String contentId,
    required String userId,
    required String content,
    String? imageUrl,
  }) async {
    await _collection(type)
        .doc(contentId)
        .collection('comments')
        .add({
      'authorId': userId,
      'content': content,
      'imageUrl': imageUrl,
      'createdAt': FieldValue.serverTimestamp(),
      'likes': [], // For storing user IDs who liked
      'likesCount': 0, // For quick count
    });
  }

  @override
  Future<void> addShare({
    required ContentType type,
    required String contentId,
    required String userId,
  }) async {
    await _collection(type)
        .doc(contentId)
        .collection('shares')
        .doc(userId)
        .set({'createdAt': FieldValue.serverTimestamp()});
  }

  @override
  Future<bool> isLiked({
    required ContentType type,
    required String contentId,
    required String userId,
  }) async {
    final doc =
        _collection(type).doc(contentId).collection('reactions').doc(userId);
    final snap = await doc.get();
    return snap.exists;
  }
}
