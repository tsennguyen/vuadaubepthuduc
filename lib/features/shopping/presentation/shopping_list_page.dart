import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import '../data/shopping_list_repository.dart';
import '../domain/shopping_list_models.dart';

import '../../../app/l10n.dart';
import '../../../app/language_controller.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

enum FilterState { all, unchecked, checked }

class ShoppingListPage extends ConsumerStatefulWidget {
  const ShoppingListPage({super.key});

  @override
  ConsumerState<ShoppingListPage> createState() => _ShoppingListPageState();
}

class _ShoppingListPageState extends ConsumerState<ShoppingListPage> {
  final _repo = FirestoreShoppingListRepository();
  final _searchController = TextEditingController();
  FilterState _filter = FilterState.all;
  String _query = '';

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  void _setFilter(FilterState value) {
    setState(() => _filter = value);
  }

  void _setQuery(String value) {
    setState(() => _query = value);
  }

  Future<void> _clearChecked(S s) async {
    final confirm = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: Text(s.isVi ? 'Xóa nguyên liệu đã mua' : 'Clear checked items'),
        content: Text(s.isVi ? 'Bạn có chắc chắn muốn xóa tất cả nguyên liệu đã đánh dấu?' : 'Are you sure you want to clear all checked items?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: Text(s.cancel),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(ctx, true),
            style: FilledButton.styleFrom(
              backgroundColor: Theme.of(context).colorScheme.error,
            ),
            child: Text(s.delete),
          ),
        ],
      ),
    );

    if (confirm == true) {
      await _repo.clearChecked();
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(s.isVi ? 'Đã xóa nguyên liệu đã mua' : 'Cleared checked items'),
            behavior: SnackBarBehavior.floating,
          ),
        );
      }
    }
  }

  Future<void> _toggleChecked(ShoppingListItem item, bool checked) async {
    await _repo.toggleChecked(item.id, checked);
  }

  Future<void> _openEditSheet(ShoppingListItem item) async {
    await showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (ctx) => _EditItemSheet(item: item, repo: _repo),
    );
  }

  @override
  Widget build(BuildContext context) {
    final locale = ref.watch(localeProvider);
    final s = S(locale);
    final isVi = s.isVi;
    final theme = Theme.of(context);

    return Scaffold(
      appBar: AppBar(
        title: Text(s.shopTitle, style: const TextStyle(fontWeight: FontWeight.bold)),
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
        actions: [
          IconButton(
            icon: const Icon(Icons.delete_sweep_rounded),
            onPressed: () => _clearChecked(s),
            tooltip: isVi ? 'Xóa đã mua' : 'Clear checked',
          ),
        ],
      ),
      body: Column(
        children: [
          // Search bar
          Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: theme.colorScheme.surface,
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withValues(alpha: 0.05),
                  blurRadius: 4,
                  offset: const Offset(0, 2),
                ),
              ],
            ),
            child: Container(
              decoration: BoxDecoration(
                color: theme.colorScheme.surfaceContainerHighest.withValues(alpha: 0.5),
                borderRadius: BorderRadius.circular(16),
              ),
              child: TextField(
                controller: _searchController,
                onChanged: _setQuery,
                decoration: InputDecoration(
                  hintText: isVi ? 'Tìm nguyên liệu...' : 'Search ingredients...',
                  prefixIcon: const Icon(Icons.search_rounded),
                  border: InputBorder.none,
                  contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
                  suffixIcon: _query.isNotEmpty
                      ? IconButton(
                          icon: const Icon(Icons.clear, size: 20),
                          onPressed: () {
                            _searchController.clear();
                            _setQuery('');
                          },
                        )
                      : null,
                ),
              ),
            ),
          ),

          // Filter chips
          _FilterBar(
            filter: _filter,
            onChanged: _setFilter,
          ),

          // List
          Expanded(
            child: StreamBuilder<List<ShoppingListItem>>(
              stream: _repo.watchItems(),
              builder: (context, snapshot) {
                if (snapshot.connectionState == ConnectionState.waiting) {
                  return const Center(child: CircularProgressIndicator());
                }

                if (snapshot.hasError) {
                  return Center(
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Icon(Icons.error_outline, size: 64, color: theme.colorScheme.error),
                        const SizedBox(height: 16),
                        Text('${s.error}: ${snapshot.error}', style: theme.textTheme.bodyLarge),
                      ],
                    ),
                  );
                }

                final allItems = snapshot.data ?? [];
                final filtered = _applyFilter(allItems, _filter, _query);

                if (filtered.isEmpty) {
                  return Center(
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Container(
                          padding: const EdgeInsets.all(24),
                          decoration: BoxDecoration(
                            color: theme.colorScheme.primaryContainer.withValues(alpha: 0.3),
                            shape: BoxShape.circle,
                          ),
                          child: Icon(
                            Icons.shopping_basket_outlined,
                            size: 64,
                            color: theme.colorScheme.primary,
                          ),
                        ),
                        const SizedBox(height: 24),
                        Text(
                          s.emptyShopTitle,
                          style: theme.textTheme.titleLarge?.copyWith(
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                        const SizedBox(height: 8),
                        Text(
                          s.emptyShopSubtitle,
                          style: theme.textTheme.bodyMedium?.copyWith(
                            color: theme.colorScheme.onSurface.withValues(alpha: 0.6),
                          ),
                          textAlign: TextAlign.center,
                        ),
                      ],
                    ),
                  );
                }

                final grouped = _groupByCategory(filtered);
                return _buildSections(grouped, s);
              },
            ),
          ),
        ],
      ),
    );
  }

  Map<String, List<ShoppingListItem>> _groupByCategory(
    List<ShoppingListItem> items,
  ) {
    final grouped = <String, List<ShoppingListItem>>{};
    for (final item in items) {
      final cat = _normalizeCategory(item.category);
      grouped.putIfAbsent(cat, () => []).add(item);
    }
    return grouped;
  }

  List<ShoppingListItem> _applyFilter(
    List<ShoppingListItem> items,
    FilterState filter,
    String query,
  ) {
    var result = items;

    // Apply filter
    switch (filter) {
      case FilterState.unchecked:
        result = result.where((item) => !item.checked).toList();
        break;
      case FilterState.checked:
        result = result.where((item) => item.checked).toList();
        break;
      case FilterState.all:
        break;
    }

    // Apply search
    if (query.trim().isNotEmpty) {
      final lower = query.toLowerCase();
      result = result
          .where((item) =>
              item.name.toLowerCase().contains(lower) ||
              item.category.toLowerCase().contains(lower))
          .toList();
    }

    return result;
  }

  Widget _buildSections(Map<String, List<ShoppingListItem>> grouped, S s) {
    final categories = grouped.keys.toList()..sort();

    return ListView.builder(
      padding: const EdgeInsets.only(bottom: 80),
      itemCount: categories.length,
      itemBuilder: (context, index) {
        final category = categories[index];
        final items = grouped[category]!;
        final meta = _categoryMeta(category, s);

        return Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Category header
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
              margin: const EdgeInsets.only(top: 8),
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  colors: [
                    meta.color.withValues(alpha: 0.15),
                    meta.color.withValues(alpha: 0.05),
                  ],
                ),
                border: Border(
                  left: BorderSide(color: meta.color, width: 4),
                ),
              ),
              child: Row(
                children: [
                  Container(
                    padding: const EdgeInsets.all(8),
                    decoration: BoxDecoration(
                      color: meta.color.withValues(alpha: 0.2),
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: Icon(meta.icon, size: 20, color: meta.color),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Text(
                      meta.label,
                      style: Theme.of(context).textTheme.titleMedium?.copyWith(
                            fontWeight: FontWeight.bold,
                            color: meta.color,
                          ),
                    ),
                  ),
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                    decoration: BoxDecoration(
                      color: meta.color.withValues(alpha: 0.2),
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: Text(
                      '${items.length}',
                      style: TextStyle(
                        fontSize: 12,
                        fontWeight: FontWeight.bold,
                        color: meta.color,
                      ),
                    ),
                  ),
                ],
              ),
            ),

            // Items
            ...items.map((item) => _ShoppingListTile(
                  item: item,
                  onToggle: _toggleChecked,
                  onEdit: _openEditSheet,
                )),
          ],
        );
      },
    );
  }
}

