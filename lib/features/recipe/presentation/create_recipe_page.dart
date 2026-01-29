import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:image_picker/image_picker.dart';
import 'package:go_router/go_router.dart';

import '../../../app/l10n.dart';
import '../../../app/language_controller.dart';
import '../application/recipe_form_controller.dart';
import '../../feed/data/recipe_model.dart';
import '../../search/domain/ai_recipe_suggestion.dart';
import '../../profile/domain/user_ban_guard.dart';

class CreateRecipePage extends ConsumerStatefulWidget {
  const CreateRecipePage({
    super.key,
    this.fromAi,
    this.initialCoverPath,
  });

  final AiRecipeSuggestion? fromAi;
  final String? initialCoverPath;

  @override
  ConsumerState<CreateRecipePage> createState() => _CreateRecipePageState();
}

class _CreateRecipePageState extends ConsumerState<CreateRecipePage> {
  @override
  void initState() {
    super.initState();
    if (widget.fromAi != null) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        ref
            .read(recipeFormControllerProvider.notifier)
            .loadFromAi(widget.fromAi!, coverPath: widget.initialCoverPath);
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final state = ref.watch(recipeFormControllerProvider);
    final controller = ref.read(recipeFormControllerProvider.notifier);

    Future<void> submit() async {
      final s = S(ref.read(localeProvider));
      final uid = FirebaseAuth.instance.currentUser?.uid;
      if (uid == null) {
        if (!context.mounted) return;
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(s.pleaseLogin),
            behavior: SnackBarBehavior.floating,
          ),
        );
        return;
      }
      try {
        final id = await controller.submitCreate(uid);
        if (!context.mounted) return;
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(s.recipePublishedSuccess),
            behavior: SnackBarBehavior.floating,
            backgroundColor: Colors.green,
          ),
        );
        if (context.canPop()) {
          context.pop(id);
        } else {
          context.go('/');
        }
      } on UserBannedException catch (e) {
        if (!context.mounted) return;
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(e.message),
            behavior: SnackBarBehavior.floating,
            backgroundColor: Theme.of(context).colorScheme.error,
          ),
        );
      } catch (e) {
        if (!context.mounted) return;
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(s.errorMessage(e.toString())),
            behavior: SnackBarBehavior.floating,
            backgroundColor: Theme.of(context).colorScheme.error,
          ),
        );
      }
    }

    final s = S(ref.watch(localeProvider));
    return _RecipeFormView(
      title: s.createRecipe,
      state: state,
      controller: controller,
      onSubmit: submit,
      submitLabel: s.publishRecipe,
      isSubmitting: state.isSubmitting,
    );
  }
}

class EditRecipePage extends ConsumerStatefulWidget {
  const EditRecipePage({super.key, required this.recipeId});

  final String recipeId;

  @override
  ConsumerState<EditRecipePage> createState() => _EditRecipePageState();
}

