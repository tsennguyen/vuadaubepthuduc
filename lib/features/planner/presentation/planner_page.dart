import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:cloud_functions/cloud_functions.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import '../../../core/widgets/modern_loading.dart';
import '../../../shared/widgets/modern_dialog.dart';
import '../../../shared/widgets/modern_ui_components.dart';
import '../../recipe/data/recipe_repository.dart';
import '../../shopping/application/shopping_from_plan_service.dart';
import '../../shopping/data/shopping_list_repository.dart';
import '../data/meal_plan_repository.dart';
import '../domain/meal_plan_models.dart';

import '../../../app/l10n.dart';
import '../../../app/language_controller.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

class PlannerPage extends ConsumerStatefulWidget {
  const PlannerPage({super.key});

  @override
  ConsumerState<PlannerPage> createState() => _PlannerPageState();
}

class _PlannerPageState extends ConsumerState<PlannerPage> {
  late final MealPlanRepository _repository;
  late final ShoppingFromPlanService _shoppingService;

  late DateTime _weekStart;
  late Stream<Map<DateTime, List<MealPlanEntry>>> _weekStream;
  bool _isAiGenerating = false;
  bool _isGeneratingShopping = false;

  bool get isVi => ref.read(localeProvider).languageCode == 'vi';

  @override
  void initState() {
    super.initState();
    // TODO: Replace with Riverpod provider / DI if desired.
    _repository = FirestoreMealPlanRepository();
    _shoppingService = ShoppingFromPlanService(
      shoppingRepo: FirestoreShoppingListRepository(),
      mealPlanRepo: _repository,
      recipeRepo: RecipeRepositoryImpl(),
    );
    _weekStart = _startOfWeek(DateTime.now());
    _weekStream = _repository.watchWeek(_weekStart);
  }

  void _goPrevWeek() => _setWeekStart(_weekStart.subtract(const Duration(days: 7)));

  void _goNextWeek() => _setWeekStart(_weekStart.add(const Duration(days: 7)));

  void _goThisWeek() => _setWeekStart(_startOfWeek(DateTime.now()));

  void _setWeekStart(DateTime start) {
    setState(() {
      _weekStart = DateTime(start.year, start.month, start.day);
      _weekStream = _repository.watchWeek(_weekStart);
    });
  }

