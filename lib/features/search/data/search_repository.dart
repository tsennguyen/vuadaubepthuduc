import 'package:cloud_firestore/cloud_firestore.dart';

import '../../feed/data/post_model.dart';
import '../../feed/data/recipe_model.dart';
import '../../profile/domain/user_summary.dart';
import '../../../core/utils/tokenizer.dart';

enum IngredientFilterMode { any, all }

extension IngredientFilterModeX on IngredientFilterMode {
  bool get isAny => this == IngredientFilterMode.any;
}

enum SearchResultType { post, recipe, user }

class SearchResultItem {
  SearchResultItem({
    required this.type,
    this.post,
    this.recipe,
    this.user,
    this.score = 0,
    this.createdAt,
  });

  final SearchResultType type;
  final Post? post;
  final Recipe? recipe;
  final UserSummary? user;
  final double score;
  final DateTime? createdAt;
}

abstract class SearchRepository {
  Future<List<SearchResultItem>> searchByKeyword(String keyword);

  Future<List<SearchResultItem>> searchUnified({
    required List<String> tokens,
    int limit = 10,
  });

  Future<List<UserSummary>> searchUsers(String query, {int limit = 10});

  Future<List<Recipe>> searchRecipesByIngredients({
    required List<String> tokens,
    required IngredientFilterMode mode,
    DocumentSnapshot? lastDoc,
    int limit = 10,
  });
}

class FirestoreSearchRepository implements SearchRepository {
  FirestoreSearchRepository({FirebaseFirestore? firestore})
      : _firestore = firestore ?? FirebaseFirestore.instance;

  final FirebaseFirestore _firestore;

  @override
  Future<List<SearchResultItem>> searchByKeyword(String keyword) async {
    final tokens = tokenize(keyword);
    if (tokens.isEmpty) return [];

    final first = tokens.first;

    final postsSnap = await _firestore
        .collection('posts')
        .where('searchTokens', arrayContains: first)
        .orderBy('createdAt', descending: true)
        .limit(20)
        .get();

    final recipesSnap = await _firestore
        .collection('recipes')
        .where('searchTokens', arrayContains: first)
        .orderBy('createdAt', descending: true)
        .limit(20)
        .get();

    final items = <SearchResultItem>[
      ...postsSnap.docs.map((doc) {
        final post = Post.fromDoc(doc);
        return SearchResultItem(
          type: SearchResultType.post,
          post: post,
          createdAt: post.createdAt,
        );
      }),
      ...recipesSnap.docs.map((doc) {
        final recipe = Recipe.fromDoc(doc);
        return SearchResultItem(
          type: SearchResultType.recipe,
          recipe: recipe,
          createdAt: recipe.createdAt,
        );
      }),
    ];

    items.sort(
      (a, b) => (b.createdAt ?? DateTime.fromMillisecondsSinceEpoch(0))
          .compareTo(a.createdAt ?? DateTime.fromMillisecondsSinceEpoch(0)),
    );
    return items;
  }

  @override
  Future<List<SearchResultItem>> searchUnified({
    required List<String> tokens,
    int limit = 10,
  }) async {
    try {
      return await _searchUnifiedInternal(
        tokens: tokens,
        limit: limit,
        orderByCreatedAt: true,
      );
    } on FirebaseException catch (e) {
      if (e.code != 'failed-precondition') rethrow;
      return _searchUnifiedInternal(
        tokens: tokens,
        limit: limit,
        orderByCreatedAt: false,
      );
    }
  }

  Future<List<SearchResultItem>> _searchUnifiedInternal({
    required List<String> tokens,
    required int limit,
    required bool orderByCreatedAt,
  }) async {
    if (tokens.isEmpty) return [];

    Query<Map<String, dynamic>> postsQuery = _firestore
        .collection('posts')
        .where('searchTokens', arrayContainsAny: tokens);
    Query<Map<String, dynamic>> recipesQuery = _firestore
        .collection('recipes')
        .where('searchTokens', arrayContainsAny: tokens);

    if (orderByCreatedAt) {
      postsQuery = postsQuery.orderBy('createdAt', descending: true);
      recipesQuery = recipesQuery.orderBy('createdAt', descending: true);
    }

    postsQuery = postsQuery.limit(limit);
    recipesQuery = recipesQuery.limit(limit);

    final results = await Future.wait([
      postsQuery.get(),
      recipesQuery.get(),
    ]);

    final postDocs = results[0].docs;
    final recipeDocs = results[1].docs;

    final List<SearchResultItem> items = [];

    for (final doc in postDocs) {
      final data = doc.data();
      final post = Post.fromDoc(doc);
      final matchCount = _countMatches(
        tokens,
        (data['searchTokens'] as List<dynamic>?)
                ?.whereType<String>()
                .toList() ??
            post.searchTokens,
      );
      final score = _rankScore(
        matchCount: matchCount,
        likes: post.likesCount,
        comments: post.commentsCount,
        shares: post.sharesCount,
        createdAt: post.createdAt,
        rating: null,
      );
      items.add(SearchResultItem(
        type: SearchResultType.post,
        post: post,
        score: score,
      ));
    }

    for (final doc in recipeDocs) {
      final data = doc.data();
      final recipe = Recipe.fromDoc(doc);
      final recipeTokens = (data['searchTokens'] as List<dynamic>?)
          ?.whereType<String>()
          .toList();
      final matchCount = _countMatches(
        tokens,
        recipeTokens ??
            <String>{
              ...recipe.tags,
              ...recipe.ingredients,
            }.map(tokenize).expand((e) => e).toSet().toList(),
      );
      final score = _rankScore(
        matchCount: matchCount,
        likes: recipe.likesCount,
        comments: recipe.commentsCount,
        shares: recipe.sharesCount,
        createdAt: recipe.createdAt,
        rating: recipe.avgRating,
      );
      items.add(SearchResultItem(
        type: SearchResultType.recipe,
        recipe: recipe,
        score: score,
      ));
    }

    items.sort((a, b) => b.score.compareTo(a.score));
    return items.take(limit).toList();
  }