class _EditRecipePageState extends ConsumerState<EditRecipePage> {
  Recipe? _recipe;
  bool _loading = true;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    final repo = ref.read(recipeRepositoryProvider);
    final recipe = await repo.getRecipeById(widget.recipeId);
    if (!context.mounted) return;
    setState(() {
      _recipe = recipe;
      _loading = false;
    });
    if (recipe != null) {
      await ref.read(recipeFormControllerProvider.notifier).loadFromRecipe(recipe);
    }
  }

  @override
  Widget build(BuildContext context) {
    final state = ref.watch(recipeFormControllerProvider);
    final controller = ref.read(recipeFormControllerProvider.notifier);

    if (_loading) {
      return const Scaffold(body: Center(child: CircularProgressIndicator()));
    }
    if (_recipe == null) {
      final s = S(ref.watch(localeProvider));
      return Scaffold(body: Center(child: Text(s.recipeNotFound)));
    }

    Future<void> submit() async {
      final s = S(ref.read(localeProvider));
      final recipe = _recipe;
      if (recipe == null) return;
      try {
        await controller.submitUpdate(recipe);
        if (!context.mounted) return;
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(s.recipeSavedSuccess),
            behavior: SnackBarBehavior.floating,
            backgroundColor: Colors.green,
          ),
        );
        if (context.canPop()) {
          context.pop(widget.recipeId);
        } else {
          context.go('/');
        }
      } on UserBannedException catch (e) {
        if (!context.mounted) return;
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(e.message),
            behavior: SnackBarBehavior.floating,
            backgroundColor: Theme.of(context).colorScheme.error,
          ),
        );
      } catch (e) {
        if (!context.mounted) return;
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(s.errorMessage(e.toString())),
            behavior: SnackBarBehavior.floating,
            backgroundColor: Theme.of(context).colorScheme.error,
          ),
        );
      }
    }

    Future<void> softDelete() async {
      final s = S(ref.read(localeProvider));
      try {
        await controller.softDelete(widget.recipeId);
        if (!context.mounted) return;
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(s.recipeHidden),
            behavior: SnackBarBehavior.floating,
          ),
        );
        if (context.canPop()) {
          context.pop();
        } else {
          context.go('/');
        }
      } on UserBannedException catch (e) {
        if (!context.mounted) return;
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(e.message),
            behavior: SnackBarBehavior.floating,
          ),
        );
      } catch (e) {
        if (!context.mounted) return;
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(s.errorMessage(e.toString())),
            behavior: SnackBarBehavior.floating,
          ),
        );
      }
    }

    Future<void> hardDelete() async {
      final s = S(ref.read(localeProvider));
      try {
        await controller.hardDelete(widget.recipeId);
        if (!context.mounted) return;
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(s.recipeDeletedForever),
            behavior: SnackBarBehavior.floating,
          ),
        );
        if (context.canPop()) {
          context.pop();
        } else {
          context.go('/');
        }
      } on UserBannedException catch (e) {
        if (!context.mounted) return;
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(e.message),
            behavior: SnackBarBehavior.floating,
          ),
        );
      } catch (e) {
        if (!context.mounted) return;
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(s.errorMessage(e.toString())),
            behavior: SnackBarBehavior.floating,
          ),
        );
      }
    }

    final s = S(ref.watch(localeProvider));
    return _RecipeFormView(
      title: s.editRecipe,
      state: state,
      controller: controller,
      onSubmit: submit,
      submitLabel: s.saveChanges,
      isSubmitting: state.isSubmitting,
      onSoftDelete: softDelete,
      onHardDelete: hardDelete,
    );
  }
}

// FIX: Chuyển sang StatefulWidget để tạo controllers 1 lần duy nhất
class _RecipeFormView extends ConsumerStatefulWidget {
  const _RecipeFormView({
    required this.title,
    required this.state,
    required this.controller,
    required this.onSubmit,
    required this.submitLabel,
    required this.isSubmitting,
    this.onSoftDelete,
    this.onHardDelete,
  });

  final String title;
  final RecipeFormState state;
  final RecipeFormController controller;
  final Future<void> Function() onSubmit;
  final String submitLabel;
  final bool isSubmitting;
  final Future<void> Function()? onSoftDelete;
  final Future<void> Function()? onHardDelete;

  @override
  ConsumerState<_RecipeFormView> createState() => _RecipeFormViewState();
}

class _RecipeFormViewState extends ConsumerState<_RecipeFormView> {
  // FIX: Tạo controllers trong state, không rebuild
  late final TextEditingController _titleController;
  late final TextEditingController _descriptionController;
  late final TextEditingController _cookTimeController;
  late final TextEditingController _tagsController;

  @override
  void initState() {
    super.initState();
    _titleController = TextEditingController(text: widget.state.title);
    _descriptionController = TextEditingController(text: widget.state.description);
    _cookTimeController = TextEditingController(
      text: widget.state.cookTimeMinutes?.toString() ?? '',
    );
    _tagsController = TextEditingController(text: widget.state.tags.join(', '));
  }

  @override
  void dispose() {
    _titleController.dispose();
    _descriptionController.dispose();
    _cookTimeController.dispose();
    _tagsController.dispose();
    super.dispose();
  }

  void _syncToController() {
    widget.controller.setTitle(_titleController.text);
    widget.controller.setDescription(_descriptionController.text);
    widget.controller.setCookTime(_cookTimeController.text);
    widget.controller.setTagsFromString(_tagsController.text);
  }

  Future<void> _handleSubmit() async {
    _syncToController();
    await widget.onSubmit();
  }

