import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:cloud_functions/cloud_functions.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/foundation.dart';

abstract class ChatFunctionsRepository {
  Future<String> createDM({required String toUid});
  Future<String> createGroup({
    required String name,
    required List<String> memberIds,
  });
}

class ChatFunctionsRepositoryImpl implements ChatFunctionsRepository {
  ChatFunctionsRepositoryImpl({FirebaseFunctions? functions})
      : _functions =
            functions ?? FirebaseFunctions.instanceFor(region: 'asia-southeast1');

  final FirebaseFunctions _functions;
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;

  @override
  Future<String> createDM({required String toUid}) async {
    try {
      // TODO: Cloud Function should verify only friends can create a DM.
      final callable = _functions.httpsCallable('createDM');
      final result = await callable.call<Map<String, dynamic>>({'toUid': toUid});
      final data = result.data as Map<String, dynamic>? ?? {};
      final chatId = data['chatId'] as String?;
      if (chatId == null || chatId.isEmpty) {
        throw Exception('Tao chat that bai: khong co chatId');
      }
      return chatId;
    } on FirebaseFunctionsException catch (e) {
      if (kIsWeb) {
        final fallback = await _fallbackCreateDm(toUid: toUid);
        if (fallback != null) return fallback;
      }
      final msg = e.message ?? e.code;
      throw Exception('Tao chat that bai: $msg');
    } catch (e) {
      if (kIsWeb) {
        final fallback = await _fallbackCreateDm(toUid: toUid);
        if (fallback != null) return fallback;
      }
      throw Exception('Tao chat that bai: $e');
    }
  }

  @override
  Future<String> createGroup({
    required String name,
    required List<String> memberIds,
  }) async {
    try {
      // TODO: Cloud Function should validate members are friends with creator.
      final callable = _functions.httpsCallable('createGroup');
      final result = await callable.call<Map<String, dynamic>>({
        'name': name,
        'memberIds': memberIds,
      });
      final data = result.data as Map<String, dynamic>? ?? {};
      final chatId = data['chatId'] as String?;
      if (chatId == null || chatId.isEmpty) {
        throw Exception('Tao nhom that bai: khong co chatId');
      }
      return chatId;
    } on FirebaseFunctionsException catch (e) {
      if (kIsWeb) {
        final fallback = await _fallbackCreateGroup(
          name: name,
          memberIds: memberIds,
        );
        if (fallback != null) return fallback;
      }
      final msg = e.message ?? e.code;
      throw Exception('Tao nhom that bai: $msg');
    } catch (e) {
      if (kIsWeb) {
        final fallback = await _fallbackCreateGroup(
          name: name,
          memberIds: memberIds,
        );
        if (fallback != null) return fallback;
      }
      throw Exception('Tao nhom that bai: $e');
    }
  }

  Future<String?> _fallbackCreateDm({required String toUid}) async {
    final fromUid = FirebaseAuth.instance.currentUser?.uid;
    if (fromUid == null) return null;

    final memberIds = <String>{fromUid, toUid}.toList()..sort();

    // Try to reuse an existing DM (no composite index required).
    final existing = await _firestore
        .collection('chats')
        .where('memberIds', arrayContains: fromUid)
        .limit(50)
        .get();
    for (final doc in existing.docs) {
      final data = doc.data();
      final isGroup = data['isGroup'] == true ||
          ((data['type'] as String?)?.toLowerCase() == 'group');
      if (isGroup) continue;
      final ids =
          (data['memberIds'] as List<dynamic>?)?.whereType<String>().toList() ??
              const <String>[];
      final normalized = [...ids]..sort();
      if (listEquals(normalized, memberIds)) {
        return doc.id;
      }
    }

    final chatDoc = _firestore.collection('chats').doc();
    await chatDoc.set({
      'isGroup': false,
      'type': 'dm',
      'name': null,
      'photoUrl': null,
      'memberIds': memberIds,
      'adminIds': memberIds,
      'createdAt': FieldValue.serverTimestamp(),
      'updatedAt': FieldValue.serverTimestamp(),
      'lastMessageAt': FieldValue.serverTimestamp(),
      'lastMessageText': '',
      'lastMessageSenderId': null,
      'mutedBy': <String>[],
      'nicknames': <String, String>{},
      'theme': null,
    });
    return chatDoc.id;
  }

  Future<String?> _fallbackCreateGroup({
    required String name,
    required List<String> memberIds,
  }) async {
    final ownerId = FirebaseAuth.instance.currentUser?.uid;
    if (ownerId == null) return null;

    final normalized = <String>{...memberIds, ownerId}.toList();
    final docRef = _firestore.collection('chats').doc();
    await docRef.set({
      'isGroup': true,
      'type': 'group',
      'name': name,
      'memberIds': normalized,
      'adminIds': [ownerId],
      'photoUrl': null,
      'lastMessageAt': FieldValue.serverTimestamp(),
      'lastMessageText': '',
      'lastMessageSenderId': null,
      'mutedBy': <String>[],
      'nicknames': <String, String>{},
      'theme': null,
      'createdAt': FieldValue.serverTimestamp(),
      'updatedAt': FieldValue.serverTimestamp(),
    });
    return docRef.id;
  }
}
