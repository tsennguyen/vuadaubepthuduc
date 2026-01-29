import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import '../../../core/constants/app_icons.dart';

class HomeShellPage extends StatelessWidget {
  const HomeShellPage({super.key, required this.child});

  final Widget child;

  int _currentIndex(String location) {
    if (location.startsWith('/search')) return 1;
    if (location.startsWith('/chat')) return 2;
    if (location.startsWith('/leaderboard')) return 3;
    if (location.startsWith('/profile')) return 4;
    return 0;
  }

  void _onTap(BuildContext context, int index) {
    switch (index) {
      case 0:
        context.go('/home');
        break;
      case 1:
        context.go('/search');
        break;
      case 2:
        context.go('/chat');
        break;
      case 3:
        context.go('/leaderboard');
        break;
      case 4:
        context.go('/profile');
        break;
    }
  }

  @override
  Widget build(BuildContext context) {
    final location = GoRouterState.of(context).uri.toString();
    return Scaffold(
      body: child,
      bottomNavigationBar: BottomNavigationBar(
        currentIndex: _currentIndex(location),
        onTap: (index) => _onTap(context, index),
        items: const [
          BottomNavigationBarItem(icon: Icon(AppIcons.home), label: 'Feed'),
          BottomNavigationBarItem(icon: Icon(AppIcons.search), label: 'Search'),
          BottomNavigationBarItem(icon: Icon(AppIcons.chat), label: 'Chat'),
          BottomNavigationBarItem(icon: Icon(AppIcons.leaderboard), label: 'Top'),
          BottomNavigationBarItem(icon: Icon(AppIcons.profile), label: 'Profile'),
        ],
      ),
    );
  }
}
