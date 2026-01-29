import 'package:cloud_firestore/cloud_firestore.dart';

class Post {
  Post({
    required this.id,
    required this.authorId,
    required this.title,
    required this.body,
    required this.photoURLs,
    required this.tags,
    required this.hidden,
    required this.searchTokens,
    required this.likesCount,
    required this.commentsCount,
    required this.sharesCount,
    required this.createdAt,
    this.updatedAt,
    this.snapshot,
  });

  final String id;
  final String authorId;
  final String title;
  final String body;
  final List<String> photoURLs;
  final List<String> tags;
  final bool hidden;
  final List<String> searchTokens;
  final int likesCount;
  final int commentsCount;
  final int sharesCount;
  final DateTime? createdAt;
  final DateTime? updatedAt;
  final DocumentSnapshot<Map<String, dynamic>>? snapshot;

  factory Post.fromDoc(DocumentSnapshot<Map<String, dynamic>> doc) {
    final data = doc.data() ?? {};
    final Timestamp? createdTs = data['createdAt'] as Timestamp?;
    final Timestamp? updatedTs = data['updatedAt'] as Timestamp?;
    return Post(
      id: doc.id,
      authorId: data['authorId'] as String? ?? '',
      title: data['title'] as String? ?? '',
      body: data['body'] as String? ?? '',
      photoURLs: _fixedUrls(
        (data['photoURLs'] as List<dynamic>?)?.whereType<String>().toList() ??
            const [],
      ),
      tags: (data['tags'] as List<dynamic>?)?.whereType<String>().toList() ??
          const [],
      hidden: data['hidden'] as bool? ?? false,
      searchTokens: (data['searchTokens'] as List<dynamic>?)
              ?.whereType<String>()
              .toList() ??
          const [],
      likesCount: (data['likesCount'] as num?)?.toInt() ?? 0,
      commentsCount: (data['commentsCount'] as num?)?.toInt() ?? 0,
      sharesCount: (data['sharesCount'] as num?)?.toInt() ?? 0,
      createdAt: createdTs?.toDate(),
      updatedAt: updatedTs?.toDate(),
      snapshot: doc,
    );
  }

  Map<String, dynamic> toMapForCreate({required String authorId}) {
    return {
      'authorId': authorId,
      'title': title,
      'body': body,
      'photoURLs': photoURLs,
      'tags': tags,
      'searchTokens': searchTokens,
      'likesCount': likesCount,
      'commentsCount': commentsCount,
      'sharesCount': sharesCount,
      'hidden': hidden,
      'createdAt': FieldValue.serverTimestamp(),
      'updatedAt': FieldValue.serverTimestamp(),
    };
  }

  Map<String, dynamic> toMapForUpdate() {
    return {
      'title': title,
      'body': body,
      'photoURLs': photoURLs,
      'tags': tags,
      'searchTokens': searchTokens,
      'hidden': hidden,
      'updatedAt': FieldValue.serverTimestamp(),
    };
  }

  @override
  String toString() {
    return 'Post(id: $id, title: $title, authorId: $authorId, likes: $likesCount)';
  }

  static List<String> _fixedUrls(List<String> urls) {
    return urls
        .map((u) => u.replaceAll('vuadaubepthuduc.appspot.com',
            'vuadaubepthuduc.firebasestorage.app'))
        .toList();
  }
}
