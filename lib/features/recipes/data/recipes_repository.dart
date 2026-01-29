import 'dart:async';

import 'package:cloud_firestore/cloud_firestore.dart';

class RecipeSummary {
  RecipeSummary({
    required this.id,
    required this.title,
    required this.authorId,
    required this.createdAt,
    this.photoUrl,
    this.avgRating,
    this.ratingsCount = 0,
    this.likesCount = 0,
    this.commentsCount = 0,
    this.cookTimeMinutes,
    this.difficulty,
    this.tags = const [],
  });

  final String id;
  final String title;
  final String authorId;
  final String? photoUrl;
  final double? avgRating;
  final int ratingsCount;
  final int likesCount;
  final int commentsCount;
  final int? cookTimeMinutes;
  final String? difficulty;
  final List<String> tags;
  final DateTime createdAt;
}

abstract class RecipesRepository {
  Future<List<RecipeSummary>> fetchRecipes({int limit = 20, DateTime? before});

  Stream<List<RecipeSummary>> watchRecipes({int limit = 50});
}

class RecipesRepositoryImpl implements RecipesRepository {
  RecipesRepositoryImpl({FirebaseFirestore? firestore})
      : _firestore = firestore ?? FirebaseFirestore.instance;

  final FirebaseFirestore _firestore;

  @override
  Future<List<RecipeSummary>> fetchRecipes(
      {int limit = 20, DateTime? before}) async {
    try {
      Query<Map<String, dynamic>> query = _firestore
          .collection('recipes')
          .where('hidden', isEqualTo: false)
          .orderBy('createdAt', descending: true)
          .limit(limit);

      if (before != null) {
        query =
            query.where('createdAt', isLessThan: Timestamp.fromDate(before));
      }

      final snap = await query.get();
      return snap.docs.map(_mapDocToSummary).toList();
    } on FirebaseException catch (e) {
      if (e.code == 'failed-precondition') {
        return _fallbackWithoutHiddenIndex(limit: limit, before: before);
      }
      rethrow;
    }
  }

  RecipeSummary _mapDocToSummary(DocumentSnapshot<Map<String, dynamic>> doc) {
    final data = doc.data() ?? {};
    final createdAt = (data['createdAt'] as Timestamp?)?.toDate() ??
        DateTime.fromMillisecondsSinceEpoch(0);
        
    final photoUrls =
        (data['photoURLs'] as List<dynamic>?)?.whereType<String>().toList();

    final cover = data['coverURL'] as String? ??
        data['coverUrl'] as String? ??
        data['photoURL'] as String? ??
        (photoUrls != null && photoUrls.isNotEmpty ? photoUrls.first : null);

    final finalPhoto = _fixUrl(cover);

    return RecipeSummary(
      id: doc.id,
      title: data['title'] as String? ?? '',
      authorId: data['authorId'] as String? ?? '',
      photoUrl: finalPhoto,
      avgRating: (data['avgRating'] as num?)?.toDouble(),
      ratingsCount: (data['ratingsCount'] as num?)?.toInt() ?? 0,
      likesCount: (data['likesCount'] as num?)?.toInt() ?? 0,
      commentsCount: (data['commentsCount'] as num?)?.toInt() ?? 0,
      cookTimeMinutes: (data['cookTimeMinutes'] as num?)?.toInt(),
      difficulty: data['difficulty'] as String?,
      tags: (data['tags'] as List<dynamic>?)?.whereType<String>().toList() ?? const [],
      createdAt: createdAt,
    );
  }

  String? _fixUrl(String? url) {
    if (url == null) return null;
    return url.replaceAll(
        'vuadaubepthuduc.appspot.com', 'vuadaubepthuduc.firebasestorage.app');
  }

  Future<List<RecipeSummary>> _fallbackWithoutHiddenIndex({
    required int limit,
    DateTime? before,
  }) async {
    Query<Map<String, dynamic>> query = _firestore
        .collection('recipes')
        .orderBy('createdAt', descending: true)
        .limit(limit * 2);

    if (before != null) {
      query = query.where('createdAt', isLessThan: Timestamp.fromDate(before));
    }

    final snap = await query.get();
    final filtered = snap.docs
        .where((doc) => (doc.data()['hidden'] as bool?) != true)
        .map(_mapDocToSummary)
        .toList();
    return filtered.take(limit).toList();
  }

  @override
  Stream<List<RecipeSummary>> watchRecipes({int limit = 50}) {
    Query<Map<String, dynamic>> query = _firestore
        .collection('recipes')
        .where('hidden', isEqualTo: false)
        .orderBy('createdAt', descending: true)
        .limit(limit);

    return query.snapshots().map(
          (snap) => snap.docs.map(_mapDocToSummary).toList(growable: false),
        );
  }
}
