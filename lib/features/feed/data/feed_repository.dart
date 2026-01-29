import 'dart:async';

import 'package:cloud_firestore/cloud_firestore.dart';

import 'post_model.dart';
import 'recipe_model.dart';

enum FeedItemType { post, recipe }

class FeedItem {
  FeedItem({
    required this.id,
    required this.type,
    required this.title,
    required this.authorId,
    required this.createdAt,
    this.imageUrl,
    this.likesCount = 0,
    this.commentsCount = 0,
    this.avgRating,
  });

  final String id;
  final FeedItemType type;
  final String title;
  final String authorId;
  final String? imageUrl;
  final int likesCount;
  final int commentsCount;
  final double? avgRating;
  final DateTime createdAt;
}

abstract class FeedRepository {
  /// Get mixed feed (posts + recipes) sorted by createdAt desc.
  Future<List<FeedItem>> fetchHomeFeed({int limit = 20, DateTime? before});

  /// Get feed from following users only
  Future<List<FeedItem>> fetchFollowingFeed({
    required List<String> followingIds,
    int limit = 20,
    DateTime? before,
  });

  Future<List<Post>> fetchPosts({Post? lastPost, int limit = 10});

  Future<List<Recipe>> fetchRecipes({Recipe? lastRecipe, int limit = 10});

  /// Realtime mixed feed (posts + recipes), newest first.
  Stream<List<FeedItem>> watchHomeFeed({int limit = 30});
}

class FeedRepositoryImpl implements FeedRepository {
  FeedRepositoryImpl({FirebaseFirestore? firestore})
      : _firestore = firestore ?? FirebaseFirestore.instance;

  final FirebaseFirestore _firestore;

  @override
  Future<List<FeedItem>> fetchHomeFeed(
      {int limit = 20, DateTime? before}) async {
    final perTypeLimit = (limit / 2).ceil();
    try {
      var postQuery = _firestore
          .collection('posts')
          .where('hidden', isEqualTo: false)
          .orderBy('createdAt', descending: true)
          .limit(perTypeLimit);
      var recipeQuery = _firestore
          .collection('recipes')
          .where('hidden', isEqualTo: false)
          .orderBy('createdAt', descending: true)
          .limit(perTypeLimit);

      if (before != null) {
        final ts = Timestamp.fromDate(before);
        postQuery = postQuery.where('createdAt', isLessThan: ts);
        recipeQuery = recipeQuery.where('createdAt', isLessThan: ts);
      }

      final results = await Future.wait([
        postQuery.get(),
        recipeQuery.get(),
      ]);

      final posts = results[0].docs.map(_mapPostToFeedItem);
      final recipes = results[1].docs.map(_mapRecipeToFeedItem);
      final merged = [...posts, ...recipes]
        ..sort((a, b) => b.createdAt.compareTo(a.createdAt));
      return merged.take(limit).toList();
    } on FirebaseException catch (e) {
      if (e.code == 'failed-precondition') {
        return _fetchHomeFeedWithoutHiddenIndex(
          limit: limit,
          before: before,
        );
      }
      rethrow;
    }
  }

