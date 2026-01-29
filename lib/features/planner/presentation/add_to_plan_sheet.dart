import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';

import '../data/meal_plan_repository.dart';
import '../domain/meal_plan_models.dart';
import '../../../core/analytics/analytics_service.dart';

class AddToPlanSheet extends StatefulWidget {
  const AddToPlanSheet({super.key, required this.recipeId});

  final String recipeId;

  @override
  State<AddToPlanSheet> createState() => _AddToPlanSheetState();
}

class _AddToPlanSheetState extends State<AddToPlanSheet> {
  late final MealPlanRepository _repository;

  DateTime _selectedDate = DateTime.now();
  MealType _mealType = MealType.lunch;
  int _servings = 1;
  final _noteController = TextEditingController();

  bool _isSaving = false;

  @override
  void initState() {
    super.initState();
    // TODO: Replace with Riverpod provider / DI if desired.
    _repository = FirestoreMealPlanRepository();
  }

  @override
  void dispose() {
    _noteController.dispose();
    super.dispose();
  }

  Future<void> _pickDate() async {
    final initial = DateTime(
      _selectedDate.year,
      _selectedDate.month,
      _selectedDate.day,
    );
    final picked = await showDatePicker(
      context: context,
      initialDate: initial,
      firstDate: DateTime.now().subtract(const Duration(days: 365)),
      lastDate: DateTime.now().add(const Duration(days: 365 * 3)),
    );
    if (picked == null) return;
    setState(() {
      _selectedDate = DateTime(picked.year, picked.month, picked.day);
    });
  }

  void _incServings() => setState(() => _servings += 1);

  void _decServings() {
    if (_servings <= 1) return;
    setState(() => _servings -= 1);
  }

  Future<void> _add() async {
    if (_servings < 1) {
      _showSnack('Khẩu phần phải ≥ 1');
      return;
    }

    final user = FirebaseAuth.instance.currentUser;
    if (user == null) {
      _showSnack('Vui lòng đăng nhập để thêm vào kế hoạch.');
      return;
    }

    setState(() => _isSaving = true);
    try {
      final note = _noteController.text.trim();
      final plannedFor = DateTime(
        _selectedDate.year,
        _selectedDate.month,
        _selectedDate.day,
        12,
      );
      final entry = MealPlanEntry(
        id: '',
        recipeId: widget.recipeId,
        mealType: _mealType,
        servings: _servings,
        note: note.isEmpty ? null : note,
        date: _selectedDate,
        plannedFor: plannedFor,
      );
      await _repository.addMeal(entry);
      analytics.logAddToPlan(widget.recipeId);
      if (!mounted) return;
      Navigator.of(context).pop(true);
    } catch (e) {
      _showSnack('Thêm thất bại: $e');
    } finally {
      if (mounted) setState(() => _isSaving = false);
    }
  }

  void _showSnack(String message) {
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(message)));
  }

  @override
  Widget build(BuildContext context) {
    return SafeArea(
      child: Padding(
        padding: EdgeInsets.only(
          left: 16,
          right: 16,
          top: 12,
          bottom: 16 + MediaQuery.viewInsetsOf(context).bottom,
        ),
        child: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'Thêm công thức vào kế hoạch ăn',
                style: Theme.of(context).textTheme.titleLarge,
              ),
              const SizedBox(height: 12),
              _ReadOnlyRow(label: 'RecipeId', value: widget.recipeId),
              const SizedBox(height: 8),
              Row(
                children: [
                  Expanded(
                    child: _ReadOnlyRow(
                      label: 'Ngày',
                      value: _formatDayMonthYear(_selectedDate),
                    ),
                  ),
                  const SizedBox(width: 12),
                  FilledButton.tonalIcon(
                    onPressed: _isSaving ? null : _pickDate,
                    icon: const Icon(Icons.calendar_month_outlined),
                    label: const Text('Chọn ngày'),
                  ),
                ],
              ),
              const SizedBox(height: 12),
              Row(
                children: [
                  const Text('Bữa:'),
                  const SizedBox(width: 12),
                  DropdownButton<MealType>(
                    value: _mealType,
                    onChanged: _isSaving
                        ? null
                        : (v) => v == null ? null : setState(() => _mealType = v),
                    items: const [
                      DropdownMenuItem(
                        value: MealType.breakfast,
                        child: Text('Sáng'),
                      ),
                      DropdownMenuItem(
                        value: MealType.lunch,
                        child: Text('Trưa'),
                      ),
                      DropdownMenuItem(
                        value: MealType.dinner,
                        child: Text('Tối'),
                      ),
                      DropdownMenuItem(
                        value: MealType.snack,
                        child: Text('Snack'),
                      ),
                    ],
                  ),
                ],
              ),
              const SizedBox(height: 12),
              Row(
                children: [
                  const Text('Khẩu phần:'),
                  const SizedBox(width: 12),
                  IconButton(
                    onPressed: _isSaving || _servings <= 1 ? null : _decServings,
                    icon: const Icon(Icons.remove_circle_outline),
                  ),
                  Text(
                    'x$_servings',
                    style: Theme.of(context).textTheme.titleMedium,
                  ),
                  IconButton(
                    onPressed: _isSaving ? null : _incServings,
                    icon: const Icon(Icons.add_circle_outline),
                  ),
                ],
              ),
              const SizedBox(height: 12),
              TextField(
                controller: _noteController,
                enabled: !_isSaving,
                maxLines: 3,
                decoration: const InputDecoration(
                  labelText: 'Ghi chú (optional)',
                  border: OutlineInputBorder(),
                ),
              ),
              const SizedBox(height: 16),
              SizedBox(
                width: double.infinity,
                child: FilledButton.icon(
                  onPressed: _isSaving ? null : _add,
                  icon: const Icon(Icons.add_task),
                  label: _isSaving
                      ? const SizedBox(
                          width: 18,
                          height: 18,
                          child: CircularProgressIndicator(strokeWidth: 2),
                        )
                      : const Text('Thêm'),
                ),
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
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        SizedBox(
          width: 72,
          child: Text(
            label,
            style: theme.textTheme.bodySmall?.copyWith(color: theme.hintColor),
          ),
        ),
        Expanded(
          child: Text(
            value.isNotEmpty ? value : '—',
            overflow: TextOverflow.ellipsis,
          ),
        ),
      ],
    );
  }
}

String _formatDayMonthYear(DateTime date) {
  String two(int n) => n.toString().padLeft(2, '0');
  final d = date.toLocal();
  return '${two(d.day)}/${two(d.month)}/${d.year}';
}
