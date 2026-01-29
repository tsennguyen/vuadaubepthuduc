import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

/// Common action buttons for admin pages: Home and Refresh
class AdminPageActions extends StatelessWidget {
  const AdminPageActions({
    super.key,
    this.onRefresh,
  });

  final VoidCallback? onRefresh;

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        IconButton(
          tooltip: 'Về trang chính',
          onPressed: () => context.go('/'),
          icon: const Icon(Icons.home_rounded),
        ),
        if (onRefresh != null)
          IconButton(
            tooltip: 'Làm mới',
            onPressed: onRefresh,
            icon: const Icon(Icons.refresh_rounded),
          ),
        const SizedBox(width: 8),
      ],
    );
  }
}
