import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:cloud_firestore/cloud_firestore.dart';

import '../data/interaction_repository.dart';

/// Provider for interaction repository
final interactionRepositoryProvider = Provider<InteractionRepository>((ref) {
  return InteractionRepository();
});

/// Provider to watch post like status
final postLikeStatusProvider =
    StreamProvider.family<bool, String>((ref, postId) {
  final repo = ref.watch(interactionRepositoryProvider);
  return repo.watchPostLikeStatus(postId);
});

/// Provider to watch post likes count from Firestore
final postLikesCountProvider =
    StreamProvider.family<int, String>((ref, postId) {
  return FirebaseFirestore.instance
      .collection('posts')
      .doc(postId)
      .snapshots()
      .map((doc) => (doc.data()?['likesCount'] as int?) ?? 0);
});

/// Provider to watch recipe like status
final recipeLikeStatusProvider =
    StreamProvider.family<bool, String>((ref, recipeId) {
  final repo = ref.watch(interactionRepositoryProvider);
  return repo.watchRecipeLikeStatus(recipeId);
});

/// Provider to watch post comments
final postCommentsProvider =
    StreamProvider.family<List<Map<String, dynamic>>, String>((ref, postId) {
  final repo = ref.watch(interactionRepositoryProvider);
  return repo.watchPostComments(postId);
});

/// Provider to watch recipe comments
final recipeCommentsProvider = StreamProvider.family<List<Map<String, dynamic>>,
    String>((ref, recipeId) {
  final repo = ref.watch(interactionRepositoryProvider);
  return repo.watchRecipeComments(recipeId);
});

/// Provider to get user's recipe rating
final userRecipeRatingProvider =
    FutureProvider.family<double?, String>((ref, recipeId) {
  final repo = ref.watch(interactionRepositoryProvider);
  return repo.getUserRecipeRating(recipeId);
});
