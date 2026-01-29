import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'reel_model.dart';

final reelRepositoryProvider = Provider<ReelRepository>((ref) {
  return ReelRepository(
    firestore: FirebaseFirestore.instance,
    auth: FirebaseAuth.instance,
  );
});

class ReelRepository {
  ReelRepository({
    required FirebaseFirestore firestore,
    required FirebaseAuth auth,
  })  : _firestore = firestore,
        _auth = auth;

  final FirebaseFirestore _firestore;
  final FirebaseAuth _auth;

  CollectionReference<Map<String, dynamic>> get _reelsCollection =>
      _firestore.collection('reels');

  /// Get a stream of reels for the feed
  Stream<List<Reel>> getReelsStream({
    int limit = 20,
    DocumentSnapshot? startAfter,
  }) {
    // Temporarily removing .where('hidden', isEqualTo: false) to avoid index error
    Query<Map<String, dynamic>> query = _reelsCollection
        .orderBy('createdAt', descending: true)
        .limit(limit);

    if (startAfter != null) {
      query = query.startAfterDocument(startAfter);
    }

    return query.snapshots().map((snapshot) {
      return snapshot.docs
          .map((doc) => Reel.fromDoc(doc))
          .where((reel) => !reel.hidden)
          .toList();
    });
  }

  /// Get a single reel by ID
  Future<Reel?> getReelById(String reelId) async {
    try {
      final doc = await _reelsCollection.doc(reelId).get();
      if (!doc.exists) return null;
      return Reel.fromDoc(doc);
    } catch (e) {
      return null;
    }
  }

  /// Get reels by a specific user
  Stream<List<Reel>> getReelsByUser(String userId) {
    return _reelsCollection
        .where('authorId', isEqualTo: userId)
        .snapshots()
        .map((snapshot) {
      final reels = snapshot.docs
          .map((doc) => Reel.fromDoc(doc))
          .where((reel) => !reel.hidden)
          .toList();
      
      // Sort in Dart to avoid index error
      reels.sort((a, b) {
        final aDate = a.createdAt ?? DateTime.fromMillisecondsSinceEpoch(0);
        final bDate = b.createdAt ?? DateTime.fromMillisecondsSinceEpoch(0);
        return bDate.compareTo(aDate);
      });
      return reels;
    });
  }

  /// Create a new reel
  Future<String> createReel(Reel reel) async {
    final user = _auth.currentUser;
    if (user == null) throw Exception('User not authenticated');

    final docRef = await _reelsCollection.add(
      reel.toMapForCreate(authorId: user.uid),
    );

    return docRef.id;
  }

  /// Update an existing reel
  Future<void> updateReel(String reelId, Reel reel) async {
    final user = _auth.currentUser;
    if (user == null) throw Exception('User not authenticated');

    final doc = await _reelsCollection.doc(reelId).get();
    if (!doc.exists) throw Exception('Reel not found');

    final existingReel = Reel.fromDoc(doc);
    if (existingReel.authorId != user.uid) {
      throw Exception('Not authorized to update this reel');
    }

    await _reelsCollection.doc(reelId).update(reel.toMapForUpdate());
  }

  /// Delete a reel
  Future<void> deleteReel(String reelId) async {
    final user = _auth.currentUser;
    if (user == null) throw Exception('User not authenticated');

    final doc = await _reelsCollection.doc(reelId).get();
    if (!doc.exists) throw Exception('Reel not found');

    final reel = Reel.fromDoc(doc);
    if (reel.authorId != user.uid) {
      throw Exception('Not authorized to delete this reel');
    }

    await _reelsCollection.doc(reelId).delete();
  }

  /// Increment view count
  Future<void> incrementViewCount(String reelId) async {
    await _reelsCollection.doc(reelId).update({
      'viewsCount': FieldValue.increment(1),
    });
  }

  /// Increment share count
  Future<void> incrementShareCount(String reelId) async {
    await _reelsCollection.doc(reelId).update({
      'sharesCount': FieldValue.increment(1),
    });
  }

  /// Get trending reels (most viewed in last 7 days)
  Stream<List<Reel>> getTrendingReels({int limit = 20}) {
    final sevenDaysAgo = DateTime.now().subtract(const Duration(days: 7));
    // Simplified query to avoid index errors
    return _reelsCollection
        .where('createdAt', isGreaterThan: Timestamp.fromDate(sevenDaysAgo))
        .orderBy('createdAt', descending: true)
        .snapshots()
        .map((snapshot) {
      final reels = snapshot.docs
          .map((doc) => Reel.fromDoc(doc))
          .where((reel) => !reel.hidden)
          .toList();
      
      // Secondary sort in Dart
      reels.sort((a, b) {
        final aViews = a.viewsCount;
        final bViews = b.viewsCount;
        if (aViews != bViews) return bViews.compareTo(aViews);
        final aDate = a.createdAt ?? DateTime.fromMillisecondsSinceEpoch(0);
        final bDate = b.createdAt ?? DateTime.fromMillisecondsSinceEpoch(0);
        return bDate.compareTo(aDate);
      });
      return reels.take(limit).toList();
    });
  }

  /// Search reels
  Stream<List<Reel>> searchReels(String query) {
    final tokens = query.toLowerCase().split(' ');
    // Simplified query to avoid index errors
    return _reelsCollection
        .where('searchTokens', arrayContainsAny: tokens)
        .snapshots()
        .map((snapshot) {
      final reels = snapshot.docs
          .map((doc) => Reel.fromDoc(doc))
          .where((reel) => !reel.hidden)
          .toList();
      
      // Sort in Dart
      reels.sort((a, b) {
        final aDate = a.createdAt ?? DateTime.fromMillisecondsSinceEpoch(0);
        final bDate = b.createdAt ?? DateTime.fromMillisecondsSinceEpoch(0);
        return bDate.compareTo(aDate);
      });
      return reels.take(20).toList();
    });
  }
}
