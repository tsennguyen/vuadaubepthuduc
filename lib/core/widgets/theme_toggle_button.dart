import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../app/language_controller.dart';
import '../../app/theme.dart';
import '../../app/theme_controller.dart';

class ThemeToggleButton extends ConsumerWidget {
  const ThemeToggleButton({super.key, this.compact = false});

  final bool compact;

  bool _isDark(ThemeMode mode, Brightness platform) {
    if (mode == ThemeMode.dark) return true;
    if (mode == ThemeMode.light) return false;
    return platform == Brightness.dark;
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final mode = ref.watch(themeModeProvider);
    final controller = ref.read(themeModeProvider.notifier);
    final locale = ref.watch(localeProvider);
    final isVi = locale.languageCode == 'vi';
    final isDark = _isDark(mode, MediaQuery.platformBrightnessOf(context));
    final scheme = Theme.of(context).colorScheme;
    final icon = isDark ? Icons.wb_sunny_rounded : Icons.dark_mode_rounded;
    
    final label = isDark 
        ? (isVi ? 'Chế độ sáng' : 'Light Mode') 
        : (isVi ? 'Chế độ tối' : 'Dark Mode');

    if (compact) {
      return IconButton(
        tooltip: isVi ? 'Bật/tắt Dark Mode' : 'Toggle Dark Mode',
        onPressed: controller.toggle,
        style: IconButton.styleFrom(
          backgroundColor: scheme.surfaceContainerHigh.withValues(alpha: 0.7),
        ),
        icon: Icon(icon),
      );
    }

    return AnimatedContainer(
      duration: const Duration(milliseconds: 220),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(AppRadii.large),
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: isDark
              ? [
                  scheme.surfaceContainerHigh,
                  scheme.surfaceContainerHighest,
                ]
              : [
                  scheme.surface,
                  scheme.surfaceContainerHighest,
                ],
        ),
        border: Border.all(color: scheme.outline.withValues(alpha: 0.25)),
        boxShadow: [
          BoxShadow(
            color: scheme.primary.withValues(alpha: 0.12),
            blurRadius: 18,
            offset: const Offset(0, 10),
          ),
        ],
      ),
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          borderRadius: BorderRadius.circular(AppRadii.large),
          onTap: controller.toggle,
          child: Padding(
            padding: const EdgeInsets.symmetric(
              horizontal: AppSpacing.s14,
              vertical: AppSpacing.s10,
            ),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(icon, size: 20, color: scheme.onSurface),
                const SizedBox(width: AppSpacing.s8),
                Text(
                  label,
                  style: Theme.of(context).textTheme.labelLarge?.copyWith(
                        fontWeight: FontWeight.w700,
                      ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
