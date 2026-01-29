import 'package:cloud_firestore/cloud_firestore.dart';

enum AdminContentType { post, recipe, reel }

class AdminContentItem {
  final String id;
  final AdminContentType type;
  final String title;
  final String authorId;
  final String authorName; // Display name of the author
  final DateTime createdAt;
  final bool hidden;
  final bool isHiddenPendingReview;
  final int reportsCount;
  final bool isSensitive;

  const AdminContentItem({
    required this.id,
    required this.type,
    required this.title,
    required this.authorId,
    required this.authorName,
    required this.createdAt,
    required this.hidden,
    required this.isHiddenPendingReview,
    required this.reportsCount,
    required this.isSensitive,
  });

  factory AdminContentItem.fromPostDoc(
    DocumentSnapshot<Map<String, dynamic>> doc,
  ) {
    return _fromDoc(doc, type: AdminContentType.post);
  }

  factory AdminContentItem.fromRecipeDoc(
    DocumentSnapshot<Map<String, dynamic>> doc,
  ) {
    return _fromDoc(doc, type: AdminContentType.recipe);
  }

  factory AdminContentItem.fromReelDoc(
    DocumentSnapshot<Map<String, dynamic>> doc,
  ) {
    return _fromDoc(doc, type: AdminContentType.reel);
  }

  static AdminContentItem _fromDoc(
    DocumentSnapshot<Map<String, dynamic>> doc, {
    required AdminContentType type,
  }) {
    final data = doc.data() ?? {};
    final createdAtValue = data['createdAt'];
    final createdAt = switch (createdAtValue) {
      Timestamp ts => ts.toDate(),
      DateTime dt => dt,
      _ => DateTime.fromMillisecondsSinceEpoch(0),
    };

    final reports = data['reportsCount'];
    final reportsCount = switch (reports) {
      int v => v,
      num v => v.toInt(),
      _ => 0,
    };

    return AdminContentItem(
      id: doc.id,
      type: type,
      title: (data['title'] as String?)?.trim().isNotEmpty == true
          ? (data['title'] as String).trim()
          : '(No title)',
      authorId: (data['authorId'] as String?) ?? '',
      authorName: '', // Will be resolved separately
      createdAt: createdAt,
      hidden: data['hidden'] as bool? ?? false,
      isHiddenPendingReview: data['isHiddenPendingReview'] as bool? ?? false,
      reportsCount: reportsCount,
      isSensitive: data['isSensitive'] as bool? ?? false,
    );
  }

  AdminContentItem copyWith({
    String? authorName,
  }) {
    return AdminContentItem(
      id: id,
      type: type,
      title: title,
      authorId: authorId,
      authorName: authorName ?? this.authorName,
      createdAt: createdAt,
      hidden: hidden,
      isHiddenPendingReview: isHiddenPendingReview,
      reportsCount: reportsCount,
      isSensitive: isSensitive,
    );
  }
}

enum ContentFilter { all, hidden, reported, pendingReview }

abstract class AdminContentRepository {
  Stream<List<AdminContentItem>> watchPosts(ContentFilter filter);
  Stream<List<AdminContentItem>> watchRecipes(ContentFilter filter);
  Stream<List<AdminContentItem>> watchReels(ContentFilter filter);

  Future<void> approveContent(AdminContentItem item);
  Future<void> hideContent(AdminContentItem item);
  Future<void> deleteContent(AdminContentItem item);
}

class FirestoreAdminContentRepository implements AdminContentRepository {
  FirestoreAdminContentRepository({FirebaseFirestore? firestore})
      : _firestore = firestore ?? FirebaseFirestore.instance;

  final FirebaseFirestore _firestore;

  CollectionReference<Map<String, dynamic>> get _posts =>
      _firestore.collection('posts');

  CollectionReference<Map<String, dynamic>> get _recipes =>
      _firestore.collection('recipes');

  CollectionReference<Map<String, dynamic>> get _reels =>
      _firestore.collection('reels');

  @override
  Stream<List<AdminContentItem>> watchPosts(ContentFilter filter) {
    final query = _buildQuery(_posts, filter);
    return query.snapshots().map(
          (snapshot) => snapshot.docs
              .map((doc) => AdminContentItem.fromPostDoc(doc))
              .toList(),
        );
  }

  @override
  Stream<List<AdminContentItem>> watchRecipes(ContentFilter filter) {
    final query = _buildQuery(_recipes, filter);
    return query.snapshots().map(
          (snapshot) => snapshot.docs
              .map((doc) => AdminContentItem.fromRecipeDoc(doc))
              .toList(),
        );
  }

  @override
  Stream<List<AdminContentItem>> watchReels(ContentFilter filter) {
    final query = _buildQuery(_reels, filter);
    return query.snapshots().map(
          (snapshot) => snapshot.docs
              .map((doc) => AdminContentItem.fromReelDoc(doc))
              .toList(),
        );
  }

  Query<Map<String, dynamic>> _buildQuery(
    CollectionReference<Map<String, dynamic>> collection,
    ContentFilter filter,
  ) {
    Query<Map<String, dynamic>> query = collection;
    switch (filter) {
      case ContentFilter.all:
        break;
      case ContentFilter.hidden:
        query = query.where('hidden', isEqualTo: true);
      case ContentFilter.reported:
        query = query.where('reportsCount', isGreaterThan: 0);
      case ContentFilter.pendingReview:
        query = query.where('isHiddenPendingReview', isEqualTo: true);
    }
    return query.orderBy('createdAt', descending: true).limit(50);
  }

  @override
  Future<void> approveContent(AdminContentItem item) async {
    final docRef = _docForItem(item);
    await docRef.update({
      'hidden': false,
      'isHiddenPendingReview': false,
    });
  }

  @override
  Future<void> hideContent(AdminContentItem item) async {
    final docRef = _docForItem(item);
    await docRef.update({'hidden': true});
  }

  @override
  Future<void> deleteContent(AdminContentItem item) async {
    final docRef = _docForItem(item);
    await docRef.delete();
  }

  DocumentReference<Map<String, dynamic>> _docForItem(AdminContentItem item) {
    switch (item.type) {
      case AdminContentType.post:
        return _posts.doc(item.id);
      case AdminContentType.recipe:
        return _recipes.doc(item.id);
      case AdminContentType.reel:
        return _reels.doc(item.id);
    }
  }
}