  @override
  Widget build(BuildContext context) {
    final s = S(ref.watch(localeProvider));
    final theme = Theme.of(context);

    return Scaffold(
      appBar: AppBar(
        title: Text(
          widget.title,
          style: const TextStyle(fontWeight: FontWeight.bold),
        ),
        flexibleSpace: Container(
          decoration: BoxDecoration(
            gradient: LinearGradient(
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
              colors: [
                theme.colorScheme.surface,
                theme.colorScheme.surfaceContainer,
              ],
            ),
          ),
        ),
        elevation: 0,
        scrolledUnderElevation: 2,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back),
          onPressed: () {
            if (context.canPop()) {
              context.pop();
            } else {
              context.go('/');
            }
          },
        ),
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Title field
            _buildStyledTextField(
              controller: _titleController,
              label: s.recipeName,
              hint: s.recipeNameHint,
              icon: Icons.restaurant,
            ),

            const SizedBox(height: 16),

            // Description field
            _buildStyledTextField(
              controller: _descriptionController,
              label: s.description,
              hint: s.descriptionHint,
              icon: Icons.description_outlined,
              maxLines: 3,
            ),

            const SizedBox(height: 16),

            // Cook time and difficulty
            Row(
              children: [
                Expanded(
                  child: _buildStyledTextField(
                    controller: _cookTimeController,
                    label: s.cookTime,
                    hint: s.minutes,
                    icon: Icons.timer_outlined,
                    keyboardType: TextInputType.number,
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Container(
                    decoration: BoxDecoration(
                      color: theme.colorScheme.surface,
                      borderRadius: BorderRadius.circular(16),
                      border: Border.all(
                        color: theme.colorScheme.outline.withValues(alpha: 0.2),
                      ),
                      boxShadow: [
                        BoxShadow(
                          color: Colors.black.withValues(alpha: 0.05),
                          blurRadius: 8,
                          offset: const Offset(0, 2),
                        ),
                      ],
                    ),
                    child: DropdownButtonFormField<String>(
                      initialValue: widget.state.difficulty,
                      items: [
                        DropdownMenuItem(value: 'De', child: Text(s.difficultyEasy)),
                        DropdownMenuItem(value: 'Trung binh', child: Text(s.difficultyMedium)),
                        DropdownMenuItem(value: 'Kho', child: Text(s.difficultyHard)),
                      ],
                      decoration: InputDecoration(
                        labelText: s.difficulty,
                        labelStyle: TextStyle(
                          color: theme.colorScheme.primary,
                          fontWeight: FontWeight.w500,
                        ),
                        border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(16),
                          borderSide: BorderSide.none,
                        ),
                        filled: true,
                        fillColor: theme.colorScheme.surfaceContainerHighest
                            .withValues(alpha: 0.3),
                        contentPadding: const EdgeInsets.symmetric(
                          horizontal: 20,
                          vertical: 18,
                        ),
                        prefixIcon: Icon(
                          Icons.bar_chart_rounded,
                          color: theme.colorScheme.primary,
                        ),
                      ),
                      onChanged: widget.controller.setDifficulty,
                    ),
                  ),
                ),
              ],
            ),

            const SizedBox(height: 24),

            // Ingredients section
            _ListSection(
              title: s.ingredients,
              items: widget.state.ingredients,
              onAdd: widget.controller.addIngredient,
              onRemove: widget.controller.removeIngredient,
              onChanged: widget.controller.updateIngredient,
            ),

            const SizedBox(height: 24),

            // Steps section
            _ListSection(
              title: s.steps,
              items: widget.state.steps,
              onAdd: widget.controller.addStep,
              onRemove: widget.controller.removeStep,
              onChanged: widget.controller.updateStep,
              numbered: true,
            ),

            const SizedBox(height: 24),

            // Tags field
            _buildStyledTextField(
              controller: _tagsController,
              label: s.tags,
              hint: s.recipeTagsHint,
              icon: Icons.tag_rounded,
            ),

            const SizedBox(height: 24),

            // Images section
            _ImageSection(
              coverUrl: widget.state.existingCoverUrl,
              coverImage: widget.state.coverImage,
              extraImages: widget.state.extraImages,
              existingExtraUrls: widget.state.existingExtraUrls,
              onPickCover: widget.controller.pickCoverImage,
              onPickExtra: widget.controller.pickExtraImages,
              onRemoveExistingExtra: widget.controller.removeExistingExtra,
              onRemoveNewExtra: widget.controller.removeNewExtraAt,
            ),

            const SizedBox(height: 24),

            // Nutrition section
            _NutritionSection(
              controller: widget.controller,
              state: widget.state,
            ),

            const SizedBox(height: 32),

            // Submit button
            Container(
              width: double.infinity,
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(16),
                gradient: LinearGradient(
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                  colors: widget.isSubmitting
                      ? [
                          theme.colorScheme.surfaceContainerHighest,
                          theme.colorScheme.surfaceContainer,
                        ]
                      : [
                          theme.colorScheme.primary,
                          theme.colorScheme.secondary,
                        ],
                ),
                boxShadow: widget.isSubmitting
                    ? null
                    : [
                        BoxShadow(
                          color: theme.colorScheme.primary.withValues(alpha: 0.4),
                          blurRadius: 12,
                          offset: const Offset(0, 4),
                        ),
                      ],
              ),
              child: ElevatedButton(
                onPressed: widget.isSubmitting ? null : _handleSubmit,
                style: ElevatedButton.styleFrom(
                  backgroundColor: Colors.transparent,
                  shadowColor: Colors.transparent,
                  padding: const EdgeInsets.symmetric(vertical: 18),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(16),
                  ),
                ),
                child: widget.isSubmitting
                    ? const SizedBox(
                        width: 24,
                        height: 24,
                        child: CircularProgressIndicator(
                          strokeWidth: 2.5,
                          color: Colors.white70,
                        ),
                      )
                    : Row(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          const Icon(Icons.send_rounded, size: 20, color: Colors.white),
                          const SizedBox(width: 8),
                          Text(
                            widget.submitLabel,
                            style: const TextStyle(
                              fontSize: 16,
                              fontWeight: FontWeight.bold,
                              color: Colors.white,
                              letterSpacing: 0.5,
                            ),
                          ),
                        ],
                      ),
              ),
            ),

            // Delete buttons
            if (widget.onSoftDelete != null || widget.onHardDelete != null) ...[
              const SizedBox(height: 16),
              Row(
                children: [
                  if (widget.onSoftDelete != null)
                    Expanded(
                      child: OutlinedButton.icon(
                        onPressed: widget.isSubmitting ? null : widget.onSoftDelete,
                        style: OutlinedButton.styleFrom(
                          foregroundColor: Colors.orange,
                          side: const BorderSide(color: Colors.orange, width: 2),
                          padding: const EdgeInsets.symmetric(vertical: 14),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(12),
                          ),
                        ),
                        icon: const Icon(Icons.visibility_off, size: 20),
                        label: Text(s.hideRecipe),
                      ),
                    ),
                  if (widget.onSoftDelete != null && widget.onHardDelete != null)
                    const SizedBox(width: 12),
                  if (widget.onHardDelete != null)
                    Expanded(
                      child: OutlinedButton.icon(
                        onPressed: widget.isSubmitting ? null : widget.onHardDelete,
                        style: OutlinedButton.styleFrom(
                          foregroundColor: Colors.red,
                          side: const BorderSide(color: Colors.red, width: 2),
                          padding: const EdgeInsets.symmetric(vertical: 14),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(12),
                          ),
                        ),
                        icon: const Icon(Icons.delete_forever, size: 20),
                        label: Text(s.deleteForever),
                      ),
                    ),
                ],
              ),
            ],

            const SizedBox(height: 24),
          ],
        ),
      ),
    );
  }

  Widget _buildStyledTextField({
    required TextEditingController controller,
    required String label,
    required String hint,
    required IconData icon,
    int maxLines = 1,
    TextInputType? keyboardType,
  }) {
    final theme = Theme.of(context);

    return Container(
      decoration: BoxDecoration(
        color: theme.colorScheme.surface,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: theme.colorScheme.outline.withValues(alpha: 0.2),
        ),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.05),
            blurRadius: 8,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: TextField(
        controller: controller,
        maxLines: maxLines,
        keyboardType: keyboardType,
        decoration: InputDecoration(
          labelText: label,
          labelStyle: TextStyle(
            color: theme.colorScheme.primary,
            fontWeight: FontWeight.w500,
          ),
          hintText: hint,
          hintStyle: TextStyle(
            color: theme.colorScheme.onSurface.withValues(alpha: 0.4),
            fontSize: 14,
          ),
          border: OutlineInputBorder(
            borderRadius: BorderRadius.circular(16),
            borderSide: BorderSide.none,
          ),
          filled: true,
          fillColor: theme.colorScheme.surfaceContainerHighest.withValues(alpha: 0.3),
          contentPadding: const EdgeInsets.all(20),
          prefixIcon: Icon(icon, color: theme.colorScheme.primary),
        ),
      ),
    );
  }
}

