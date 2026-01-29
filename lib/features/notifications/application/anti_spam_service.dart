import 'dart:developer' as dev;
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';

/// Anti-spam service to detect and prevent spam behavior
/// Tracks user actions and flags suspicious patterns
class AntiSpamService {
  AntiSpamService({
    FirebaseFirestore? firestore,
    FirebaseAuth? auth,
  })  : _firestore = firestore ?? FirebaseFirestore.instance,
        _auth = auth ?? FirebaseAuth.instance;

  final FirebaseFirestore _firestore;
  final FirebaseAuth _auth;

  CollectionReference<Map<String, dynamic>> get _actionLogs =>
      _firestore.collection('user_action_logs');

  /// Spam detection thresholds
  static const int maxFollowsIn5Min = 50;
  static const int maxFriendRequestsIn5Min = 30;
  static const int maxCommentsIn5Min = 20;
  static const int maxLikesIn5Min = 100;
  static const int duplicateCommentThreshold = 3;

  /// Check if user is spamming before allowing action
  /// Returns true if action is allowed, false if spam detected
  Future<bool> checkAndLogAction(SpamActionType actionType,
      {String? contentId, String? content}) async {
    final userId = _auth.currentUser?.uid;
    if (userId == null) return true;

    try {
      // Check spam before logging
      final isSpam = await _isSpamming(userId, actionType, content: content);
      if (isSpam) {
        dev.log('🚫 SPAM DETECTED: User $userId attempting $actionType',
            name: 'AntiSpam');
        
        // Log spam attempt
        await _logSpamAttempt(userId, actionType);
        
        return false;
      }

      // Log legitimate action
      await _logAction(userId, actionType, contentId: contentId, content: content);
      return true;
    } catch (e) {
      dev.log('⚠️ AntiSpam check failed: $e', name: 'AntiSpam');
      // On error, allow action to not block legitimate users
      return true;
    }
  }

  /// Check if user is currently spamming
  Future<bool> _isSpamming(String userId, SpamActionType actionType,
      {String? content}) async {
    final now = DateTime.now();
    final fiveMinutesAgo = now.subtract(const Duration(minutes: 5));

    // Get recent actions of this type
    final recentActions = await _actionLogs
        .where('userId', isEqualTo: userId)
        .where('actionType', isEqualTo: actionType.name)
        .where('timestamp', isGreaterThan: Timestamp.fromDate(fiveMinutesAgo))
        .orderBy('timestamp', descending: true)
        .limit(150) // Get more than max to check
        .get();

    final count = recentActions.docs.length;

    // Check rate limits based on action type
    switch (actionType) {
      case SpamActionType.follow:
        if (count >= maxFollowsIn5Min) {
          dev.log('🚫 Follow spam: $count follows in 5 min', name: 'AntiSpam');
          return true;
        }
        break;

      case SpamActionType.friendRequest:
        if (count >= maxFriendRequestsIn5Min) {
          dev.log('🚫 Friend request spam: $count requests in 5 min',
              name: 'AntiSpam');
          return true;
        }
        break;

      case SpamActionType.comment:
        // Check both rate limit and duplicate content
        if (count >= maxCommentsIn5Min) {
          dev.log('🚫 Comment rate spam: $count comments in 5 min',
              name: 'AntiSpam');
          return true;
        }

        // Check for duplicate comments
        if (content != null && content.trim().isNotEmpty) {
          final duplicateCount = recentActions.docs
              .where((doc) =>
                  (doc.data()['content'] as String?) == content.trim())
              .length;
          if (duplicateCount >= duplicateCommentThreshold) {
            dev.log('🚫 Duplicate comment spam: "$content" repeated $duplicateCount times',
                name: 'AntiSpam');
            return true;
          }
        }
        break;

      case SpamActionType.like:
        if (count >= maxLikesIn5Min) {
          dev.log('🚫 Like spam: $count likes in 5 min', name: 'AntiSpam');
          return true;
        }
        break;

      case SpamActionType.share:
        // Shares are less likely to be spam, use higher threshold
        if (count >= 50) {
          dev.log('🚫 Share spam: $count shares in 5 min', name: 'AntiSpam');
          return true;
        }
        break;
    }

    return false;
  }

  /// Log user action to Firestore
  Future<void> _logAction(String userId, SpamActionType actionType,
      {String? contentId, String? content}) async {
    try {
      await _actionLogs.add({
        'userId': userId,
        'actionType': actionType.name,
        'contentId': contentId,
        'content': content, // For duplicate detection
        'timestamp': FieldValue.serverTimestamp(),
        'isSpam': false,
      });
    } catch (e) {
      // Silently fail logging to not block user
      dev.log('Failed to log action: $e', name: 'AntiSpam');
    }
  }

