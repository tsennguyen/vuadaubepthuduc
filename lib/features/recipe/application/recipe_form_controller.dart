import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:image_picker/image_picker.dart';
import 'package:cloud_firestore/cloud_firestore.dart';

import '../../../core/services/ai_service.dart';
import '../../../core/utils/tokenizer.dart';
import '../../feed/data/recipe_model.dart';
import '../../search/domain/ai_recipe_suggestion.dart';
import '../data/recipe_repository.dart';
import '../data/recipe_storage_service.dart';
import '../../profile/domain/user_ban_guard.dart';
import '../../profile/application/profile_controller.dart';

class RecipeFormState {
  const RecipeFormState({
    this.title = '',
    this.description = '',
    this.cookTimeMinutes,
    this.difficulty,
    this.ingredients = const [''],
    this.steps = const [''],
    this.tags = const [],
    this.coverImage,
    this.extraImages = const [],
    this.existingCoverUrl,
    this.existingExtraUrls = const [],
    this.isSubmitting = false,
    this.isEnriching = false,
    this.isEstimatingNutrition = false,
    this.calories,
    this.protein,
    this.carbs,
    this.fat,
    this.error,
  });

  final String title;
  final String description;
  final int? cookTimeMinutes;
  final String? difficulty;
  final List<String> ingredients;
  final List<String> steps;
  final List<String> tags;
  final XFile? coverImage;
  final List<XFile> extraImages;
  final String? existingCoverUrl;
  final List<String> existingExtraUrls;
  final bool isSubmitting;
  final bool isEnriching;
  final bool isEstimatingNutrition;
  final int? calories;
  final int? protein;
  final int? carbs;
  final int? fat;
  final Object? error;

  RecipeFormState copyWith({
    String? title,
    String? description,
    int? cookTimeMinutes,
    String? difficulty,
    List<String>? ingredients,
    List<String>? steps,
    List<String>? tags,
    XFile? coverImage,
    bool coverImageNull = false,
    List<XFile>? extraImages,
    String? existingCoverUrl,
    List<String>? existingExtraUrls,
    bool? isSubmitting,
    bool? isEnriching,
    bool? isEstimatingNutrition,
    int? calories,
    int? protein,
    int? carbs,
    int? fat,
    Object? error = _noUpdateError,
  }) {
    return RecipeFormState(
      title: title ?? this.title,
      description: description ?? this.description,
      cookTimeMinutes: cookTimeMinutes ?? this.cookTimeMinutes,
      difficulty: difficulty ?? this.difficulty,
      ingredients: ingredients ?? this.ingredients,
      steps: steps ?? this.steps,
      tags: tags ?? this.tags,
      coverImage: coverImageNull ? null : coverImage ?? this.coverImage,
      extraImages: extraImages ?? this.extraImages,
      existingCoverUrl: existingCoverUrl ?? this.existingCoverUrl,
      existingExtraUrls: existingExtraUrls ?? this.existingExtraUrls,
      isSubmitting: isSubmitting ?? this.isSubmitting,
      isEnriching: isEnriching ?? this.isEnriching,
      isEstimatingNutrition: isEstimatingNutrition ?? this.isEstimatingNutrition,
      calories: calories ?? this.calories,
      protein: protein ?? this.protein,
      carbs: carbs ?? this.carbs,
      fat: fat ?? this.fat,
      error: error == _noUpdateError ? this.error : error,
    );
  }

  static const _noUpdateError = Object();
}

final recipeRepositoryProvider = Provider<RecipeRepository>((ref) {
  return RecipeRepositoryImpl();
});

final recipeStorageServiceProvider = Provider<RecipeStorageService>((ref) {
  return RecipeStorageService();
});

final recipeFormControllerProvider =
    StateNotifierProvider.autoDispose<RecipeFormController, RecipeFormState>(
        (ref) {
  final repo = ref.watch(recipeRepositoryProvider);
  final storage = ref.watch(recipeStorageServiceProvider);
  final banGuard = ref.watch(userBanGuardProvider);
  return RecipeFormController(repo, storage, banGuard);
});