// FIX: Chuyển sang StatefulWidget cho ingredients/steps với controllers riêng
class _ListSection extends ConsumerStatefulWidget {
  const _ListSection({
    required this.title,
    required this.items,
    required this.onAdd,
    required this.onRemove,
    required this.onChanged,
    this.numbered = false,
  });

  final String title;
  final List<String> items;
  final VoidCallback onAdd;
  final void Function(int) onRemove;
  final void Function(int, String) onChanged;
  final bool numbered;

  @override
  ConsumerState<_ListSection> createState() => _ListSectionState();
}

class _ListSectionState extends ConsumerState<_ListSection> {
  final Map<int, TextEditingController> _controllers = {};

  @override
  void initState() {
    super.initState();
    _updateControllers();
  }

  @override
  void didUpdateWidget(_ListSection oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.items != widget.items) {
      _updateControllers();
    }
  }

  void _updateControllers() {
    // Remove controllers for deleted items
    _controllers.removeWhere((key, value) {
      if (key >= widget.items.length) {
        value.dispose();
        return true;
      }
      return false;
    });

    // Add controllers for new items
    for (int i = 0; i < widget.items.length; i++) {
      if (!_controllers.containsKey(i)) {
        _controllers[i] = TextEditingController(text: widget.items[i]);
      } else if (_controllers[i]!.text != widget.items[i]) {
        // Update text if changed externally (from AI, etc)
        _controllers[i]!.text = widget.items[i];
      }
    }
  }

  @override
  void dispose() {
    for (var controller in _controllers.values) {
      controller.dispose();
    }
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final s = S(ref.watch(localeProvider));

    return Container(
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [
            theme.colorScheme.surfaceContainerHighest.withValues(alpha: 0.3),
            theme.colorScheme.surfaceContainer.withValues(alpha: 0.2),
          ],
        ),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: theme.colorScheme.outline.withValues(alpha: 0.2),
        ),
      ),
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(
                widget.numbered ? Icons.format_list_numbered : Icons.checklist_rounded,
                color: theme.colorScheme.primary,
                size: 22,
              ),
              const SizedBox(width: 8),
              Text(
                widget.title,
                style: theme.textTheme.titleMedium?.copyWith(
                  fontWeight: FontWeight.bold,
                  color: theme.colorScheme.primary,
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          ...widget.items.asMap().entries.map((e) {
            final controller = _controllers[e.key]!;
            return Padding(
              padding: const EdgeInsets.only(bottom: 8),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.center,
                children: [
                  if (widget.numbered)
                    Container(
                      width: 28,
                      height: 28,
                      decoration: BoxDecoration(
                        gradient: LinearGradient(
                          colors: [
                            theme.colorScheme.primary,
                            theme.colorScheme.secondary,
                          ],
                        ),
                        shape: BoxShape.circle,
                      ),
                      alignment: Alignment.center,
                      child: Text(
                        '${e.key + 1}',
                        style: const TextStyle(
                          color: Colors.white,
                          fontWeight: FontWeight.bold,
                          fontSize: 12,
                        ),
                      ),
                    ),
                  if (widget.numbered) const SizedBox(width: 8),
                  Expanded(
                    child: Container(
                      decoration: BoxDecoration(
                        color: theme.colorScheme.surface,
                        borderRadius: BorderRadius.circular(12),
                        boxShadow: [
                          BoxShadow(
                            color: Colors.black.withValues(alpha: 0.05),
                            blurRadius: 4,
                            offset: const Offset(0, 2),
                          ),
                        ],
                      ),
                      child: TextField(
                        controller: controller,
                        decoration: InputDecoration(
                          hintText: s.enterContent,
                          hintStyle: TextStyle(
                            color: theme.colorScheme.onSurface.withValues(alpha: 0.4),
                          ),
                          border: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(12),
                            borderSide: BorderSide.none,
                          ),
                          filled: true,
                          fillColor: theme.colorScheme.surfaceContainerHighest.withValues(alpha: 0.3),
                          contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                          isDense: true,
                        ),
                        onChanged: (val) => widget.onChanged(e.key, val),
                        maxLines: null,
                      ),
                    ),
                  ),
                  const SizedBox(width: 8),
                  IconButton(
                    icon: Icon(
                      Icons.close_rounded,
                      color: theme.colorScheme.error,
                    ),
                    onPressed: () => widget.onRemove(e.key),
                    tooltip: s.remove,
                  ),
                ],
              ),
            );
          }),
          const SizedBox(height: 8),
          OutlinedButton.icon(
            onPressed: widget.onAdd,
            style: OutlinedButton.styleFrom(
              foregroundColor: theme.colorScheme.primary,
              side: BorderSide(
                color: theme.colorScheme.primary.withValues(alpha: 0.5),
                width: 1.5,
              ),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(12),
              ),
            ),
            icon: const Icon(Icons.add_rounded, size: 20),
            label: Text(s.add, style: const TextStyle(fontWeight: FontWeight.w600)),
          ),
        ],
      ),
    );
  }
}

