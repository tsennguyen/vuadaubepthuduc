import 'dart:ui';

import 'package:flutter/material.dart';

import 'theme.dart';
import 'l10n.dart';
import 'language_controller.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

/// Shared scaffold that hosts the tab navigation for the user area.
class AppScaffold extends ConsumerWidget {
  const AppScaffold({
    super.key,
    required this.child,
    required this.currentIndex,
    required this.onTabSelected,
    this.isAdmin = false,
    this.onCreatePressed,
  });

  final Widget child;
  final int currentIndex;
  final ValueChanged<int> onTabSelected;
  final bool isAdmin;
  final VoidCallback? onCreatePressed;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final locale = ref.watch(localeProvider);
    final s = S(locale);
    final destinations = _buildDestinations(isAdmin: isAdmin, s: s);
    final clampedIndex = currentIndex.clamp(0, destinations.length - 1).toInt();
    final width = MediaQuery.sizeOf(context).width;
    final isDesktop = width >= 1200;

    if (isDesktop) {
      return Scaffold(
        backgroundColor: Theme.of(context).scaffoldBackgroundColor,
        body: Row(
          children: [
            NavigationRail(
              selectedIndex: clampedIndex,
              onDestinationSelected: onTabSelected,
              extended: true,
              labelType: NavigationRailLabelType.none,
              destinations: destinations
                  .map(
                    (d) => NavigationRailDestination(
                      icon: d.icon,
                      selectedIcon: d.selectedIcon,
                      label: Text(d.label),
                    ),
                  )
                  .toList(),
            ),
            const VerticalDivider(width: 1),
            Expanded(
              child: AnimatedSwitcher(
                duration: const Duration(milliseconds: 220),
                switchInCurve: Curves.easeOut,
                switchOutCurve: Curves.easeIn,
                child: KeyedSubtree(
                  key: ValueKey(clampedIndex),
                  child: child,
                ),
              ),
            ),
          ],
        ),
        floatingActionButton: onCreatePressed == null
            ? null
            : _CreateFab(
                onPressed: onCreatePressed!,
              ),
      );
    }

    return Scaffold(
      backgroundColor: Theme.of(context).scaffoldBackgroundColor,
      body: AnimatedSwitcher(
        duration: const Duration(milliseconds: 220),
        switchInCurve: Curves.easeOut,
        switchOutCurve: Curves.easeIn,
        child: KeyedSubtree(
          key: ValueKey(clampedIndex),
          child: child,
        ),
      ),
      bottomNavigationBar: _FrostedNavigationBar(
        destinations: destinations,
        selectedIndex: clampedIndex,
        onDestinationSelected: onTabSelected,
        hasCenterFab: onCreatePressed != null,
      ),
      floatingActionButton: onCreatePressed == null
          ? null
          : _CreateFab(
              onPressed: onCreatePressed!,
            ),
      floatingActionButtonLocation: FloatingActionButtonLocation.centerDocked,
    );
  }

  List<NavigationDestination> _buildDestinations({
    required bool isAdmin,
    required S s,
  }) {
    final items = <NavigationDestination>[
      NavigationDestination(
        icon: const Icon(Icons.dynamic_feed_outlined),
        selectedIcon: const Icon(Icons.dynamic_feed),
        label: s.feed,
      ),
      NavigationDestination(
        icon: const Icon(Icons.restaurant_menu_outlined),
        selectedIcon: const Icon(Icons.restaurant_menu),
        label: s.recipes,
      ),
      NavigationDestination(
        icon: const Icon(Icons.video_library_outlined),
        selectedIcon: const Icon(Icons.video_library),
        label: s.reels,
      ),
      NavigationDestination(
        icon: const Icon(Icons.calendar_month_outlined),
        selectedIcon: const Icon(Icons.calendar_month),
        label: s.planner,
      ),
      NavigationDestination(
        icon: const Icon(Icons.chat_bubble_outline),
        selectedIcon: const Icon(Icons.chat_bubble),
        label: s.chat,
      ),
      NavigationDestination(
        icon: const Icon(Icons.person_outline),
        selectedIcon: const Icon(Icons.person),
        label: s.profile,
      ),
    ];

    return items;
  }
}

class _FrostedNavigationBar extends StatelessWidget {
  const _FrostedNavigationBar({
    required this.destinations,
    required this.selectedIndex,
    required this.onDestinationSelected,
    required this.hasCenterFab,
  });

