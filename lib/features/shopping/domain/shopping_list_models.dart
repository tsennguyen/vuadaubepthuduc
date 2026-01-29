import 'package:cloud_firestore/cloud_firestore.dart';

class ShoppingListItem {
  final String id;
  final String name;
  final double quantity;
  final String unit;
  final String category;
  final bool checked;
  final List<String> sourceRecipeIds;
  final DateTime? updatedAt;

  const ShoppingListItem({
    required this.id,
    required this.name,
    required this.quantity,
    required this.unit,
    required this.category,
    required this.checked,
    required this.sourceRecipeIds,
    required this.updatedAt,
  });

  ShoppingListItem copyWith({
    String? id,
    String? name,
    double? quantity,
    String? unit,
    String? category,
    bool? checked,
    List<String>? sourceRecipeIds,
    DateTime? updatedAt,
  }) {
    return ShoppingListItem(
      id: id ?? this.id,
      name: name ?? this.name,
      quantity: quantity ?? this.quantity,
      unit: unit ?? this.unit,
      category: category ?? this.category,
      checked: checked ?? this.checked,
      sourceRecipeIds: sourceRecipeIds ?? this.sourceRecipeIds,
      updatedAt: updatedAt ?? this.updatedAt,
    );
  }

  Map<String, dynamic> toFirestore() {
    return <String, dynamic>{
      'name': name,
      'quantity': quantity,
      'unit': unit,
      'category': category,
      'checked': checked,
      'sourceRecipeIds': sourceRecipeIds,
    };
  }

  factory ShoppingListItem.fromFirestore(
    String id,
    Map<String, dynamic> data,
  ) {
    final updatedAtValue = data['updatedAt'];
    DateTime? updatedAt;
    if (updatedAtValue is Timestamp) {
      updatedAt = updatedAtValue.toDate();
    } else if (updatedAtValue is DateTime) {
      updatedAt = updatedAtValue;
    }

    return ShoppingListItem(
      id: id,
      name: (data['name'] as String?)?.trim() ?? '',
      quantity: _parseDouble(data['quantity']) ?? 0,
      unit: (data['unit'] as String?)?.trim() ?? '',
      category: (data['category'] as String?)?.trim() ?? 'other',
      checked: _parseBool(data['checked']),
      sourceRecipeIds: _parseStringList(data['sourceRecipeIds']),
      updatedAt: updatedAt,
    );
  }
}

double? _parseDouble(dynamic value) {
  if (value == null) return null;
  if (value is num) return value.toDouble();
  if (value is String) return double.tryParse(value.trim());
  return null;
}

bool _parseBool(dynamic value) {
  if (value == null) return false;
  if (value is bool) return value;
  if (value is num) return value != 0;
  if (value is String) {
    final v = value.trim().toLowerCase();
    if (v == 'true' || v == '1' || v == 'yes') return true;
    if (v == 'false' || v == '0' || v == 'no') return false;
  }
  return false;
}

List<String> _parseStringList(dynamic value) {
  if (value is Iterable) {
    return value
        .whereType<String>()
        .map((e) => e.trim())
        .where((e) => e.isNotEmpty)
        .toList(growable: false);
  }
  return const <String>[];
}