class _FilterBar extends ConsumerWidget {
  const _FilterBar({
    required this.filter,
    required this.onChanged,
  });

  final FilterState filter;
  final ValueChanged<FilterState> onChanged;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final s = S(ref.watch(localeProvider));
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      child: Row(
        children: [
          _FilterChip(
            label: s.filterAll,
            isSelected: filter == FilterState.all,
            onTap: () => onChanged(FilterState.all),
          ),
          const SizedBox(width: 8),
          _FilterChip(
            label: s.filterUnchecked,
            isSelected: filter == FilterState.unchecked,
            onTap: () => onChanged(FilterState.unchecked),
          ),
          const SizedBox(width: 8),
          _FilterChip(
            label: s.filterChecked,
            isSelected: filter == FilterState.checked,
            onTap: () => onChanged(FilterState.checked),
          ),
        ],
      ),
    );
  }
}

class _FilterChip extends StatelessWidget {
  const _FilterChip({
    required this.label,
    required this.isSelected,
    required this.onTap,
  });

  final String label;
  final bool isSelected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;

    return GestureDetector(
      onTap: onTap,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 200),
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
        decoration: BoxDecoration(
          color: isSelected
              ? (isDark
                  ? theme.colorScheme.primary.withValues(alpha: 0.3)
                  : theme.colorScheme.primary)
              : theme.colorScheme.surfaceContainerHighest,
          borderRadius: BorderRadius.circular(20),
          boxShadow: isSelected
              ? [
                  BoxShadow(
                    color: theme.colorScheme.primary.withValues(
                      alpha: isDark ? 0.15 : 0.3,
                    ),
                    blurRadius: 8,
                    offset: const Offset(0, 2),
                  )
                ]
              : null,
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            if (isSelected)
              Icon(
                Icons.check_circle,
                size: 16,
                color: isDark
                    ? theme.colorScheme.onSurface.withValues(alpha: 0.85)
                    : theme.colorScheme.onPrimary,
              ),
            if (isSelected) const SizedBox(width: 6),
            Text(
              label,
              style: TextStyle(
                color: isSelected
                    ? (isDark
                        ? theme.colorScheme.onSurface.withValues(alpha: 0.85)
                        : theme.colorScheme.onPrimary)
                    : theme.colorScheme.onSurface,
                fontWeight: isSelected ? FontWeight.bold : FontWeight.w500,
                fontSize: 13,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _ShoppingListTile extends ConsumerWidget {
  const _ShoppingListTile({
    required this.item,
    required this.onToggle,
    required this.onEdit,
  });

  final ShoppingListItem item;
  final Function(ShoppingListItem, bool) onToggle;
  final Function(ShoppingListItem) onEdit;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final s = S(ref.watch(localeProvider));
    final theme = Theme.of(context);

    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
      decoration: BoxDecoration(
        color: item.checked
            ? theme.colorScheme.surfaceContainerHighest.withValues(alpha: 0.5)
            : theme.colorScheme.surface,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(
          color: item.checked
              ? theme.colorScheme.outline.withValues(alpha: 0.2)
              : theme.colorScheme.outline.withValues(alpha: 0.1),
        ),
      ),
      child: ListTile(
        onTap: () => onEdit(item),
        contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
        leading: Checkbox(
          value: item.checked,
          onChanged: (val) => onToggle(item, val ?? false),
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(4)),
        ),
        title: Text(
          item.name,
          style: TextStyle(
            decoration: item.checked ? TextDecoration.lineThrough : null,
            color: item.checked
                ? theme.colorScheme.onSurface.withValues(alpha: 0.5)
                : theme.colorScheme.onSurface,
            fontWeight: FontWeight.w600,
          ),
        ),
        subtitle: Text(
          _buildSubtitle(s),
          style: TextStyle(
            fontSize: 12,
            color: theme.colorScheme.onSurface.withValues(alpha: 0.6),
          ),
        ),
        trailing: IconButton(
          icon: const Icon(Icons.edit_outlined, size: 20),
          onPressed: () => onEdit(item),
          tooltip: s.edit,
        ),
      ),
    );
  }

  String _buildSubtitle(S s) {
    if (item.quantity > 0) {
      final qty = _formatQuantity(item.quantity);
      if (item.unit.isNotEmpty) {
        return '$qty ${item.unit}';
      }
      return qty;
    }
    return s.isVi ? 'Chưa có thông tin' : 'No info';
  }
}

class _CategoryMeta {
  final String label;
  final IconData icon;
  final Color color;

