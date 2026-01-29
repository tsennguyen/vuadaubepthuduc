import 'dart:async';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';

import '../../recipes/data/recipes_repository.dart';
import '../../reels/data/reel_model.dart';
import 'profile_repository.dart';

/// Firestore schema assumption:
/// - users/{uid} stores profile fields (displayName, email, photoURL, bio, postsCount, recipesCount, savedCount).
/// - posts/{postId} and recipes/{recipeId} hold authored content with createdAt, hidden, and optional deleted flags.
/// - saved recipes are stored at users/{uid}/bookmarks/{recipeId} with fields recipeId and bookmarkedAt (saved posts TODO).
class FirebaseProfileRepository implements ProfileRepository {
  FirebaseProfileRepository({
    FirebaseFirestore? firestore,
    FirebaseAuth? auth,
  })  : _firestore = firestore ?? FirebaseFirestore.instance,
        _auth = auth ?? FirebaseAuth.instance;

  final FirebaseFirestore _firestore;
  final FirebaseAuth _auth;

  CollectionReference<Map<String, dynamic>> get _users =>
      _firestore.collection('users');
  CollectionReference<Map<String, dynamic>> get _posts =>
      _firestore.collection('posts');
  CollectionReference<Map<String, dynamic>> get _recipes =>
      _firestore.collection('recipes');
  CollectionReference<Map<String, dynamic>> get _reels =>
      _firestore.collection('reels');
  CollectionReference<Map<String, dynamic>> _bookmarks(String uid) =>
      _users.doc(uid).collection('bookmarks');

  @override
  Future<AppUserProfile?> fetchProfile(String uid) async {
    final doc = await _users.doc(uid).get();
    if (!doc.exists) return null;
    return AppUserProfile.fromDoc(doc);
  }

  @override
  Future<AppUserProfile> ensureProfileFromAuth(User user) async {
    final docRef = _users.doc(user.uid);
    final doc = await docRef.get();
    if (!doc.exists) {
      await docRef.set({
        'uid': user.uid,
        'email': user.email,
        'displayName': user.displayName ?? user.email ?? '',
        'photoURL': user.photoURL,
        'bio': '',
        'createdAt': FieldValue.serverTimestamp(),
        'updatedAt': FieldValue.serverTimestamp(),
      });
      final created = await docRef.get();
      return AppUserProfile.fromDoc(created);
    }
    return AppUserProfile.fromDoc(doc);
  }

  @override
  Future<void> updateProfile({
    required String uid,
    required String displayName,
    String? bio,
    String? photoUrl,
  }) async {
    // Update Firestore
    await _users.doc(uid).set(
      {
        'displayName': displayName,
        'fullName': displayName,
        'bio': bio,
        'photoURL': photoUrl,
        'updatedAt': FieldValue.serverTimestamp(),
      },
      SetOptions(merge: true),
    );

    // Also update Firebase Auth User profile to keep them in sync
    final currentUser = _auth.currentUser;
    if (currentUser != null && currentUser.uid == uid) {
      try {
        await currentUser.updateDisplayName(displayName);
        if (photoUrl != null && photoUrl.isNotEmpty) {
          await currentUser.updatePhotoURL(photoUrl);
        }
        // Reload to refresh the user object
        await currentUser.reload();
      } catch (e) {
        // If Auth update fails, it's okay - Firestore is source of truth
        print('Failed to update Firebase Auth profile: $e');
      }
    }
  }

