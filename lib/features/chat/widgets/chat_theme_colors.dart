import 'package:flutter/material.dart';

/// Chat theme color definitions
class ChatThemeColors {
  final Color primaryStart;
  final Color primaryEnd;
  final String name;

  const ChatThemeColors({
    required this.primaryStart,
    required this.primaryEnd,
    required this.name,
  });

  static const defaultTheme = ChatThemeColors(
    primaryStart: Color(0xFF2196F3),
    primaryEnd: Color(0xFF1976D2),
    name: 'default',
  );

  static const mint = ChatThemeColors(
    primaryStart: Color(0xFF4CAF50),
    primaryEnd: Color(0xFF388E3C),
    name: 'mint',
  );

  static const sunset = ChatThemeColors(
    primaryStart: Color(0xFFFF9800),
    primaryEnd: Color(0xFFF57C00),
    name: 'sunset',
  );

  static const ocean = ChatThemeColors(
    primaryStart: Color(0xFF03A9F4),
    primaryEnd: Color(0xFF0288D1),
    name: 'ocean',
  );

  static const rose = ChatThemeColors(
    primaryStart: Color(0xFFE91E63),
    primaryEnd: Color(0xFFC2185B),
    name: 'rose',
  );

  static ChatThemeColors fromString(String? theme) {
    switch (theme?.toLowerCase()) {
      case 'mint':
        return mint;
      case 'sunset':
        return sunset;
      case 'ocean':
        return ocean;
      case 'rose':
        return rose;
      default:
        return defaultTheme;
    }
  }

  LinearGradient get gradient => LinearGradient(
        begin: Alignment.topLeft,
        end: Alignment.bottomRight,
        colors: [
          primaryStart.withValues(alpha: 0.9),
          primaryEnd.withValues(alpha: 0.85),
        ],
      );
}
