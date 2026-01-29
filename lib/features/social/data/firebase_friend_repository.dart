import 'dart:async';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';

import '../domain/friend_models.dart';
import '../domain/friend_repository.dart';
import '../../profile/domain/user_ban_guard.dart';
import '../../profile/data/firebase_profile_repository.dart';
import '../../notifications/application/notification_service.dart';
import '../../notifications/application/anti_spam_service.dart';

class FirebaseFriendRepository implements FriendRepository {
  FirebaseFriendRepository({
    FirebaseFirestore? firestore,
    FirebaseAuth? auth,
    UserBanGuard? userBanGuard,
  })  : _firestore = firestore ?? FirebaseFirestore.instance,
        _auth = auth ?? FirebaseAuth.instance,
        _banGuard = userBanGuard ??
            UserBanGuard(profileRepository: FirebaseProfileRepository());

  final FirebaseFirestore _firestore;
  final FirebaseAuth _auth;
  final UserBanGuard _banGuard;
  
  // Lazy getters to avoid initialization issues
  NotificationService get _notificationService => NotificationService();
  AntiSpamService get _antiSpamService => AntiSpamService();

  CollectionReference<Map<String, dynamic>> _follows(String uid) =>
      _firestore.collection('follows').doc(uid).collection('targets');

  CollectionReference<Map<String, dynamic>> get _friendRequests =>
      _firestore.collection('friendRequests');

  CollectionReference<Map<String, dynamic>> _friends(String uid) =>
      _firestore.collection('friends').doc(uid).collection('items');

  String? get _currentUid => _auth.currentUser?.uid;

  Future<void> _ensureNotBanned() async {
    await _banGuard.ensureNotBanned();
  }

  @override
  Future<void> followUser(String targetUid) async {
    final uid = _currentUid;
    if (uid == null || targetUid.isEmpty || uid == targetUid) {
      return;
    }
    
    // Check for spam before following
    final canFollow = await _antiSpamService.checkAndLogAction(
      SpamActionType.follow,
      contentId: targetUid,
    );
    if (!canFollow) {
      throw Exception('Spam detected. Please slow down.');
    }
    
    await _follows(uid).doc(targetUid).set({
      'createdAt': FieldValue.serverTimestamp(),
    }, SetOptions(merge: true));
    
    // Send follow notification
    try {
      await _notificationService.notifyFollow(
        targetUserId: targetUid,
      );
    } catch (e) {
      // Silently fail notification
      print('⚠️ [FriendRepo] Follow notification failed: $e');
    }
    
    // TODO: Firestore Rules should allow only account owner to write their follows.
  }

  @override
  Future<void> unfollowUser(String targetUid) async {
    final uid = _currentUid;
    if (uid == null || targetUid.isEmpty || uid == targetUid) return;
    await _follows(uid).doc(targetUid).delete();
  }

  @override
  Stream<bool> watchIsFollowing(String targetUid) {
    final uid = _currentUid;
    if (uid == null || targetUid.isEmpty || uid == targetUid) {
      return Stream<bool>.value(false);
    }
    return _follows(uid)
        .doc(targetUid)
        .snapshots()
        .map((doc) => doc.exists);
  }

  @override
  Future<void> sendFriendRequest(String targetUid) async {
    await _ensureNotBanned();
    final requesterId = _currentUid;
    if (requesterId == null) return;
    if (targetUid.isEmpty || targetUid == requesterId) return;

    // Check for spam before sending friend request
    final canSend = await _antiSpamService.checkAndLogAction(
      SpamActionType.friendRequest,
      contentId: targetUid,
    );
    if (!canSend) {
      throw Exception('Spam detected. You are sending too many friend requests.');
    }

    // Prevent duplicate pending requests between the same pair.
    final pending = await _friendRequests
        .where('requesterId', isEqualTo: requesterId)
        .where('targetId', isEqualTo: targetUid)
        .where('status', isEqualTo: 'pending')
        .limit(1)
        .get();
    if (pending.docs.isNotEmpty) return;

    await _friendRequests.add({
      'requesterId': requesterId,
      'targetId': targetUid,
      'status': 'pending',
      'createdAt': FieldValue.serverTimestamp(),
      'respondedAt': null,
      'lastUpdatedAt': FieldValue.serverTimestamp(),
    });
    
    // Clean up any old friend request notifications before sending new one
    try {
      await _notificationService.deleteFriendRequestNotification(
        targetUserId: targetUid,
        requesterId: requesterId,
      );
    } catch (_) {
      // Ignore cleanup errors
    }
    
    // Send notification to target user
    try {
      await _notificationService.notifyFriendRequest(
        recipientId: targetUid,
      );
    } catch (_) {}
    
    // TODO: Firestore Rules should ensure only requester can create/cancel their requests.
  }

  @override
  Future<void> cancelFriendRequest(String requestId) async {
    await _ensureNotBanned();
    final uid = _currentUid;
    if (uid == null || requestId.isEmpty) return;
    final docRef = _friendRequests.doc(requestId);
    
    String? targetId;
    
    await _firestore.runTransaction((tx) async {
      final snap = await tx.get(docRef);
      if (!snap.exists) return;
      final data = snap.data() ?? {};
      if (data['requesterId'] != uid) return;
      if ((data['status'] as String?) != 'pending') return;
      
      // Extract targetId before updating
      targetId = data['targetId'] as String?;
      
      tx.update(docRef, {
        'status': 'cancelled',
        'respondedAt': FieldValue.serverTimestamp(),
        'lastUpdatedAt': FieldValue.serverTimestamp(),
      });
    });
    
    // Delete the friend request notification from target's notifications
    if (targetId != null && targetId!.isNotEmpty) {
      try {
        await _notificationService.deleteFriendRequestNotification(
          targetUserId: targetId!,
          requesterId: uid,
        );
      } catch (_) {
        // Ignore notification deletion errors
      }
    }
  }

