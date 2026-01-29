import 'package:cloud_firestore/cloud_firestore.dart';

/// Helper class to fetch user display names from Firestore
class UserNameResolver {
  UserNameResolver({FirebaseFirestore? firestore})
      : _firestore = firestore ?? FirebaseFirestore.instance;

  final FirebaseFirestore _firestore;
  final Map<String, String> _cache = {};

  /// Fetch a single username by userId
  Future<String> getUserName(String userId) async {
    if (userId.isEmpty) return '(Unknown)';

    // Check cache first
    if (_cache.containsKey(userId)) {
      return _cache[userId]!;
    }

    try {
      final doc = await _firestore.collection('users').doc(userId).get();
      if (!doc.exists) {
        _cache[userId] = '(User not found)';
        return _cache[userId]!;
      }

      final data = doc.data() ?? {};
      final name = (data['displayName'] ??
              data['fullName'] ??
              data['name'] ??
              '') as String? ??
          '';

      final displayName = name.trim().isNotEmpty ? name.trim() : '(No name)';
      _cache[userId] = displayName;
      return displayName;
    } catch (e) {
      _cache[userId] = '(Error loading)';
      return _cache[userId]!;
    }
  }

  /// Fetch multiple usernames at once
  Future<Map<String, String>> getUserNames(List<String> userIds) async {
    final result = <String, String>{};
    final uncachedIds = <String>[];

    for (final id in userIds) {
      if (id.isEmpty) continue;
      if (_cache.containsKey(id)) {
        result[id] = _cache[id]!;
      } else {
        uncachedIds.add(id);
      }
    }

    if (uncachedIds.isEmpty) return result;

    // Fetch uncached users in batches
    const batchSize = 10;
    for (var i = 0; i < uncachedIds.length; i += batchSize) {
      final batch = uncachedIds.skip(i).take(batchSize).toList();
      try {
        final docs = await Future.wait(
          batch.map((id) => _firestore.collection('users').doc(id).get()),
        );

        for (var j = 0; j < docs.length; j++) {
          final doc = docs[j];
          final userId = batch[j];

          if (!doc.exists) {
            result[userId] = '(User not found)';
            _cache[userId] = result[userId]!;
            continue;
          }

          final data = doc.data() ?? {};
          final name = (data['displayName'] ??
                  data['fullName'] ??
                  data['name'] ??
                  '') as String? ??
              '';

          final displayName =
              name.trim().isNotEmpty ? name.trim() : '(No name)';
          result[userId] = displayName;
          _cache[userId] = displayName;
        }
      } catch (e) {
        for (final id in batch) {
          result[id] = '(Error loading)';
          _cache[id] = result[id]!;
        }
      }
    }

    return result;
  }

  /// Clear the cache
  void clearCache() {
    _cache.clear();
  }
}