  const _CategoryMeta({
    required this.label,
    required this.icon,
    required this.color,
  });
}

_CategoryMeta _categoryMeta(String category, S s) {
  switch (category.toLowerCase()) {
    case 'rau củ':
    case 'vegetables':
      return _CategoryMeta(
        label: s.catVeg,
        icon: Icons.grass_outlined,
        color: const Color(0xFF4CAF50),
      );
    case 'thịt':
    case 'meat':
      return _CategoryMeta(
        label: s.catMeat,
        icon: Icons.set_meal_outlined,
        color: const Color(0xFFE53935),
      );
    case 'hải sản':
    case 'seafood':
      return _CategoryMeta(
        label: s.catSeafood,
        icon: Icons.phishing_outlined,
        color: const Color(0xFF039BE5),
      );
    case 'gia vị':
    case 'spices':
      return _CategoryMeta(
        label: s.catSpices,
        icon: Icons.spa_outlined,
        color: const Color(0xFFFB8C00),
      );
    case 'ngũ cốc':
    case 'grains':
      return _CategoryMeta(
        label: s.catGrains,
        icon: Icons.grain_outlined,
        color: const Color(0xFF8D6E63),
      );
    case 'sữa':
    case 'dairy':
      return _CategoryMeta(
        label: s.catDairy,
        icon: Icons.coffee_outlined,
        color: const Color(0xFF5E35B1),
      );
    default:
      return _CategoryMeta(
        label: s.catOther,
        icon: Icons.shopping_basket_outlined,
        color: const Color(0xFF757575),
      );
  }
}

String _normalizeCategory(String input) {
  final map = {
    'vegetable': 'Rau củ',
    'vegetables': 'Rau củ',
    'meat': 'Thịt',
    'seafood': 'Hải sản',
    'spice': 'Gia vị',
    'spices': 'Gia vị',
    'grain': 'Ngũ cốc',
    'grains': 'Ngũ cốc',
    'dairy': 'Sữa',
  };
  
  final lower = input.toLowerCase().trim();
  return map[lower] ?? input;
}

String _formatQuantity(double value) {
  if (value == value.toInt()) {
    return value.toInt().toString();
  }
  return value.toStringAsFixed(1).replaceAll(RegExp(r'\.0$'), '');
}


class _EditItemSheet extends ConsumerStatefulWidget {
  const _EditItemSheet({
    required this.item,
    required this.repo,
  });

