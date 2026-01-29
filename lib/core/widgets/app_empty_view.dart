import 'package:flutter/material.dart';

import '../../app/theme.dart';

class AppEmptyView extends StatelessWidget {
  const AppEmptyView({
    super.key,
    this.icon = Icons.inbox_outlined,
    this.title = 'Không có dữ liệu',
    this.subtitle,
    this.action,
  });

  final IconData icon;
  final String title;
  final String? subtitle;
  final Widget? action;

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(AppSpacing.s24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(icon, size: 44, color: Theme.of(context).iconTheme.color),
            const SizedBox(height: AppSpacing.s12),
            Text(
              title,
              style: Theme.of(context).textTheme.titleMedium,
              textAlign: TextAlign.center,
            ),
            if (subtitle != null) ...[
              const SizedBox(height: AppSpacing.s8),
              Text(
                subtitle!,
                style: Theme.of(context).textTheme.bodyMedium,
                textAlign: TextAlign.center,
              ),
            ],
            if (action != null) ...[
              const SizedBox(height: AppSpacing.s16),
              action!,
            ],
          ],
        ),
      ),
    );
  }
}
