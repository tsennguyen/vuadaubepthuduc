import 'dart:async';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';

import '../domain/meal_plan_models.dart';

/// Firestore structure:
/// - `mealPlans/{uid}/days/{yyyy-MM-dd}/meals/{mealId}`
///   - `{uid}`: `FirebaseAuth.currentUser.uid`
///   - `{yyyy-MM-dd}`: local date key (e.g. "2025-03-10")
///   - `{mealId}`: auto id (or specified id)
///
/// Meal document fields:
/// - `mealType`: "breakfast" | "lunch" | "dinner" | "snack"
/// - `recipeId`: string (points to `recipes/{rid}`)
/// - `title`: string? (optional, AI plan may fill)
/// - `servings`: number
/// - `note`: string? (optional)
/// - `createdAt`: Timestamp (serverTimestamp)
/// - `plannedFor`: Timestamp? (optional)
/// - `estimatedMacros`: {calories, protein, carbs, fat}? (per serving, optional)
///
/// Audit / extra fields are OK, but keep core fields stable.
abstract class MealPlanRepository {
  /// Stream plan of a single day for current user.
  Stream<List<MealPlanEntry>> watchDay(DateTime day);

  /// Stream plan of a week (7 days) starting from [weekStart].
  /// [weekStart] is treated as a local date (time is ignored).
  Stream<Map<DateTime, List<MealPlanEntry>>> watchWeek(DateTime weekStart);

  /// Load plan of a week (7 days) once.
  ///
  /// Useful for one-off operations like generating a shopping list.
  Future<List<MealPlanEntry>> getWeekOnce(DateTime weekStart);

  Future<void> addMeal(MealPlanEntry entry);
  Future<void> updateMeal(MealPlanEntry entry);
  Future<void> deleteMeal(String dayId, String mealId);
}

class NotAuthenticatedException implements Exception {
  NotAuthenticatedException([this.message = 'User is not authenticated']);
  final String message;

  @override
  String toString() => 'NotAuthenticatedException: $message';
}