  final ShoppingListItem item;
  final ShoppingListRepository repo;

  @override
  ConsumerState<_EditItemSheet> createState() => _EditItemSheetState();
}

class _EditItemSheetState extends ConsumerState<_EditItemSheet> {
  late final TextEditingController _nameController;
  late final TextEditingController _quantityController;
  late final TextEditingController _unitController;

  @override
  void initState() {
    super.initState();
    _nameController = TextEditingController(text: widget.item.name);
    _quantityController = TextEditingController(
      text: widget.item.quantity.toString(),
    );
    _unitController = TextEditingController(text: widget.item.unit);
  }

  @override
  void dispose() {
    _nameController.dispose();
    _quantityController.dispose();
    _unitController.dispose();
    super.dispose();
  }

  Future<void> _save(S s) async {
    final name = _nameController.text.trim();
    if (name.isEmpty) {
      _showSnack(s.isVi ? 'Vui lòng nhập tên nguyên liệu' : 'Please enter ingredient name');
      return;
    }

    final qtyText = _quantityController.text.trim();
    final qty = qtyText.isEmpty ? 0.0 : (double.tryParse(qtyText) ?? 0.0);

    final updatedItem = widget.item.copyWith(
      name: name,
      quantity: qty,
      unit: _unitController.text.trim(),
    );

    await widget.repo.updateItem(updatedItem);

    if (mounted) {
      Navigator.pop(context);
      _showSnack(s.isVi ? 'Đã cập nhật nguyên liệu' : 'Ingredient updated');
    }
  }

