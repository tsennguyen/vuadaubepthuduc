import 'package:flutter/material.dart';
import 'dart:ui';

/// Modern animated card with glassmorphism effect for 2025 UI
class GlassCard extends StatelessWidget {
  const GlassCard({
    super.key,
    required this.child,
    this.padding,
    this.margin,
    this.borderRadius,
    this.elevation = 2,
  });

  final Widget child;
  final EdgeInsetsGeometry? padding;
  final EdgeInsetsGeometry? margin;
  final BorderRadius? borderRadius;
  final double elevation;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final radius = borderRadius ?? BorderRadius.circular(16);

    return Container(
      margin: margin,
      decoration: BoxDecoration(
        borderRadius: radius,
        boxShadow: [
          BoxShadow(
            color: theme.colorScheme.primary.withValues(alpha: 0.05),
            blurRadius: 12 + (elevation * 4),
            offset: Offset(0, 4 + (elevation * 2)),
          ),
        ],
      ),
      child: ClipRRect(
        borderRadius: radius,
        child: BackdropFilter(
          filter: ImageFilter.blur(sigmaX: 10, sigmaY: 10),
          child: Container(
            padding: padding,
            decoration: BoxDecoration(
              gradient: LinearGradient(
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
                colors: [
                  theme.colorScheme.surface.withValues(alpha: 0.9),
                  theme.colorScheme.surfaceContainerHighest
                      .withValues(alpha: 0.85),
                ],
              ),
              borderRadius: radius,
              border: Border.all(
                color: theme.colorScheme.outline.withValues(alpha: 0.1),
                width: 1,
              ),
            ),
            child: child,
          ),
        ),
      ),
    );
  }
}

/// Shimmer loading effect for modern skeleton screens
class ShimmerLoading extends StatefulWidget {
  const ShimmerLoading({
    super.key,
    required this.child,
    this.isLoading = true,
    this.baseColor,
    this.highlightColor,
  });

  final Widget child;
  final bool isLoading;
  final Color? baseColor;
  final Color? highlightColor;

  @override
  State<ShimmerLoading> createState() => _ShimmerLoadingState();
}

class _ShimmerLoadingState extends State<ShimmerLoading>
    with SingleTickerProviderStateMixin {
  late AnimationController _controller;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1500),
    )..repeat();
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    if (!widget.isLoading) {
      return widget.child;
    }

    final theme = Theme.of(context);
    final baseColor = widget.baseColor ??
        theme.colorScheme.surfaceContainerHighest.withValues(alpha: 0.3);
    final highlightColor = widget.highlightColor ??
        theme.colorScheme.surface.withValues(alpha: 0.5);

    return AnimatedBuilder(
      animation: _controller,
      builder: (context, child) {
        return ShaderMask(
          blendMode: BlendMode.srcATop,
          shaderCallback: (bounds) {
            return LinearGradient(
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
              colors: [
                baseColor,
                highlightColor,
                baseColor,
              ],
              stops: [
                _controller.value - 0.3,
                _controller.value,
                _controller.value + 0.3,
              ],
            ).createShader(bounds);
          },
          child: widget.child,
        );
      },
    );
  }
}

/// Modern animated button with haptic feedback
class ModernButton extends StatefulWidget {
  const ModernButton({
    super.key,
    required this.onPressed,
    required this.child,
    this.style = ModernButtonStyle.primary,
    this.fullWidth = false,
    this.icon,
    this.padding,
  });

  final VoidCallback? onPressed;
  final Widget child;
  final ModernButtonStyle style;
  final bool fullWidth;
  final IconData? icon;
  final EdgeInsetsGeometry? padding;

  @override
  State<ModernButton> createState() => _ModernButtonState();
}