  @override
  Stream<UserProfileStats> watchUserStats(String uid) {
    final controller = StreamController<UserProfileStats>();
    int? postsCountFromDoc;
    int? recipesCountFromDoc;
    int? savedCountFromDoc;
    var postsCountLocal = 0;
    var recipesCountLocal = 0;
    var savedCountLocal = 0;
    var isClosed = false;

    void emit() {
      if (isClosed) return;
      controller.add(
        UserProfileStats(
          postsCount: postsCountFromDoc ?? postsCountLocal,
          recipesCount: recipesCountFromDoc ?? recipesCountLocal,
          savedCount: savedCountFromDoc ?? savedCountLocal,
        ),
      );
    }

    final userSub = _users.doc(uid).snapshots().listen((doc) {
      final data = doc.data();
      postsCountFromDoc = (data?['postsCount'] as num?)?.toInt();
      recipesCountFromDoc = (data?['recipesCount'] as num?)?.toInt();
      savedCountFromDoc = (data?['savedCount'] as num?)?.toInt();
      emit();
    }, onError: (e, st) {
      if (e is FirebaseException && e.code == 'permission-denied') {
        emit();
        return;
      }
      controller.addError(e, st);
    });

    final postsSub = watchUserPosts(uid).listen((posts) {
      postsCountLocal = posts.length;
      emit();
    }, onError: controller.addError);

    final recipesSub = watchUserRecipes(uid).listen((recipes) {
      recipesCountLocal = recipes.length;
      emit();
    }, onError: controller.addError);

    final savedSub = _bookmarks(uid).snapshots().listen((snap) {
      savedCountLocal = snap.size;
      emit();
    }, onError: (e, st) {
      if (e is FirebaseException && e.code == 'permission-denied') {
        savedCountLocal = 0;
        emit();
        return;
      }
      controller.addError(e, st);
    });

    controller.onCancel = () async {
      isClosed = true;
      await userSub.cancel();
      await postsSub.cancel();
      await recipesSub.cancel();
      await savedSub.cancel();
      await controller.close();
    };

    return controller.stream;
  }

  @override
  Stream<List<PostSummary>> watchUserPosts(String uid) {
    return _listenWithFallback<PostSummary>(
      primary: _posts
          .where('authorId', isEqualTo: uid)
          .orderBy('createdAt', descending: true),
      fallback: _posts.where('authorId', isEqualTo: uid),
      mapper: (snap) => snap.docs
          .where((doc) {
            final data = doc.data();
            return (data['hidden'] as bool?) != true &&
                (data['deleted'] as bool?) != true;
          })
          .map(_mapPostSummary)
          .toList(growable: false)
        ..sort(
          (a, b) => (b.createdAt ?? DateTime(0))
              .compareTo(a.createdAt ?? DateTime(0)),
        ),
    );
  }

  @override
  Stream<List<RecipeSummary>> watchUserRecipes(String uid) {
    return _listenWithFallback<RecipeSummary>(
      primary: _recipes
          .where('authorId', isEqualTo: uid)
          .orderBy('createdAt', descending: true),
      fallback: _recipes.where('authorId', isEqualTo: uid),
      mapper: (snap) => snap.docs
          .where((doc) {
            final data = doc.data();
            return (data['hidden'] as bool?) != true &&
                (data['deleted'] as bool?) != true;
          })
          .map(_mapRecipeSummary)
          .toList(growable: false)
        ..sort(
          (a, b) => b.createdAt.compareTo(a.createdAt),
        ),
    );
  }