  Future<void> _delete(S s) async {
    final confirm = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: Text(s.isVi ? 'Xóa nguyên liệu' : 'Delete ingredient'),
        content: Text(s.isVi ? 'Bạn có chắc chắn muốn xóa nguyên liệu này?' : 'Are you sure you want to delete this ingredient?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: Text(s.cancel),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(ctx, true),
            style: FilledButton.styleFrom(
              backgroundColor: Theme.of(context).colorScheme.error,
            ),
            child: Text(s.delete),
          ),
        ],
      ),
    );

    if (confirm == true) {
      await widget.repo.deleteItem(widget.item.id);
      if (mounted) {
        Navigator.pop(context);
        _showSnack(s.isVi ? 'Đã xóa nguyên liệu' : 'Ingredient deleted');
      }
    }
  }

  void _showSnack(String message) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(message),
        behavior: SnackBarBehavior.floating,
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final s = S(ref.watch(localeProvider));
    final isVi = s.isVi;
    final theme = Theme.of(context);

    return Container(
      decoration: BoxDecoration(
        color: theme.colorScheme.surface,
        borderRadius: const BorderRadius.vertical(top: Radius.circular(24)),
      ),
      padding: EdgeInsets.only(
        left: 24,
        right: 24,
        top: 24,
        bottom: MediaQuery.of(context).viewInsets.bottom + 24,
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Expanded(
                child: Text(
                  isVi ? 'Chỉnh sửa nguyên liệu' : 'Edit Ingredient',
                  style: theme.textTheme.titleLarge?.copyWith(
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ),
              IconButton(
                icon: const Icon(Icons.close),
                onPressed: () => Navigator.pop(context),
              ),
            ],
          ),
          const SizedBox(height: 24),
          TextField(
            controller: _nameController,
            decoration: InputDecoration(
              labelText: isVi ? 'Tên nguyên liệu' : 'Name',
              border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
              filled: true,
            ),
          ),
          const SizedBox(height: 16),
          Row(
            children: [
              Expanded(
                flex: 2,
                child: TextField(
                  controller: _quantityController,
                  keyboardType: TextInputType.number,
                  decoration: InputDecoration(
                    labelText: isVi ? 'Số lượng' : 'Quantity',
                    border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
                    filled: true,
                  ),
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: TextField(
                  controller: _unitController,
                  decoration: InputDecoration(
                    labelText: isVi ? 'Đơn vị' : 'Unit',
                    hintText: 'kg, g...',
                    border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
                    filled: true,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 24),
          Row(
            children: [
              Expanded(
                child: OutlinedButton.icon(
                  onPressed: () => _delete(s),
                  style: OutlinedButton.styleFrom(
                    foregroundColor: theme.colorScheme.error,
                    side: BorderSide(color: theme.colorScheme.error),
                    padding: const EdgeInsets.symmetric(vertical: 14),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12),
                    ),
                  ),
                  icon: const Icon(Icons.delete_outline, size: 20),
                  label: Text(s.delete),
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                flex: 2,
                child: FilledButton.icon(
                  onPressed: () => _save(s),
                  style: FilledButton.styleFrom(
                    padding: const EdgeInsets.symmetric(vertical: 14),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12),
                    ),
                  ),
                  icon: const Icon(Icons.check, size: 20),
                  label: Text(s.save),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}
