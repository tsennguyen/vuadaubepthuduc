import 'package:flutter/material.dart';

class DashboardChart extends StatelessWidget {
  const DashboardChart({
    super.key,
    required this.title,
    required this.child,
    this.height = 280,
  });

  final String title;
  final Widget child;
  final double height;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;

    return Card(
      elevation: 2,
      clipBehavior: Clip.antiAlias,
      child: Container(
        decoration: BoxDecoration(
          color: colorScheme.surface,
        ),
        child: Padding(
          padding: const EdgeInsets.all(20),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                title,
                style: theme.textTheme.titleLarge?.copyWith(
                  fontWeight: FontWeight.w700,
                  color: colorScheme.onSurface,
                ),
              ),
              const SizedBox(height: 16),
              SizedBox(
                height: height,
                child: child,
              ),
            ],
          ),
        ),
      ),
    );
  }
}