  Future<void> _openCreateSheet({
    required DateTime date,
    required MealType mealType,
  }) async {
    await showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      showDragHandle: true,
      builder: (context) => _MealEditSheet(
        repository: _repository,
        date: date,
        mealType: mealType,
      ),
    );
  }

  Future<void> _openEditSheet(MealPlanEntry entry) async {
    await showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      showDragHandle: true,
      builder: (context) => _MealEditSheet(
        repository: _repository,
        date: entry.date,
        mealType: entry.mealType,
        existing: entry,
      ),
    );
  }

  Future<void> _openCellSheet({
    required DateTime date,
    required MealType mealType,
    required List<MealPlanEntry> entries,
  }) async {
    await showModalBottomSheet<void>(
      context: context,
      showDragHandle: true,
      isScrollControlled: true,
      builder: (context) => _MealCellSheet(
        date: date,
        mealType: mealType,
        entries: entries,
        onAdd: () => _openCreateSheet(date: date, mealType: mealType),
        onEdit: _openEditSheet,
      ),
    );
  }

  Future<void> _generateAiPlan() async {
    final user = FirebaseAuth.instance.currentUser;
    if (user == null) {
      _showSnack(isVi ? 'Vui lòng đăng nhập để sử dụng tính năng này.' : 'Please login to use this feature.');
      return;
    }

    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => ModernDialog(
        title: isVi ? 'AI tạo kế hoạch tuần' : 'AI Generate Weekly Plan',
        icon: Icons.auto_awesome,
        content: Text.rich(
          TextSpan(
            children: [
              TextSpan(
                text: isVi ? 'AI sẽ ghi đè kế hoạch tuần bắt đầu ' : 'AI will override the plan for the week starting ',
              ),
              TextSpan(
                text: _formatDayMonthYear(_weekStart),
                style: const TextStyle(fontWeight: FontWeight.bold),
              ),
              TextSpan(
                text: isVi ? ' (bao gồm các bữa hiện tại).\n\n' : ' (including existing meals).\n\n',
              ),
              TextSpan(
                text: isVi ? 'Macro chỉ mang tính chất ước lượng, không thay thế tư vấn dinh dưỡng chuyên gia.' : 'Macros are estimates only, not a substitute for professional nutritional advice.',
                style: TextStyle(
                  fontStyle: FontStyle.italic,
                  fontSize: 13,
                  color: Theme.of(context).colorScheme.onSurface.withValues(alpha: 0.7),
                ),
              ),
            ],
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Huỷ'),
          ),
          ModernButton(
            onPressed: () => Navigator.pop(context, true),
            style: ModernButtonStyle.primary,
            child: Text(isVi ? 'Tạo kế hoạch' : 'Create Plan'),
          ),
        ],
      ),
    );
    if (confirmed != true) return;

    setState(() => _isAiGenerating = true);
    try {
      final callable = FirebaseFunctions.instanceFor(region: 'asia-southeast1')
          .httpsCallable('aiGenerateMealPlan');
      final weekIso = _formatIsoDate(_weekStart);
      await callable.call({
        'userId': user.uid,
        'weekStart': weekIso,
      });
      if (mounted) {
        _weekStream = _repository.watchWeek(_weekStart);
        _showSnack(isVi ? 'AI sẽ tạo kế hoạch cho tuần $weekIso' : 'AI will generate plan for week $weekIso');
      }
    } on FirebaseFunctionsException catch (e) {
      _showSnack(isVi ? 'Không thể tạo kế hoạch AI: ${e.message ?? e.code}' : 'Failed to generate AI plan: ${e.message ?? e.code}');
      debugPrint('AI error: ${e.code} ${e.message}');
    } catch (e) {
      _showSnack(isVi ? 'Không thể tạo kế hoạch AI: $e' : 'Failed to generate AI plan: $e');
    } finally {
      if (mounted) setState(() => _isAiGenerating = false);
    }
  }

  Future<void> _generateShoppingList() async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => ModernDialog(
        title: isVi ? 'Tạo shopping list tuần này' : 'Generate shopping list for this week',
        icon: Icons.shopping_cart_checkout_rounded,
        content: Text(
          isVi ? 'Danh sách sẽ được gộp vào shopping list hiện có, bạn có muốn tiếp tục không?' : 'Items will be merged into existing shopping list, do you want to continue?',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Huỷ'),
          ),
          ModernButton(
            onPressed: () => Navigator.pop(context, true),
            style: ModernButtonStyle.primary,
            icon: Icons.add_shopping_cart_rounded,
            child: Text(isVi ? 'Tạo danh sách' : 'Generate List'),
          ),
        ],
      ),
    );
    if (confirmed != true) return;

    setState(() => _isGeneratingShopping = true);
    try {
      await _shoppingService.generateWeeklyShoppingList(_weekStart);
      _showSnack(
        isVi ? 'Đã gộp shopping list tuần này.' : 'Merged weekly shopping list.',
        actionLabel: isVi ? 'Xem list' : 'View list',
        onAction: () => context.go('/shopping'),
      );
    } catch (e) {
      _showSnack(isVi ? 'Tạo shopping list thất bại: $e' : 'Failed to generate shopping list: $e');
    } finally {
      if (mounted) setState(() => _isGeneratingShopping = false);
    }
  }


  void _showSnack(String message, {String? actionLabel, VoidCallback? onAction}) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(message),
        action: actionLabel != null && onAction != null
            ? SnackBarAction(label: actionLabel, onPressed: onAction)
            : null,
      ),
    );
  }


  @override
  Widget build(BuildContext context) {
    final locale = ref.watch(localeProvider);
    final s = S(locale);
    final isVi = s.isVi;
    final headerRange = _weekRangeLabel(_weekStart, isVi);
    final theme = Theme.of(context);

    return Scaffold(
      appBar: AppBar(
        title: Text(s.planner),
        actions: [
          IconButton.filledTonal(
            tooltip: isVi ? 'Xem Shopping List' : 'View Shopping List',
            onPressed: () => context.go('/shopping'),
            icon: const Icon(Icons.shopping_cart_outlined, size: 26),
            style: IconButton.styleFrom(
              backgroundColor: theme.colorScheme.primaryContainer,
              foregroundColor: theme.colorScheme.onPrimaryContainer,
            ),
          ),
          const SizedBox(width: 8),
        ],
      ),
      body: Column(
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 12, 16, 8),
            child: Row(
              children: [
                Expanded(
                  child: Text(
                    headerRange,
                    style: Theme.of(context).textTheme.titleMedium,
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
                const SizedBox(width: 12),
                TextButton(
                  onPressed: _goPrevWeek,
                  child: Text('< ${s.prevWeek}'),
                ),
                const SizedBox(width: 8),
                FilledButton.tonal(
                  onPressed: _goThisWeek,
                  child: Text(s.thisWeek),
                ),
                const SizedBox(width: 8),
                TextButton(
                  onPressed: _goNextWeek,
                  child: Text('${s.nextWeek} >'),
                ),
              ],
            ),
          ),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
            child: Row(
              children: [
                Expanded(
                  child: _ActionCard(
                    icon: Icons.auto_awesome_rounded,
                    label: isVi ? 'AI Kế hoạch' : 'AI Plan',
                    subtitle: isVi ? 'Kế hoạch' : 'Plan',
                    gradientColors: [
                      Theme.of(context).colorScheme.primary,
                      Theme.of(context).colorScheme.secondary,
                    ],
                    isLoading: _isAiGenerating,
                    onTap: _isAiGenerating ? null : _generateAiPlan,
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: _ActionCard(
                    icon: Icons.shopping_cart_rounded,
                    label: isVi ? 'Tạo List' : 'Create List',
                    subtitle: isVi ? 'tuần này' : 'this week',
                    gradientColors: [
                      Theme.of(context).colorScheme.tertiary,
                      Theme.of(context).colorScheme.primary,
                    ],
                    isLoading: _isGeneratingShopping,
                    onTap: _isGeneratingShopping ? null : _generateShoppingList,
                  ),
                ),
              ],
            ),
          ),
          const Divider(height: 1),
          Expanded(
            child: StreamBuilder<Map<DateTime, List<MealPlanEntry>>>(
              stream: _weekStream,
              builder: (context, snapshot) {
                if (snapshot.hasError) {
                  return _ErrorView(
                    message: '${snapshot.error}',
                    onRetry: () => _setWeekStart(_weekStart),
                  );
                }
                if (!snapshot.hasData) {
                  return ListView.builder(
                    padding: const EdgeInsets.all(16),
                    itemCount: 3,
                    itemBuilder: (context, index) => const Padding(
                      padding: EdgeInsets.only(bottom: 16),
                      child: SkeletonLoader(height: 200),
                    ),
                  );
                }

                final weekData = snapshot.data ?? const <DateTime, List<MealPlanEntry>>{};
                return _WeekGrid(
                  weekStart: _weekStart,
                  weekData: weekData,
                  onTapCell: _openCellSheet,
                );
              },
            ),
          ),
        ],
      ),
    );
  }
}

