import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/foundation.dart';

import '../../notifications/application/notification_service.dart';

/// Repository to manage post/recipe interactions (likes, comments, ratings)
class InteractionRepository {
  InteractionRepository({
    FirebaseFirestore? firestore,
    FirebaseAuth? auth,
    NotificationService? notificationService,
  })  : _firestore = firestore ?? FirebaseFirestore.instance,
        _auth = auth ?? FirebaseAuth.instance,
        _notificationService =
            notificationService ?? NotificationService();

  final FirebaseFirestore _firestore;
  final FirebaseAuth _auth;
  final NotificationService _notificationService;

  String? get _currentUserId => _auth.currentUser?.uid;

  // ==================== LIKES ====================

  /// Toggle like on a post
  Future<void> togglePostLike(String postId) async {
    final uid = _currentUserId;
    if (uid == null) throw Exception('User not authenticated');

    final postRef = _firestore.collection('posts').doc(postId);
    final likeRef = postRef.collection('likes').doc(uid);

    final likeDoc = await likeRef.get();

    if (likeDoc.exists) {
      await Future.wait([
        likeRef.delete(),
        postRef.update({'likesCount': FieldValue.increment(-1)}),
      ]);
    } else {
      Map<String, dynamic>? postData;
      try {
        final snapshot = await postRef.get();
        postData = snapshot.data();
      } catch (_) {
        postData = null;
      }

      await Future.wait([
        likeRef.set({
          'userId': uid,
          'createdAt': FieldValue.serverTimestamp(),
        }),
        postRef.update({'likesCount': FieldValue.increment(1)}),
      ]);

      final authorId = postData?['authorId'] as String?;
      final title = postData?['title'] as String?;
      if (authorId != null && authorId.isNotEmpty) {
        _notificationService
            .notifyLike(
              contentId: postId,
              contentType: 'post',
              contentAuthorId: authorId,
              contentTitle: title,
            )
            .catchError((_) {});
      }
    }
  }

  /// Toggle like on a recipe
  Future<void> toggleRecipeLike(String recipeId) async {
    final uid = _currentUserId;
    if (uid == null) throw Exception('User not authenticated');

    debugPrint('?? [InteractionRepo] toggleRecipeLike - Recipe: $recipeId, User: $uid');

    final recipeRef = _firestore.collection('recipes').doc(recipeId);
    final likeRef = recipeRef.collection('likes').doc(uid);

    final likeDoc = await likeRef.get();

    if (likeDoc.exists) {
      debugPrint('?? [InteractionRepo] Unliking recipe $recipeId');
      await Future.wait([
        likeRef.delete(),
        recipeRef.update({'likesCount': FieldValue.increment(-1)}),
      ]);
      debugPrint('?? [InteractionRepo] Unlike completed');
    } else {
      debugPrint('?? [InteractionRepo] Liking recipe $recipeId');

      Map<String, dynamic>? recipeData;
      try {
        final snapshot = await recipeRef.get();
        recipeData = snapshot.data();
      } catch (_) {
        recipeData = null;
      }

      await Future.wait([
        likeRef.set({
          'userId': uid,
          'createdAt': FieldValue.serverTimestamp(),
        }),
        recipeRef.update({'likesCount': FieldValue.increment(1)}),
      ]);
      debugPrint('?? [InteractionRepo] Like completed');

      final authorId = recipeData?['authorId'] as String?;
      final title = recipeData?['title'] as String?;
      if (authorId != null && authorId.isNotEmpty) {
        _notificationService
            .notifyLike(
              contentId: recipeId,
              contentType: 'recipe',
              contentAuthorId: authorId,
              contentTitle: title,
            )
            .catchError((_) {});
      }
    }
  }

  /// Stream of user's like status for a post
  Stream<bool> watchPostLikeStatus(String postId) {
    final uid = _currentUserId;
    if (uid == null) return Stream.value(false);

    return _firestore
        .collection('posts')
        .doc(postId)
        .collection('likes')
        .doc(uid)
        .snapshots()
        .map((doc) => doc.exists);
  }

  /// Stream of user's like status for a recipe
  Stream<bool> watchRecipeLikeStatus(String recipeId) {
    final uid = _currentUserId;
    if (uid == null) return Stream.value(false);

    return _firestore
        .collection('recipes')
        .doc(recipeId)
        .collection('likes')
        .doc(uid)
        .snapshots()
        .map((doc) => doc.exists);
  }

  // ==================== COMMENTS ====================