  @override
  Future<List<FeedItem>> fetchFollowingFeed({
    required List<String> followingIds,
    int limit = 20,
    DateTime? before,
  }) async {
    // If no following, return empty
    if (followingIds.isEmpty) return const [];

    final perTypeLimit = (limit / 2).ceil();
    
    try {
      // Firestore 'in' operator max 30 items
      const chunkSize = 30;
      final chunks = <List<String>>[];
      for (var i = 0; i < followingIds.length; i += chunkSize) {
        final end = (i + chunkSize < followingIds.length) 
            ? i + chunkSize 
            : followingIds.length;
        chunks.add(followingIds.sublist(i, end));
      }

      final allPosts = <FeedItem>[];
      final allRecipes = <FeedItem>[];

      // Query each chunk
      for (final chunk in chunks) {
        var postQuery = _firestore
            .collection('posts')
            .where('hidden', isEqualTo: false)
            .where('authorId', whereIn: chunk)
            .orderBy('createdAt', descending: true)
            .limit(perTypeLimit);
        
        var recipeQuery = _firestore
            .collection('recipes')
            .where('hidden', isEqualTo: false)
            .where('authorId', whereIn: chunk)
            .orderBy('createdAt', descending: true)
            .limit(perTypeLimit);

        if (before != null) {
          final ts = Timestamp.fromDate(before);
          postQuery = postQuery.where('createdAt', isLessThan: ts);
          recipeQuery = recipeQuery.where('createdAt', isLessThan: ts);
        }

        final results = await Future.wait([
          postQuery.get(),
          recipeQuery.get(),
        ]);

        allPosts.addAll(results[0].docs.map(_mapPostToFeedItem));
        allRecipes.addAll(results[1].docs.map(_mapRecipeToFeedItem));
      }

      // Merge and sort
      final merged = [...allPosts, ...allRecipes]
        ..sort((a, b) => b.createdAt.compareTo(a.createdAt));
      return merged.take(limit).toList();
    } on FirebaseException catch (e) {
      if (e.code == 'failed-precondition') {
        // Fallback without index
        return _fetchFollowingFeedFallback(
          followingIds: followingIds,
          limit: limit,
          before: before,
        );
      }
      rethrow;
    }
  }

  Future<List<FeedItem>> _fetchFollowingFeedFallback({
    required List<String> followingIds,
    required int limit,
    DateTime? before,
  }) async {
    if (followingIds.isEmpty) return const [];

    final fetchLimit = limit * 2;
    const chunkSize = 30;
    final chunks = <List<String>>[];
    
    for (var i = 0; i < followingIds.length; i += chunkSize) {
      final end = (i + chunkSize < followingIds.length) 
          ? i + chunkSize 
          : followingIds.length;
      chunks.add(followingIds.sublist(i, end));
    }

    final allPosts = <FeedItem>[];
    final allRecipes = <FeedItem>[];

    for (final chunk in chunks) {
      var postQuery = _firestore
          .collection('posts')
          .where('authorId', whereIn: chunk)
          .orderBy('createdAt', descending: true)
          .limit(fetchLimit);
      
      var recipeQuery = _firestore
          .collection('recipes')
          .where('authorId', whereIn: chunk)
          .orderBy('createdAt', descending: true)
          .limit(fetchLimit);

      if (before != null) {
        final ts = Timestamp.fromDate(before);
        postQuery = postQuery.where('createdAt', isLessThan: ts);
        recipeQuery = recipeQuery.where('createdAt', isLessThan: ts);
      }

      final results = await Future.wait([
        postQuery.get(),
        recipeQuery.get(),
      ]);

      final posts = results[0]
          .docs
          .where((doc) => (doc.data()['hidden'] as bool?) != true)
          .map(_mapPostToFeedItem);
      final recipes = results[1]
          .docs
          .where((doc) => (doc.data()['hidden'] as bool?) != true)
          .map(_mapRecipeToFeedItem);
      
      allPosts.addAll(posts);
      allRecipes.addAll(recipes);
    }

    final merged = [...allPosts, ...allRecipes]
      ..sort((a, b) => b.createdAt.compareTo(a.createdAt));
    return merged.take(limit).toList();
  }

  @override
  Future<List<Post>> fetchPosts({Post? lastPost, int limit = 10}) async {
    try {
      Query<Map<String, dynamic>> query = _firestore
          .collection('posts')
          .where('hidden', isEqualTo: false)
          .orderBy('createdAt', descending: true)
          .limit(limit);

      if (lastPost?.snapshot != null) {
        query = query.startAfterDocument(lastPost!.snapshot!);
      } else if (lastPost?.createdAt != null) {
        query = query.startAfter([lastPost!.createdAt]);
      }

      final snap = await query.get();
      return snap.docs.map(Post.fromDoc).toList();
    } on FirebaseException catch (e) {
      if (e.code == 'failed-precondition') {
        return _fallbackPosts(limit: limit, lastPost: lastPost);
      }
      rethrow;
    }
  }

