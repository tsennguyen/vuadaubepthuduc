import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:image_picker/image_picker.dart';

import '../../search/domain/ai_recipe_suggestion.dart';

class AiRecipePreviewPage extends ConsumerStatefulWidget {
  const AiRecipePreviewPage({super.key, required this.suggestion});

  final AiRecipeSuggestion suggestion;

  @override
  ConsumerState<AiRecipePreviewPage> createState() =>
      _AiRecipePreviewPageState();
}

class _AiRecipePreviewPageState extends ConsumerState<AiRecipePreviewPage> {
  XFile? _coverImage;

  Future<void> _pickImage() async {
    final picker = ImagePicker();
    final image = await picker.pickImage(source: ImageSource.gallery);
    if (image != null) {
      setState(() {
        _coverImage = image;
      });
    }
  }

  void _useAsTemplate() {
    context.push(
      '/create-recipe',
      extra: {
        'fromAi': widget.suggestion,
        'initialCoverPath': _coverImage?.path,
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final s = widget.suggestion;

    return Scaffold(
      appBar: AppBar(title: const Text('Xem công thức AI')),
      body: Column(
        children: [
          Expanded(
            child: SingleChildScrollView(
              padding: const EdgeInsets.only(bottom: 80),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // Cover
                  GestureDetector(
                    onTap: _pickImage,
                    child: _coverImage != null
                        ? (kIsWeb
                            ? Image.network(
                                _coverImage!.path,
                                height: 200,
                                width: double.infinity,
                                fit: BoxFit.cover,
                              )
                            : Image.file(
                                File(_coverImage!.path),
                                height: 200,
                                width: double.infinity,
                                fit: BoxFit.cover,
                              ))
                        : Container(
                            height: 200,
                            width: double.infinity,
                            color: Colors.grey.shade200,
                            child: const Center(
                              child: Icon(Icons.add_a_photo,
                                  size: 48, color: Colors.grey),
                            ),
                          ),
                  ),
                  Padding(
                    padding:
                        const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                    child: Row(
                      children: [
                        OutlinedButton.icon(
                          onPressed: _pickImage,
                          icon: const Icon(Icons.photo_library_outlined),
                          label: const Text('Chọn ảnh bìa (tuỳ chọn)'),
                        ),
                        if (_coverImage != null) ...[
                          const SizedBox(width: 12),
                          Text(
                            'Đã chọn',
                            style: theme.textTheme.bodySmall,
                          ),
                        ],
                      ],
                    ),
                  ),
                  Padding(
                    padding: const EdgeInsets.all(16),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(s.title, style: theme.textTheme.headlineSmall),
                        const SizedBox(height: 8),
                        Text(s.description),
                        const SizedBox(height: 16),
                        Wrap(
                          spacing: 8,
                          children: [
                            if (s.estimatedMinutes != null)
                              Chip(
                                avatar: const Icon(Icons.access_time, size: 16),
                                label: Text('${s.estimatedMinutes} phút'),
                              ),
                            if (s.difficulty != null)
                              Chip(
                                avatar: const Icon(Icons.bar_chart, size: 16),
                                label: Text(s.difficulty!),
                              ),
                            ...s.tags.map((t) => Chip(label: Text(t))),
                          ],
                        ),
                        const SizedBox(height: 24),
                        Text('Nguyên liệu', style: theme.textTheme.titleMedium),
                        const SizedBox(height: 8),
                        ...s.ingredients.map((i) => Padding(
                              padding: const EdgeInsets.symmetric(vertical: 4),
                              child: Row(children: [
                                const Icon(Icons.circle, size: 6),
                                const SizedBox(width: 8),
                                Expanded(child: Text(i.original)),
                              ]),
                            )),
                        const SizedBox(height: 24),
                        Text('Cách làm', style: theme.textTheme.titleMedium),
                        const SizedBox(height: 8),
                        ...s.steps.asMap().entries.map((e) => Padding(
                              padding: const EdgeInsets.symmetric(vertical: 8),
                              child: Row(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  CircleAvatar(
                                      radius: 12,
                                      child: Text('${e.key + 1}',
                                          style:
                                              const TextStyle(fontSize: 12))),
                                  const SizedBox(width: 12),
                                  Expanded(child: Text(e.value.content)),
                                ],
                              ),
                            )),
                        if (s.nutrition != null) ...[
                          const SizedBox(height: 24),
                          Text('Giá trị dinh dưỡng (tham khảo)',
                              style: theme.textTheme.titleMedium),
                          const SizedBox(height: 8),
                          Container(
                            padding: const EdgeInsets.all(12),
                            decoration: BoxDecoration(
                                color:
                                    theme.colorScheme.surfaceContainerHighest,
                                borderRadius: BorderRadius.circular(12)),
                            child: Row(
                                mainAxisAlignment:
                                    MainAxisAlignment.spaceAround,
                                children: [
                                  _NutriItem('Calories',
                                      '${s.nutrition!.macros.calories.toInt()}'),
                                  _NutriItem('Protein',
                                      '${s.nutrition!.macros.protein.toInt()}g'),
                                  _NutriItem('Carbs',
                                      '${s.nutrition!.macros.carbs.toInt()}g'),
                                  _NutriItem('Fat',
                                      '${s.nutrition!.macros.fat.toInt()}g'),
                                ]),
                          ),
                        ],
                      ],
                    ),
                  ),
                ],
              ),
            ),
          ),
          Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
                color: theme.colorScheme.surface,
                boxShadow: const [
                  BoxShadow(
                      color: Colors.black12,
                      blurRadius: 4,
                      offset: Offset(0, -2))
                ]),
            child: SafeArea(
              child: SizedBox(
                width: double.infinity,
                child: FilledButton.icon(
                  onPressed: _useAsTemplate,
                  icon: const Icon(Icons.edit_note),
                  label: const Text('Dùng làm mẫu để đăng công thức'),
                  style: FilledButton.styleFrom(
                    padding: const EdgeInsets.all(16),
                  ),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _NutriItem extends StatelessWidget {
  const _NutriItem(this.label, this.value);
  final String label;
  final String value;
  @override
  Widget build(BuildContext context) {
    return Column(children: [
      Text(value,
          style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
      Text(label, style: const TextStyle(fontSize: 12)),
    ]);
  }
}