class _ImageSection extends ConsumerWidget {
  const _ImageSection({
    required this.coverUrl,
    required this.coverImage,
    required this.extraImages,
    required this.onPickCover,
    required this.onPickExtra,
    this.existingExtraUrls = const [],
    this.onRemoveExistingExtra,
    this.onRemoveNewExtra,
  });

  final String? coverUrl;
  final XFile? coverImage;
  final List<XFile> extraImages;
  final VoidCallback onPickCover;
  final VoidCallback onPickExtra;
  final List<String> existingExtraUrls;
  final void Function(String url)? onRemoveExistingExtra;
  final void Function(int index)? onRemoveNewExtra;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final theme = Theme.of(context);
    final s = S(ref.watch(localeProvider));

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Icon(Icons.image_rounded, color: theme.colorScheme.primary),
            const SizedBox(width: 8),
            Text(
              s.coverImage,
              style: theme.textTheme.titleMedium?.copyWith(
                fontWeight: FontWeight.bold,
                color: theme.colorScheme.primary,
              ),
            ),
          ],
        ),
        const SizedBox(height: 12),
        GestureDetector(
          onTap: onPickCover,
          child: Container(
            height: 200,
            width: double.infinity,
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(16),
              gradient: (coverUrl == null || coverUrl!.isEmpty)
                  ? LinearGradient(
                      colors: [
                        theme.colorScheme.primaryContainer.withValues(alpha: 0.3),
                        theme.colorScheme.secondaryContainer.withValues(alpha: 0.3),
                      ],
                    )
                  : null,
              image: (coverUrl != null && coverUrl!.isNotEmpty)
                  ? DecorationImage(
                      image: NetworkImage(coverUrl!),
                      fit: BoxFit.cover,
                    )
                  : null,
              border: Border.all(
                color: theme.colorScheme.outline.withValues(alpha: 0.3),
                width: 2,
              ),
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withValues(alpha: 0.1),
                  blurRadius: 8,
                  offset: const Offset(0, 2),
                ),
              ],
            ),
            child: (coverUrl == null || coverUrl!.isEmpty)
                ? Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Icon(
                        Icons.add_photo_alternate_rounded,
                        size: 48,
                        color: theme.colorScheme.primary,
                      ),
                      const SizedBox(height: 8),
                      Text(
                        coverImage != null ? coverImage!.name : s.selectCoverImage,
                        style: TextStyle(
                          color: theme.colorScheme.primary,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ],
                  )
                : null,
          ),
        ),
      ],
    );
  }
}