  @override
  Future<List<Recipe>> fetchRecipes(
      {Recipe? lastRecipe, int limit = 10}) async {
    try {
      Query<Map<String, dynamic>> query = _firestore
          .collection('recipes')
          .where('hidden', isEqualTo: false)
          .orderBy('createdAt', descending: true)
          .limit(limit);

      if (lastRecipe?.snapshot != null) {
        query = query.startAfterDocument(lastRecipe!.snapshot!);
      } else if (lastRecipe?.createdAt != null) {
        query = query.startAfter([lastRecipe!.createdAt]);
      }

      final snap = await query.get();
      return snap.docs.map(Recipe.fromDoc).toList();
    } on FirebaseException catch (e) {
      if (e.code == 'failed-precondition') {
        return _fallbackRecipes(limit: limit, lastRecipe: lastRecipe);
      }
      rethrow;
    }
  }

  FeedItem _mapPostToFeedItem(DocumentSnapshot<Map<String, dynamic>> doc) {
    final data = doc.data() ?? {};
    final createdAt = _timestampToDate(data['createdAt'] as Timestamp?);
    final photoUrls =
        (data['photoURLs'] as List<dynamic>?)?.whereType<String>().toList() ??
            const [];
    return FeedItem(
      id: doc.id,
      type: FeedItemType.post,
      title: data['title'] as String? ?? '',
      authorId: data['authorId'] as String? ?? '',
      imageUrl: _fixUrl(photoUrls.isNotEmpty ? photoUrls.first : null),
      likesCount: (data['likesCount'] as num?)?.toInt() ?? 0,
      commentsCount: (data['commentsCount'] as num?)?.toInt() ?? 0,
      createdAt: createdAt,
    );
  }

  FeedItem _mapRecipeToFeedItem(DocumentSnapshot<Map<String, dynamic>> doc) {
    final data = doc.data() ?? {};
    final createdAt = _timestampToDate(data['createdAt'] as Timestamp?);
    final photoUrls =
        (data['photoURLs'] as List<dynamic>?)?.whereType<String>().toList() ??
            const [];
    
    // Check all possible image fields
    final cover = data['coverURL'] as String? ??
        data['coverUrl'] as String? ??
        data['photoURL'] as String? ??
        (photoUrls.isNotEmpty ? photoUrls.first : null);

    final photo = _fixUrl(cover);
    
    return FeedItem(
      id: doc.id,
      type: FeedItemType.recipe,
      title: data['title'] as String? ?? '',
      authorId: data['authorId'] as String? ?? '',
      imageUrl: photo,
      likesCount: (data['likesCount'] as num?)?.toInt() ?? 0,
      commentsCount: (data['commentsCount'] as num?)?.toInt() ?? 0,
      avgRating: (data['avgRating'] as num?)?.toDouble(),
      createdAt: createdAt,
    );
  }

  DateTime _timestampToDate(Timestamp? ts) {
    return ts?.toDate() ?? DateTime.fromMillisecondsSinceEpoch(0);
  }

  String? _fixUrl(String? url) {
    if (url == null) return null;
    return url.replaceAll(
        'vuadaubepthuduc.appspot.com', 'vuadaubepthuduc.firebasestorage.app');
  }

