import 'package:cloud_firestore/cloud_firestore.dart';

abstract class RecipeSocialRepository {
  Future<void> setRating({
    required String recipeId,
    required String userId,
    required int stars,
  });

  Future<int?> getUserRating({
    required String recipeId,
    required String userId,
  });

  Stream<int?> watchUserRating({
    required String recipeId,
    required String userId,
  });

  Future<void> toggleBookmark({
    required String recipeId,
    required String userId,
    required bool value,
  });

  Stream<bool> watchBookmark({
    required String recipeId,
    required String userId,
  });

  Stream<List<String>> watchBookmarkedIds(String userId);
}

class RecipeSocialRepositoryImpl implements RecipeSocialRepository {
  RecipeSocialRepositoryImpl({FirebaseFirestore? firestore})
      : _firestore = firestore ?? FirebaseFirestore.instance;

  final FirebaseFirestore _firestore;

  CollectionReference<Map<String, dynamic>> get _recipes =>
      _firestore.collection('recipes');

  CollectionReference<Map<String, dynamic>> _bookmarks(String userId) =>
      _firestore.collection('users').doc(userId).collection('bookmarks');

  @override
  Future<void> setRating({
    required String recipeId,
    required String userId,
    required int stars,
  }) async {
    if (stars < 1 || stars > 5) {
      throw ArgumentError('stars must be between 1 and 5');
    }
    final ref = _recipes.doc(recipeId).collection('ratings').doc(userId);
    final snap = await ref.get();
    final now = FieldValue.serverTimestamp();
    if (snap.exists) {
      await ref.update({
        'stars': stars,
        'updatedAt': now,
      });
    } else {
      await ref.set({
        'stars': stars,
        'createdAt': now,
        'updatedAt': now,
      });
    }
    
    await _recalculateRatings(recipeId);
  }

  Future<void> _recalculateRatings(String recipeId) async {
    final ratingsSnap =
        await _recipes.doc(recipeId).collection('ratings').get();
    
    if (ratingsSnap.docs.isEmpty) {
      await _recipes.doc(recipeId).update({
        'avgRating': 0.0,
        'ratingsCount': 0,
        'updatedAt': FieldValue.serverTimestamp(),
      });
      return;
    }

    double total = 0;
    for (var doc in ratingsSnap.docs) {
      total += (doc.data()['stars'] as num?)?.toDouble() ?? 0.0;
    }

    final avg = total / ratingsSnap.size;
    final roundedAvg = double.parse(avg.toStringAsFixed(1));

    await _recipes.doc(recipeId).update({
      'avgRating': roundedAvg,
      'ratingsCount': ratingsSnap.size,
      'updatedAt': FieldValue.serverTimestamp(),
    });
  }

  @override
  Future<int?> getUserRating({
    required String recipeId,
    required String userId,
  }) async {
    final snap =
        await _recipes.doc(recipeId).collection('ratings').doc(userId).get();
    if (!snap.exists) return null;
    return (snap.data()?['stars'] as num?)?.toInt();
  }

  @override
  Stream<int?> watchUserRating({
    required String recipeId,
    required String userId,
  }) {
    return _recipes
        .doc(recipeId)
        .collection('ratings')
        .doc(userId)
        .snapshots()
        .map((doc) => (doc.data()?['stars'] as num?)?.toInt());
  }

  @override
  Future<void> toggleBookmark({
    required String recipeId,
    required String userId,
    required bool value,
  }) async {
    final ref = _bookmarks(userId).doc(recipeId);
    if (value) {
      await ref.set({
        'recipeId': recipeId,
        'bookmarkedAt': FieldValue.serverTimestamp(),
      });
    } else {
      await ref.delete();
    }
  }

  @override
  Stream<bool> watchBookmark({
    required String recipeId,
    required String userId,
  }) {
    return _bookmarks(userId)
        .doc(recipeId)
        .snapshots()
        .map((doc) => doc.exists);
  }

  @override
  Stream<List<String>> watchBookmarkedIds(String userId) {
    return _bookmarks(userId).snapshots().map(
          (snap) =>
              snap.docs.map((doc) => doc.data()['recipeId'] as String? ?? doc.id).toList(),
        );
  }
}
