import 'package:flutter/material.dart';

import '../theme.dart';
import '../../shared/widgets/notification_bell_icon.dart';

class AppTopBar extends StatelessWidget implements PreferredSizeWidget {
  const AppTopBar({
    super.key,
    required this.title,
    this.centerTitle = false,
    this.showSearch = true,
    this.onSearchTap,
    this.onNotificationsTap,
    this.actions,
  });

  final String title;
  final bool centerTitle;
  final bool showSearch;
  final VoidCallback? onSearchTap;
  final VoidCallback? onNotificationsTap;
  final List<Widget>? actions;

  @override
  Widget build(BuildContext context) {
    final textTheme = Theme.of(context).textTheme;
    return AppBar(
      title: Text(
        title,
        style: textTheme.titleLarge?.copyWith(
          fontWeight: FontWeight.w800,
          letterSpacing: -0.5,
        ),
      ),
      centerTitle: centerTitle,
      elevation: 0,
      scrolledUnderElevation: 0,
      shape: Border(
        bottom: BorderSide(
          color: Theme.of(context).colorScheme.outline.withValues(alpha: 0.05),
          width: 1,
        ),
      ),
      actions: _buildActions(context),
    );
  }

  List<Widget> _buildActions(BuildContext context) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;
    final widgets = <Widget>[];

    if (showSearch) {
      widgets.add(
        IconButton.filledTonal(
          tooltip: 'Search',
          style: IconButton.styleFrom(
            backgroundColor: isDark
                ? theme.colorScheme.surfaceContainerHigh
                : theme.colorScheme.surfaceVariant
                    .withValues(alpha: 0.6),
            foregroundColor: theme.colorScheme.onSurface,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(16),
            ),
          ),
          icon: const Icon(Icons.search_rounded, size: 26),
          onPressed: onSearchTap,
        ),
      );
      widgets.add(const SizedBox(width: 8));
    }

    if (onNotificationsTap != null) {
      widgets.add(const NotificationBellIcon());
      widgets.add(const SizedBox(width: 8));
    }

    if (actions != null) {
      for (var i = 0; i < actions!.length; i++) {
        widgets.add(actions![i]);
        if (i < actions!.length - 1) {
          widgets.add(const SizedBox(width: 8));
        }
      }
    }

    return widgets;
  }

  @override
  Size get preferredSize => const Size.fromHeight(kToolbarHeight);
}

class AppSliverTopBar extends StatelessWidget {
  const AppSliverTopBar({
    super.key,
    required this.title,
    this.pinned = true,
    this.expandedHeight = 140,
    this.onSearchTap,
    this.onNotificationsTap,
    this.actions,
  });

  final String title;
  final bool pinned;
  final double expandedHeight;
  final VoidCallback? onSearchTap;
  final VoidCallback? onNotificationsTap;
  final List<Widget>? actions;

  @override
  Widget build(BuildContext context) {
    final textTheme = Theme.of(context).textTheme;
    return SliverAppBar(
      pinned: pinned,
      floating: false,
      stretch: true,
      expandedHeight: expandedHeight,
      actions: _buildActions(context),
      flexibleSpace: FlexibleSpaceBar(
        titlePadding: const EdgeInsetsDirectional.only(
          start: AppSpacing.s16,
          bottom: AppSpacing.s12,
        ),
        title: Text(
          title,
          style: textTheme.titleLarge?.copyWith(fontWeight: FontWeight.w700),
        ),
      ),
    );
  }

  List<Widget> _buildActions(BuildContext context) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;
    final widgets = <Widget>[];

    if (onSearchTap != null) {
      widgets.add(
        IconButton.filledTonal(
          tooltip: 'Search',
          style: IconButton.styleFrom(
            backgroundColor: isDark
                ? theme.colorScheme.surfaceContainerHigh
                : theme.colorScheme.surfaceVariant
                    .withValues(alpha: 0.6),
            foregroundColor: theme.colorScheme.onSurface,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(16),
            ),
          ),
          icon: const Icon(Icons.search_rounded, size: 26),
          onPressed: onSearchTap,
        ),
      );
      widgets.add(const SizedBox(width: 8));
    }

    if (onNotificationsTap != null) {
      widgets.add(const NotificationBellIcon());
      widgets.add(const SizedBox(width: 8));
    }

    if (actions != null) {
      for (var i = 0; i < actions!.length; i++) {
        widgets.add(actions![i]);
        if (i < actions!.length - 1) {
          widgets.add(const SizedBox(width: 8));
        }
      }
    }
    return widgets;
  }
}
