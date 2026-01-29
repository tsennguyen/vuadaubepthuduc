import 'package:flutter/material.dart';

enum AppButtonStyle { primary, secondary, text }

class AppButton extends StatelessWidget {
  const AppButton({
    super.key,
    required this.label,
    required this.onPressed,
    this.icon,
    this.style = AppButtonStyle.primary,
  });

  final String label;
  final VoidCallback? onPressed;
  final IconData? icon;
  final AppButtonStyle style;

  @override
  Widget build(BuildContext context) {
    final child = Row(
      mainAxisSize: MainAxisSize.min,
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        if (icon != null) ...[
          Icon(icon, size: 18),
          const SizedBox(width: 8),
        ],
        Text(label),
      ],
    );

    switch (style) {
      case AppButtonStyle.primary:
        return ElevatedButton(
          onPressed: onPressed,
          child: child,
        );
      case AppButtonStyle.secondary:
        return OutlinedButton(
          onPressed: onPressed,
          child: child,
        );
      case AppButtonStyle.text:
        return TextButton(
          onPressed: onPressed,
          child: child,
        );
    }
  }
}