class _WeekGrid extends StatelessWidget {
  const _WeekGrid({
    required this.weekStart,
    required this.weekData,
    required this.onTapCell,
  });

  final DateTime weekStart;
  final Map<DateTime, List<MealPlanEntry>> weekData;
  final Future<void> Function({
    required DateTime date,
    required MealType mealType,
    required List<MealPlanEntry> entries,
  }) onTapCell;

  @override
  Widget build(BuildContext context) {
    final days = List<DateTime>.generate(
      7,
      (i) => weekStart.add(Duration(days: i)),
      growable: false,
    );

    final byDayId = <String, List<MealPlanEntry>>{};
    for (final entry in weekData.entries) {
      byDayId[_dayId(entry.key)] = entry.value;
    }

    return ListView.builder(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      itemCount: days.length,
      itemBuilder: (context, index) {
        final day = days[index];
        final entries = byDayId[_dayId(day)] ?? const <MealPlanEntry>[];
        return _DaySection(
          date: day,
          entries: entries,
          onTapCell: onTapCell,
        );
      },
    );
  }
}

class _DaySection extends ConsumerWidget {
  const _DaySection({
    required this.date,
    required this.entries,
    required this.onTapCell,
  });

  final DateTime date;
  final List<MealPlanEntry> entries;
  final Future<void> Function({
    required DateTime date,
    required MealType mealType,
    required List<MealPlanEntry> entries,
  }) onTapCell;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final s = S(ref.watch(localeProvider));
    final theme = Theme.of(ref.context);
    final now = DateTime.now();
    final isToday = now.year == date.year &&
        now.month == date.month &&
        now.day == date.day;

    final grouped = <MealType, List<MealPlanEntry>>{
      for (final t in MealType.values) t: <MealPlanEntry>[],
    };
    for (final e in entries) {
      grouped[e.mealType]?.add(e);
    }

    return Card(
      margin: const EdgeInsets.only(bottom: 12),
      clipBehavior: Clip.antiAlias,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            width: double.infinity,
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
            decoration: BoxDecoration(
              color: isToday
                  ? theme.colorScheme.primary.withValues(alpha: 0.12)
                  : theme.colorScheme.surfaceContainerHighest,
            ),
            child: Row(
              children: [
                if (isToday) ...[
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                    decoration: BoxDecoration(
                      color: theme.brightness == Brightness.dark
                          ? theme.colorScheme.primary.withValues(alpha: 0.3)
                          : theme.colorScheme.primary,
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: Text(
                      s.todayLabel,
                      style: theme.textTheme.labelSmall?.copyWith(
                        color: theme.brightness == Brightness.dark
                            ? theme.colorScheme.onSurface.withValues(alpha: 0.85)
                            : theme.colorScheme.onPrimary,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ),
                  const SizedBox(width: 12),
                ],
                Text(
                  '${_weekdayLabel(date, s.isVi)}, ${_formatDayMonth(date)}',
                  style: theme.textTheme.titleMedium?.copyWith(
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ],
            ),
          ),
          for (final mealType in MealType.values)
            _MealRow(
              date: date,
              mealType: mealType,
              entries: grouped[mealType] ?? const <MealPlanEntry>[],
              onTap: () => onTapCell(
                date: date,
                mealType: mealType,
                entries: grouped[mealType] ?? const <MealPlanEntry>[],
              ),
            ),
        ],
      ),
    );
  }
}

class _MealRow extends ConsumerWidget {
  const _MealRow({
    required this.date,
    required this.mealType,
    required this.entries,
    required this.onTap,
  });

  final DateTime date;
  final MealType mealType;
  final List<MealPlanEntry> entries;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final s = S(ref.watch(localeProvider));
    final theme = Theme.of(context);
    final title = _mealTypeLabel(mealType, s);

