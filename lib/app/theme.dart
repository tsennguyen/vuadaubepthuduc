import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

import '../core/constants/app_colors.dart';

/// Spacing scale used across the app.
class AppSpacing {
  static const double s4 = 4;
  static const double s6 = 6;
  static const double s8 = 8;
  static const double s10 = 10;
  static const double s12 = 12;
  static const double s14 = 14;
  static const double s16 = 16;
  static const double s20 = 20;
  static const double s24 = 24;
}

/// Backward-compatible radius tokens for older widgets.
class AppRadius {
  static const double r8 = AppSpacing.s8;
  static const double r12 = AppSpacing.s12;
}

/// Corner radii used to keep shapes consistent.
class AppRadii {
  static const double small = 8;
  static const double medium = 12;
  static const double large = 16;
  static const double extraLarge = 24;
  static const double pill = 999;
}

/// Typography helpers powered by Google Fonts.
class AppTypography {
  static TextTheme textThemeFor(ColorScheme scheme) {
    final base = GoogleFonts.lexendTextTheme();

    final onSurface = scheme.onSurface;
    final onSurfaceVariant = scheme.onSurfaceVariant;

    return base
        .copyWith(
          headlineLarge: base.headlineLarge?.copyWith(fontWeight: FontWeight.w700),
          headlineMedium: base.headlineMedium?.copyWith(fontWeight: FontWeight.w700),
          titleLarge: base.titleLarge?.copyWith(fontWeight: FontWeight.w700),
          titleMedium: base.titleMedium?.copyWith(fontWeight: FontWeight.w600),
          bodyLarge: base.bodyLarge?.copyWith(fontWeight: FontWeight.w500),
          bodyMedium: base.bodyMedium?.copyWith(fontWeight: FontWeight.w500),
          bodySmall: base.bodySmall?.copyWith(color: onSurfaceVariant),
          labelSmall: base.labelSmall?.copyWith(color: onSurfaceVariant),
        )
        .apply(
          bodyColor: onSurface,
          displayColor: onSurface,
        );
  }
}

class AppTheme {
  static ThemeData get lightTheme => _buildTheme(_lightColorScheme);

  static ThemeData get darkTheme => _buildTheme(_darkColorScheme);

  static final ColorScheme _lightColorScheme = ColorScheme.fromSeed(
    seedColor: AppColors.primary,
    brightness: Brightness.light,
    primary: AppColors.primary,
    secondary: AppColors.secondary,
    surface: AppColors.surface,
  ).copyWith(
    surfaceTint: AppColors.primary.withValues(alpha: 0.08),
    onPrimary: Colors.white,
    onSecondary: AppColors.textPrimary,
    onSurface: AppColors.textPrimary,
    onSurfaceVariant: AppColors.textSecondary,
    outline: AppColors.textSecondary.withValues(alpha: 0.22),
    outlineVariant: AppColors.border,
    shadow: Colors.black.withValues(alpha: 0.08),
  );

  static final ColorScheme _darkColorScheme = ColorScheme.fromSeed(
    seedColor: const Color(0xFF34D399),
    brightness: Brightness.dark,
    primary: const Color(0xFF34D399),
    secondary: const Color(0xFFFFC773),
    surface: AppColors.darkSurface,
  ).copyWith(
    surface: AppColors.darkSurface,
    surfaceContainerLowest: AppColors.darkBackground,
    surfaceContainerLow: const Color(0xFF0E1828),
    surfaceContainer: const Color(0xFF131C2D),
    surfaceContainerHigh: const Color(0xFF152036),
    surfaceContainerHighest: AppColors.darkSurfaceHigh,
    surfaceTint: const Color(0xFF34D399),
    onPrimary: const Color(0xFF052011),
    onSecondary: AppColors.darkTextPrimary,
    onSurface: AppColors.darkTextPrimary,
    onSurfaceVariant: AppColors.darkTextSecondary,
    outline: AppColors.darkBorder,
    outlineVariant: const Color(0xFF1B273A),
    shadow: Colors.black.withValues(alpha: 0.6),
  );

  static ThemeData _buildTheme(ColorScheme colorScheme) {
    final isDark = colorScheme.brightness == Brightness.dark;
    final base = ThemeData(
      useMaterial3: true,
      colorScheme: colorScheme,
      brightness: colorScheme.brightness,
    );

    final chipTheme = ChipThemeData.fromDefaults(
      brightness: colorScheme.brightness,
      secondaryColor: colorScheme.primary,
      labelStyle: TextStyle(color: colorScheme.onSurface),
    ).copyWith(
      backgroundColor: colorScheme.surfaceContainerHighest.withValues(alpha: isDark ? 0.6 : 0.8),
      selectedColor: colorScheme.primary.withValues(alpha: 0.16),
      secondarySelectedColor: colorScheme.primary.withValues(alpha: 0.16),
      padding: const EdgeInsets.symmetric(horizontal: AppSpacing.s12, vertical: AppSpacing.s8),
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(AppRadii.medium),
        side: BorderSide(color: colorScheme.outline.withValues(alpha: 0.3)),
      ),
    );

