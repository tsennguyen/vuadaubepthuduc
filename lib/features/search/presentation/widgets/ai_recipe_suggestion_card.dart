import 'package:flutter/material.dart';

import '../../domain/ai_recipe_suggestion.dart';

class AiRecipeSuggestionCard extends StatelessWidget {
  const AiRecipeSuggestionCard({
    super.key,
    required this.suggestion,
    required this.onPreview,
    required this.onUseAsTemplate,
  });

  final AiRecipeSuggestion suggestion;
  final VoidCallback onPreview;
  final VoidCallback onUseAsTemplate;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;
    final isDark = colorScheme.brightness == Brightness.dark;

    return Card(
      margin: const EdgeInsets.only(bottom: 12),
      elevation: isDark ? 0 : 2,
      shadowColor: isDark ? Colors.black.withValues(alpha: 0.4) : Colors.black12,
      color: colorScheme.surface,
      surfaceTintColor: colorScheme.surfaceTint,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(16),
        side: BorderSide(color: colorScheme.outlineVariant.withValues(alpha: 0.6)),
      ),
      clipBehavior: Clip.antiAlias,
      child: InkWell(
        onTap: onPreview,
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Title
              Text(
                suggestion.title,
                style: theme.textTheme.titleMedium?.copyWith(
                  fontWeight: FontWeight.bold,
                ),
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
              ),
              const SizedBox(height: 4),
              // Description
              if (suggestion.description.isNotEmpty) ...[
                Text(
                  suggestion.description,
                  style: theme.textTheme.bodyMedium?.copyWith(
                    color: colorScheme.onSurfaceVariant,
                  ),
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                ),
                const SizedBox(height: 12),
              ],
              // Tags
              if (suggestion.tags.isNotEmpty) ...[
                Wrap(
                  spacing: 8,
                  runSpacing: 4,
                  children: suggestion.tags.take(3).map((tag) {
                    return Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 8,
                        vertical: 4,
                      ),
                      decoration: BoxDecoration(
                        color: colorScheme.surfaceContainerHighest.withValues(alpha: isDark ? 0.8 : 1),
                        borderRadius: BorderRadius.circular(8),
                        border: Border.all(
                          color: colorScheme.outlineVariant.withValues(alpha: 0.4),
                        ),
                      ),
                      child: Text(
                        tag,
                        style: TextStyle(
                          fontSize: 12,
                          color: colorScheme.onSurfaceVariant,
                        ),
                      ),
                    );
                  }).toList(),
                ),
                const SizedBox(height: 12),
              ],
              // Meta
              Row(
                children: [
                  _InfoIcon(
                    icon: Icons.format_list_bulleted,
                    label: '${suggestion.ingredientCount} nguyên liệu',
                  ),
                  const SizedBox(width: 16),
                  _InfoIcon(
                    icon: Icons.check_circle_outline,
                    label: '${suggestion.stepCount} bước',
                  ),
                  if (suggestion.estimatedMinutes != null) ...[
                    const SizedBox(width: 16),
                    _InfoIcon(
                      icon: Icons.access_time,
                      label: '${suggestion.estimatedMinutes} phút',
                    ),
                  ],
                ],
              ),
              const SizedBox(height: 16),
              // Actions
              Row(
                mainAxisAlignment: MainAxisAlignment.end,
                children: [
                  OutlinedButton(
                    onPressed: onPreview,
                    child: const Text('Xem chi tiết'),
                  ),
                  const SizedBox(width: 12),
                  ElevatedButton(
                    style: ElevatedButton.styleFrom(
                      backgroundColor: colorScheme.primary,
                      foregroundColor: colorScheme.onPrimary,
                      elevation: 0,
                    ),
                    onPressed: onUseAsTemplate,
                    child: const Text('Dùng làm mẫu'),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _InfoIcon extends StatelessWidget {
  const _InfoIcon({required this.icon, required this.label});

  final IconData icon;
  final String label;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;
    return Row(
      children: [
        Icon(icon, size: 16, color: colorScheme.secondary),
        const SizedBox(width: 4),
        Text(
          label,
          style: theme.textTheme.bodySmall?.copyWith(
            color: colorScheme.onSurfaceVariant,
          ),
        ),
      ],
    );
  }
}
