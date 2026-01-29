import 'package:cloud_firestore/cloud_firestore.dart';

enum MealType { breakfast, lunch, dinner, snack }

extension MealTypeX on MealType {
  String toFirestore() => switch (this) {
        MealType.breakfast => 'breakfast',
        MealType.lunch => 'lunch',
        MealType.dinner => 'dinner',
        MealType.snack => 'snack',
      };

  static MealType fromFirestore(String? value) {
    switch ((value ?? '').trim().toLowerCase()) {
      case 'breakfast':
        return MealType.breakfast;
      case 'lunch':
        return MealType.lunch;
      case 'dinner':
        return MealType.dinner;
      case 'snack':
        return MealType.snack;
      default:
        return MealType.lunch;
    }
  }
}

class MealPlanEntry {
  final String id;
  final String recipeId;
  final String? title;
  final MealType mealType;
  final int servings;
  final String? note;
  final DateTime date; // yyyy-MM-dd (local date)
  final DateTime? plannedFor; // optional full DateTime
  final Map<String, double>? estimatedMacros; // calories/protein/carbs/fat per serving

  const MealPlanEntry({
    required this.id,
    required this.recipeId,
    this.title,
    required this.mealType,
    required this.servings,
    this.note,
    required this.date,
    this.plannedFor,
    this.estimatedMacros,
  });

  String get dayId {
    final local = date.toLocal();
    String two(int n) => n.toString().padLeft(2, '0');
    return '${local.year}-${two(local.month)}-${two(local.day)}';
  }

  Map<String, dynamic> toFirestore() {
    final data = <String, dynamic>{
      'mealType': mealType.toFirestore(),
      'recipeId': recipeId,
      'servings': servings,
    };
    if (title != null && title!.trim().isNotEmpty) {
      data['title'] = title!.trim();
    }

    final trimmedNote = note?.trim();
    if (trimmedNote != null && trimmedNote.isNotEmpty) {
      data['note'] = trimmedNote;
    }

    if (plannedFor != null) {
      data['plannedFor'] = Timestamp.fromDate(plannedFor!.toLocal());
    }
    final macros = estimatedMacros;
    if (macros != null && macros.isNotEmpty) {
      data['estimatedMacros'] = _serializeMacros(macros);
    }

    return data;
  }

  factory MealPlanEntry.fromFirestore({
    required String id,
    required String dayId,
    required Map<String, dynamic> data,
  }) {
    final plannedForValue = data['plannedFor'];
    final plannedFor = switch (plannedForValue) {
      Timestamp ts => ts.toDate(),
      DateTime dt => dt,
      _ => null,
    };

    return MealPlanEntry(
      id: id,
      recipeId: (data['recipeId'] as String?)?.trim() ?? '',
      mealType: MealTypeX.fromFirestore(data['mealType'] as String?),
      servings: _parseInt(data['servings'], fallback: 1),
      note: (data['note'] as String?)?.trim(),
      date: _parseDayId(dayId),
      plannedFor: plannedFor?.toLocal(),
      title: (data['title'] as String?)?.trim(),
      estimatedMacros: _parseMacros(data['estimatedMacros']),
    );
  }
}

int _parseInt(dynamic value, {required int fallback}) {
  if (value is int) return value;
  if (value is num) return value.toInt();
  if (value is String) {
    final parsed = int.tryParse(value.trim());
    if (parsed != null) return parsed;
  }
  return fallback;
}

DateTime _parseDayId(String dayId) {
  final parts = dayId.trim().split('-');
  if (parts.length != 3) return DateTime.fromMillisecondsSinceEpoch(0);
  final year = int.tryParse(parts[0]);
  final month = int.tryParse(parts[1]);
  final day = int.tryParse(parts[2]);
  if (year == null || month == null || day == null) {
    return DateTime.fromMillisecondsSinceEpoch(0);
  }
  return DateTime(year, month, day);
}

Map<String, double>? _parseMacros(dynamic raw) {
  if (raw is! Map) return null;
  double? parse(Object? v) {
    if (v is num) return v.toDouble().clamp(0, double.infinity);
    if (v is String) {
      final parsed = double.tryParse(v);
      if (parsed != null) return parsed.clamp(0, double.infinity);
    }
    return null;
  }

  final calories = parse(raw['calories']);
  final protein = parse(raw['protein']);
  final carbs = parse(raw['carbs']);
  final fat = parse(raw['fat']);
  if (calories == null && protein == null && carbs == null && fat == null) {
    return null;
  }
  return {
    if (calories != null) 'calories': calories,
    if (protein != null) 'protein': protein,
    if (carbs != null) 'carbs': carbs,
    if (fat != null) 'fat': fat,
  };
}

Map<String, double> _serializeMacros(Map<String, double> input) {
  final out = <String, double>{};
  for (final entry in input.entries) {
    final key = entry.key;
    final value = entry.value;
    if (value.isNaN || value.isInfinite) continue;
    if (value < 0) continue;
    if (key == 'calories' ||
        key == 'protein' ||
        key == 'carbs' ||
        key == 'fat') {
      out[key] = value;
    }
  }
  return out;
}
