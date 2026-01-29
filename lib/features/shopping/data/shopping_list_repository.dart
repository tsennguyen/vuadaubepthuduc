import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/foundation.dart';

import '../domain/shopping_list_models.dart';

/// Firestore structure:
/// - `shoppingLists/{uid}/items/{itemId}`
///   - `{uid}`: `FirebaseAuth.currentUser.uid`
///   - `{itemId}`: auto id (or specified id)
///
/// Item document fields (core schema):
/// - `name`: string
/// - `quantity`: number
/// - `unit`: string
/// - `category`: string ("veg" | "meat" | "condiments" | "grain" | "dairy" | "other")
/// - `checked`: bool (default false)
/// - `sourceRecipeIds`: string[]
/// - `updatedAt`: Timestamp (serverTimestamp)
///
/// Audit / extra fields are OK, but keep core fields stable.
abstract class ShoppingListRepository {
  Stream<List<ShoppingListItem>> watchItems();

  Future<void> addItem(ShoppingListItem item);
  Future<void> updateItem(ShoppingListItem item);
  Future<void> deleteItem(String itemId);

  Future<void> toggleChecked(String itemId, bool checked);

  /// Upsert used when syncing from recipe/mealPlan.
  /// - If an item with the same (name + unit) exists: increment quantity, union
  ///   `sourceRecipeIds`, update `updatedAt`.
  /// - Otherwise: create a new item.
  Future<void> upsertItemByNameAndUnit({
    required String name,
    required double quantity,
    required String unit,
    required String category,
    required String sourceRecipeId,
  });

  /// Clear purchased items. Implementation chooses to delete checked items.
  Future<void> clearChecked();
}

class NotAuthenticatedException implements Exception {
  NotAuthenticatedException([this.message = 'User is not authenticated']);
  final String message;

  @override
  String toString() => 'NotAuthenticatedException: $message';
}

class FirestoreShoppingListRepository implements ShoppingListRepository {
  FirestoreShoppingListRepository({
    FirebaseAuth? auth,
    FirebaseFirestore? firestore,
  })  : _auth = auth ?? FirebaseAuth.instance,
        _firestore = firestore ?? FirebaseFirestore.instance;

  final FirebaseAuth _auth;
  final FirebaseFirestore _firestore;

  String _requireUid() {
    final uid = _auth.currentUser?.uid;
    if (uid == null) throw NotAuthenticatedException();
    return uid;
  }

  CollectionReference<Map<String, dynamic>> _itemsRef(String uid) {
    return _firestore.collection('shoppingLists').doc(uid).collection('items');
  }

  @override
  Stream<List<ShoppingListItem>> watchItems() {
    final uid = _auth.currentUser?.uid;
    if (uid == null) return Stream.error(NotAuthenticatedException());

    debugPrint('🛍️ [Repository] watchItems called for user: $uid');
    
    return _itemsRef(uid)
        .orderBy('updatedAt', descending: true) // Changed: more reliable than category/name
        .snapshots()
        .map(
          (snapshot) {
            debugPrint('🛍️ [Repository] Snapshot received: ${snapshot.docs.length} docs');
            final items = <ShoppingListItem>[];
            for (final doc in snapshot.docs) {
              try {
                final item = ShoppingListItem.fromFirestore(doc.id, doc.data());
                items.add(item);
              } catch (e) {
                debugPrint('🛍️ [Repository] ⚠️ Failed to parse item ${doc.id}: $e');
                debugPrint('🛍️ [Repository] Data: ${doc.data()}');
                // Skip invalid items
              }
            }
            debugPrint('🛍️ [Repository] Successfully parsed ${items.length} items');
            return items;
          },
        );
  }

  @override
  Future<void> addItem(ShoppingListItem item) async {
    final uid = _requireUid();

    final trimmedName = item.name.trim();
    if (trimmedName.isEmpty) {
      throw ArgumentError.value(item.name, 'name', 'Name is required');
    }

    final data = item.toFirestore()
      ..['name'] = trimmedName
      ..['unit'] = item.unit.trim()
      ..['category'] = item.category.trim()
      ..['updatedAt'] = FieldValue.serverTimestamp();

    final items = _itemsRef(uid);
    final trimmedId = item.id.trim();
    if (trimmedId.isNotEmpty) {
      await items.doc(trimmedId).set(data, SetOptions(merge: true));
      return;
    }

    await items.add(data);
  }

  @override
  Future<void> updateItem(ShoppingListItem item) async {
    final uid = _requireUid();
    final trimmedId = item.id.trim();
    if (trimmedId.isEmpty) {
      throw ArgumentError.value(item.id, 'id', 'Item id is required');
    }

    final trimmedName = item.name.trim();
    if (trimmedName.isEmpty) {
      throw ArgumentError.value(item.name, 'name', 'Name is required');
    }

    final data = item.toFirestore()
      ..['name'] = trimmedName
      ..['unit'] = item.unit.trim()
      ..['category'] = item.category.trim()
      ..['updatedAt'] = FieldValue.serverTimestamp();

    await _itemsRef(uid).doc(trimmedId).update(data);
  }

  @override
  Future<void> deleteItem(String itemId) async {
    final uid = _requireUid();
    final trimmed = itemId.trim();
    if (trimmed.isEmpty) {
      throw ArgumentError.value(itemId, 'itemId', 'Item id is required');
    }
    await _itemsRef(uid).doc(trimmed).delete();
  }