  @override
  Stream<List<SavedItem>> watchUserSavedItems(String uid) {
    late final StreamController<List<SavedItem>> controller;
    StreamSubscription<QuerySnapshot<Map<String, dynamic>>>? sub;

    Future<void> handleSnap(
      QuerySnapshot<Map<String, dynamic>> snap,
    ) async {
      if (snap.docs.isEmpty) {
        controller.add(<SavedItem>[]);
        return;
      }

      final items = snap.docs.map((doc) {
        final data = doc.data();
        final ts = data['bookmarkedAt'] as Timestamp?;
        final targetId = (data['recipeId'] as String?) ?? doc.id;
        final targetType = (data['targetType'] as String?) ?? 'recipe';
        return SavedItem(
          id: doc.id,
          targetId: targetId,
          targetType: targetType,
          createdAt: ts?.toDate(),
        );
      }).toList();

      final recipeIds = items
          .where((item) => item.targetType == 'recipe')
          .map((e) => e.targetId)
          .where((id) => id.isNotEmpty)
          .toSet()
          .toList(growable: false);
      
      final postIds = items
          .where((item) => item.targetType == 'post')
          .map((e) => e.targetId)
          .where((id) => id.isNotEmpty)
          .toSet()
          .toList(growable: false);

      final reelIds = items
          .where((item) => item.targetType == 'reel')
          .map((e) => e.targetId)
          .where((id) => id.isNotEmpty)
          .toSet()
          .toList(growable: false);

      final recipesById = await _fetchRecipesByIds(recipeIds);
      final postsById = await _fetchPostsByIds(postIds);
      final reelsById = await _fetchReelsByIds(reelIds);

      controller.add(
        items
            .map(
              (item) => item.copyWith(
                recipe: recipesById[item.targetId],
                post: postsById[item.targetId],
                reel: reelsById[item.targetId],
              ),
            )
            .toList(growable: false),
      );
    }

    void listen() {
      sub = _bookmarks(uid)
          .orderBy('bookmarkedAt', descending: true)
          .snapshots()
          .listen(
        (snap) {
          handleSnap(snap);
        },
        onError: (e, st) {
          if (e is FirebaseException &&
              (e.code == 'permission-denied' ||
                  e.code == 'failed-precondition')) {
            controller.add(<SavedItem>[]);
            return;
          }
          controller.addError(e, st);
        },
      );
    }

    controller = StreamController<List<SavedItem>>(
      onListen: listen,
      onCancel: () => sub?.cancel(),
    );

    return controller.stream;
  }

  PostSummary _mapPostSummary(DocumentSnapshot<Map<String, dynamic>> doc) {
    final data = doc.data() ?? {};
    final ts = data['createdAt'] as Timestamp?;
    final photoUrls =
        (data['photoURLs'] as List<dynamic>?)?.whereType<String>().toList() ??
            const [];
    return PostSummary(
      id: doc.id,
      title: data['title'] as String? ?? '',
      authorId: data['authorId'] as String? ?? '',
      body: data['body'] as String?,
      photoUrls: _fixUrls(photoUrls),
      tags: (data['tags'] as List<dynamic>?)?.whereType<String>().toList() ??
          const [],
      likesCount: (data['likesCount'] as num?)?.toInt() ?? 0,
      commentsCount: (data['commentsCount'] as num?)?.toInt() ?? 0,
      hidden: data['hidden'] as bool? ?? false,
      deleted: data['deleted'] as bool? ?? false,
      createdAt: ts?.toDate(),
    );
  }

  RecipeSummary _mapRecipeSummary(DocumentSnapshot<Map<String, dynamic>> doc) {
    final data = doc.data() ?? {};
    final createdAt = (data['createdAt'] as Timestamp?)?.toDate() ??
        DateTime.fromMillisecondsSinceEpoch(0);
    final photoUrls =
        (data['photoURLs'] as List<dynamic>?)?.whereType<String>().toList();
    final firstPhoto = photoUrls != null && photoUrls.isNotEmpty
        ? _fixUrl(photoUrls.first)
        : null;
    final singlePhoto = _fixUrl(data['photoURL'] as String?);
    final coverUrl = _fixUrl(data['coverURL'] as String?);
    final coverUrlLower = _fixUrl(data['coverUrl'] as String?);

    return RecipeSummary(
      id: doc.id,
      title: data['title'] as String? ?? '',
      authorId: data['authorId'] as String? ?? '',
      photoUrl: coverUrl ?? coverUrlLower ?? singlePhoto ?? firstPhoto ?? '',
      avgRating: (data['avgRating'] as num?)?.toDouble(),
      ratingsCount: (data['ratingsCount'] as num?)?.toInt() ?? 0,
      likesCount: (data['likesCount'] as num?)?.toInt() ?? 0,
      commentsCount: (data['commentsCount'] as num?)?.toInt() ?? 0,
      cookTimeMinutes: (data['cookTimeMinutes'] as num?)?.toInt(),
      createdAt: createdAt,
    );
  }

