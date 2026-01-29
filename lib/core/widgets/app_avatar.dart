import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';

class AppAvatar extends StatelessWidget {
  const AppAvatar({
    super.key,
    required this.url,
    this.size = 40,
    this.heroTag,
    this.onTap,
    this.fallbackText,
  });

  final String url;
  final double size;
  final String? heroTag;
  final VoidCallback? onTap;
  final String? fallbackText;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    
    Widget avatar = Container(
      width: size,
      height: size,
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        color: theme.colorScheme.surface,
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.1),
            blurRadius: size * 0.2,
            offset: Offset(0, size * 0.05),
          ),
        ],
      ),
      padding: EdgeInsets.all(size * 0.04), // Clean white gap
      child: Container(
        decoration: BoxDecoration(
          shape: BoxShape.circle,
          color: theme.colorScheme.surface,
        ),
        clipBehavior: Clip.antiAlias,
        child: url.isNotEmpty
            ? CachedNetworkImage(
                imageUrl: url,
                width: size,
                height: size,
                fit: BoxFit.cover,
                placeholder: (context, url) => Container(
                  color: theme.colorScheme.surfaceContainerHighest,
                ),
                errorWidget: (ctx, error, stackTrace) => _buildFallback(theme),
              )
            : _buildFallback(theme),
      ),
    );

    if (heroTag != null && heroTag!.isNotEmpty) {
      avatar = Hero(
        tag: heroTag!,
        flightShuttleBuilder: (
          context,
          animation,
          direction,
          fromContext,
          toContext,
        ) {
          return ScaleTransition(
            scale: Tween<double>(begin: 0.96, end: 1).animate(
              CurvedAnimation(parent: animation, curve: Curves.easeOutCubic),
            ),
            child: toContext.widget,
          );
        },
        child: avatar,
      );
    }

    if (onTap != null) {
      avatar = Material(
        type: MaterialType.transparency,
        child: InkWell(
          customBorder: const CircleBorder(),
          onTap: onTap,
          child: avatar,
        ),
      );
    }

    return avatar;
  }

  Widget _buildFallback(ThemeData theme) {
    return Container(
      color: theme.colorScheme.primaryContainer.withValues(alpha: 0.3),
      child: Center(
        child: fallbackText != null && fallbackText!.isNotEmpty
            ? Text(
                fallbackText!.toUpperCase(),
                style: TextStyle(
                  fontSize: size * 0.36,
                  fontWeight: FontWeight.w700,
                  color: theme.colorScheme.primary,
                ),
              )
            : Icon(
                Icons.person,
                size: size * 0.6,
                color: theme.colorScheme.primary,
              ),
      ),
    );
  }
}