    return InkWell(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
        decoration: BoxDecoration(
          border: Border(
            top: BorderSide(color: theme.dividerColor, width: 0.5),
          ),
        ),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            SizedBox(
              width: 70,
              child: Text(
                title,
                style: theme.textTheme.labelLarge?.copyWith(
                  fontWeight: FontWeight.w600,
                  color: theme.brightness == Brightness.dark
                      ? theme.colorScheme.primary.withValues(alpha: 0.8)
                      : theme.colorScheme.primary,
                ),
              ),
            ),
            const SizedBox(width: 16),
            Expanded(
              child: entries.isEmpty
                  ? Row(
                      children: [
                        Icon(
                          Icons.add_circle_outline,
                          size: 18,
                          color: theme.colorScheme.outline,
                        ),
                        const SizedBox(width: 8),
                        Text(
                          s.addMeal,
                          style: theme.textTheme.bodyMedium?.copyWith(
                            color: theme.colorScheme.outline,
                          ),
                        ),
                      ],
                    )
                  : Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        for (final entry in entries) ...[
                          Text(
                            _mealLabel(entry),
                            style: theme.textTheme.bodyMedium?.copyWith(
                              fontWeight: FontWeight.w500,
                            ),
                            maxLines: 2,
                            overflow: TextOverflow.ellipsis,
                          ),
                          Text(
                            'x${entry.servings}${entry.note?.isNotEmpty == true ? " · ${entry.note}" : ""}',
                            style: theme.textTheme.bodySmall?.copyWith(
                              color: theme.colorScheme.onSurfaceVariant,
                            ),
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                          ),
                          if (entry != entries.last) const SizedBox(height: 8),
                        ],
                      ],
                    ),
            ),
            const SizedBox(width: 8),
            Icon(
              Icons.chevron_right,
              size: 20,
              color: theme.colorScheme.outline,
            ),
          ],
        ),
      ),
    );
  }
}

class _MealCellSheet extends ConsumerWidget {
  const _MealCellSheet({
    required this.date,
    required this.mealType,
    required this.entries,
    required this.onAdd,
    required this.onEdit,
  });

  final DateTime date;
  final MealType mealType;
  final List<MealPlanEntry> entries;
  final VoidCallback onAdd;
  final Future<void> Function(MealPlanEntry) onEdit;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final s = S(ref.watch(localeProvider));
    return SafeArea(
      child: Padding(
        padding: EdgeInsets.only(
          left: 16,
          right: 16,
          top: 12,
          bottom: 16 + MediaQuery.viewInsetsOf(context).bottom,
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              '${_mealTypeLabel(mealType, s)} • ${_formatDayMonthYear(date)}',
              style: Theme.of(context).textTheme.titleMedium,
            ),
            const SizedBox(height: 12),
            if (entries.isEmpty)
              _EmptyDetail(onAdd: onAdd)
            else
              ...entries.map((e) => _MealDetailTile(entry: e, onEdit: () => onEdit(e))),
            const SizedBox(height: 12),
            SizedBox(
              width: double.infinity,
              child: FilledButton.icon(
                onPressed: onAdd,
                icon: const Icon(Icons.add),
                label: Text(s.addMeal),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _MealDetailTile extends StatelessWidget {
  const _MealDetailTile({required this.entry, required this.onEdit});

  final MealPlanEntry entry;
  final VoidCallback onEdit;

  @override
  Widget build(BuildContext context) {
    final subtitle = [
      if (entry.servings > 0) 'Servings: x${entry.servings}',
      if (entry.note?.isNotEmpty == true) entry.note!,
    ].join(' • ');
    return Card(
      margin: const EdgeInsets.only(bottom: 8),
      child: ListTile(
        title: Text(_mealLabel(entry)),
        subtitle: subtitle.isNotEmpty ? Text(subtitle) : null,
        trailing: IconButton(
          icon: const Icon(Icons.chevron_right),
          onPressed: onEdit,
        ),
        onTap: () => context.push('/recipe/${entry.recipeId}'),
      ),
    );
  }
}

class _EmptyDetail extends ConsumerWidget {
  const _EmptyDetail({required this.onAdd});

  final VoidCallback onAdd;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final s = S(ref.watch(localeProvider));
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Theme.of(context).colorScheme.surfaceContainerHighest,
        borderRadius: BorderRadius.circular(12),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(s.isVi ? 'Chưa có món cho bữa này' : 'No meals for this slot'),
          const SizedBox(height: 8),
          FilledButton.tonalIcon(
            onPressed: onAdd,
            icon: const Icon(Icons.restaurant_outlined),
            label: Text(s.addMeal),
          ),
        ],
      ),
    );
  }
}

// ignore: unused_element
class _MealSelectSheet extends ConsumerWidget {
  const _MealSelectSheet({
    required this.date,
    required this.mealType,
    required this.entries,
    required this.onSelect,
    required this.onAddNew,
  });