class _ModernButtonState extends State<ModernButton>
    with SingleTickerProviderStateMixin {
  late AnimationController _controller;
  bool _isPressed = false;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 150),
    );
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isEnabled = widget.onPressed != null;
    final isDark = theme.brightness == Brightness.dark;
    
    // Màu text trầm hơn cho dark mode
    final textColor = isDark
        ? theme.colorScheme.onSurface.withValues(alpha: 0.85)
        : Colors.white;

    return GestureDetector(
      onTapDown: isEnabled
          ? (_) {
              setState(() => _isPressed = true);
              _controller.forward();
            }
          : null,
      onTapUp: isEnabled
          ? (_) {
              setState(() => _isPressed = false);
              _controller.reverse();
              widget.onPressed?.call();
            }
          : null,
      onTapCancel: isEnabled
          ? () {
              setState(() => _isPressed = false);
              _controller.reverse();
            }
          : null,
      child: AnimatedBuilder(
        animation: _controller,
        builder: (context, child) {
          final scale = 1.0 - (_controller.value * 0.05);
          return Transform.scale(
            scale: scale,
            child: Opacity(
              opacity: isEnabled ? 1.0 : 0.5,
              child: Container(
                width: widget.fullWidth ? double.infinity : null,
                padding: widget.padding ??
                    const EdgeInsets.symmetric(horizontal: 24, vertical: 14),
                decoration: BoxDecoration(
                  gradient: _getGradient(theme),
                  borderRadius: BorderRadius.circular(12),
                  boxShadow: isEnabled
                      ? [
                          BoxShadow(
                            color: _getShadowColor(theme),
                            blurRadius: _isPressed ? 8 : 16,
                            offset: Offset(0, _isPressed ? 2 : 6),
                          ),
                        ]
                      : null,
                ),
                child: Row(
                  mainAxisSize:
                      widget.fullWidth ? MainAxisSize.max : MainAxisSize.min,
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    if (widget.icon != null) ...[
                      Icon(widget.icon, color: textColor, size: 20),
                      const SizedBox(width: 8),
                    ],
                    DefaultTextStyle(
                      style: theme.textTheme.titleMedium!.copyWith(
                        color: textColor,
                        fontWeight: FontWeight.w600,
                      ),
                      child: widget.child,
                    ),
                  ],
                ),
              ),
            ),
          );
        },
      ),
    );
  }

  LinearGradient _getGradient(ThemeData theme) {
    final isDark = theme.brightness == Brightness.dark;
    
    switch (widget.style) {
      case ModernButtonStyle.primary:
        return LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: isDark
              ? [
                  theme.colorScheme.primary.withValues(alpha: 0.4),
                  theme.colorScheme.secondary.withValues(alpha: 0.4),
                ]
              : [
                  theme.colorScheme.primary,
                  theme.colorScheme.secondary,
                ],
        );
      case ModernButtonStyle.secondary:
        return LinearGradient(
          colors: isDark
              ? [
                  theme.colorScheme.secondary.withValues(alpha: 0.3),
                  theme.colorScheme.tertiary.withValues(alpha: 0.3),
                ]
              : [
                  theme.colorScheme.secondary.withValues(alpha: 0.8),
                  theme.colorScheme.tertiary.withValues(alpha: 0.8),
                ],
        );
      case ModernButtonStyle.outlined:
        return const LinearGradient(
          colors: [
            Colors.transparent,
            Colors.transparent,
          ],
        );
    }
  }

  Color _getShadowColor(ThemeData theme) {
    switch (widget.style) {
      case ModernButtonStyle.primary:
        return theme.colorScheme.primary.withValues(alpha: 0.3);
      case ModernButtonStyle.secondary:
        return theme.colorScheme.secondary.withValues(alpha: 0.3);
      case ModernButtonStyle.outlined:
        return Colors.black.withValues(alpha: 0.1);
    }
  }
}

enum ModernButtonStyle {
  primary,
  secondary,
  outlined,
}

/// Avatar with gradient border
class GradientAvatar extends StatelessWidget {
  const GradientAvatar({
    super.key,
    this.imageUrl,
    this.radius = 20,
    this.borderWidth = 2,
    this.child,
  });

  final String? imageUrl;
  final double radius;
  final double borderWidth;
  final Widget? child;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Container(
      width: radius * 2,
      height: radius * 2,
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [
            theme.colorScheme.primary,
            theme.colorScheme.secondary,
          ],
        ),
      ),
      padding: EdgeInsets.all(borderWidth),
      child: Container(
        decoration: BoxDecoration(
          shape: BoxShape.circle,
          color: theme.colorScheme.surface,
        ),
        child: CircleAvatar(
          radius: radius - borderWidth,
          backgroundImage:
              imageUrl != null && imageUrl!.isNotEmpty ? NetworkImage(imageUrl!) : null,
          child: child,
        ),
      ),
    );
  }
}
