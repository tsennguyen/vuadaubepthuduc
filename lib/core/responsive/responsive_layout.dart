import 'package:flutter/material.dart';

/// Simple breakpoint-based layout helper.
///
/// - width < 600 : [mobile]
/// - 600–1200    : [tablet] if provided, else [mobile]
/// - > 1200      : [desktop] if provided, else [tablet]/[mobile]
class ResponsiveLayout extends StatelessWidget {
  const ResponsiveLayout({
    super.key,
    required this.mobile,
    this.tablet,
    this.desktop,
  });

  final Widget mobile;
  final Widget? tablet;
  final Widget? desktop;

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) {
        final width = constraints.maxWidth;
        if (width >= 1200) return desktop ?? tablet ?? mobile;
        if (width >= 600) return tablet ?? mobile;
        return mobile;
      },
    );
  }
}
