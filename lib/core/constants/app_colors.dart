import 'package:flutter/material.dart';

/// Centralized color palette for the app.
class AppColors {
  /// Forest Green (Muted & Rich)
  static const Color primary = Color(0xFF2D6A4F);

  /// Sage Green (Muted accent)
  static const Color secondary = Color(0xFF52796F);



  /// Light background used for scaffolds.
  static const Color background = Color(0xFFF8F9FA);

  /// Card and surface backgrounds.
  static const Color surface = Color(0xFFFFFFFF);

  /// Main body text.
  static const Color textPrimary = Color(0xFF1F2933);

  /// Secondary/supporting text.
  static const Color textSecondary = Color(0xFF52606D);

  /// Alias kept for compatibility with existing usage.
  static const Color text = textPrimary;

  /// Neutral border and divider tones.
  static const Color border = Color(0xFFE5E7EB);

  // ---- Dark palette ----

  /// Deep navy background for dark mode.
  static const Color darkBackground = Color(0xFF0B1220);

  /// Base surface for cards and sheets in dark mode.
  static const Color darkSurface = Color(0xFF111927);

  /// Elevated surface for cards with subtle depth.
  static const Color darkSurfaceHigh = Color(0xFF162235);

  /// Primary text on dark surfaces.
  static const Color darkTextPrimary = Color(0xFFE5ECF5);

  /// Muted/supporting text on dark surfaces.
  static const Color darkTextSecondary = Color(0xFF9FB1C6);

  /// Borders/dividers in dark mode.
  static const Color darkBorder = Color(0xFF243047);
}
