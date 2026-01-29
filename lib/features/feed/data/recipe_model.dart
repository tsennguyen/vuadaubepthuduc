import 'package:cloud_firestore/cloud_firestore.dart';

class Recipe {
  Recipe({
    required this.id,
    required this.authorId,
    required this.title,
    required this.description,
    required this.coverUrl,
    required this.photoURLs,
    required this.steps,
    required this.ingredients,
    required this.tags,
    required this.cookTimeMinutes,
    required this.difficulty,
    required this.likesCount,
    required this.commentsCount,
    required this.ratingsCount,
    required this.avgRating,
    required this.sharesCount,
    required this.createdAt,
    this.calories,
    this.protein,
    this.carbs,
    this.fat,
    this.updatedAt,
    this.snapshot,
  });

  final String id;
  final String authorId;
  final String title;
  final String description;
  final String coverUrl;
  final List<String> photoURLs;
  final List<String> steps;
  final List<String> ingredients;
  final List<String> tags;
  final int? cookTimeMinutes;
  final String? difficulty;
  final int likesCount;
  final int commentsCount;
  final int ratingsCount;
  final double avgRating;
  final int sharesCount;
  final DateTime? createdAt;
  // Nutrition values per serving
  final int? calories;
  final int? protein;
  final int? carbs;
  final int? fat;
  final DateTime? updatedAt;
  final DocumentSnapshot<Map<String, dynamic>>? snapshot;

  factory Recipe.fromDoc(DocumentSnapshot<Map<String, dynamic>> doc) {
    final data = doc.data() ?? {};
    final Timestamp? createdTs = data['createdAt'] as Timestamp?;
    final Timestamp? updatedTs = data['updatedAt'] as Timestamp?;
    final singlePhoto = _fixUrl(data['photoURL'] as String?);
    final multiPhotos = (data['photoURLs'] as List<dynamic>?)
        ?.whereType<String>()
        .map(_fixUrl)
        .whereType<String>()
        .toList();
    final cover = data['coverURL'] as String? ??
        data['coverUrl'] as String? ??
        (multiPhotos != null && multiPhotos.isNotEmpty
            ? multiPhotos.first
            : singlePhoto);
    return Recipe(
      id: doc.id,
      authorId: data['authorId'] as String? ?? '',
      title: data['title'] as String? ?? '',
      description: data['description'] as String? ?? '',
      coverUrl: cover ?? '',
      photoURLs: (multiPhotos != null && multiPhotos.isNotEmpty)
          ? multiPhotos
          : [
              if (singlePhoto != null && singlePhoto.isNotEmpty) singlePhoto,
            ],
      steps: (data['steps'] as List<dynamic>?)?.whereType<String>().toList() ??
          const [],
      ingredients: (data['ingredients'] as List<dynamic>?)
              ?.whereType<String>()
              .toList() ??
          (data['ingredientsTokens'] as List<dynamic>?)
              ?.whereType<String>()
              .toList() ??
          const [],
      tags: (data['tags'] as List<dynamic>?)?.whereType<String>().toList() ??
          const [],
      cookTimeMinutes: (data['cookTimeMinutes'] as num?)?.toInt(),
      difficulty: data['difficulty'] as String?,
      likesCount: (data['likesCount'] as num?)?.toInt() ?? 0,
      commentsCount: (data['commentsCount'] as num?)?.toInt() ?? 0,
      ratingsCount: (data['ratingsCount'] as num?)?.toInt() ?? 0,
      avgRating: (data['avgRating'] as num?)?.toDouble() ?? 0.0,
      sharesCount: (data['sharesCount'] as num?)?.toInt() ?? 0,
      createdAt: createdTs?.toDate(),
      // Nutrition values
      calories: (data['calories'] as num?)?.toInt(),
      protein: (data['protein'] as num?)?.toInt(),
      carbs: (data['carbs'] as num?)?.toInt(),
      fat: (data['fat'] as num?)?.toInt(),
      updatedAt: updatedTs?.toDate(),
      snapshot: doc,
    );
  }

  @override
  String toString() {
    return 'Recipe(id: $id, title: $title, rating: $avgRating)';
  }

  static String? _fixUrl(String? url) {
    if (url == null) return null;
    return url.replaceAll(
        'vuadaubepthuduc.appspot.com', 'vuadaubepthuduc.firebasestorage.app');
  }
}
