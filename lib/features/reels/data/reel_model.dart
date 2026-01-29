import 'package:cloud_firestore/cloud_firestore.dart';

class Reel {
  Reel({
    required this.id,
    required this.authorId,
    required this.videoUrl,
    required this.thumbnailUrl,
    required this.title,
    required this.description,
    required this.tags,
    required this.hidden,
    required this.searchTokens,
    required this.likesCount,
    required this.commentsCount,
    required this.sharesCount,
    required this.viewsCount,
    required this.duration,
    required this.createdAt,
    this.updatedAt,
    this.snapshot,
  });

  final String id;
  final String authorId;
  final String videoUrl;
  final String thumbnailUrl;
  final String title;
  final String description;
  final List<String> tags;
  final bool hidden;
  final List<String> searchTokens;
  final int likesCount;
  final int commentsCount;
  final int sharesCount;
  final int viewsCount;
  final int duration; // in seconds
  final DateTime? createdAt;
  final DateTime? updatedAt;
  final DocumentSnapshot<Map<String, dynamic>>? snapshot;

  factory Reel.fromDoc(DocumentSnapshot<Map<String, dynamic>> doc) {
    final data = doc.data() ?? {};
    final Timestamp? createdTs = data['createdAt'] as Timestamp?;
    final Timestamp? updatedTs = data['updatedAt'] as Timestamp?;
    return Reel(
      id: doc.id,
      authorId: data['authorId'] as String? ?? '',
      videoUrl: _fixedUrl(data['videoUrl'] as String? ?? ''),
      thumbnailUrl: _fixedUrl(data['thumbnailUrl'] as String? ?? ''),
      title: data['title'] as String? ?? '',
      description: data['description'] as String? ?? '',
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
      viewsCount: (data['viewsCount'] as num?)?.toInt() ?? 0,
      duration: (data['duration'] as num?)?.toInt() ?? 0,
      createdAt: createdTs?.toDate(),
      updatedAt: updatedTs?.toDate(),
      snapshot: doc,
    );
  }

  Map<String, dynamic> toMapForCreate({required String authorId}) {
    return {
      'authorId': authorId,
      'videoUrl': videoUrl,
      'thumbnailUrl': thumbnailUrl,
      'title': title,
      'description': description,
      'tags': tags,
      'searchTokens': searchTokens,
      'likesCount': likesCount,
      'commentsCount': commentsCount,
      'sharesCount': sharesCount,
      'viewsCount': viewsCount,
      'duration': duration,
      'hidden': hidden,
      'createdAt': FieldValue.serverTimestamp(),
      'updatedAt': FieldValue.serverTimestamp(),
    };
  }

  Map<String, dynamic> toMapForUpdate() {
    return {
      'title': title,
      'description': description,
      'tags': tags,
      'videoUrl': videoUrl,
      'thumbnailUrl': thumbnailUrl,
      'searchTokens': searchTokens,
      'hidden': hidden,
      'updatedAt': FieldValue.serverTimestamp(),
    };
  }

  Reel copyWith({
    String? id,
    String? authorId,
    String? videoUrl,
    String? thumbnailUrl,
    String? title,
    String? description,
    List<String>? tags,
    bool? hidden,
    List<String>? searchTokens,
    int? likesCount,
    int? commentsCount,
    int? sharesCount,
    int? viewsCount,
    int? duration,
    DateTime? createdAt,
    DateTime? updatedAt,
    DocumentSnapshot<Map<String, dynamic>>? snapshot,
  }) {
    return Reel(
      id: id ?? this.id,
      authorId: authorId ?? this.authorId,
      videoUrl: videoUrl ?? this.videoUrl,
      thumbnailUrl: thumbnailUrl ?? this.thumbnailUrl,
      title: title ?? this.title,
      description: description ?? this.description,
      tags: tags ?? this.tags,
      hidden: hidden ?? this.hidden,
      searchTokens: searchTokens ?? this.searchTokens,
      likesCount: likesCount ?? this.likesCount,
      commentsCount: commentsCount ?? this.commentsCount,
      sharesCount: sharesCount ?? this.sharesCount,
      viewsCount: viewsCount ?? this.viewsCount,
      duration: duration ?? this.duration,
      createdAt: createdAt ?? this.createdAt,
      updatedAt: updatedAt ?? this.updatedAt,
      snapshot: snapshot ?? this.snapshot,
    );
  }

  @override
  String toString() {
    return 'Reel(id: $id, title: $title, authorId: $authorId, likes: $likesCount, views: $viewsCount)';
  }

  static String _fixedUrl(String url) {
    return url.replaceAll('vuadaubepthuduc.appspot.com',
        'vuadaubepthuduc.firebasestorage.app');
  }
}