class RecipeFormController extends StateNotifier<RecipeFormState> {
  RecipeFormController(
    this._repository,
    this._storage,
    this._banGuard, {
    AiService? aiService,
  })  : _aiService = aiService ?? AiService(),
        super(const RecipeFormState());

  final RecipeRepository _repository;
  final RecipeStorageService _storage;
  final AiService _aiService;
  final UserBanGuard _banGuard;

  void setTitle(String value) => state = state.copyWith(title: value);
  void setDescription(String value) =>
      state = state.copyWith(description: value);

  void setCookTime(String value) {
    final parsed = int.tryParse(value);
    state = state.copyWith(cookTimeMinutes: parsed);
  }

  void setDifficulty(String? value) =>
      state = state.copyWith(difficulty: value);

  void setTagsFromString(String value) {
    final tags = value
        .split(',')
        .map((e) => e.trim())
        .where((e) => e.isNotEmpty)
        .toList();
    state = state.copyWith(tags: tags);
  }

  void updateIngredient(int index, String value) {
    final list = [...state.ingredients];
    if (index < list.length) {
      list[index] = value;
      state = state.copyWith(ingredients: list);
    }
  }

  void addIngredient() {
    state = state.copyWith(ingredients: [...state.ingredients, '']);
  }

  void removeIngredient(int index) {
    final list = [...state.ingredients];
    if (index >= 0 && index < list.length) {
      list.removeAt(index);
      if (list.isEmpty) list.add('');
      state = state.copyWith(ingredients: list);
    }
  }

  void updateStep(int index, String value) {
    final list = [...state.steps];
    if (index < list.length) {
      list[index] = value;
      state = state.copyWith(steps: list);
    }
  }

  void addStep() {
    state = state.copyWith(steps: [...state.steps, '']);
  }

  void removeStep(int index) {
    final list = [...state.steps];
    if (index >= 0 && index < list.length) {
      list.removeAt(index);
      if (list.isEmpty) list.add('');
      state = state.copyWith(steps: list);
    }
  }

  Future<void> enrichWithAi() async {
    if (state.isEnriching) return;
    state = state.copyWith(isEnriching: true, error: null);
    try {
      final data = await _aiService.enrichRecipeDraft(
        title: state.title,
        description: state.description,
        rawIngredients: state.ingredients.join('\n'),
      );
      final ingList = (data['ingredients'] as List<dynamic>?)
              ?.whereType<Map<String, dynamic>>()
              .map((e) => (e['name'] as String? ?? '').trim())
              .where((e) => e.isNotEmpty)
              .toList() ??
          const <String>[];
      final tags =
          (data['tags'] as List<dynamic>?)?.whereType<String>().toList() ??
              <String>[];
      state = state.copyWith(
        ingredients: ingList.isNotEmpty ? ingList : state.ingredients,
        tags: tags.isNotEmpty ? tags : state.tags,
      );
    } on AiException catch (e) {
      state = state.copyWith(error: e.message);
    } catch (_) {
      state = state.copyWith(
        error: 'Không lấy được gợi ý từ AI. Vui lòng thử lại sau.',
      );
    } finally {
      state = state.copyWith(isEnriching: false);
    }
  }

