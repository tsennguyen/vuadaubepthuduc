import 'package:cloud_functions/cloud_functions.dart';

class AiSuggestion {
  AiSuggestion({
    required this.title,
    this.description,
    this.tags = const [],
  });

  final String title;
  final String? description;
  final List<String> tags;
}

class TrendingItem {
  TrendingItem({
    required this.id,
    required this.title,
    this.photoUrl,
    required this.isRecipe,
  });

  final String id;
  final String title;
  final String? photoUrl;
  final bool isRecipe;
}

class SuggestResult {
  SuggestResult({
    this.aiSuggestions = const [],
    this.trending = const [],
  });

  final List<AiSuggestion> aiSuggestions;
  final List<TrendingItem> trending;
}

abstract class SuggestRepository {
  Future<SuggestResult> suggest({
    required String rawQuery,
    required List<String> tokens,
    required String type, // "unified" | "ingredients"
  });
}

class SuggestRepositoryImpl implements SuggestRepository {
  SuggestRepositoryImpl({FirebaseFunctions? functions})
      : _functions =
            functions ?? FirebaseFunctions.instanceFor(region: 'asia-southeast1');

  final FirebaseFunctions _functions;

  @override
  Future<SuggestResult> suggest({
    required String rawQuery,
    required List<String> tokens,
    required String type,
  }) async {
    final callable = _functions.httpsCallable('suggestSearch');
    final result = await callable.call<Map<String, dynamic>>({
      'q': rawQuery,
      'tokens': tokens,
      'type': type,
    });
    final data =
        (result.data as Map<String, dynamic>?) ?? <String, dynamic>{};
    final aiList = (data['aiSuggestions'] as List<dynamic>?)
            ?.whereType<Map<String, dynamic>>()
            .map((item) => AiSuggestion(
                  title: item['title'] as String? ?? '',
                  description: item['description'] as String?,
                  tags: (item['tags'] as List<dynamic>?)
                          ?.whereType<String>()
                          .toList() ??
                      const [],
                ))
            .where((s) => s.title.isNotEmpty)
            .toList() ??
        const <AiSuggestion>[];

    final trendingRecipes = (data['trendingRecipes'] as List<dynamic>?)
            ?.whereType<Map<String, dynamic>>()
            .map((item) {
              final photo = (item['photoURL'] ?? item['photoUrl']) as String?;
              return TrendingItem(
                id: item['id'] as String? ?? '',
                title: item['title'] as String? ?? '',
                photoUrl: photo,
                isRecipe: true,
              );
            })
            .where((t) => t.id.isNotEmpty && t.title.isNotEmpty)
            .toList() ??
        const <TrendingItem>[];

    final trendingPosts = (data['trendingPosts'] as List<dynamic>?)
            ?.whereType<Map<String, dynamic>>()
            .map((item) {
              final photo = (item['photoURL'] ?? item['photoUrl']) as String?;
              return TrendingItem(
                id: item['id'] as String? ?? '',
                title: item['title'] as String? ?? '',
                photoUrl: photo,
                isRecipe: false,
              );
            })
            .where((t) => t.id.isNotEmpty && t.title.isNotEmpty)
            .toList() ??
        const <TrendingItem>[];

    return SuggestResult(
      aiSuggestions: aiList,
      trending: [...trendingRecipes, ...trendingPosts],
    );
  }
}
