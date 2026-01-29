import 'package:flutter/material.dart';

import '../../../../app/theme.dart';

class AdminNavItem {
  const AdminNavItem({
    required this.label,
    required this.icon,
    required this.path,
  });

  final String label;
  final IconData icon;
  final String path;
}

class AdminNavDrawer extends StatelessWidget {
  const AdminNavDrawer({
    super.key,
    required this.items,
    required this.selectedIndex,
    required this.onSelect,
    this.compact = false,
  });

  final List<AdminNavItem> items;
  final int selectedIndex;
  final ValueChanged<int> onSelect;
  final bool compact;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;
    return Container(
      decoration: BoxDecoration(
        color: colorScheme.surface,
        border: Border(
          right: BorderSide(
            color: colorScheme.outline.withValues(alpha: 0.1),
            width: 1,
          ),
        ),
      ),
      child: SafeArea(
        child: Container(
          padding: EdgeInsets.only(
            left: AppSpacing.s12,
            right: compact ? AppSpacing.s8 : AppSpacing.s12,
            top: AppSpacing.s16,
            bottom: AppSpacing.s12,
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              _DrawerHeader(compact: compact),
              const SizedBox(height: AppSpacing.s20),
              Expanded(
                child: ListView.separated(
                  itemCount: items.length,
                  separatorBuilder: (_, __) => const SizedBox(height: 8),
                  itemBuilder: (context, index) {
                    final item = items[index];
                    final selected = index == selectedIndex;
                    return _NavTile(
                      item: item,
                      selected: selected,
                      compact: compact,
                      onTap: () => onSelect(index),
                    );
                  },
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _DrawerHeader extends StatelessWidget {
  const _DrawerHeader({required this.compact});

  final bool compact;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Row(
      children: [
        Container(
          width: compact ? 38 : 46,
          height: compact ? 38 : 46,
          decoration: BoxDecoration(
            color: theme.colorScheme.primary,
            borderRadius: BorderRadius.circular(AppRadii.large),
            boxShadow: [
              BoxShadow(
                color: theme.colorScheme.primary.withValues(alpha: 0.3),
                blurRadius: 12,
                offset: const Offset(0, 4),
              ),
            ],
          ),
          alignment: Alignment.center,
          child: Text(
            'V',
            style: theme.textTheme.titleLarge?.copyWith(
              color: Colors.white,
              fontWeight: FontWeight.w900,
            ),
          ),
        ),
        if (!compact) ...[
          const SizedBox(width: AppSpacing.s14),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  '',
                  style: theme.textTheme.titleLarge?.copyWith(
                    fontWeight: FontWeight.w800,
                  ),
                ),
                const SizedBox(height: 2),
                Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 8,
                    vertical: 2,
                  ),
                  decoration: BoxDecoration(
                    color: theme.colorScheme.primary.withValues(alpha: 0.1),
                    borderRadius: BorderRadius.circular(AppRadii.small),
                  ),
                  child: Text(
                    'Admin Dashboard',
                    style: theme.textTheme.bodySmall?.copyWith(
                      color: theme.colorScheme.primary,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                ),
              ],
            ),
          ),
        ],
      ],
    );
  }
}

class _NavTile extends StatefulWidget {
  const _NavTile({
    required this.item,
    required this.selected,
    required this.compact,
    required this.onTap,
  });

  final AdminNavItem item;
  final bool selected;
  final bool compact;
  final VoidCallback onTap;

  @override
  State<_NavTile> createState() => _NavTileState();
}

class _NavTileState extends State<_NavTile> {
  bool _hovering = false;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;

    return MouseRegion(
      onEnter: (_) => setState(() => _hovering = true),
      onExit: (_) => setState(() => _hovering = false),
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 200),
        decoration: BoxDecoration(
          color: widget.selected
              ? colorScheme.primary.withValues(alpha: 0.1)
              : _hovering
                  ? colorScheme.surfaceContainerHighest.withValues(alpha: 0.3)
                  : null,
          borderRadius: BorderRadius.circular(AppRadii.large),
        ),
        child: InkWell(
          borderRadius: BorderRadius.circular(AppRadii.large),
          onTap: widget.onTap,
          child: Stack(
            children: [
              if (widget.selected)
                Positioned(
                  left: 0,
                  top: 12,
                  bottom: 12,
                  child: Container(
                    width: 3,
                    decoration: BoxDecoration(
                      color: colorScheme.primary,
                      borderRadius: const BorderRadius.horizontal(
                        right: Radius.circular(4),
                      ),
                    ),
                  ),
                ),
              Padding(
                padding: EdgeInsets.symmetric(
                  horizontal: widget.compact ? AppSpacing.s10 : AppSpacing.s14,
                  vertical: AppSpacing.s12,
                ),
                child: Row(
                  children: [
                    Container(
                      padding: const EdgeInsets.all(6),
                      decoration: BoxDecoration(
                        color: widget.selected
                            ? colorScheme.primary
                            : _hovering
                                ? colorScheme.primary.withValues(alpha: 0.1)
                                : Colors.transparent,
                        borderRadius: BorderRadius.circular(AppRadii.small),
                      ),
                      child: Icon(
                        widget.item.icon,
                        color: widget.selected
                            ? Colors.white
                            : colorScheme.onSurface,
                        size: widget.compact ? 18 : 20,
                      ),
                    ),
                    if (!widget.compact) ...[
                      const SizedBox(width: AppSpacing.s12),
                      Expanded(
                        child: Text(
                          widget.item.label,
                          style: theme.textTheme.titleSmall?.copyWith(
                            color: widget.selected
                                ? colorScheme.primary
                                : colorScheme.onSurface,
                            fontWeight: widget.selected
                                ? FontWeight.w700
                                : FontWeight.w600,
                          ),
                        ),
                      ),
                    ],
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
