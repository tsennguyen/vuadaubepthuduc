import 'dart:developer' as dev;
import 'package:cloud_firestore/cloud_firestore.dart';

/// Utility to clean up duplicate friend request notifications
/// Run this once to fix existing database issues
class NotificationCleanupHelper {
  static Future<void> cleanupDuplicateFriendRequests(String userId) async {
    final firestore = FirebaseFirestore.instance;
    final CollectionReference<Map<String, dynamic>> notifications =
        firestore.collection('notifications');
    
    dev.log('Starting cleanup for user: $userId', name: 'NotificationCleanup');
    
    try {
      // Get all friend request notifications for this user
      final QuerySnapshot<Map<String, dynamic>> snapshot = await notifications
          .where('userId', isEqualTo: userId)
          .where('type', isEqualTo: 'friendRequest')
          .get();
      
      dev.log('Found ${snapshot.docs.length} friend request notifications', 
              name: 'NotificationCleanup');
      
      // Group by actorId
      final Map<String, List<QueryDocumentSnapshot<Map<String, dynamic>>>> grouped = {};
      for (final doc in snapshot.docs) {
        final actorId = doc.data()['actorId'] as String?;
        if (actorId != null) {
          grouped.putIfAbsent(actorId, () => []).add(doc);
        }
      }
      
      dev.log('Grouped into ${grouped.length} unique actors', 
              name: 'NotificationCleanup');
      
      // For each actor, keep only the most recent notification
      int deletedCount = 0;
      final batch = firestore.batch();
      
      for (final entry in grouped.entries) {
        final docs = entry.value;
        if (docs.length > 1) {
          // Sort by createdAt descending
          docs.sort((a, b) {
            final aTime = (a.data()['createdAt'] as Timestamp?)?.toDate();
            final bTime = (b.data()['createdAt'] as Timestamp?)?.toDate();
            if (aTime == null || bTime == null) return 0;
            return bTime.compareTo(aTime);
          });
          
          // Delete all except the first (most recent)
          for (int i = 1; i < docs.length; i++) {
            batch.delete(docs[i].reference);
            deletedCount++;
          }
        }
      }
      
      if (deletedCount > 0) {
        await batch.commit();
        dev.log('Deleted $deletedCount duplicate notifications', 
                name: 'NotificationCleanup');
      } else {
        dev.log('No duplicates found', name: 'NotificationCleanup');
      }
      
    } catch (e, stack) {
      dev.log('Error during cleanup: $e', 
              name: 'NotificationCleanup', 
              error: e, 
              stackTrace: stack);
    }
  }
}