  final DateTime date;
  final MealType mealType;
  final List<MealPlanEntry> entries;
  final ValueChanged<MealPlanEntry> onSelect;
  final VoidCallback onAddNew;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final s = S(ref.watch(localeProvider));
    return SafeArea(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              '${_mealTypeLabel(mealType, s)} • ${_formatDayMonthYear(date)}',
              style: Theme.of(context).textTheme.titleMedium,
            ),
            const SizedBox(height: 12),
            ConstrainedBox(
              constraints: const BoxConstraints(maxHeight: 360),
              child: ListView.separated(
                shrinkWrap: true,
                itemCount: entries.length,
                separatorBuilder: (_, __) => const Divider(height: 1),
                itemBuilder: (context, index) {
                  final e = entries[index];
                  return ListTile(
                    title: Text(_mealLabel(e)),
                    subtitle: Text('Servings: x${e.servings}'),
                    trailing: const Icon(Icons.chevron_right),
                    onTap: () => onSelect(e),
                  );
                },
              ),
            ),
            const SizedBox(height: 12),
            SizedBox(
              width: double.infinity,
              child: FilledButton.icon(
                onPressed: onAddNew,
                icon: const Icon(Icons.add),
                label: const Text('Thêm bữa mới'),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _MealEditSheet extends ConsumerStatefulWidget {
  const _MealEditSheet({
    required this.repository,
    required this.date,
    required this.mealType,
    this.existing,
  });

  final MealPlanRepository repository;
  final DateTime date;
  final MealType mealType;
  final MealPlanEntry? existing;

  @override
  ConsumerState<_MealEditSheet> createState() => _MealEditSheetState();
}

class _MealEditSheetState extends ConsumerState<_MealEditSheet> {
  late final TextEditingController _recipeIdController;
  late final TextEditingController _servingsController;
  late final TextEditingController _noteController;

  bool _isSaving = false;

  bool get _isEdit => widget.existing != null;

  @override
  void initState() {
    super.initState();
    _recipeIdController = TextEditingController(
      text: widget.existing?.recipeId ?? '',
    );
    _servingsController = TextEditingController(
      text: (widget.existing?.servings ?? 1).toString(),
    );
    _noteController = TextEditingController(text: widget.existing?.note ?? '');
  }

  @override
  void dispose() {
    _recipeIdController.dispose();
    _servingsController.dispose();
    _noteController.dispose();
    super.dispose();
  }

  Future<void> _save() async {
    final s = S(ref.read(localeProvider));
    final isVi = s.isVi;

    final recipeId = _recipeIdController.text.trim();
    final servings = int.tryParse(_servingsController.text.trim()) ?? 1;
    final note = _noteController.text.trim();

    if (!_isEdit && recipeId.isEmpty) {
      _showSnack(isVi ? 'Vui lòng chọn công thức.' : 'Please choose a recipe.');
      return;
    }
    if (servings <= 0) {
      _showSnack(isVi ? 'Số khẩu phần phải > 0' : 'Servings must be > 0');
      return;
    }

    setState(() => _isSaving = true);
    try {
      if (_isEdit) {
        final old = widget.existing!;
        final updated = MealPlanEntry(
          id: old.id,
          recipeId: old.recipeId,
          title: old.title, // Keep existing title
          mealType: old.mealType,
          servings: servings,
          note: note.isEmpty ? null : note,
          date: old.date,
          plannedFor: old.plannedFor,
        );
        await widget.repository.updateMeal(updated);
      } else {
        // Fetch recipe title from Firestore
        String? recipeTitle;
        try {
          final recipeDoc = await FirebaseFirestore.instance
              .collection('recipes')
              .doc(recipeId)
              .get();
          if (recipeDoc.exists) {
            recipeTitle = recipeDoc.data()?['title'] as String?;
          }
        } catch (_) {
          // Ignore fetch error, will use recipeId as fallback
        }

        final entry = MealPlanEntry(
          id: '',
          recipeId: recipeId,
          title: recipeTitle, // Store recipe title
          mealType: widget.mealType,
          servings: servings,
          note: note.isEmpty ? null : note,
          date: widget.date,
          plannedFor: null,
        );
        await widget.repository.addMeal(entry);
      }

      if (!mounted) return;
      Navigator.of(context).pop();
    } catch (e) {
      _showSnack(isVi ? 'Lưu thất bại: $e' : 'Save failed: $e');
    } finally {
      if (mounted) setState(() => _isSaving = false);
    }
  }

  Future<void> _delete() async {
    final s = S(ref.read(localeProvider));
    final isVi = s.isVi;
    final existing = widget.existing;
    if (existing == null) return;

    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: Text(isVi ? 'Xoá bữa ăn?' : 'Delete meal?'),
        content: Text(isVi ? 'Bạn chắc chắn muốn xoá bữa ăn này?' : 'Are you sure you want to delete this meal?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(false),
            child: Text(s.cancel),
          ),
          FilledButton.tonal(
            onPressed: () => Navigator.of(context).pop(true),
            child: Text(s.delete),
          ),
        ],
      ),
    );

    if (confirmed != true) return;

    setState(() => _isSaving = true);
    try {
      await widget.repository.deleteMeal(existing.dayId, existing.id);
      if (!mounted) return;
      Navigator.of(context).pop();
    } catch (e) {
      _showSnack(isVi ? 'Xoá thất bại: $e' : 'Delete failed: $e');
    } finally {
      if (mounted) setState(() => _isSaving = false);
    }
  }

  Future<void> _chooseRecipePlaceholder() async {
    final result = await showDialog<String>(
      context: context,
      builder: (context) => const _RecipePickerDialog(),
    );
    if (result != null && result.isNotEmpty) {
      _recipeIdController.text = result;
    }
  }