    return base.copyWith(
      colorScheme: colorScheme,
      scaffoldBackgroundColor:
          isDark ? AppColors.darkBackground : AppColors.background,
      textTheme: AppTypography.textThemeFor(colorScheme),
      appBarTheme: AppBarTheme(
        backgroundColor: Colors.transparent,
        foregroundColor: colorScheme.onSurface,
        elevation: 0,
        surfaceTintColor: Colors.transparent,
        centerTitle: false,
      ),
      navigationBarTheme: NavigationBarThemeData(
        backgroundColor: Colors.transparent,
        elevation: 0,
        indicatorColor: colorScheme.primary.withValues(alpha: 0.16),
        iconTheme: WidgetStateProperty.resolveWith((states) {
          final isSelected = states.contains(WidgetState.selected);
          return IconThemeData(
            color: isSelected ? colorScheme.primary : colorScheme.onSurfaceVariant,
          );
        }),
        labelTextStyle: WidgetStateProperty.resolveWith((states) {
          final isSelected = states.contains(WidgetState.selected);
          return TextStyle(
            fontWeight: FontWeight.w600,
            color: isSelected ? colorScheme.primary : colorScheme.onSurfaceVariant,
          );
        }),
      ),
      bottomNavigationBarTheme: BottomNavigationBarThemeData(
        backgroundColor: colorScheme.surface,
        selectedItemColor: colorScheme.primary,
        unselectedItemColor: colorScheme.onSurfaceVariant,
        type: BottomNavigationBarType.fixed,
        elevation: 8,
      ),
      chipTheme: chipTheme,
      elevatedButtonTheme: ElevatedButtonThemeData(
        style: ElevatedButton.styleFrom(
          backgroundColor: colorScheme.primary,
          foregroundColor: colorScheme.onPrimary,
          padding: const EdgeInsets.symmetric(
            vertical: 14,
            horizontal: AppSpacing.s16,
          ),
          textStyle: const TextStyle(fontWeight: FontWeight.w600),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(AppRadii.large),
          ),
          elevation: 0,
        ),
      ),
      outlinedButtonTheme: OutlinedButtonThemeData(
        style: OutlinedButton.styleFrom(
          foregroundColor: colorScheme.onSurface,
          side: BorderSide(color: colorScheme.outline),
          padding: const EdgeInsets.symmetric(
            horizontal: AppSpacing.s14,
            vertical: AppSpacing.s10,
          ),
          textStyle: const TextStyle(fontWeight: FontWeight.w600),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(AppRadii.large),
          ),
        ),
      ),
      inputDecorationTheme: InputDecorationTheme(
        filled: true,
        fillColor: colorScheme.surface,
        contentPadding: const EdgeInsets.symmetric(
          horizontal: AppSpacing.s16,
          vertical: AppSpacing.s12,
        ),
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(AppRadii.medium),
          borderSide: BorderSide(color: colorScheme.outlineVariant),
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(AppRadii.medium),
          borderSide: BorderSide(color: colorScheme.outlineVariant),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(AppRadii.medium),
          borderSide: BorderSide(color: colorScheme.primary, width: 1.4),
        ),
        hintStyle: TextStyle(color: colorScheme.onSurfaceVariant),
      ),
      cardTheme: CardThemeData(
        color: colorScheme.surface,
        elevation: isDark ? 0 : 2,
        margin: const EdgeInsets.all(AppSpacing.s8),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(AppRadii.medium),
          side: BorderSide(color: colorScheme.outline.withValues(alpha: 0.1)),
        ),
        surfaceTintColor: colorScheme.surfaceTint,
        shadowColor: colorScheme.shadow,
      ),
      floatingActionButtonTheme: FloatingActionButtonThemeData(
        backgroundColor: colorScheme.primary,
        foregroundColor: colorScheme.onPrimary,
      ),
      dividerColor: colorScheme.outline.withValues(alpha: 0.24),
      switchTheme: SwitchThemeData(
        thumbColor: WidgetStateProperty.resolveWith((states) {
          if (states.contains(WidgetState.selected)) return colorScheme.primary;
          return colorScheme.surfaceTint;
        }),
        trackColor: WidgetStateProperty.resolveWith((states) {
          if (states.contains(WidgetState.selected)) {
            return colorScheme.primary.withValues(alpha: 0.35);
          }
          return colorScheme.outline.withValues(alpha: 0.3);
        }),
      ),
      iconTheme: IconThemeData(color: colorScheme.onSurface),
    );
  }
}
