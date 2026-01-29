import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import '../../../../core/constants/app_sizes.dart';
import '../../data/ai_recipe_idea.dart';
import '../../domain/ai_recipe_suggestion.dart';

class AiRecipeIdeaCard extends StatelessWidget {
  const AiRecipeIdeaCard({super.key, required this.idea});

  final AiRecipeIdea idea;

  @override
  Widget build(BuildContext context) {
    final textTheme = Theme.of(context).textTheme;

    return Card(
      margin: const EdgeInsets.symmetric(vertical: 6),
      child: Padding(
        padding: const EdgeInsets.all(AppSizes.md),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              idea.title,
              style:
                  textTheme.titleMedium?.copyWith(fontWeight: FontWeight.w600),
            ),
            if (idea.shortDescription.isNotEmpty) ...[
              const SizedBox(height: AppSizes.sm),
              Text(idea.shortDescription, style: textTheme.bodyMedium),
            ],
            if (idea.tags.isNotEmpty) ...[
              const SizedBox(height: AppSizes.sm),
              Wrap(
                spacing: 8,
                runSpacing: 4,
                children: idea.tags
                    .map(
                      (t) => Chip(
                        label: Text(t),
                        visualDensity: VisualDensity.compact,
                      ),
                    )
                    .toList(),
              ),
            ],
            const SizedBox(height: AppSizes.sm),
            Row(
              children: [
                _InfoPill(
                  icon: Icons.list_alt,
                  label: '${idea.ingredients.length} nguyên liệu',
                ),
                const SizedBox(width: AppSizes.sm),
                _InfoPill(
                  icon: Icons.menu_book,
                  label: '${idea.steps.length} bước',
                ),
              ],
            ),
            const SizedBox(height: AppSizes.sm),
            Align(
              alignment: Alignment.centerRight,
              child: OutlinedButton(
                onPressed: () {
                  final suggestion = AiRecipeSuggestion(
                    id: DateTime.now().millisecondsSinceEpoch.toString(),
                    title: idea.title,
                    description: idea.shortDescription,
                    tags: idea.tags,
                    ingredientCount: idea.ingredients.length,
                    stepCount: idea.steps.length,
                    ingredients: idea.ingredients
                        .map((e) => RecipeIngredient(original: e))
                        .toList(),
                    steps:
                        idea.steps.map((e) => RecipeStep(content: e)).toList(),
                  );
                  context.push('/create-recipe', extra: {'fromAi': suggestion});
                },
                child: const Text('Dùng làm mẫu'),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _InfoPill extends StatelessWidget {
  const _InfoPill({required this.icon, required this.label});

  final IconData icon;
  final String label;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(
        horizontal: AppSizes.sm,
        vertical: AppSizes.xs,
      ),
      decoration: BoxDecoration(
        color: Theme.of(context).colorScheme.surfaceContainerHighest,
        borderRadius: BorderRadius.circular(12),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 18),
          const SizedBox(width: 6),
          Text(label, style: Theme.of(context).textTheme.bodySmall),
        ],
      ),
    );
  }
}