  /// Add comment to a post
  Future<String> addPostComment({
    required String postId,
    required String text,
  }) async {
    final uid = _currentUserId;
    if (uid == null) throw Exception('User not authenticated');

    final commentRef = _firestore
        .collection('posts')
        .doc(postId)
        .collection('comments')
        .doc();

    await Future.wait([
      commentRef.set({
        'id': commentRef.id,
        'postId': postId,
        'userId': uid,
        'text': text,
        'createdAt': FieldValue.serverTimestamp(),
      }),
      _firestore.collection('posts').doc(postId).update({
        'commentsCount': FieldValue.increment(1),
      }),
    ]);

    return commentRef.id;
  }

  /// Add comment to a recipe
  Future<String> addRecipeComment({
    required String recipeId,
    required String text,
  }) async {
    final uid = _currentUserId;
    if (uid == null) throw Exception('User not authenticated');

    final commentRef = _firestore
        .collection('recipes')
        .doc(recipeId)
        .collection('comments')
        .doc();

    await Future.wait([
      commentRef.set({
        'id': commentRef.id,
        'recipeId': recipeId,
        'userId': uid,
        'text': text,
        'createdAt': FieldValue.serverTimestamp(),
      }),
      _firestore.collection('recipes').doc(recipeId).update({
        'commentsCount': FieldValue.increment(1),
      }),
    ]);

    return commentRef.id;
  }

  /// Get comments for a post
  Stream<List<Map<String, dynamic>>> watchPostComments(String postId) {
    return _firestore
        .collection('posts')
        .doc(postId)
        .collection('comments')
        .orderBy('createdAt', descending: true)
        .limit(50)
        .snapshots()
        .map((snapshot) => snapshot.docs.map((doc) => doc.data()).toList());
  }

  /// Get comments for a recipe
  Stream<List<Map<String, dynamic>>> watchRecipeComments(String recipeId) {
    return _firestore
        .collection('recipes')
        .doc(recipeId)
        .collection('comments')
        .orderBy('createdAt', descending: true)
        .limit(50)
        .snapshots()
        .map((snapshot) => snapshot.docs.map((doc) => doc.data()).toList());
  }

  // ==================== RATINGS (for recipes) ====================

  /// Add or update recipe rating
  Future<void> rateRecipe({
    required String recipeId,
    required double rating,
  }) async {
    final uid = _currentUserId;
    if (uid == null) throw Exception('User not authenticated');

    if (rating < 1.0 || rating > 5.0) {
      throw Exception('Rating must be between 1.0 and 5.0');
    }

    final ratingRef = _firestore
        .collection('recipes')
        .doc(recipeId)
        .collection('ratings')
        .doc(uid);

    final existingRating = await ratingRef.get();
    
    await ratingRef.set({
      'userId': uid,
      'rating': rating,
      'createdAt': existingRating.exists
          ? existingRating.data()!['createdAt']
          : FieldValue.serverTimestamp(),
      'updatedAt': FieldValue.serverTimestamp(),
    });

    await _recalculateRecipeRating(recipeId);
  }

  /// Recalculate recipe average rating
  Future<void> _recalculateRecipeRating(String recipeId) async {
    final ratingsSnapshot = await _firestore
        .collection('recipes')
        .doc(recipeId)
        .collection('ratings')
        .get();

    if (ratingsSnapshot.docs.isEmpty) {
      await _firestore.collection('recipes').doc(recipeId).update({
        'rating': 0.0,
        'ratingsCount': 0,
      });
      return;
    }

    double sum = 0;
    for (final doc in ratingsSnapshot.docs) {
      sum += (doc.data()['rating'] as num?)?.toDouble() ?? 0.0;
    }

    final average = sum / ratingsSnapshot.docs.length;

    await _firestore.collection('recipes').doc(recipeId).update({
      'rating': double.parse(average.toStringAsFixed(1)),
      'ratingsCount': ratingsSnapshot.docs.length,
    });
  }

  /// Get user's rating for a recipe
  Future<double?> getUserRecipeRating(String recipeId) async {
    final uid = _currentUserId;
    if (uid == null) return null;

    final ratingDoc = await _firestore
        .collection('recipes')
        .doc(recipeId)
        .collection('ratings')
        .doc(uid)
        .get();

    if (!ratingDoc.exists) return null;
    return (ratingDoc.data()?['rating'] as num?)?.toDouble();
  }

  // ==================== SHARES ====================

  /// Increment share count for a post
  Future<void> sharePost(String postId) async {
    await _firestore.collection('posts').doc(postId).update({
      'sharesCount': FieldValue.increment(1),
    });
  }

  /// Increment share count for a recipe
  Future<void> shareRecipe(String recipeId) async {
    await _firestore.collection('recipes').doc(recipeId).update({
      'sharesCount': FieldValue.increment(1),
    });
  }
}