  Future<List<FeedItem>> _fetchHomeFeedWithoutHiddenIndex({
    required int limit,
    DateTime? before,
  }) async {
    final fetchLimit = limit * 2;
    var postQuery = _firestore
        .collection('posts')
        .orderBy('createdAt', descending: true)
        .limit(fetchLimit);
    var recipeQuery = _firestore
        .collection('recipes')
        .orderBy('createdAt', descending: true)
        .limit(fetchLimit);

    if (before != null) {
      final ts = Timestamp.fromDate(before);
      postQuery = postQuery.where('createdAt', isLessThan: ts);
      recipeQuery = recipeQuery.where('createdAt', isLessThan: ts);
    }

    final results = await Future.wait([
      postQuery.get(),
      recipeQuery.get(),
    ]);

    final posts = results[0]
        .docs
        .where((doc) => (doc.data()['hidden'] as bool?) != true)
        .map(_mapPostToFeedItem);
    final recipes = results[1]
        .docs
        .where((doc) => (doc.data()['hidden'] as bool?) != true)
        .map(_mapRecipeToFeedItem);
    final merged = [...posts, ...recipes]
      ..sort((a, b) => b.createdAt.compareTo(a.createdAt));
    return merged.take(limit).toList();
  }

  Future<List<Post>> _fallbackPosts({int limit = 10, Post? lastPost}) async {
    Query<Map<String, dynamic>> query = _firestore
        .collection('posts')
        .orderBy('createdAt', descending: true)
        .limit(limit * 2);

    if (lastPost?.snapshot != null) {
      query = query.startAfterDocument(lastPost!.snapshot!);
    } else if (lastPost?.createdAt != null) {
      query = query.startAfter([lastPost!.createdAt]);
    }

    final snap = await query.get();
    final filtered = snap.docs
        .where((doc) => (doc.data()['hidden'] as bool?) != true)
        .map(Post.fromDoc)
        .toList();
    return filtered.take(limit).toList();
  }

  Future<List<Recipe>> _fallbackRecipes(
      {int limit = 10, Recipe? lastRecipe}) async {
    Query<Map<String, dynamic>> query = _firestore
        .collection('recipes')
        .orderBy('createdAt', descending: true)
        .limit(limit * 2);

    if (lastRecipe?.snapshot != null) {
      query = query.startAfterDocument(lastRecipe!.snapshot!);
    } else if (lastRecipe?.createdAt != null) {
      query = query.startAfter([lastRecipe!.createdAt]);
    }

    final snap = await query.get();
    final filtered = snap.docs
        .where((doc) => (doc.data()['hidden'] as bool?) != true)
        .map(Recipe.fromDoc)
        .toList();
    return filtered.take(limit).toList();
  }

  @override
  Stream<List<FeedItem>> watchHomeFeed({int limit = 30}) {
    final perTypeLimit = (limit / 2).ceil();

    Query<Map<String, dynamic>> postQuery = _firestore
        .collection('posts')
        .where('hidden', isEqualTo: false)
        .orderBy('createdAt', descending: true)
        .limit(perTypeLimit);
    Query<Map<String, dynamic>> recipeQuery = _firestore
        .collection('recipes')
        .where('hidden', isEqualTo: false)
        .orderBy('createdAt', descending: true)
        .limit(perTypeLimit);

    late final StreamController<List<FeedItem>> controller;
    StreamSubscription<QuerySnapshot<Map<String, dynamic>>>? postSub;
    StreamSubscription<QuerySnapshot<Map<String, dynamic>>>? recipeSub;

    var latestPosts = <FeedItem>[];
    var latestRecipes = <FeedItem>[];

    void emit() {
      final merged = [...latestPosts, ...latestRecipes]
        ..sort((a, b) => b.createdAt.compareTo(a.createdAt));
      controller.add(merged.take(limit).toList(growable: false));
    }

    controller = StreamController<List<FeedItem>>(
      onListen: () {
        postSub = postQuery.snapshots().listen(
          (snap) {
            latestPosts = snap.docs.map(_mapPostToFeedItem).toList();
            emit();
          },
          onError: controller.addError,
        );
        recipeSub = recipeQuery.snapshots().listen(
          (snap) {
            latestRecipes = snap.docs.map(_mapRecipeToFeedItem).toList();
            emit();
          },
          onError: controller.addError,
        );
      },
      onCancel: () async {
        await postSub?.cancel();
        await recipeSub?.cancel();
      },
    );

    return controller.stream;
  }
}
