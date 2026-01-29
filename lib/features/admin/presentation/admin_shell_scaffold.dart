import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import '../../../app/theme.dart';
import '../../../core/widgets/theme_toggle_button.dart';
import 'widgets/admin_nav_drawer.dart';

class AdminShell extends StatelessWidget {
  const AdminShell({
    required this.child,
    this.actions,
    super.key,
  });

  final Widget child;
  final List<Widget>? actions;

  String _getAdminName() {
    final user = FirebaseAuth.instance.currentUser;
    return user?.displayName ?? user?.email?.split('@').first ?? 'Admin';
  }

  @override
  Widget build(BuildContext context) {
    final width = MediaQuery.sizeOf(context).width;
    final isWide = width >= 1100;
    final location = GoRouterState.of(context).uri.path;
    final selectedIndex = adminIndexForLocation(location);

    void handleSelect(int index) {
      final path = adminPathForIndex(index);
      if (path != location) {
        context.go(path);
      }
      if (!isWide) {
        Navigator.of(context).maybePop();
      }
    }

    final navDrawer = AdminNavDrawer(
      items: _navItems,
      selectedIndex: selectedIndex,
      onSelect: handleSelect,
      compact: isWide,
    );
    final mergedActions = <Widget>[
      const Padding(
        padding: EdgeInsets.symmetric(horizontal: 4),
        child: ThemeToggleButton(compact: true),
      ),
      if (actions != null) ...actions!,
    ];

    return Scaffold(
      backgroundColor: Theme.of(context).colorScheme.surface,
      appBar: PreferredSize(
        preferredSize: const Size.fromHeight(70),
        child: Container(
          decoration: BoxDecoration(
            color: Theme.of(context).colorScheme.surface.withValues(alpha: 0.8),
            border: Border(
              bottom: BorderSide(
                color: Theme.of(context).colorScheme.outline.withValues(alpha: 0.1),
                width: 1,
              ),
            ),
          ),
          child: AppBar(
            backgroundColor: Colors.transparent,
            elevation: 0,
            centerTitle: false,
            leadingWidth: isWide ? 0 : 56,
            leading: isWide
                ? const SizedBox.shrink()
                : Builder(
                    builder: (builderContext) => Padding(
                      padding: const EdgeInsets.only(left: 8),
                      child: IconButton(
                        icon: const Icon(Icons.menu_open_rounded),
                        onPressed: () => Scaffold.of(builderContext).openDrawer(),
                        style: IconButton.styleFrom(
                          foregroundColor: Theme.of(context).colorScheme.primary,
                        ),
                      ),
                    ),
                  ),
            title: Row(
              children: [
                if (isWide) const SizedBox(width: 8),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Text(
                        'Hệ thống quản trị',
                        style: TextStyle(
                          fontSize: 12,
                          fontWeight: FontWeight.w600,
                          color: Theme.of(context).colorScheme.outline,
                          letterSpacing: 0.5,
                        ),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                      const SizedBox(height: 2),
                      Text(
                        'Chào ${_getAdminName()}! 👋',
                        style: const TextStyle(
                          fontWeight: FontWeight.w800,
                          fontSize: 18,
                          letterSpacing: -0.5,
                        ),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ],
                  ),
                ),
              ],
            ),
            actions: [
              ...mergedActions,
              const SizedBox(width: 12),
            ],
          ),
        ),
      ),
      drawer: isWide ? null : Drawer(child: navDrawer),
      body: Row(
        children: [
          if (isWide) SizedBox(width: 260, child: navDrawer),
          Expanded(
            child: Container(
              color: Theme.of(context)
                  .colorScheme
                  .surfaceContainerHighest
                  .withValues(alpha: 0.1),
              child: child,
            ),
          ),
        ],
      ),
    );
  }
}

String adminPathForIndex(int index) {
  if (index < 0 || index >= _navItems.length) return _navItems.first.path;
  return _navItems[index].path;
}

int adminIndexForLocation(String location) {
  if (location.startsWith('/admin/ai-configs')) return 5; // group under settings
  for (var i = 0; i < _navItems.length; i++) {
    if (location.startsWith(_navItems[i].path)) return i;
  }
  if (location == '/admin' || location == '/admin/') return 0;
  return 0;
}

const List<AdminNavItem> _navItems = [
  AdminNavItem(
    label: 'Tổng quan',
    icon: Icons.dashboard_rounded,
    path: '/admin/overview',
  ),
  AdminNavItem(
    label: 'Người dùng',
    icon: Icons.people_alt_rounded,
    path: '/admin/users',
  ),
  AdminNavItem(
    label: 'Nội dung',
    icon: Icons.article_rounded,
    path: '/admin/content',
  ),
  AdminNavItem(
    label: 'Báo cáo',
    icon: Icons.flag_rounded,
    path: '/admin/reports',
  ),
  AdminNavItem(
    label: 'AI Prompts',
    icon: Icons.auto_awesome_rounded,
    path: '/admin/ai-prompts',
  ),
  AdminNavItem(
    label: 'Quản trị Chat',
    icon: Icons.security_rounded,
    path: '/admin/chats',
  ),
  AdminNavItem(
    label: 'Cài đặt',
    icon: Icons.settings_rounded,
    path: '/admin/settings',
  ),
  AdminNavItem(
    label: 'Nhật ký hệ thống',
    icon: Icons.receipt_long_rounded,
    path: '/admin/audit-logs',
  ),
];