  @override
  Future<List<Recipe>> searchRecipesByIngredients({
    required List<String> tokens,
    required IngredientFilterMode mode,
    DocumentSnapshot? lastDoc,
    int limit = 10,
  }) async {
    try {
      return await _searchRecipesByIngredientsInternal(
        tokens: tokens,
        mode: mode,
        lastDoc: lastDoc,
        limit: limit,
        orderByCreatedAt: true,
      );
    } on FirebaseException catch (e) {
      if (e.code != 'failed-precondition') rethrow;
      return _searchRecipesByIngredientsInternal(
        tokens: tokens,
        mode: mode,
        lastDoc: lastDoc,
        limit: limit,
        orderByCreatedAt: false,
      );
    }
  }

  Future<List<Recipe>> _searchRecipesByIngredientsInternal({
    required List<String> tokens,
    required IngredientFilterMode mode,
    required DocumentSnapshot? lastDoc,
    required int limit,
    required bool orderByCreatedAt,
  }) async {
    if (tokens.isEmpty) return [];

    if (mode.isAny) {
      Query<Map<String, dynamic>> query = _firestore
          .collection('recipes')
          .where('ingredientsTokens', arrayContainsAny: tokens);
      if (orderByCreatedAt) {
        query = query.orderBy('createdAt', descending: true);
      }
      query = query.limit(limit);
      if (lastDoc != null) {
        query = query.startAfterDocument(lastDoc);
      }
      final snap = await query.get();
      return snap.docs.map(Recipe.fromDoc).toList();
    }

    // ALL mode: Firestore lacks array-contains-all, so query by first token then filter client-side.
    final firstToken = tokens.first;
    Query<Map<String, dynamic>> query = _firestore
        .collection('recipes')
        .where('ingredientsTokens', arrayContains: firstToken);
    if (orderByCreatedAt) {
      query = query.orderBy('createdAt', descending: true);
    }
    query = query.limit(limit * 3);
    if (lastDoc != null) {
      query = query.startAfterDocument(lastDoc);
    }
    final snap = await query.get();
    final filtered = snap.docs
        .map((doc) {
          final data = doc.data();
          final ingTokens = (data['ingredientsTokens'] as List<dynamic>?)
                  ?.whereType<String>()
                  .toList() ??
              const [];
          final containsAll =
              tokens.every((t) => ingTokens.contains(t.toLowerCase()));
          if (!containsAll) return null;
          return Recipe.fromDoc(doc);
        })
        .whereType<Recipe>()
        .toList();
    return filtered.take(limit).toList();
  }

  int _countMatches(List<String> queryTokens, List<String> targetTokens) {
    final targetSet = targetTokens.toSet();
    int count = 0;
    for (final token in queryTokens) {
      if (targetSet.contains(token)) count++;
    }
    return count;
  }

  double _rankScore({
    required int matchCount,
    required int likes,
    required int comments,
    required int shares,
    required DateTime? createdAt,
    required double? rating,
  }) {
    final freshnessDays =
        createdAt != null ? DateTime.now().difference(createdAt).inDays : 365;
    final freshnessScore = 1 / (1 + freshnessDays / 7);
    final engagement = likes * 0.1 + comments * 0.15 + shares * 0.2;
    final ratingScore = rating != null ? rating * 0.3 : 0;
    return matchCount * 3 + engagement + ratingScore + freshnessScore;
  }

  @override
  Future<List<UserSummary>> searchUsers(String query, {int limit = 10}) async {
    if (query.trim().isEmpty) return [];

    final searchQuery = normalizeQuery(query);
    
    // Fetch all active users (we'll filter client-side)
    // This is not ideal for scale, but Firestore doesn't support word search
    final usersSnap = await _firestore
        .collection('users')
        .orderBy('displayName')
        .limit(100) // Fetch up to 100 users for filtering
        .get();

    // Filter client-side: check if query matches any word in display name
    final results = usersSnap.docs
        .where((doc) {
          final data = doc.data();
          final disabled = data['disabled'] as bool? ?? false;
          if (disabled) return false;
          
          final displayName = normalizeQuery(data['displayName'] as String? ?? '');
          
          // Check if query matches:
          // 1. Full name contains query
          // 2. Any word starts with query
          // 3. Multiple consecutive words match
          
          if (displayName.contains(searchQuery)) return true;
          
          // Split name into words and check if any word starts with query
          final words = displayName.split(RegExp(r'[\s_]+'));
          for (var i = 0; i < words.length; i++) {
            // Check single word
            if (words[i].startsWith(searchQuery)) return true;
            
            // Check consecutive words (e.g., "thanh hiệp")
            if (i < words.length - 1) {
              final twoWords = '${words[i]} ${words[i + 1]}';
              if (twoWords.startsWith(searchQuery) || twoWords.contains(searchQuery)) {
                return true;
              }
            }
            
            // Check three consecutive words
            if (i < words.length - 2) {
              final threeWords = '${words[i]} ${words[i + 1]} ${words[i + 2]}';
              if (threeWords.startsWith(searchQuery) || threeWords.contains(searchQuery)) {
                return true;
              }
            }
          }
          
          return false;
        })
        .take(limit)
        .map((doc) {
          final data = doc.data();
          return UserSummary(
            uid: doc.id,
            displayName: data['displayName'] as String? ?? 'User',
            photoUrl: data['photoURL'] as String?,
          );
        })
        .toList();
    
    return results;
  }
}