  @override
  Future<void> acceptFriendRequest(String requestId) async {
    await _ensureNotBanned();
    final uid = _currentUid;
    if (uid == null || requestId.isEmpty) return;
    final docRef = _friendRequests.doc(requestId);

    await _firestore.runTransaction((tx) async {
      final snap = await tx.get(docRef);
      if (!snap.exists) return;
      final data = snap.data() ?? {};
      final requesterId = data['requesterId'] as String? ?? '';
      final targetId = data['targetId'] as String? ?? '';
      final status = data['status'] as String? ?? '';
      if (status != 'pending') return;
      if (targetId != uid || requesterId.isEmpty) return;

      final now = FieldValue.serverTimestamp();
      final requesterFriendRef = _friends(requesterId).doc(targetId);
      final targetFriendRef = _friends(targetId).doc(requesterId);

      tx.set(requesterFriendRef, {'createdAt': now}, SetOptions(merge: true));
      tx.set(targetFriendRef, {'createdAt': now}, SetOptions(merge: true));

      // Auto follow both sides when becoming friends.
      tx.set(_follows(requesterId).doc(targetId), {'createdAt': now},
          SetOptions(merge: true));
      tx.set(_follows(targetId).doc(requesterId), {'createdAt': now},
          SetOptions(merge: true));

      tx.update(docRef, {
        'status': 'accepted',
        'respondedAt': now,
        'lastUpdatedAt': now,
      });
    });
    
    // Send notification to requester that their request was accepted
    final requestDoc = await docRef.get();
    final requesterId = (requestDoc.data()?['requesterId'] as String?) ?? '';
    if (requesterId.isNotEmpty) {
      _notificationService.notifyFriendAccepted(
        recipientId: requesterId,
      ).catchError((_) {}); // Ignore notification errors
    }
    
    // TODO: Firestore/Functions rules should enforce that only targetId can accept.
  }

  @override
  Future<void> rejectFriendRequest(String requestId) async {
    await _ensureNotBanned();
    final uid = _currentUid;
    if (uid == null || requestId.isEmpty) return;
    final docRef = _friendRequests.doc(requestId);
    await _firestore.runTransaction((tx) async {
      final snap = await tx.get(docRef);
      if (!snap.exists) return;
      final data = snap.data() ?? {};
      if (data['targetId'] != uid) return;
      if ((data['status'] as String?) != 'pending') return;
      tx.update(docRef, {
        'status': 'rejected',
        'respondedAt': FieldValue.serverTimestamp(),
        'lastUpdatedAt': FieldValue.serverTimestamp(),
      });
    });
  }

  @override
  Stream<List<FriendRequest>> watchIncomingRequests() {
    final uid = _currentUid;
    if (uid == null) return Stream<List<FriendRequest>>.value(const []);
    return _friendRequests
        .where('targetId', isEqualTo: uid)
        .snapshots()
        .map((snap) {
      final requests = snap.docs.map(FriendRequest.fromDoc).toList();
      requests.sort(
        (a, b) => (b.createdAt ?? DateTime(0)).compareTo(a.createdAt ?? DateTime(0)),
      );
      return requests;
    });
  }

  @override
  Stream<List<FriendRequest>> watchOutgoingRequests() {
    final uid = _currentUid;
    if (uid == null) return Stream<List<FriendRequest>>.value(const []);
    return _friendRequests
        .where('requesterId', isEqualTo: uid)
        .snapshots()
        .map((snap) {
      final requests = snap.docs.map(FriendRequest.fromDoc).toList();
      requests.sort(
        (a, b) => (b.createdAt ?? DateTime(0)).compareTo(a.createdAt ?? DateTime(0)),
      );
      return requests;
    });
  }

  @override
  Stream<List<Friend>> watchFriends() {
    final uid = _currentUid;
    if (uid == null) return Stream<List<Friend>>.value(const []);
    return _friends(uid).orderBy('createdAt', descending: true).snapshots().map(
          (snap) => snap.docs.map(Friend.fromDoc).toList(growable: false),
        );
  }

  @override
  Future<bool> isFriend(String otherUid) async {
    final uid = _currentUid;
    if (uid == null || otherUid.isEmpty) return false;
    final doc = await _friends(uid).doc(otherUid).get();
    return doc.exists;
  }

  @override
  Future<void> removeFriend(String otherUid) async {
    final uid = _currentUid;
    if (uid == null || otherUid.isEmpty) return;
    final myRef = _friends(uid).doc(otherUid);
    final otherRef = _friends(otherUid).doc(uid);
    await _firestore.runTransaction((tx) async {
      tx.delete(myRef);
      tx.delete(otherRef);
    });
    // TODO: Rules should ensure only owners can delete their friends list.
  }

  @override
  Future<List<String>> getFriendIds() async {
    final uid = _currentUid;
    if (uid == null) return const [];
    
    try {
      final snapshot = await _friends(uid).get();
      return snapshot.docs.map((doc) => doc.id).toList();
    } catch (e) {
      // Return empty if error
      return const [];
    }
  }
}