  /// Log spam attempt for monitoring
  Future<void> _logSpamAttempt(String userId, SpamActionType actionType) async {
    try {
      await _firestore.collection('spam_attempts').add({
        'userId': userId,
        'actionType': actionType.name,
        'timestamp': FieldValue.serverTimestamp(),
        'severity': 'medium',
      });

      // Also increment spam counter in user profile
      await _firestore.collection('users').doc(userId).set({
        'spamAttempts': FieldValue.increment(1),
        'lastSpamAttempt': FieldValue.serverTimestamp(),
      }, SetOptions(merge: true));
    } catch (e) {
      dev.log('Failed to log spam attempt: $e', name: 'AntiSpam');
    }
  }

  /// Clean up old action logs (call periodically, or use Cloud Functions)
  Future<void> cleanupOldLogs() async {
    try {
      final userId = _auth.currentUser?.uid;
      if (userId == null) return;

      final sevenDaysAgo =
          DateTime.now().subtract(const Duration(days: 7));

      final oldLogs = await _actionLogs
          .where('userId', isEqualTo: userId)
          .where('timestamp', isLessThan: Timestamp.fromDate(sevenDaysAgo))
          .limit(100)
          .get();

      final batch = _firestore.batch();
      for (final doc in oldLogs.docs) {
        batch.delete(doc.reference);
      }
      await batch.commit();

      dev.log('Cleaned up ${oldLogs.docs.length} old action logs',
          name: 'AntiSpam');
    } catch (e) {
      dev.log('Failed to cleanup logs: $e', name: 'AntiSpam');
    }
  }

  /// Get user's spam score (for admin/monitoring)
  Future<SpamScore> getUserSpamScore(String userId) async {
    try {
      final now = DateTime.now();
      final fiveMinutesAgo = now.subtract(const Duration(minutes: 5));
      final oneDayAgo = now.subtract(const Duration(days: 1));

      // Get recent actions
      final recentActions = await _actionLogs
          .where('userId', isEqualTo: userId)
          .where('timestamp', isGreaterThan: Timestamp.fromDate(fiveMinutesAgo))
          .get();

      // Get daily actions
      final dailyActions = await _actionLogs
          .where('userId', isEqualTo: userId)
          .where('timestamp', isGreaterThan: Timestamp.fromDate(oneDayAgo))
          .get();

      // Get spam attempts
      final spamAttempts = await _firestore
          .collection('spam_attempts')
          .where('userId', isEqualTo: userId)
          .where('timestamp', isGreaterThan: Timestamp.fromDate(oneDayAgo))
          .get();

      return SpamScore(
        userId: userId,
        actionsLast5Min: recentActions.docs.length,
        actionsLast24Hours: dailyActions.docs.length,
        spamAttemptsLast24Hours: spamAttempts.docs.length,
        riskLevel: _calculateRiskLevel(
          recentActions.docs.length,
          spamAttempts.docs.length,
        ),
      );
    } catch (e) {
      dev.log('Failed to get spam score: $e', name: 'AntiSpam');
      return SpamScore(
        userId: userId,
        actionsLast5Min: 0,
        actionsLast24Hours: 0,
        spamAttemptsLast24Hours: 0,
        riskLevel: SpamRiskLevel.low,
      );
    }
  }

  SpamRiskLevel _calculateRiskLevel(int recentActions, int spamAttempts) {
    if (spamAttempts >= 5 || recentActions >= 150) {
      return SpamRiskLevel.high;
    } else if (spamAttempts >= 2 || recentActions >= 80) {
      return SpamRiskLevel.medium;
    }
    return SpamRiskLevel.low;
  }
}

/// Types of actions that can be spam
enum SpamActionType {
  follow,
  friendRequest,
  comment,
  like,
  share,
}

/// User's spam score
class SpamScore {
  const SpamScore({
    required this.userId,
    required this.actionsLast5Min,
    required this.actionsLast24Hours,
    required this.spamAttemptsLast24Hours,
    required this.riskLevel,
  });

  final String userId;
  final int actionsLast5Min;
  final int actionsLast24Hours;
  final int spamAttemptsLast24Hours;
  final SpamRiskLevel riskLevel;
}

enum SpamRiskLevel {
  low,
  medium,
  high,
}