  final List<NavigationDestination> destinations;
  final int selectedIndex;
  final ValueChanged<int> onDestinationSelected;
  final bool hasCenterFab;

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;

    return SafeArea(
      top: false,
      child: Padding(
        padding: EdgeInsets.fromLTRB(
          AppSpacing.s12,
          AppSpacing.s8,
          AppSpacing.s12,
          hasCenterFab ? AppSpacing.s20 : AppSpacing.s12,
        ),
        child: ClipRRect(
          borderRadius: BorderRadius.circular(AppRadii.large + 8),
          child: BackdropFilter(
            filter: ImageFilter.blur(sigmaX: 24, sigmaY: 24),
            child: Container(
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                  colors: [
                    colorScheme.surface.withValues(alpha: 0.95),
                    colorScheme.surfaceContainerHighest.withValues(alpha: 0.92),
                  ],
                ),
                borderRadius: BorderRadius.circular(AppRadii.large + 8),
                border: Border.all(
                  color: colorScheme.outline.withValues(alpha: 0.15),
                  width: 1.5,
                ),
                boxShadow: [
                  BoxShadow(
                    color: colorScheme.primary.withValues(alpha: 0.08),
                    blurRadius: 16,
                    offset: const Offset(0, -4),
                  ),
                  const BoxShadow(
                    color: Color(0x14000000),
                    blurRadius: 24,
                    offset: Offset(0, -2),
                  ),
                ],
              ),
              child: NavigationBar(
                height: 64,
                backgroundColor: Colors.transparent,
                elevation: 0,
                indicatorColor: colorScheme.primary.withValues(alpha: 0.1),
                indicatorShape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(16),
                ),
                selectedIndex: selectedIndex,
                onDestinationSelected: onDestinationSelected,
                labelBehavior: NavigationDestinationLabelBehavior.alwaysHide,
                destinations: destinations,
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class _CreateFab extends StatefulWidget {
  const _CreateFab({required this.onPressed});

  final VoidCallback onPressed;

  @override
  State<_CreateFab> createState() => _CreateFabState();
}

class _CreateFabState extends State<_CreateFab>
    with SingleTickerProviderStateMixin {
  late AnimationController _controller;
  late Animation<double> _scaleAnimation;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      duration: const Duration(milliseconds: 1500),
      vsync: this,
    )..repeat(reverse: true);
    _scaleAnimation = Tween<double>(begin: 1.0, end: 1.05).animate(
      CurvedAnimation(parent: _controller, curve: Curves.easeInOut),
    );
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    return AnimatedBuilder(
      animation: _scaleAnimation,
      builder: (context, child) {
        return Transform.scale(
          scale: _scaleAnimation.value,
          child: Container(
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              gradient: LinearGradient(
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
                colors: [
                  colorScheme.primary,
                  colorScheme.secondary,
                ],
              ),
              boxShadow: [
                BoxShadow(
                  color: colorScheme.primary.withValues(alpha: 0.4),
                  blurRadius: 20,
                  offset: const Offset(0, 8),
                ),
                BoxShadow(
                  color: colorScheme.secondary.withValues(alpha: 0.3),
                  blurRadius: 12,
                  offset: const Offset(0, 4),
                ),
              ],
            ),
            child: FloatingActionButton.large(
              onPressed: widget.onPressed,
              backgroundColor: Colors.transparent,
              elevation: 0,
              shape: const CircleBorder(),
              child: const Icon(
                Icons.add_rounded,
                size: 32,
                color: Colors.white,
              ),
            ),
          ),
        );
      },
    );
  }
}

/// Map a tab index to its corresponding path.
String pathForIndex(int index, {required bool isAdmin}) {
  switch (index) {
    case 0:
      return '/feed';
    case 1:
      return '/recipes';
    case 2:
      return '/reels';
    case 3:
      return '/planner';
    case 4:
      return '/chat';
    case 5:
      return '/me';
    default:
      return '/feed';
  }
}

/// Map the current location to the selected tab index.
int indexForLocation(String location, {required bool isAdmin}) {
  if (location.startsWith('/profile')) return 5;
  if (location.startsWith('/me')) return 5;
  if (location.startsWith('/friends')) return 5;
  if (location.startsWith('/chat')) return 4;
  if (location.startsWith('/planner')) return 3;
  if (location.startsWith('/shopping')) return 3;
  if (location.startsWith('/reels')) return 2;
  if (location.startsWith('/recipes')) return 1;
  if (location.startsWith('/recipe')) return 1;
  return 0;
}