  /// Estimate nutrition values using AI based on current ingredients
  Future<void> estimateNutrition() async {
    if (state.isEstimatingNutrition) return;
    
    // Validate ingredients
    final validIngredients = state.ingredients
        .where((e) => e.trim().isNotEmpty)
        .toList();
    
    if (validIngredients.isEmpty) {
      state = state.copyWith(
        error: 'Vui lòng điền nguyên liệu trước khi ước lượng dinh dưỡng',
      );
      return;
    }

    state = state.copyWith(isEstimatingNutrition: true, error: null);
    
    try {
      final data = await _aiService.estimateNutrition(
        ingredients: validIngredients,
        servings: 1, // Per serving
      );
      
      // Parse values as num (can be int or double) then convert to int
      final calories = (data['calories'] as num?)?.toInt();
      final protein = (data['protein'] as num?)?.toInt();
      final carbs = (data['carbs'] as num?)?.toInt();
      final fat = (data['fat'] as num?)?.toInt();
      
      state = state.copyWith(
        calories: calories,
        protein: protein,
        carbs: carbs,
        fat: fat,
      );
    } on AiException catch (e) {
      state = state.copyWith(error: e.message);
    } catch (e) {
      state = state.copyWith(
        error: 'Không thể ước lượng dinh dưỡng. Vui lòng thử lại sau.',
      );
    } finally {
      state = state.copyWith(isEstimatingNutrition: false);
    }
  }

  Future<void> pickCoverImage() async {
    final picker = ImagePicker();
    final image = await picker.pickImage(source: ImageSource.gallery);
    if (image != null) {
      state = state.copyWith(coverImage: image, existingCoverUrl: null);
    }
  }

  Future<void> pickExtraImages() async {
    final picker = ImagePicker();
    final images = await picker.pickMultiImage();
    if (images.isNotEmpty) {
      state = state.copyWith(extraImages: [...state.extraImages, ...images]);
    }
  }

  void removeExistingExtra(String url) {
    final list = [...state.existingExtraUrls];
    list.remove(url);
    state = state.copyWith(existingExtraUrls: list);
  }

  void removeNewExtraAt(int index) {
    final list = [...state.extraImages];
    if (index >= 0 && index < list.length) {
      list.removeAt(index);
      state = state.copyWith(extraImages: list);
    }
  }

  bool _validate({bool requireCover = false}) {
    if (state.title.trim().isEmpty || state.description.trim().isEmpty) {
      throw Exception('Tiêu đề và mô tả không được để trống');
    }
    if (state.ingredients.where((e) => e.trim().isNotEmpty).isEmpty) {
      throw Exception('Cần ít nhất 1 nguyên liệu');
    }
    if (state.steps.where((e) => e.trim().isNotEmpty).isEmpty) {
      throw Exception('Cần ít nhất 1 bước thực hiện');
    }
    if (requireCover &&
        state.coverImage == null &&
        (state.existingCoverUrl == null || state.existingCoverUrl!.isEmpty)) {
      throw Exception('Chọn ảnh bìa');
    }
    return true;
  }

  Future<String?> submitCreate(String authorId) async {
    _validate(requireCover: true);
    await _banGuard.ensureNotBanned();
    state = state.copyWith(isSubmitting: true, error: null);
    try {
      final recipeId =
          FirebaseFirestore.instance.collection('recipes').doc().id;
      final coverUrl = state.coverImage != null
          ? await _storage.uploadCover(
              recipeId: recipeId, image: state.coverImage!)
          : '';
      final extraUrls = state.extraImages.isNotEmpty
          ? await _storage.uploadPhotos(
              recipeId: recipeId, images: state.extraImages)
          : <String>[];
      final ingredientsTokens = buildIngredientsTokens(state.ingredients);
      final searchTokens = buildSearchTokens(
        title: state.title,
        tags: state.tags,
        extra: [state.description],
      );
      await _repository.createRecipe(
        recipeId: recipeId,
        authorId: authorId,
        title: state.title.trim(),
        description: state.description.trim(),
        cookTimeMinutes: state.cookTimeMinutes,
        difficulty: state.difficulty,
        ingredients: state.ingredients,
        steps: state.steps,
        tags: state.tags,
        coverUrl: coverUrl,
        photoUrls: extraUrls,
        ingredientsTokens: ingredientsTokens,
        searchTokens: searchTokens,
        calories: state.calories,
        protein: state.protein,
        carbs: state.carbs,
        fat: state.fat,
      );
      return recipeId;
    } catch (e) {
      state = state.copyWith(error: e);
      rethrow;
    } finally {
      state = state.copyWith(isSubmitting: false);
    }
  }

