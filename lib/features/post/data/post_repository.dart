import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_storage/firebase_storage.dart';

import '../../feed/data/post_model.dart';

abstract class PostRepository {
  Future<String> createPost({
    required String authorId,
    required String title,
    required String body,
    required List<String> tags,
    required List<String> photoUrls,
    List<String> searchTokens,
  });

  Future<void> updatePost({
    required String postId,
    required String title,
    required String body,
    required List<String> tags,
    required List<String> photoUrls,
    List<String> searchTokens,
  });

  Future<void> softDeletePost(String postId);

  Future<void> hardDeletePost({
    required String postId,
    required List<String> photoUrls,
  });

  Future<Post?> getPostById(String postId);
}

class PostRepositoryImpl implements PostRepository {
  PostRepositoryImpl({
    FirebaseFirestore? firestore,
    FirebaseStorage? storage,
  })  : _firestore = firestore ?? FirebaseFirestore.instance,
        _storage = storage ?? FirebaseStorage.instance;

  final FirebaseFirestore _firestore;
  final FirebaseStorage _storage;

  CollectionReference<Map<String, dynamic>> get _posts =>
      _firestore.collection('posts');

  List<String> _generateTokens(String title, List<String> tags) {
    final text = '$title ${tags.join(' ')}'
        .toLowerCase()
        .replaceAll(RegExp(r'[^a-z0-9\s]'), ' ');
    final parts = text.split(RegExp(r'\s+')).where((e) => e.length > 1);
    return parts.toSet().toList();
  }

  @override
  Future<String> createPost({
    required String authorId,
    required String title,
    required String body,
    required List<String> tags,
    required List<String> photoUrls,
    List<String> searchTokens = const [],
  }) async {
    final docRef = _posts.doc();
    final tokens = searchTokens.isNotEmpty
        ? searchTokens
        : _generateTokens(title, tags);
    await docRef.set({
      'authorId': authorId,
      'title': title,
      'body': body,
      'photoURLs': photoUrls,
      'tags': tags,
      'searchTokens': tokens,
      'likesCount': 0,
      'commentsCount': 0,
      'sharesCount': 0,
      'hidden': false,
      'createdAt': FieldValue.serverTimestamp(),
      'updatedAt': FieldValue.serverTimestamp(),
    });
    return docRef.id;
  }

  @override
  Future<void> updatePost({
    required String postId,
    required String title,
    required String body,
    required List<String> tags,
    required List<String> photoUrls,
    List<String> searchTokens = const [],
  }) async {
    final tokens = searchTokens.isNotEmpty
        ? searchTokens
        : _generateTokens(title, tags);
    await _posts.doc(postId).update({
      'title': title,
      'body': body,
      'photoURLs': photoUrls,
      'tags': tags,
      'searchTokens': tokens,
      'updatedAt': FieldValue.serverTimestamp(),
    });
  }

  @override
  Future<void> softDeletePost(String postId) async {
    await _posts.doc(postId).update({
      'hidden': true,
      'updatedAt': FieldValue.serverTimestamp(),
    });
  }

  @override
  Future<void> hardDeletePost({
    required String postId,
    required List<String> photoUrls,
  }) async {
    for (final url in photoUrls) {
      try {
        await _storage.refFromURL(url).delete();
      } catch (_) {
        // ignore errors on individual deletes
      }
    }
    await _posts.doc(postId).delete();
  }

  @override
  Future<Post?> getPostById(String postId) async {
    final doc = await _posts.doc(postId).get();
    if (!doc.exists) return null;
    return Post.fromDoc(doc);
  }
}
