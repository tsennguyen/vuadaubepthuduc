import 'package:flutter/foundation.dart';
import '../../feed/data/recipe_model.dart';

class ParsedIngredient {
  const ParsedIngredient({
    required this.name,
    required this.quantity,
    required this.unit,
    required this.category,
  });

  final String name;
  final double quantity;
  final String unit;
  final String category;
}

List<ParsedIngredient> parseRecipeIngredientsForShopping(Recipe recipe) {
  debugPrint('🥕 [Parsing] Recipe: ${recipe.title}, ${recipe.ingredients.length} raw ingredients');
  final tags = recipe.tags.map((e) => e.toLowerCase()).toList(growable: false);

  final results = <ParsedIngredient>[];
  for (final raw in recipe.ingredients) {
    final line = raw.trim();
    if (line.isEmpty) {
      debugPrint('🥕 [Parsing] Skipping empty line');
      continue;
    }

    debugPrint('🥕 [Parsing] Raw: "$line"');
    final parsed = _parseIngredientLine(line);
    final category = _guessCategory(parsed.name, tags);
    
    debugPrint('🥕 [Parsing] → Parsed: ${parsed.name} (${parsed.quantity} ${parsed.unit}) [$category]');

    results.add(
      ParsedIngredient(
        name: parsed.name,
        quantity: parsed.quantity,
        unit: parsed.unit,
        category: category,
      ),
    );
  }
  debugPrint('🥕 [Parsing] Total parsed: ${results.length} ingredients');
  return results;
}

ParsedIngredient _parseIngredientLine(String input) {
  final trimmed = input.trim();
  if (trimmed.isEmpty) {
    return const ParsedIngredient(
      name: '',
      quantity: 0,
      unit: 'pcs',
      category: 'other',
    );
  }

  // Strategy (best-effort):
  // 1) Parse leading "<qty><unit?> <name>".
  // 2) Parse trailing "<name> <qty><unit>".
  // 3) Fallback: treat as "1 pcs <whole string>".
  final leading = RegExp(r'^(\d+(?:[.,]\d+)?)\s*([^\s\d]+)?\s+(.+)$');
  final leadingMatch = leading.firstMatch(trimmed);
  if (leadingMatch != null) {
    final qty = _toDouble(leadingMatch.group(1));
    final unit = leadingMatch.group(2)?.trim();
    final name = leadingMatch.group(3)?.trim();
    if (qty != null && qty > 0 && name != null && name.isNotEmpty) {
      return ParsedIngredient(
        name: name,
        quantity: qty,
        unit: (unit == null || unit.isEmpty) ? 'pcs' : unit,
        category: 'other',
      );
    }
  }

  final trailing = RegExp(r'^(.+?)\s+(\d+(?:[.,]\d+)?)\s*([^\s\d]+)$');
  final trailingMatch = trailing.firstMatch(trimmed);
  if (trailingMatch != null) {
    final name = trailingMatch.group(1)?.trim();
    final qty = _toDouble(trailingMatch.group(2));
    final unit = trailingMatch.group(3)?.trim();
    if (qty != null && qty > 0 && unit != null && unit.isNotEmpty) {
      return ParsedIngredient(
        name: name ?? '',
        quantity: qty,
        unit: unit,
        category: 'other',
      );
    }
  }

  return ParsedIngredient(
    name: trimmed,
    quantity: 1,
    unit: 'pcs',
    category: 'other',
  );
}

double? _toDouble(String? input) {
  if (input == null) return null;
  final normalized = input.trim().replaceAll(',', '.');
  return double.tryParse(normalized);
}

String _guessCategory(String name, List<String> tagsLower) {
  // Tag-based hints (optional).
  if (tagsLower.contains('veg') || tagsLower.contains('vegetarian')) {
    return 'veg';
  }

  final n = name.toLowerCase();

  if (_containsAny(n, const ['thịt', 'bò', 'gà', 'heo', 'lợn', 'cá', 'tôm'])) {
    return 'meat';
  }
  if (_containsAny(n, const ['rau', 'cải', 'hành', 'tỏi', 'ớt', 'cà', 'dưa'])) {
    return 'veg';
  }
  if (_containsAny(n, const ['gạo', 'bún', 'mì', 'bột', 'yến mạch'])) {
    return 'grain';
  }
  if (_containsAny(n, const ['sữa', 'phô mai', 'bơ', 'yaourt', 'yogurt'])) {
    return 'dairy';
  }
  if (_containsAny(n, const ['muối', 'đường', 'nước mắm', 'xì dầu', 'tiêu'])) {
    return 'condiments';
  }

  return 'other';
}

bool _containsAny(String inputLower, List<String> needlesLower) {
  for (final n in needlesLower) {
    if (inputLower.contains(n)) return true;
  }
  return false;
}
