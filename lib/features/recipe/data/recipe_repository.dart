import 'dart:io';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_storage/firebase_storage.dart';

import '../../../core/utils/tokenizer.dart';
import '../../feed/data/recipe_model.dart';
import '../../search/domain/ai_recipe_suggestion.dart';

abstract class RecipeRepository {
  Future<String> createRecipe({
    String? recipeId,
    required String authorId,
    required String title,
    required String description,
    required int? cookTimeMinutes,
    required String? difficulty,
    required List<String> ingredients,
    required List<String> steps,
    required List<String> tags,
    required String coverUrl,
    required List<String> photoUrls,
    required List<String> ingredientsTokens,
    required List<String> searchTokens,
    int? calories,
    int? protein,
    int? carbs,
    int? fat,
  });

  Future<void> updateRecipe({
    required String recipeId,
    required String title,
    required String description,
    required int? cookTimeMinutes,
    required String? difficulty,
    required List<String> ingredients,
    required List<String> steps,
    required List<String> tags,
    required String coverUrl,
    required List<String> photoUrls,
    required List<String> ingredientsTokens,
    required List<String> searchTokens,
    int? calories,
    int? protein,
    int? carbs,
    int? fat,
  });

  Future<void> softDeleteRecipe(String recipeId);
  Future<void> hardDeleteRecipe({
    required String recipeId,
    required List<String> photoUrls,
    required String coverUrl,
  });

  Future<Recipe?> getRecipeById(String id);

  Future<String> createFromAiSuggestion({
    required String authorId,
    required AiRecipeSuggestion suggestion,
    String? coverPath,
  });
}

class RecipeRepositoryImpl implements RecipeRepository {
  RecipeRepositoryImpl({
    FirebaseFirestore? firestore,
    FirebaseStorage? storage,
  })  : _firestore = firestore ?? FirebaseFirestore.instance,
        _storage = storage ?? FirebaseStorage.instance;

  final FirebaseFirestore _firestore;
  final FirebaseStorage _storage;

  CollectionReference<Map<String, dynamic>> get _recipes =>
      _firestore.collection('recipes');

  @override
  Future<String> createRecipe({
    String? recipeId,
    required String authorId,
    required String title,
    required String description,
    required int? cookTimeMinutes,
    required String? difficulty,
    required List<String> ingredients,
    required List<String> steps,
    required List<String> tags,
    required String coverUrl,
    required List<String> photoUrls,
    required List<String> ingredientsTokens,
    required List<String> searchTokens,
    int? calories,
    int? protein,
    int? carbs,
    int? fat,
  }) async {
    final docRef = recipeId != null ? _recipes.doc(recipeId) : _recipes.doc();
    await docRef.set({
      'authorId': authorId,
      'title': title,
      'description': description,
      'cookTimeMinutes': cookTimeMinutes,
      'difficulty': difficulty,
      'ingredients': ingredients,
      'steps': steps,
      'tags': tags,
      'coverURL': coverUrl,
      'photoURLs': photoUrls,
      'ingredientsTokens': ingredientsTokens,
      'searchTokens': searchTokens,
      if (calories != null) 'calories': calories,
      if (protein != null) 'protein': protein,
      if (carbs != null) 'carbs': carbs,
      if (fat != null) 'fat': fat,
      'likesCount': 0,
      'commentsCount': 0,
      'ratingsCount': 0,
      'avgRating': 0,
      'sharesCount': 0,
      'hidden': false,
      'createdAt': FieldValue.serverTimestamp(),
      'updatedAt': FieldValue.serverTimestamp(),
    });
    return docRef.id;
  }

  @override
  Future<String> createFromAiSuggestion({
    required String authorId,
    required AiRecipeSuggestion suggestion,
    String? coverPath,
  }) async {
    String coverUrl = '';

    if (coverPath != null && coverPath.isNotEmpty) {
      if (!coverPath.startsWith('http')) {
        try {
          final ext = coverPath.split('.').lastOrNull ?? 'jpg';
          final ref = _storage
              .ref('recipes/${DateTime.now().millisecondsSinceEpoch}.$ext');
          await ref.putFile(File(coverPath));
          coverUrl = await ref.getDownloadURL();
        } catch (_) {
          // Fallback or ignore
        }
      } else {
        coverUrl = coverPath;
      }
    }

    // Flatten ingredients and steps
    final ingredients = suggestion.ingredients.map((e) => e.original).toList();
    final steps = suggestion.steps.map((e) => e.content).toList();

    // Tokenize
    final ingredientsTokens =
        ingredients.expand((i) => tokenize(i)).toSet().toList();
    
    final searchInput =
        '${suggestion.title} ${suggestion.description} ${suggestion.tags.join(" ")}';
    final searchTokens = tokenize(searchInput).toSet().toList();

    return createRecipe(
      authorId: authorId,
      title: suggestion.title,
      description: suggestion.description,
      cookTimeMinutes: suggestion.estimatedMinutes,
      difficulty: suggestion.difficulty,
      ingredients: ingredients,
      steps: steps,
      tags: suggestion.tags,
      coverUrl: coverUrl,
      photoUrls: [], // AI doesn't provide multi-photos yet
      ingredientsTokens: ingredientsTokens,
      searchTokens: searchTokens,
    );
  }

  @override
  Future<void> updateRecipe({
    required String recipeId,
    required String title,
    required String description,
    required int? cookTimeMinutes,
    required String? difficulty,
    required List<String> ingredients,
    required List<String> steps,
    required List<String> tags,
    required String coverUrl,
    required List<String> photoUrls,
    required List<String> ingredientsTokens,
    required List<String> searchTokens,
    int? calories,
    int? protein,
    int? carbs,
    int? fat,
  }) async {
    await _recipes.doc(recipeId).update({
      'title': title,
      'description': description,
      'cookTimeMinutes': cookTimeMinutes,
      'difficulty': difficulty,
      'ingredients': ingredients,
      'steps': steps,
      'tags': tags,
      'coverURL': coverUrl,
      'photoURLs': photoUrls,
      'ingredientsTokens': ingredientsTokens,
      'searchTokens': searchTokens,
      if (calories != null) 'calories': calories,
      if (protein != null) 'protein': protein,
      if (carbs != null) 'carbs': carbs,
      if (fat != null) 'fat': fat,
      'updatedAt': FieldValue.serverTimestamp(),
    });
  }

  @override
  Future<void> softDeleteRecipe(String recipeId) async {
    await _recipes.doc(recipeId).update({
      'hidden': true,
      'updatedAt': FieldValue.serverTimestamp(),
    });
  }

  @override
  Future<void> hardDeleteRecipe({
    required String recipeId,
    required List<String> photoUrls,
    required String coverUrl,
  }) async {
    for (final url in [...photoUrls, coverUrl]) {
      if (url.isEmpty) continue;
      try {
        await _storage.refFromURL(url).delete();
      } catch (_) {
        // ignore
      }
    }
    await _recipes.doc(recipeId).delete();
  }

  @override
  Future<Recipe?> getRecipeById(String id) async {
    final doc = await _recipes.doc(id).get();
    if (!doc.exists) return null;
    return Recipe.fromDoc(doc);
  }
}
final recipeRepositoryProvider = Provider<RecipeRepository>((ref) {
  return RecipeRepositoryImpl();
});
