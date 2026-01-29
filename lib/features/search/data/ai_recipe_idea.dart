class AiRecipeIdea {
  AiRecipeIdea({
    required this.title,
    required this.shortDescription,
    required this.ingredients,
    required this.steps,
    required this.tags,
  });

  final String title;
  final String shortDescription;
  final List<String> ingredients;
  final List<String> steps;
  final List<String> tags;

  factory AiRecipeIdea.fromMap(Map<String, dynamic> map) {
    final title = (map['title'] as String? ?? '').trim();
    if (title.isEmpty) {
      throw ArgumentError('Missing title in AI idea');
    }
    final desc = ((map['shortDescription'] as String?) ??
            (map['description'] as String?) ??
            '')
        .trim();
    final ingredients = (map['ingredients'] as List<dynamic>?)
            ?.whereType<String>()
            .map((e) => e.trim())
            .where((e) => e.isNotEmpty)
            .toList() ??
        const <String>[];
    final steps = (map['steps'] as List<dynamic>?)
            ?.whereType<String>()
            .map((e) => e.trim())
            .where((e) => e.isNotEmpty)
            .toList() ??
        const <String>[];
    final tags = (map['tags'] as List<dynamic>?)
            ?.whereType<String>()
            .map((e) => e.trim())
            .where((e) => e.isNotEmpty)
            .toList() ??
        const <String>[];

    return AiRecipeIdea(
      title: title,
      shortDescription: desc,
      ingredients: ingredients,
      steps: steps,
      tags: tags,
    );
  }

  static AiRecipeIdea? maybeFromDynamic(dynamic value) {
    if (value is! Map<String, dynamic>) return null;
    try {
      return AiRecipeIdea.fromMap(value);
    } catch (_) {
      return null;
    }
  }
}