  Future<Map<String, RecipeSummary>> _fetchRecipesByIds(
    List<String> recipeIds,
  ) async {
    if (recipeIds.isEmpty) return {};
    final batches = <List<String>>[];
    const chunkSize = 10;
    for (var i = 0; i < recipeIds.length; i += chunkSize) {
      batches.add(
        recipeIds.sublist(
          i,
          i + chunkSize > recipeIds.length ? recipeIds.length : i + chunkSize,
        ),
      );
    }

    final results = <String, RecipeSummary>{};
    for (final batch in batches) {
      final snap =
          await _recipes.where(FieldPath.documentId, whereIn: batch).get();
      for (final doc in snap.docs) {
        final summary = _mapRecipeSummary(doc);
        results[doc.id] = summary;
      }
    }
    return results;
  }

  Future<Map<String, PostSummary>> _fetchPostsByIds(
    List<String> postIds,
  ) async {
    if (postIds.isEmpty) return {};
    final results = <String, PostSummary>{};
    
    // Batch fetch posts (limit 10 for whereIn)
    for (var i = 0; i < postIds.length; i += 10) {
      final chunk = postIds.sublist(i, 
        i + 10 > postIds.length ? postIds.length : i + 10);
      final snap = await _posts.where(FieldPath.documentId, whereIn: chunk).get();
      for (final doc in snap.docs) {
        results[doc.id] = _mapPostSummary(doc);
      }
    }
    return results;
  }

  Future<Map<String, Reel>> _fetchReelsByIds(
    List<String> reelIds,
  ) async {
    if (reelIds.isEmpty) return {};
    final results = <String, Reel>{};
    
    // Batch fetch reels (limit 10 for whereIn)
    for (var i = 0; i < reelIds.length; i += 10) {
      final chunk = reelIds.sublist(i, 
        i + 10 > reelIds.length ? reelIds.length : i + 10);
      final snap = await _reels.where(FieldPath.documentId, whereIn: chunk).get();
      for (final doc in snap.docs) {
        results[doc.id] = Reel.fromDoc(doc);
      }
    }
    return results;
  }

  List<String> _fixUrls(List<String> urls) {
    return urls
        .map(
          (u) => u.replaceAll('vuadaubepthuduc.appspot.com',
              'vuadaubepthuduc.firebasestorage.app'),
        )
        .toList();
  }

  String? _fixUrl(String? url) {
    if (url == null) return null;
    return url.replaceAll(
        'vuadaubepthuduc.appspot.com', 'vuadaubepthuduc.firebasestorage.app');
  }

  Stream<List<T>> _listenWithFallback<T>({
    required Query<Map<String, dynamic>> primary,
    required Query<Map<String, dynamic>> fallback,
    required List<T> Function(QuerySnapshot<Map<String, dynamic>>) mapper,
  }) {
    late final StreamController<List<T>> controller;
    StreamSubscription<QuerySnapshot<Map<String, dynamic>>>? sub;

    void listen(Query<Map<String, dynamic>> query, {required bool isFallback}) {
      sub = query.snapshots().listen(
        (snap) => controller.add(mapper(snap)),
        onError: (e, st) {
          if (e is FirebaseException &&
              (e.code == 'failed-precondition' ||
                  e.code == 'permission-denied')) {
            if (!isFallback) {
              sub?.cancel();
              listen(fallback, isFallback: true);
            } else {
              controller.add(<T>[]);
            }
          } else {
            controller.addError(e, st);
          }
        },
      );
    }

    controller = StreamController<List<T>>(
      onListen: () => listen(primary, isFallback: false),
      onCancel: () => sub?.cancel(),
    );

    return controller.stream;
  }
}