class _NutritionSection extends ConsumerWidget {
  const _NutritionSection({
    required this.controller,
    required this.state,
  });

  final RecipeFormController controller;
  final RecipeFormState state;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final theme = Theme.of(context);
    final s = S(ref.watch(localeProvider));

    return Container(
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [
            theme.colorScheme.primaryContainer.withValues(alpha: 0.2),
            theme.colorScheme.secondaryContainer.withValues(alpha: 0.2),
          ],
        ),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: theme.colorScheme.outline.withValues(alpha: 0.2),
        ),
      ),
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(Icons.restaurant_menu, color: theme.colorScheme.primary),
              const SizedBox(width: 8),
              Expanded(
                child: Text(
                  s.nutritionInfo,
                  style: theme.textTheme.titleMedium?.copyWith(
                    fontWeight: FontWeight.bold,
                    color: theme.colorScheme.primary,
                  ),
                ),
              ),
              Container(
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    colors: [
                      theme.colorScheme.primary,
                      theme.colorScheme.secondary,
                    ],
                  ),
                  borderRadius: BorderRadius.circular(12),
                  boxShadow: [
                    BoxShadow(
                      color: theme.colorScheme.primary.withValues(alpha: 0.3),
                      blurRadius: 6,
                      offset: const Offset(0, 2),
                    ),
                  ],
                ),
                child: ElevatedButton.icon(
                  onPressed: state.isEstimatingNutrition
                      ? null
                      : () => controller.estimateNutrition(),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Colors.transparent,
                    shadowColor: Colors.transparent,
                    padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12),
                    ),
                  ),
                  icon: state.isEstimatingNutrition
                      ? const SizedBox(
                          width: 16,
                          height: 16,
                          child: CircularProgressIndicator(
                            strokeWidth: 2,
                            color: Colors.white,
                          ),
                        )
                      : const Icon(Icons.auto_awesome, size: 18, color: Colors.white),
                  label: Text(
                    state.isEstimatingNutrition ? s.estimating : s.aiEstimate,
                    style: const TextStyle(
                      fontSize: 12,
                      fontWeight: FontWeight.bold,
                      color: Colors.white,
                    ),
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),
          Text(
            s.nutritionPerServing,
            style: theme.textTheme.bodySmall?.copyWith(
              color: theme.colorScheme.onSurface.withValues(alpha: 0.6),
            ),
          ),
          const SizedBox(height: 12),
          Row(
            children: [
              Expanded(
                child: _NutritionField(
                  label: 'Calories',
                  value: state.calories,
                  unit: 'kcal',
                  icon: Icons.local_fire_department,
                  color: Colors.orange,
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: _NutritionField(
                  label: 'Protein',
                  value: state.protein,
                  unit: 'g',
                  icon: Icons.fitness_center,
                  color: Colors.blue,
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          Row(
            children: [
              Expanded(
                child: _NutritionField(
                  label: 'Carb',
                  value: state.carbs,
                  unit: 'g',
                  icon: Icons.grain,
                  color: Colors.green,
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: _NutritionField(
                  label: 'Fat',
                  value: state.fat,
                  unit: 'g',
                  icon: Icons.water_drop,
                  color: Colors.red,
                ),
              ),
            ],
          ),
          if (state.calories == null) ...[
            const SizedBox(height: 12),
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: theme.colorScheme.surfaceContainerHighest.withValues(alpha: 0.5),
                borderRadius: BorderRadius.circular(8),
              ),
              child: Row(
                children: [
                  Icon(
                    Icons.info_outline,
                    size: 20,
                    color: theme.colorScheme.primary,
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      'Điền nguyên liệu rồi nhấn "AI Ước lượng" để tự động tính dinh dưỡng',
                      style: theme.textTheme.bodySmall?.copyWith(
                        color: theme.colorScheme.onSurface.withValues(alpha: 0.7),
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ],
        ],
      ),
    );
  }
}

class _NutritionField extends StatelessWidget {
  const _NutritionField({
    required this.label,
    required this.value,
    required this.unit,
    required this.icon,
    required this.color,
  });

  final String label;
  final int? value;
  final String unit;
  final IconData icon;
  final Color color;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.1),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(
          color: color.withValues(alpha: 0.3),
          width: 2,
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(icon, size: 16, color: color),
              const SizedBox(width: 4),
              Text(
                label,
                style: theme.textTheme.labelSmall?.copyWith(
                  color: color,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),
          Text(
            value != null ? '$value' : '--',
            style: theme.textTheme.headlineSmall?.copyWith(
              fontWeight: FontWeight.bold,
              color: value != null
                  ? theme.colorScheme.onSurface
                  : theme.colorScheme.onSurface.withValues(alpha: 0.3),
            ),
          ),
          Text(
            unit,
            style: theme.textTheme.bodySmall?.copyWith(
              color: theme.colorScheme.onSurface.withValues(alpha: 0.6),
            ),
          ),
        ],
      ),
    );
  }
}
