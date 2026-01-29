import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:image_picker/image_picker.dart';
import '../data/reel_model.dart';
import '../data/reel_repository.dart';
import '../data/reel_storage_service.dart';
import '../../profile/domain/user_ban_guard.dart';
import '../../profile/application/profile_controller.dart';

class ReelFormState {
  const ReelFormState({
    this.title = '',
    this.description = '',
    this.tags = const [],
    this.videoFile,
    this.thumbnailFile,
    this.isSubmitting = false,
    this.error,
  });

  final String title;
  final String description;
  final List<String> tags;
  final XFile? videoFile;
  final XFile? thumbnailFile;
  final bool isSubmitting;
  final Object? error;

  ReelFormState copyWith({
    String? title,
    String? description,
    List<String>? tags,
    XFile? videoFile,
    XFile? thumbnailFile,
    bool? isSubmitting,
    Object? error = _noUpdateError,
  }) {
    return ReelFormState(
      title: title ?? this.title,
      description: description ?? this.description,
      tags: tags ?? this.tags,
      videoFile: videoFile ?? this.videoFile,
      thumbnailFile: thumbnailFile ?? this.thumbnailFile,
      isSubmitting: isSubmitting ?? this.isSubmitting,
      error: error == _noUpdateError ? this.error : error,
    );
  }

  static const _noUpdateError = Object();
}

final reelStorageServiceProvider = Provider<ReelStorageService>((ref) {
  return ReelStorageService();
});

final reelFormControllerProvider =
    StateNotifierProvider.autoDispose<ReelFormController, ReelFormState>((ref) {
  final repo = ref.watch(reelRepositoryProvider);
  final storage = ref.watch(reelStorageServiceProvider);
  final banGuard = ref.watch(userBanGuardProvider);
  return ReelFormController(repo, storage, banGuard);
});

class ReelFormController extends StateNotifier<ReelFormState> {
  ReelFormController(this._repository, this._storage, this._banGuard)
      : super(const ReelFormState());

  final ReelRepository _repository;
  final ReelStorageService _storage;
  final UserBanGuard _banGuard;

  void setTitle(String value) => state = state.copyWith(title: value);
  void setDescription(String value) => state = state.copyWith(description: value);

  void setTagsFromString(String value) {
    final tags = value
        .split(',')
        .map((e) => e.trim())
        .where((e) => e.isNotEmpty)
        .toList();
    state = state.copyWith(tags: tags);
  }

  Future<void> pickVideo() async {
    final picker = ImagePicker();
    final picked = await picker.pickVideo(
      source: ImageSource.gallery,
    );
    if (picked != null) {
      state = state.copyWith(videoFile: picked);
    }
  }

  void clearVideo() {
    state = state.copyWith(videoFile: null, thumbnailFile: null);
  }

  Future<void> pickThumbnail() async {
    final picker = ImagePicker();
    final picked = await picker.pickImage(source: ImageSource.gallery);
    if (picked != null) {
      state = state.copyWith(thumbnailFile: picked);
    }
  }

  Future<String?> submit(String authorId) async {
    if (state.videoFile == null) {
      throw Exception('Video is required');
    }
    
    await _banGuard.ensureNotBanned();
    state = state.copyWith(isSubmitting: true, error: null);
    
    try {
      // Create a temporary reel document to get ID or just add and then update logic
      // For simplicity, we create with empty URLs first
      final tempReel = Reel(
        id: '', // Will be set by Firestore
        authorId: authorId,
        videoUrl: '',
        thumbnailUrl: '',
        title: state.title,
        description: state.description,
        tags: state.tags,
        hidden: false,
        searchTokens: state.title.toLowerCase().split(' '),
        likesCount: 0,
        commentsCount: 0,
        sharesCount: 0,
        viewsCount: 0,
        duration: 0,
        createdAt: DateTime.now(),
      );

      final reelId = await _repository.createReel(tempReel);
      
      // Upload video
      final videoUrl = await _storage.uploadVideo(reelId: reelId, video: state.videoFile!);
      
      // Upload thumbnail if exists
      String thumbUrl = '';
      if (state.thumbnailFile != null) {
        thumbUrl = await _storage.uploadThumbnail(reelId: reelId, thumbnail: state.thumbnailFile!);
      }

      // Update reel with final URLs
      final finalReel = tempReel.copyWith(
        videoUrl: videoUrl,
        thumbnailUrl: thumbUrl,
      );
      
      await _repository.updateReel(reelId, finalReel);
      
      return reelId;
    } catch (e) {
      state = state.copyWith(error: e);
      rethrow;
    } finally {
      state = state.copyWith(isSubmitting: false);
    }
  }
}
