import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../core/constants/app_sizes.dart';
import '../../../core/widgets/tag_chip.dart';
import '../../feed/widgets/recipe_card.dart';
import '../application/ingredient_search_controller.dart';
import '../data/search_repository.dart';
import 'widgets/search_suggest_view.dart';

class IngredientSearchPage extends ConsumerStatefulWidget {
  const IngredientSearchPage({super.key});

  @override
  ConsumerState<IngredientSearchPage> createState() =>
      _IngredientSearchPageState();
}

class _IngredientSearchPageState extends ConsumerState<IngredientSearchPage> {
  final TextEditingController _controller = TextEditingController();

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  void _addIngredient(String value) {
    ref.read(ingredientSearchControllerProvider.notifier).addIngredient(value);
    _controller.clear();
  }

  Future<void> _submit() async {
    await ref.read(ingredientSearchControllerProvider.notifier).submit();
  }

  @override
  Widget build(BuildContext context) {
    final state = ref.watch(ingredientSearchControllerProvider);

    return Scaffold(
      appBar: AppBar(
        title: const Text('Tìm theo nguyên liệu'),
      ),
      body: Padding(
        padding: const EdgeInsets.all(AppSizes.md),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Expanded(
                  child: TextField(
                    controller: _controller,
                    textInputAction: TextInputAction.done,
                    onSubmitted: (v) {
                      _addIngredient(v);
                      _submit();
                    },
                    decoration: const InputDecoration(
                      hintText: 'Thêm nguyên liệu, ví dụ: trứng, cà chua…',
                      prefixIcon: Icon(Icons.add),
                    ),
                  ),
                ),
                const SizedBox(width: AppSizes.sm),
                ElevatedButton(
                  onPressed: () {
                    _addIngredient(_controller.text);
                    _submit();
                  },
                  child: const Text('Tìm món'),
                ),
              ],
            ),
            const SizedBox(height: AppSizes.sm),
            Wrap(
              spacing: 8,
              runSpacing: 4,
              children: state.ingredients
                  .map(
                    (ing) => InputChip(
                      label: Text(ing),
                      onDeleted: () {
                        ref
                            .read(ingredientSearchControllerProvider.notifier)
                            .removeIngredient(ing);
                      },
                    ),
                  )
                  .toList(),
            ),
            const SizedBox(height: AppSizes.sm),
            Row(
              children: [
                ChoiceChip(
                  label: const Text('Có ít nhất một'),
                  selected: state.mode == IngredientFilterMode.any,
                  onSelected: (_) {
                    ref
                        .read(ingredientSearchControllerProvider.notifier)
                        .changeMode(IngredientFilterMode.any);
                    _submit();
                  },
                ),
                const SizedBox(width: AppSizes.sm),
                ChoiceChip(
                  label: const Text('Có toàn bộ'),
                  selected: state.mode == IngredientFilterMode.all,
                  onSelected: (_) {
                    ref
                        .read(ingredientSearchControllerProvider.notifier)
                        .changeMode(IngredientFilterMode.all);
                    _submit();
                  },
                ),
              ],
            ),
            const SizedBox(height: AppSizes.md),
            Expanded(child: _buildResults(context, state)),
          ],
        ),
      ),
    );
  }

  Widget _buildResults(
      BuildContext context, IngredientSearchState state) {
    if (state.isLoading) {
      return const Center(child: CircularProgressIndicator());
    }
    if (state.ingredients.isEmpty) {
      return const Center(
          child: Text('Thêm nguyên liệu để tìm món phù hợp.'));
    }
    if (state.error != null) {
      return Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Text('Đã xảy ra lỗi.'),
            const SizedBox(height: AppSizes.sm),
            ElevatedButton(
              onPressed: _submit,
              child: const Text('Thử lại'),
            ),
          ],
        ),
      );
    }
    if (state.results.isEmpty) {
      return Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          const Center(child: Text('Không tìm thấy món phù hợp.')),
          const SizedBox(height: AppSizes.md),
          SearchSuggestView(
            rawQuery: state.ingredients.join(', '),
            tokens: state.ingredients,
            type: 'ingredients',
          ),
        ],
      );
    }
    return ListView.builder(
      itemCount: state.results.length,
      itemBuilder: (context, index) {
        final recipe = state.results[index];
        return Card(
          margin: const EdgeInsets.symmetric(vertical: 8),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Padding(
                padding: EdgeInsets.only(
                  top: AppSizes.sm,
                  left: AppSizes.sm,
                ),
                child: TagChip(label: 'Công thức'),
              ),
              RecipeCard(
                recipe: recipe,
                onTap: () => context.push('/recipe/${recipe.id}'),
              ),
            ],
          ),
        );
      },
    );
  }
}