  Future<void> loadFromRecipe(Recipe recipe) async {
    state = state.copyWith(
      title: recipe.title,
      description: recipe.description,
      cookTimeMinutes: recipe.cookTimeMinutes,
      difficulty: recipe.difficulty,
      ingredients: recipe.ingredients.isNotEmpty ? recipe.ingredients : [''],
      steps: recipe.steps.isNotEmpty ? recipe.steps : [''],
      tags: recipe.tags,
      existingCoverUrl: recipe.coverUrl,
      existingExtraUrls: recipe.photoURLs,
      calories: recipe.calories,
      protein: recipe.protein,
      carbs: recipe.carbs,
      fat: recipe.fat,
      coverImageNull: true,
    );
  }

  void loadFromAi(AiRecipeSuggestion suggestion, {String? coverPath}) {
    if (state.title.isNotEmpty) return; // Prevent overwrite if already editing? Or allow?
    
    // Convert AiRecipeIngredient to String
    final ingredients = suggestion.ingredients.map((e) => e.original).toList();
    if (ingredients.isEmpty) ingredients.add('');

    // Convert AiRecipeStep to String
    final steps = suggestion.steps.map((e) => e.content).toList();
    if (steps.isEmpty) steps.add('');

    state = state.copyWith(
      title: suggestion.title,
      description: suggestion.description,
      cookTimeMinutes: suggestion.estimatedMinutes,
      difficulty: suggestion.difficulty,
      ingredients: ingredients,
      steps: steps,
      tags: suggestion.tags,
      coverImage: coverPath != null ? XFile(coverPath) : null,
      existingCoverUrl: null,
      coverImageNull: coverPath == null,
    );
  }

  Future<void> submitUpdate(Recipe existing) async {
    _validate(requireCover: true);
    await _banGuard.ensureNotBanned();
    state = state.copyWith(isSubmitting: true, error: null);
    try {
      String coverUrl = state.existingCoverUrl ?? existing.coverUrl;
      if (state.coverImage != null) {
        coverUrl = await _storage.uploadCover(
          recipeId: existing.id,
          image: state.coverImage!,
        );
      }
      final extraNew = state.extraImages.isNotEmpty
          ? await _storage.uploadPhotos(
              recipeId: existing.id, images: state.extraImages)
          : <String>[];
      final combinedPhotos = [
        ...state.existingExtraUrls,
        ...extraNew,
      ];
      final ingredientsTokens = buildIngredientsTokens(state.ingredients);
      final searchTokens = buildSearchTokens(
        title: state.title,
        tags: state.tags,
        extra: [state.description],
      );
      await _repository.updateRecipe(
        recipeId: existing.id,
        title: state.title.trim(),
        description: state.description.trim(),
        cookTimeMinutes: state.cookTimeMinutes,
        difficulty: state.difficulty,
        ingredients: state.ingredients,
        steps: state.steps,
        tags: state.tags,
        coverUrl: coverUrl,
        photoUrls: combinedPhotos,
        ingredientsTokens: ingredientsTokens,
        searchTokens: searchTokens,
        calories: state.calories,
        protein: state.protein,
        carbs: state.carbs,
        fat: state.fat,
      );
      state = state.copyWith(
        existingCoverUrl: coverUrl,
        existingExtraUrls: combinedPhotos,
        extraImages: const [],
        coverImageNull: true,
      );
    } catch (e) {
      state = state.copyWith(error: e);
      rethrow;
    } finally {
      state = state.copyWith(isSubmitting: false);
    }
  }

  Future<void> softDelete(String recipeId) {
    return _banGuard.ensureNotBanned().then(
          (_) => _repository.softDeleteRecipe(recipeId),
        );
  }

  Future<void> hardDelete(String recipeId) {
    return _banGuard.ensureNotBanned().then(
          (_) => _repository.hardDeleteRecipe(
            recipeId: recipeId,
            photoUrls: [...state.existingExtraUrls],
            coverUrl: state.existingCoverUrl ?? '',
          ),
        );
  }
}
