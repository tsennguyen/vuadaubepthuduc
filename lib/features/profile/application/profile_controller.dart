import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../recipes/data/recipes_repository.dart';
import '../data/firebase_profile_repository.dart';
import '../data/profile_repository.dart';
import '../domain/user_ban_guard.dart';

class ProfileState {
  const ProfileState({
    this.isLoading = false,
    this.isSaving = false,
    this.profile,
    this.error,
  });

  final bool isLoading;
  final bool isSaving;
  final AppUserProfile? profile;
  final Object? error;

  ProfileState copyWith({
    bool? isLoading,
    bool? isSaving,
    AppUserProfile? profile,
    Object? error = _noUpdateError,
  }) {
    return ProfileState(
      isLoading: isLoading ?? this.isLoading,
      isSaving: isSaving ?? this.isSaving,
      profile: profile ?? this.profile,
      error: error == _noUpdateError ? this.error : error,
    );
  }

  static const _noUpdateError = Object();
}

final currentUserIdProvider = Provider<String?>(
  (ref) => FirebaseAuth.instance.currentUser?.uid,
);

final profileRepositoryProvider = Provider<ProfileRepository>((ref) {
  return FirebaseProfileRepository();
});

final userBanGuardProvider = Provider<UserBanGuard>((ref) {
  final repo = ref.watch(profileRepositoryProvider);
  return UserBanGuard(profileRepository: repo);
});

final userProfileStatsProvider =
    StreamProvider.autoDispose.family<UserProfileStats, String>((ref, uid) {
  final repo = ref.watch(profileRepositoryProvider);
  return repo.watchUserStats(uid);
});

final userPostsProvider =
    StreamProvider.autoDispose.family<List<PostSummary>, String>((ref, uid) {
  final repo = ref.watch(profileRepositoryProvider);
  return repo.watchUserPosts(uid);
});

final userRecipesProvider =
    StreamProvider.autoDispose.family<List<RecipeSummary>, String>((ref, uid) {
  final repo = ref.watch(profileRepositoryProvider);
  return repo.watchUserRecipes(uid);
});

final userSavedItemsProvider =
    StreamProvider.autoDispose.family<List<SavedItem>, String>((ref, uid) {
  final repo = ref.watch(profileRepositoryProvider);
  return repo.watchUserSavedItems(uid);
});

final profileControllerProvider = StateNotifierProvider.autoDispose
    .family<ProfileController, ProfileState, String?>((ref, uid) {
  final repo = ref.watch(profileRepositoryProvider);
  final auth = FirebaseAuth.instance;
  return ProfileController(
    repository: repo,
    auth: auth,
    uidOverride: uid,
  )..loadProfile();
});

class ProfileController extends StateNotifier<ProfileState> {
  ProfileController({
    required ProfileRepository repository,
    required FirebaseAuth auth,
    required String? uidOverride,
  })  : _repository = repository,
        _auth = auth,
        _uidOverride = uidOverride,
        super(const ProfileState());

  final ProfileRepository _repository;
  final FirebaseAuth _auth;
  final String? _uidOverride;
  bool _hasLoaded = false;

  String? get _targetUid => _uidOverride ?? _auth.currentUser?.uid;

  Future<void> loadProfile() async {
    if (_hasLoaded) return;
    _hasLoaded = true;
    await refresh();
  }

  Future<void> refresh() async {
    final uid = _targetUid;
    if (uid == null) {
      state = state.copyWith(
        error: 'Chua dang nhap',
        profile: null,
        isLoading: false,
      );
      return;
    }
    state = state.copyWith(isLoading: true, error: null);
    try {
      var profile = await _repository.fetchProfile(uid);
      if (!mounted) return;
      if (profile == null && _auth.currentUser != null) {
        profile = await _repository.ensureProfileFromAuth(_auth.currentUser!);
        if (!mounted) return;
      }
      state = state.copyWith(isLoading: false, profile: profile);
    } catch (e) {
      if (!mounted) return;
      state = state.copyWith(isLoading: false, error: e);
    }
  }

  Future<void> updateProfile({
    required String displayName,
    String? bio,
    String? photoUrl,
  }) async {
    final uid = _targetUid;
    if (uid == null) {
      state = state.copyWith(error: 'Chua dang nhap');
      return;
    }
    state = state.copyWith(isSaving: true, error: null);
    try {
      await _repository.updateProfile(
        uid: uid,
        displayName: displayName,
        bio: bio,
        photoUrl: photoUrl,
      );
      if (!mounted) return;
      final updatedProfile = (state.profile ??
              AppUserProfile(
                uid: uid,
                displayName: displayName,
                email: _auth.currentUser?.email ?? '',
              ))
          .copyWith(
        displayName: displayName,
        bio: bio,
        photoUrl: photoUrl,
      );
      state = state.copyWith(profile: updatedProfile);
    } catch (e) {
      if (!mounted) return;
      state = state.copyWith(error: e);
    } finally {
      if (mounted) {
        state = state.copyWith(isSaving: false);
      }
    }
  }
}