class FirestoreMealPlanRepository implements MealPlanRepository {
  FirestoreMealPlanRepository({
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

  DocumentReference<Map<String, dynamic>> _dayDocRef(String uid, String dayId) {
    return _firestore
        .collection('mealPlans')
        .doc(uid)
        .collection('days')
        .doc(dayId);
  }

  CollectionReference<Map<String, dynamic>> _mealsRef(String uid, String dayId) {
    return _dayDocRef(uid, dayId).collection('meals');
  }

  @override
  Stream<List<MealPlanEntry>> watchDay(DateTime day) {
    final uid = _auth.currentUser?.uid;
    if (uid == null) {
      return Stream.error(NotAuthenticatedException());
    }

    final localInput = day.toLocal();
    final local = DateTime(localInput.year, localInput.month, localInput.day);
    final dayId = _dayId(local);

    return _mealsRef(uid, dayId)
        .orderBy('plannedFor', descending: false)
        .snapshots()
        .map((snapshot) {
          final entries = snapshot.docs
              .map(
                (doc) => MealPlanEntry.fromFirestore(
                  id: doc.id,
                  dayId: dayId,
                  data: doc.data(),
                ),
              )
              .toList();
          entries.sort(_compareMeals);
          return entries;
        });
  }

  @override
  Stream<Map<DateTime, List<MealPlanEntry>>> watchWeek(DateTime weekStart) {
    final uid = _auth.currentUser?.uid;
    if (uid == null) {
      return Stream.error(NotAuthenticatedException());
    }

    final localInput = weekStart.toLocal();
    final start =
        DateTime(localInput.year, localInput.month, localInput.day);
    final days = List<DateTime>.generate(
      7,
      (i) => start.add(Duration(days: i)),
      growable: false,
    );

    late final StreamController<Map<DateTime, List<MealPlanEntry>>> controller;
    final subs = <StreamSubscription<List<MealPlanEntry>>>[];
    final latest = <DateTime, List<MealPlanEntry>>{
      for (final d in days) d: const <MealPlanEntry>[],
    };

    void emit() {
      controller.add(Map<DateTime, List<MealPlanEntry>>.unmodifiable(latest));
    }

    controller = StreamController<Map<DateTime, List<MealPlanEntry>>>(
      onListen: () {
        for (final day in days) {
          final sub = watchDay(day).listen(
            (entries) {
              latest[day] = entries;
              emit();
            },
            onError: controller.addError,
          );
          subs.add(sub);
        }
        emit();
      },
      onCancel: () async {
        for (final sub in subs) {
          await sub.cancel();
        }
      },
    );

    return controller.stream;
  }

  @override
  Future<List<MealPlanEntry>> getWeekOnce(DateTime weekStart) async {
    final uid = _requireUid();

    final localInput = weekStart.toLocal();
    final start = DateTime(localInput.year, localInput.month, localInput.day);
    final days = List<DateTime>.generate(
      7,
      (i) => start.add(Duration(days: i)),
      growable: false,
    );

    final results = <MealPlanEntry>[];
    for (final day in days) {
      final dayId = _dayId(day);
      final snapshot = await _mealsRef(uid, dayId)
          .orderBy('plannedFor', descending: false)
          .limit(200)
          .get();
      final dayEntries = snapshot.docs
          .map(
            (doc) => MealPlanEntry.fromFirestore(
              id: doc.id,
              dayId: dayId,
              data: doc.data(),
            ),
          )
          .toList();
      dayEntries.sort(_compareMeals);
      results.addAll(dayEntries);
    }

    return results;
  }

  @override
  Future<void> addMeal(MealPlanEntry entry) async {
    final uid = _requireUid();
    final dayId = entry.dayId;

    // Ensure day doc exists (useful for future listing / rules).
    await _dayDocRef(uid, dayId).set(
      {
        'dayId': dayId,
        'updatedAt': FieldValue.serverTimestamp(),
      },
      SetOptions(merge: true),
    );

    final plannedFor = entry.plannedFor ??
        DateTime(entry.date.year, entry.date.month, entry.date.day, 12);

    final data = entry.toFirestore()
      ..['plannedFor'] = Timestamp.fromDate(plannedFor)
      ..['createdAt'] = FieldValue.serverTimestamp();

    final meals = _mealsRef(uid, dayId);
    final trimmedId = entry.id.trim();
    if (trimmedId.isNotEmpty) {
      await meals.doc(trimmedId).set(data, SetOptions(merge: true));
      return;
    }

    await meals.add(data);
  }

  @override
  Future<void> updateMeal(MealPlanEntry entry) async {
    final uid = _requireUid();
    final dayId = entry.dayId;
    final trimmedId = entry.id.trim();
    if (trimmedId.isEmpty) {
      throw ArgumentError.value(entry.id, 'id', 'Meal id is required');
    }

    final plannedFor = entry.plannedFor ??
        DateTime(entry.date.year, entry.date.month, entry.date.day, 12);

    final data = entry.toFirestore()
      ..['plannedFor'] = Timestamp.fromDate(plannedFor)
      ..['updatedAt'] = FieldValue.serverTimestamp();

    await _mealsRef(uid, dayId).doc(trimmedId).update(data);
  }

  @override
  Future<void> deleteMeal(String dayId, String mealId) async {
    final uid = _requireUid();
    final did = dayId.trim();
    final mid = mealId.trim();
    if (did.isEmpty) {
      throw ArgumentError.value(dayId, 'dayId', 'dayId is required');
    }
    if (mid.isEmpty) {
      throw ArgumentError.value(mealId, 'mealId', 'mealId is required');
    }
    await _mealsRef(uid, did).doc(mid).delete();
  }

  String _dayId(DateTime date) {
    String two(int n) => n.toString().padLeft(2, '0');
    return '${date.year}-${two(date.month)}-${two(date.day)}';
  }

  int _compareMeals(MealPlanEntry a, MealPlanEntry b) {
    final aTime = _entryTime(a);
    final bTime = _entryTime(b);
    final timeCompare = aTime.compareTo(bTime);
    if (timeCompare != 0) return timeCompare;
    return a.id.compareTo(b.id);
  }

  DateTime _entryTime(MealPlanEntry entry) {
    final date = entry.date.toLocal();
    final planned = entry.plannedFor?.toLocal();
    if (planned != null) return planned;
    final hour = switch (entry.mealType) {
      MealType.breakfast => 8,
      MealType.lunch => 12,
      MealType.dinner => 18,
      MealType.snack => 15,
    };
    return DateTime(date.year, date.month, date.day, hour);
  }
}
final mealPlanRepositoryProvider = Provider<MealPlanRepository>((ref) {
  return FirestoreMealPlanRepository();
});
