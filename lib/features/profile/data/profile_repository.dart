// Firestore schema assumption:
// - users/{uid} stores profile fields (displayName, email, photoURL, bio, postsCount, recipesCount, savedCount).
// - posts/{postId} and recipes/{recipeId} hold authored content with createdAt, hidden, and optional deleted flags.
// - saved recipes are stored at users/{uid}/bookmarks/{recipeId} with fields recipeId and bookmarkedAt (saved posts TODO).
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';

import '../../recipes/data/recipes_repository.dart';
import '../../reels/data/reel_model.dart';

class AppUserProfile {
  AppUserProfile({
    required this.uid,
    required this.displayName,
    required this.email,
    this.photoUrl,
    this.bio,
    this.createdAt,
    this.updatedAt,
    this.snapshot,
    this.isBanned = false,
    this.banReason,
    this.banUntil,
  });

  final String uid;
  final String displayName;
  final String email;
  final String? photoUrl;
  final String? bio;
  final DateTime? createdAt;
  final DateTime? updatedAt;
  final DocumentSnapshot<Map<String, dynamic>>? snapshot;
  final bool isBanned;
  final String? banReason;
  final DateTime? banUntil;

  AppUserProfile copyWith({
    String? displayName,
    String? email,
    String? photoUrl,
    String? bio,
    DateTime? createdAt,
    DateTime? updatedAt,
    DocumentSnapshot<Map<String, dynamic>>? snapshot,
    bool? isBanned,
    String? banReason,
    DateTime? banUntil,
  }) {
    return AppUserProfile(
      uid: uid,
      displayName: displayName ?? this.displayName,
      email: email ?? this.email,
      photoUrl: photoUrl ?? this.photoUrl,
      bio: bio ?? this.bio,
      createdAt: createdAt ?? this.createdAt,
      updatedAt: updatedAt ?? this.updatedAt,
      snapshot: snapshot ?? this.snapshot,
      isBanned: isBanned ?? this.isBanned,
      banReason: banReason ?? this.banReason,
      banUntil: banUntil ?? this.banUntil,
    );
  }

  factory AppUserProfile.fromDoc(DocumentSnapshot<Map<String, dynamic>> doc) {
    final data = doc.data() ?? {};
    final createdTs = data['createdAt'] as Timestamp?;
    final updatedTs = data['updatedAt'] as Timestamp?;
    return AppUserProfile(
      uid: doc.id,
      displayName: (data['displayName'] ??
              data['fullName'] ??
              data['name'] ??
              '') as String? ??
          '',
      email: data['email'] as String? ?? '',
      photoUrl: data['photoURL'] as String?,
      bio: data['bio'] as String?,
      createdAt: createdTs?.toDate(),
      updatedAt: updatedTs?.toDate(),
      snapshot: doc,
      isBanned: _parseBool(data['isBanned']),
      banReason: (data['banReason'] as String?)?.trim(),
      banUntil: (data['banUntil'] as Timestamp?)?.toDate(),
    );
  }
}

class UserProfileStats {
  const UserProfileStats({
    required this.postsCount,
    required this.recipesCount,
    required this.savedCount,
  });

  final int postsCount;
  final int recipesCount;
  final int savedCount;

  UserProfileStats copyWith({
    int? postsCount,
    int? recipesCount,
    int? savedCount,
  }) {
    return UserProfileStats(
      postsCount: postsCount ?? this.postsCount,
      recipesCount: recipesCount ?? this.recipesCount,
      savedCount: savedCount ?? this.savedCount,
    );
  }

  static const empty = UserProfileStats(
    postsCount: 0,
    recipesCount: 0,
    savedCount: 0,
  );
}

class PostSummary {
  PostSummary({
    required this.id,
    required this.title,
    required this.authorId,
    required this.createdAt,
    this.body,
    this.photoUrls = const [],
    this.tags = const [],
    this.likesCount = 0,
    this.commentsCount = 0,
    this.hidden = false,
    this.deleted = false,
  });

  final String id;
  final String title;
  final String authorId;
  final String? body;
  final List<String> photoUrls;
  final List<String> tags;
  final int likesCount;
  final int commentsCount;
  final bool hidden;
  final bool deleted;
  final DateTime? createdAt;

  PostSummary copyWith({
    String? title,
    String? authorId,
    String? body,
    List<String>? photoUrls,
    List<String>? tags,
    int? likesCount,
    int? commentsCount,
    bool? hidden,
    bool? deleted,
    DateTime? createdAt,
  }) {
    return PostSummary(
      id: id,
      title: title ?? this.title,
      authorId: authorId ?? this.authorId,
      body: body ?? this.body,
      photoUrls: photoUrls ?? this.photoUrls,
      tags: tags ?? this.tags,
      likesCount: likesCount ?? this.likesCount,
      commentsCount: commentsCount ?? this.commentsCount,
      hidden: hidden ?? this.hidden,
      deleted: deleted ?? this.deleted,
      createdAt: createdAt ?? this.createdAt,
    );
  }
}

class SavedItem {
  const SavedItem({
    required this.id,
    required this.targetId,
    required this.targetType,
    required this.createdAt,
    this.recipe,
    this.post,
    this.reel,
  });

  final String id;
  final String targetId;
  final String targetType; // 'post' | 'recipe' | 'reel'
  final DateTime? createdAt;
  final RecipeSummary? recipe;
  final PostSummary? post;
  final Reel? reel;

  SavedItem copyWith({
    String? targetId,
    String? targetType,
    DateTime? createdAt,
    RecipeSummary? recipe,
    PostSummary? post,
    Reel? reel,
  }) {
    return SavedItem(
      id: id,
      targetId: targetId ?? this.targetId,
      targetType: targetType ?? this.targetType,
      createdAt: createdAt ?? this.createdAt,
      recipe: recipe ?? this.recipe,
      post: post ?? this.post,
      reel: reel ?? this.reel,
    );
  }
}

abstract class ProfileRepository {
  Future<AppUserProfile?> fetchProfile(String uid);

  Future<AppUserProfile> ensureProfileFromAuth(User user);

  Future<void> updateProfile({
    required String uid,
    required String displayName,
    String? bio,
    String? photoUrl,
  });

  Stream<UserProfileStats> watchUserStats(String uid);

  Stream<List<PostSummary>> watchUserPosts(String uid);

  Stream<List<RecipeSummary>> watchUserRecipes(String uid);

  Stream<List<SavedItem>> watchUserSavedItems(String uid);
}

bool _parseBool(dynamic value) {
  if (value is bool) return value;
  if (value is num) return value != 0;
  if (value is String) {
    final v = value.trim().toLowerCase();
    if (v == 'true' || v == '1' || v == 'yes') return true;
    if (v == 'false' || v == '0' || v == 'no') return false;
  }
  return false;
}
