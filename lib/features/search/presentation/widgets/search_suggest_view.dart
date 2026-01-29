import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../../core/constants/app_sizes.dart';
import '../../application/suggest_controller.dart';
import '../../data/suggest_repository.dart';

class SearchSuggestView extends ConsumerStatefulWidget {
  const SearchSuggestView({
    super.key,
    required this.rawQuery,
    required this.tokens,
    required this.type,
  });

  final String rawQuery;
  final List<String> tokens;
  final String type; // "unified" | "ingredients"

  @override
  ConsumerState<SearchSuggestView> createState() => _SearchSuggestViewState();
}

class _SearchSuggestViewState extends ConsumerState<SearchSuggestView> {
  late SuggestParams _params;

  @override
  void initState() {
    super.initState();
    _params = SuggestParams(
      rawQuery: widget.rawQuery,
      tokens: widget.tokens,
      type: widget.type,
    );
    _fetchIfNeeded();
  }

  @override
  void didUpdateWidget(covariant SearchSuggestView oldWidget) {
    super.didUpdateWidget(oldWidget);
    final newParams = SuggestParams(
      rawQuery: widget.rawQuery,
      tokens: widget.tokens,
      type: widget.type,
    );
    if (newParams != _params) {
      _params = newParams;
      _fetchIfNeeded(force: true);
    }
  }

  void _fetchIfNeeded({bool force = false}) {
    if (_params.rawQuery.trim().isEmpty && _params.tokens.isEmpty) return;
    final state = ref.read(suggestControllerProvider(_params));
    if (force || (!state.isLoading && state.data == null && state.error == null)) {
      Future.microtask(
        () => ref.read(suggestControllerProvider(_params).notifier).fetchSuggest(),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final state = ref.watch(suggestControllerProvider(_params));

    if (state.isLoading && state.data == null) {
      return const Padding(
        padding: EdgeInsets.symmetric(vertical: AppSizes.md),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            SizedBox(
              width: 18,
              height: 18,
              child: CircularProgressIndicator(strokeWidth: 2),
            ),
            SizedBox(width: AppSizes.sm),
            Text('Đang tìm gợi ý...'),
          ],
        ),
      );
    }

    if (state.error != null) {
      return const Padding(
        padding: EdgeInsets.symmetric(vertical: AppSizes.md),
        child: Text(
          'Không lấy được gợi ý. Bạn thử tìm từ khóa khác nhé.',
          textAlign: TextAlign.center,
        ),
      );
    }

    final data = state.data;
    if (data == null ||
        (data.aiSuggestions.isEmpty && data.trending.isEmpty)) {
      return const SizedBox.shrink();
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        if (data.aiSuggestions.isNotEmpty) _buildAiSuggestions(data.aiSuggestions),
        if (data.trending.isNotEmpty) _buildTrending(context, data.trending),
      ],
    );
  }

  Widget _buildAiSuggestions(List<AiSuggestion> suggestions) {
    return Card(
      margin: const EdgeInsets.symmetric(vertical: AppSizes.sm),
      child: Padding(
        padding: const EdgeInsets.all(AppSizes.md),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              'Bạn có thể thử:',
              style: TextStyle(fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: AppSizes.sm),
            ...suggestions.map(
              (s) => Padding(
                padding: const EdgeInsets.symmetric(vertical: 6),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      s.title,
                      style: const TextStyle(fontWeight: FontWeight.w600),
                    ),
                    if (s.description != null && s.description!.isNotEmpty) ...[
                      const SizedBox(height: 4),
                      Text(
                        s.description!,
                        style: const TextStyle(color: Colors.black87),
                      ),
                    ],
                    if (s.tags.isNotEmpty) ...[
                      const SizedBox(height: 4),
                      Wrap(
                        spacing: 6,
                        runSpacing: 4,
                        children: s.tags
                            .map((t) => Chip(
                                  label: Text(t),
                                  visualDensity: VisualDensity.compact,
                                ))
                            .toList(),
                      ),
                    ],
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildTrending(BuildContext context, List<TrendingItem> trending) {
    return Card(
      margin: const EdgeInsets.symmetric(vertical: AppSizes.sm),
      child: Padding(
        padding: const EdgeInsets.all(AppSizes.md),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              'Món đang nổi bật',
              style: TextStyle(fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: AppSizes.sm),
            SizedBox(
              height: 140,
              child: ListView.builder(
                scrollDirection: Axis.horizontal,
                itemCount: trending.length,
                itemBuilder: (context, index) {
                  final item = trending[index];
                  return GestureDetector(
                    onTap: () {
                      if (item.isRecipe) {
                        context.push('/recipe/${item.id}');
                      } else {
                        context.push('/post/${item.id}');
                      }
                    },
                    child: Container(
                      width: 180,
                      margin: const EdgeInsets.only(right: AppSizes.md),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          AspectRatio(
                            aspectRatio: 16 / 9,
                            child: Container(
                              decoration: BoxDecoration(
                                color: Colors.grey.shade200,
                                borderRadius: BorderRadius.circular(12),
                                image: item.photoUrl != null &&
                                        item.photoUrl!.isNotEmpty
                                    ? DecorationImage(
                                        image: NetworkImage(item.photoUrl!),
                                        fit: BoxFit.cover,
                                      )
                                    : null,
                              ),
                              child: item.photoUrl == null ||
                                      item.photoUrl!.isEmpty
                                  ? const Icon(Icons.image, color: Colors.grey)
                                  : null,
                            ),
                          ),
                          const SizedBox(height: 6),
                          Text(
                            item.title,
                            maxLines: 2,
                            overflow: TextOverflow.ellipsis,
                            style: const TextStyle(fontWeight: FontWeight.w600),
                          ),
                          const SizedBox(height: 4),
                          Chip(
                            label: Text(item.isRecipe ? 'Công thức' : 'Bài viết'),
                            visualDensity: VisualDensity.compact,
                          ),
                        ],
                      ),
                    ),
                  );
                },
              ),
            ),
          ],
        ),
      ),
    );
  }
}
