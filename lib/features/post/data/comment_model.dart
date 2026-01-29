import 'package:cloud_firestore/cloud_firestore.dart';

class Comment {
  Comment({
    required this.id,
    required this.authorId,
    required this.content,
    required this.createdAt,
    this.imageUrl,
  });

  final String id;
  final String authorId;
  final String content;
  final String? imageUrl;
  final DateTime? createdAt;

  factory Comment.fromDoc(DocumentSnapshot<Map<String, dynamic>> doc) {
    final data = doc.data() ?? {};
    final Timestamp? createdTs = data['createdAt'] as Timestamp?;
    return Comment(
      id: doc.id,
      authorId: data['authorId'] as String? ?? '',
      content: data['content'] as String? ?? '',
      imageUrl: data['imageUrl'] as String?,
      createdAt: createdTs?.toDate(),
    );
  }
}