  @override
  Future<void> toggleChecked(String itemId, bool checked) async {
    final uid = _requireUid();
    final trimmed = itemId.trim();
    if (trimmed.isEmpty) {
      throw ArgumentError.value(itemId, 'itemId', 'Item id is required');
    }
    await _itemsRef(uid).doc(trimmed).update({
      'checked': checked,
      'updatedAt': FieldValue.serverTimestamp(),
    });
  }

  @override
  Future<void> upsertItemByNameAndUnit({
    required String name,
    required double quantity,
    required String unit,
    required String category,
    required String sourceRecipeId,
  }) async {
    debugPrint('💾 [Repository] upsertItemByNameAndUnit called');
    debugPrint('💾 [Repository] Input: name="$name", qty=$quantity, unit="$unit", cat="$category", source="$sourceRecipeId"');
    
    final uid = _requireUid();
    debugPrint('💾 [Repository] User ID: $uid');
    
    final trimmedName = name.trim();
    final trimmedUnit = unit.trim();
    final trimmedCategory = category.trim().isEmpty ? 'other' : category.trim();
    final trimmedSource = sourceRecipeId.trim();

    if (trimmedName.isEmpty) {
      debugPrint('💾 [Repository] ❌ Error: Name is empty');
      throw ArgumentError.value(name, 'name', 'Name is required');
    }
    if (trimmedUnit.isEmpty) {
      debugPrint('💾 [Repository] ❌ Error: Unit is empty');
      throw ArgumentError.value(unit, 'unit', 'Unit is required');
    }
    if (quantity.isNaN || quantity.isInfinite || quantity <= 0) {
      debugPrint('💾 [Repository] ❌ Error: Invalid quantity: $quantity');
      throw ArgumentError.value(quantity, 'quantity', 'Quantity must be > 0');
    }
    if (trimmedSource.isEmpty) {
      debugPrint('💾 [Repository] ❌ Error: Source recipe ID is empty');
      throw ArgumentError.value(
        sourceRecipeId,
        'sourceRecipeId',
        'sourceRecipeId is required',
      );
    }

    debugPrint('💾 [Repository] Validation passed');
    final items = _itemsRef(uid);

    DocumentReference<Map<String, dynamic>>? existingRef;
    Map<String, dynamic>? existingData;

    // Preferred: query by exact fields (may require index; fallback if needed).
    try {
      debugPrint('💾 [Repository] Querying existing items...');
      final snapshot = await items
          .where('name', isEqualTo: trimmedName)
          .where('unit', isEqualTo: trimmedUnit)
          .limit(1)
          .get();
      if (snapshot.docs.isNotEmpty) {
        final doc = snapshot.docs.first;
        existingRef = doc.reference;
        existingData = doc.data();
        debugPrint('💾 [Repository] Found existing item: ${doc.id}');
      } else {
        debugPrint('💾 [Repository] No existing item found (exact query)');
      }
    } on FirebaseException catch (e) {
      debugPrint('💾 [Repository] ⚠️ Firestore query failed: ${e.code} - ${e.message}');
      debugPrint('💾 [Repository] Falling back to client-side matching...');
      // Fallback: load a batch and match client-side (case-insensitive).
      final snapshot = await items.limit(500).get();
      final n = trimmedName.toLowerCase();
      final u = trimmedUnit.toLowerCase();
      for (final doc in snapshot.docs) {
        final data = doc.data();
        final dn = (data['name'] as String?)?.trim().toLowerCase();
        final du = (data['unit'] as String?)?.trim().toLowerCase();
        if (dn == n && du == u) {
          existingRef = doc.reference;
          existingData = data;
          debugPrint('💾 [Repository] Found existing item (fallback): ${doc.id}');
          break;
        }
      }
      if (existingRef == null) {
        debugPrint('💾 [Repository] No existing item found (fallback)');
      }
    }

    if (existingRef != null) {
      debugPrint('💾 [Repository] Updating existing item...');
      final existingCategory = (existingData?['category'] as String?)?.trim();
      final shouldSetCategory = existingCategory == null || existingCategory.isEmpty;

      final update = <String, dynamic>{
        'quantity': FieldValue.increment(quantity),
        'sourceRecipeIds': FieldValue.arrayUnion(<String>[trimmedSource]),
        'updatedAt': FieldValue.serverTimestamp(),
      };
      if (shouldSetCategory) {
        update['category'] = trimmedCategory;
        debugPrint('💾 [Repository] Setting category: $trimmedCategory');
      }

      await existingRef.update(update);
      debugPrint('💾 [Repository] ✅ Updated existing item');
      return;
    }

    debugPrint('💾 [Repository] Creating new item...');
    final newDoc = await items.add({
      'name': trimmedName,
      'quantity': quantity,
      'unit': trimmedUnit,
      'category': trimmedCategory,
      'checked': false,
      'sourceRecipeIds': <String>[trimmedSource],
      'updatedAt': FieldValue.serverTimestamp(),
    });
    debugPrint('💾 [Repository] ✅ Created new item: ${newDoc.id}');
  }

  @override
  Future<void> clearChecked() async {
    final uid = _requireUid();
    final items = _itemsRef(uid);

    final snapshot =
        await items.where('checked', isEqualTo: true).limit(500).get();
    if (snapshot.docs.isEmpty) return;

    WriteBatch batch = _firestore.batch();
    var opCount = 0;

    Future<void> commit() async {
      await batch.commit();
      batch = _firestore.batch();
      opCount = 0;
    }

    for (final doc in snapshot.docs) {
      batch.delete(doc.reference);
      opCount += 1;
      if (opCount >= 450) {
        await commit();
      }
    }

    if (opCount > 0) {
      await commit();
    }
  }
}

