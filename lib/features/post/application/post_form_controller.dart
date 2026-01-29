import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:image_picker/image_picker.dart';

import '../../feed/data/post_model.dart';
import '../data/post_repository.dart';
import '../data/post_storage_service.dart';
import '../../profile/domain/user_ban_guard.dart';
import '../../profile/application/profile_controller.dart';

class PostFormState {
  const PostFormState({
    this.title = '',
    this.body = '',
    this.tags = const [],
    this.newImages = const [],
    this.existingImageUrls = const [],
    this.isSubmitting = false,
    this.error,
  });

  final String title;
  final String body;
  final List<String> tags;
  final List<XFile> newImages;
  final List<String> existingImageUrls;
  final bool isSubmitting;
  final Object? error;

  PostFormState copyWith({
    String? title,
    String? body,
    List<String>? tags,
    List<XFile>? newImages,
    List<String>? existingImageUrls,
    bool? isSubmitting,
    Object? error = _noUpdateError,
  }) {
    return PostFormState(
      title: title ?? this.title,
      body: body ?? this.body,
      tags: tags ?? this.tags,
      newImages: newImages ?? this.newImages,
      existingImageUrls: existingImageUrls ?? this.existingImageUrls,
      isSubmitting: isSubmitting ?? this.isSubmitting,
      error: error == _noUpdateError ? this.error : error,
    );
  }

  static const _noUpdateError = Object();
}

final postRepositoryProvider = Provider<PostRepository>((ref) {
  return PostRepositoryImpl();
});

final postStorageServiceProvider = Provider<PostStorageService>((ref) {
  return PostStorageService();
});

final postFormControllerProvider =
    StateNotifierProvider.autoDispose<PostFormController, PostFormState>((ref) {
  final repo = ref.watch(postRepositoryProvider);
  final storage = ref.watch(postStorageServiceProvider);
  final banGuard = ref.watch(userBanGuardProvider);
  return PostFormController(repo, storage, banGuard);
});

class PostFormController extends StateNotifier<PostFormState> {
  PostFormController(this._repository, this._storage, this._banGuard)
      : super(const PostFormState());

  final PostRepository _repository;
  final PostStorageService _storage;
  final UserBanGuard _banGuard;

  void setTitle(String value) => state = state.copyWith(title: value);
  void setBody(String value) => state = state.copyWith(body: value);

  void setTagsFromString(String value) {
    final tags = value
        .split(',')
        .map((e) => e.trim())
        .where((e) => e.isNotEmpty)
        .toList();
    state = state.copyWith(tags: tags);
  }

  Future<void> pickImages() async {
    final picker = ImagePicker();
    final picked = await picker.pickMultiImage();
    if (picked.isNotEmpty) {
      state = state.copyWith(newImages: [...state.newImages, ...picked]);
    }
  }

  Future<String?> submitCreate(String authorId) async {
    if (state.title.isEmpty || state.body.isEmpty) {
      throw Exception('Title and body are required');
    }
    await _banGuard.ensureNotBanned();
    state = state.copyWith(isSubmitting: true, error: null);
    try {
      // Create post with empty photos first.
      final postId = await _repository.createPost(
        authorId: authorId,
        title: state.title,
        body: state.body,
        tags: state.tags,
        photoUrls: const [],
      );

      // Upload images if any, then update.
      if (state.newImages.isNotEmpty) {
        final urls = await _storage.uploadPostImages(
          postId: postId,
          images: state.newImages,
        );
        await _repository.updatePost(
          postId: postId,
          title: state.title,
          body: state.body,
          tags: state.tags,
          photoUrls: urls,
        );
      }
      return postId;
    } catch (e) {
      state = state.copyWith(error: e);
      rethrow;
    } finally {
      state = state.copyWith(isSubmitting: false);
    }
  }

  Future<void> loadFromPost(Post post) async {
    state = state.copyWith(
      title: post.title,
      body: post.body,
      tags: post.tags,
      existingImageUrls: post.photoURLs,
    );
  }

  Future<void> submitUpdate(String postId) async {
    if (state.title.isEmpty || state.body.isEmpty) {
      throw Exception('Title and body are required');
    }
    await _banGuard.ensureNotBanned();
    state = state.copyWith(isSubmitting: true, error: null);
    try {
      List<String> photoUrls = [...state.existingImageUrls];
      if (state.newImages.isNotEmpty) {
        final urls = await _storage.uploadPostImages(
          postId: postId,
          images: state.newImages,
        );
        photoUrls = [...photoUrls, ...urls];
      }
      await _repository.updatePost(
        postId: postId,
        title: state.title,
        body: state.body,
        tags: state.tags,
        photoUrls: photoUrls,
      );
      state = state.copyWith(
        existingImageUrls: photoUrls,
        newImages: const [],
      );
    } catch (e) {
      state = state.copyWith(error: e);
      rethrow;
    } finally {
      state = state.copyWith(isSubmitting: false);
    }
  }

  Future<void> softDelete(String postId) {
    return _banGuard.ensureNotBanned().then((_) => _repository.softDeletePost(postId));
  }

  Future<void> hardDelete(String postId) {
    return _banGuard.ensureNotBanned().then(
      (_) => _repository.hardDeletePost(
        postId: postId,
        photoUrls: [...state.existingImageUrls],
      ),
    );
  }
}