  void _showSnack(String message) {
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(message)));
  }

  @override
  Widget build(BuildContext context) {
    final s = S(ref.watch(localeProvider));
    final isVi = s.isVi;
    final existing = widget.existing;
    final title = _isEdit 
        ? (isVi ? 'Chi tiết bữa ăn' : 'Meal Details') 
        : (isVi ? 'Thêm vào kế hoạch' : 'Add to Plan');

    return SafeArea(
      child: Padding(
        padding: EdgeInsets.only(
          left: 16,
          right: 16,
          top: 8,
          bottom: 16 + MediaQuery.viewInsetsOf(context).bottom,
        ),
        child: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(title, style: Theme.of(context).textTheme.titleLarge),
              const SizedBox(height: 12),
              _ReadOnlyRow(
                label: isVi ? 'Ngày' : 'Date',
                value: _formatDayMonthYear(widget.date),
              ),
              _ReadOnlyRow(label: isVi ? 'Bữa' : 'Meal', value: _mealTypeLabel(widget.mealType, s)),
              const SizedBox(height: 12),
              if (_isEdit) ...[
                _ReadOnlyRow(label: 'RecipeId', value: existing!.recipeId),
              ] else ...[
                Row(
                  children: [
                    Expanded(
                      child: TextField(
                        controller: _recipeIdController,
                        decoration: InputDecoration(
                          labelText: isVi ? 'Mã công thức' : 'Recipe ID',
                          border: const OutlineInputBorder(),
                        ),
                      ),
                    ),
                    const SizedBox(width: 8),
                    FilledButton.tonalIcon(
                      onPressed: _isSaving ? null : _chooseRecipePlaceholder,
                      icon: const Icon(Icons.restaurant_menu_outlined),
                      label: Text(isVi ? 'Chọn' : 'Choose'),
                    ),
                  ],
                ),
              ],
              const SizedBox(height: 12),
              Row(
                children: [
                  Expanded(
                    child: TextField(
                      controller: _servingsController,
                      keyboardType: TextInputType.number,
                      decoration: InputDecoration(
                        labelText: isVi ? 'Số khẩu phần' : 'Servings',
                        border: const OutlineInputBorder(),
                      ),
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: TextField(
                      controller: _noteController,
                      decoration: InputDecoration(
                        labelText: isVi ? 'Ghi chú' : 'Note (optional)',
                        border: const OutlineInputBorder(),
                      ),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 16),
              Row(
                children: [
                  if (_isEdit)
                    TextButton.icon(
                      onPressed: _isSaving ? null : _delete,
                      icon: const Icon(Icons.delete_outline),
                      label: Text(s.delete),
                    ),
                  const Spacer(),
                  TextButton(
                    onPressed:
                        _isSaving ? null : () => Navigator.of(context).pop(),
                    child: Text(s.cancel),
                  ),
                  const SizedBox(width: 8),
                  FilledButton(
                    onPressed: _isSaving ? null : _save,
                    child: _isSaving
                        ? const SizedBox(
                            width: 18,
                            height: 18,
                            child: CircularProgressIndicator(strokeWidth: 2),
                          )
                        : Text(_isEdit ? s.save : (isVi ? 'Thêm' : 'Add')),
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

class _ReadOnlyRow extends StatelessWidget {
  const _ReadOnlyRow({required this.label, required this.value});

  final String label;
  final String value;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Padding(
      padding: const EdgeInsets.only(bottom: 6),
      child: Row(
        children: [
          SizedBox(
            width: 80,
            child: Text(
              label,
              style: theme.textTheme.bodySmall?.copyWith(color: theme.hintColor),
            ),
          ),
          Expanded(
            child: Text(
              value.isNotEmpty ? value : '—',
              style: theme.textTheme.bodyMedium,
              overflow: TextOverflow.ellipsis,
            ),
          ),
        ],
      ),
    );
  }
}

class _ErrorView extends StatelessWidget {
  const _ErrorView({required this.message, required this.onRetry});

  final String message;
  final VoidCallback onRetry;

  @override
  Widget build(BuildContext context) {
    return Center(
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 560),
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(
                'Không tải được kế hoạch',
                style: Theme.of(context).textTheme.titleMedium,
              ),
              const SizedBox(height: 8),
              Text(message, textAlign: TextAlign.center),
              const SizedBox(height: 12),
              ElevatedButton.icon(
                onPressed: onRetry,
                icon: const Icon(Icons.refresh),
                label: const Text('Thử lại'),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

DateTime _startOfWeek(DateTime date) {
  final local = date.toLocal();
  final d = DateTime(local.year, local.month, local.day);
  return d.subtract(Duration(days: d.weekday - DateTime.monday));
}

String _weekdayLabel(DateTime date, bool isVi) {
  switch (date.weekday) {
    case DateTime.monday:
      return isVi ? 'Th2' : 'Mon';
    case DateTime.tuesday:
      return isVi ? 'Th3' : 'Tue';
    case DateTime.wednesday:
      return isVi ? 'Th4' : 'Wed';
    case DateTime.thursday:
      return isVi ? 'Th5' : 'Thu';
    case DateTime.friday:
      return isVi ? 'Th6' : 'Fri';
    case DateTime.saturday:
      return isVi ? 'Th7' : 'Sat';
    case DateTime.sunday:
      return isVi ? 'CN' : 'Sun';
  }
  return '';
}

String _formatDayMonth(DateTime date) {
  String two(int n) => n.toString().padLeft(2, '0');
  final d = date.toLocal();
  return '${two(d.day)}/${two(d.month)}';
}

String _formatDayMonthYear(DateTime date) {
  String two(int n) => n.toString().padLeft(2, '0');
  final d = date.toLocal();
  return '${two(d.day)}/${two(d.month)}/${d.year}';
}

String _weekRangeLabel(DateTime weekStart, bool isVi) {
  final start = weekStart.toLocal();
  final end = start.add(const Duration(days: 6));
  return '${_formatDayMonthYear(start)} - ${_formatDayMonthYear(end)}';
}

String _formatIsoDate(DateTime date) {
  String two(int n) => n.toString().padLeft(2, '0');
  final d = date.toLocal();
  return '${d.year}-${two(d.month)}-${two(d.day)}';
}

String _dayId(DateTime date) {
  String two(int n) => n.toString().padLeft(2, '0');
  final d = date.toLocal();
  return '${d.year}-${two(d.month)}-${two(d.day)}';
}

String _mealTypeLabel(MealType type, S s) {
  switch (type) {
    case MealType.breakfast:
      return s.mealBreakfast;
    case MealType.lunch:
      return s.mealLunch;
    case MealType.dinner:
      return s.mealDinner;
    case MealType.snack:
      return s.mealSnack;
  }
}

String _shortRecipeLabel(String recipeId) {
  final trimmed = recipeId.trim();
  if (trimmed.isEmpty) return '(No recipe)';
  if (trimmed.length <= 10) return trimmed;
  return '${trimmed.substring(0, 10)}...';
}


String _mealLabel(MealPlanEntry entry) {
  final t = entry.title?.trim();
  if (t != null && t.isNotEmpty) return t;
  return _shortRecipeLabel(entry.recipeId);
}

// Recipe Picker Dialog
class _RecipePickerDialog extends ConsumerStatefulWidget {
  const _RecipePickerDialog();

  @override
  ConsumerState<_RecipePickerDialog> createState() => _RecipePickerDialogState();
}

class _RecipePickerDialogState extends ConsumerState<_RecipePickerDialog> {
  final _searchController = TextEditingController();
  final _firestore = FirebaseFirestore.instance;
  List<QueryDocumentSnapshot> _recipes = [];
  List<QueryDocumentSnapshot> _filteredRecipes = [];
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    _loadRecipes();
    _searchController.addListener(_filterRecipes);
  }

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  Future<void> _loadRecipes() async {
    try {
      final uid = FirebaseAuth.instance.currentUser?.uid;
      if (uid == null) {
        setState(() => _isLoading = false);
        return;
      }

      // Load user's own recipes
      final ownRecipesSnapshot = await _firestore
          .collection('recipes')
          .where('authorId', isEqualTo: uid)
          .get();

      // Load saved/bookmarked recipes
      final bookmarksSnapshot = await _firestore
          .collection('users')
          .doc(uid)
          .collection('bookmarks')
          .get();

      // Get recipe IDs from bookmarks
      final bookmarkedRecipeIds = bookmarksSnapshot.docs
          .map((doc) => doc.data()['recipeId'] as String?)
          .where((id) => id != null && id.isNotEmpty)
          .toSet();

      // Load bookmarked recipes (in batches of 10 due to Firestore 'in' limit)
      final List<QueryDocumentSnapshot> bookmarkedRecipeDocs = [];
      if (bookmarkedRecipeIds.isNotEmpty) {
        final batches = <List<String>>[];
        final ids = bookmarkedRecipeIds.whereType<String>().toList();
        for (var i = 0; i < ids.length; i += 10) {
          batches.add(ids.skip(i).take(10).toList());
        }

        for (final batch in batches) {
          final snapshot = await _firestore
              .collection('recipes')
              .where(FieldPath.documentId, whereIn: batch)
              .get();
          bookmarkedRecipeDocs.addAll(snapshot.docs);
        }
      }

      // Combine and filter out hidden recipes
      final allRecipes = [...ownRecipesSnapshot.docs, ...bookmarkedRecipeDocs];
      final visibleDocs = allRecipes.where((doc) {
        final data = doc.data() as Map<String, dynamic>;
        final hidden = data['hidden'] as bool? ?? false;
        return !hidden;
      }).toList();

      // Remove duplicates (in case user bookmarked their own recipe)
      final uniqueDocs = <String, QueryDocumentSnapshot>{};
      for (final doc in visibleDocs) {
        uniqueDocs[doc.id] = doc;
      }

      setState(() {
        _recipes = uniqueDocs.values.toList();
        _filteredRecipes = uniqueDocs.values.toList();
        _isLoading = false;
      });
    } catch (e) {
      setState(() => _isLoading = false);
    }
  }

  void _filterRecipes() {
    final query = _searchController.text.toLowerCase();
    setState(() {
      if (query.isEmpty) {
        _filteredRecipes = _recipes;
      } else {
        _filteredRecipes = _recipes.where((doc) {
          final data = doc.data() as Map<String, dynamic>;
          final title = (data['title'] as String? ?? '').toLowerCase();
          return title.contains(query);
        }).toList();
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    final locale = ref.watch(localeProvider);
    final isVi = locale.languageCode == 'vi';

    return Dialog(
      child: Container(
        constraints: const BoxConstraints(maxWidth: 500, maxHeight: 600),
        padding: const EdgeInsets.all(16),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Row(
              children: [
                Expanded(
                  child: Text(
                    isVi ? 'Chọn công thức' : 'Choose recipe',
                    style: const TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
                  ),
                ),
                IconButton(
                  icon: const Icon(Icons.close),
                  onPressed: () => Navigator.of(context).pop(),
                ),
              ],
            ),
            const SizedBox(height: 16),
            TextField(
              controller: _searchController,
              decoration: InputDecoration(
                hintText: isVi ? 'Tìm kiếm công thức...' : 'Search recipes...',
                prefixIcon: const Icon(Icons.search),
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(12),
                ),
              ),
            ),
            const SizedBox(height: 16),
            if (_isLoading)
              const Expanded(
                child: Center(child: CircularProgressIndicator()),
              )
            else if (_filteredRecipes.isEmpty)
              Expanded(
                child: Center(
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Icon(Icons.restaurant_menu_outlined,
                          size: 64, color: Colors.grey[400]),
                      const SizedBox(height: 16),
                      Text(
                        _searchController.text.isEmpty
                            ? (isVi ? 'Chưa có công thức nào' : 'No recipes yet')
                            : (isVi ? 'Không tìm thấy công thức' : 'No recipes found'),
                        style: TextStyle(color: Colors.grey[600]),
                      ),
                    ],
                  ),
                ),
              )
            else
              Expanded(
                child: ListView.builder(
                  itemCount: _filteredRecipes.length,
                  itemBuilder: (context, index) {
                    final doc = _filteredRecipes[index];
                    final data = doc.data() as Map<String, dynamic>;
                    final recipeId = doc.id;
                    final title = data['title'] as String? ?? 'Không có tên';
                    final imageUrl = data['coverURL'] as String?;

                    return ListTile(
                      leading: imageUrl != null && imageUrl.isNotEmpty
                          ? ClipRRect(
                              borderRadius: BorderRadius.circular(8),
                              child: Image.network(
                                imageUrl,
                                width: 50,
                                height: 50,
                                fit: BoxFit.cover,
                                errorBuilder: (_, __, ___) => Container(
                                  width: 50,
                                  height: 50,
                                  decoration: BoxDecoration(
                                    color: Colors.grey[300],
                                    borderRadius: BorderRadius.circular(8),
                                  ),
                                  child: const Icon(Icons.restaurant),
                                ),
                              ),
                            )
                          : Container(
                              width: 50,
                              height: 50,
                              decoration: BoxDecoration(
                                color: Colors.grey[300],
                                borderRadius: BorderRadius.circular(8),
                              ),
                              child: const Icon(Icons.restaurant),
                            ),
                      title: Text(
                        title,
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                      ),
                      onTap: () => Navigator.of(context).pop(recipeId),
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

class _ActionCard extends StatelessWidget {
  const _ActionCard({
    required this.icon,
    required this.label,
    required this.subtitle,
    required this.gradientColors,
    required this.isLoading,
    this.onTap,
  });

  final IconData icon;
  final String label;
  final String subtitle;
  final List<Color> gradientColors;
  final bool isLoading;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;
    
    // Tạo màu gradient trầm hơn cho dark mode
    final adjustedGradientColors = isDark
        ? gradientColors.map((c) => c.withValues(alpha: 0.4)).toList()
        : gradientColors;
    
    // Màu text trầm hơn cho dark mode
    final textColor = isDark 
        ? theme.colorScheme.onSurface.withValues(alpha: 0.85)
        : Colors.white;

    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: isLoading ? null : onTap,
        borderRadius: BorderRadius.circular(16),
        child: Ink(
          decoration: BoxDecoration(
            gradient: LinearGradient(
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
              colors: adjustedGradientColors,
            ),
            borderRadius: BorderRadius.circular(16),
            boxShadow: [
              BoxShadow(
                color: gradientColors[0].withValues(alpha: isDark ? 0.15 : 0.3),
                blurRadius: 8,
                offset: const Offset(0, 4),
              ),
            ],
          ),
          child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 20),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                if (isLoading)
                  SizedBox(
                    width: 40,
                    height: 40,
                    child: CircularProgressIndicator(
                      strokeWidth: 3,
                      valueColor: AlwaysStoppedAnimation(textColor),
                    ),
                  )
                else
                  Icon(
                    icon,
                    size: 40,
                    color: textColor,
                  ),
                const SizedBox(height: 10),
                Text(
                  label,
                  style: theme.textTheme.titleMedium?.copyWith(
                    color: textColor,
                    fontWeight: FontWeight.bold,
                    fontSize: 15,
                  ),
                  textAlign: TextAlign.center,
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
