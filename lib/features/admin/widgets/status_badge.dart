import 'package:flutter/material.dart';

/// Compact badge for roles, statuses, and flags across the admin panel.
class StatusBadge extends StatelessWidget {
  const StatusBadge({
    super.key,
    required this.label,
    required this.variant,
  });

  final String label;
  final StatusVariant variant;

  @override
  Widget build(BuildContext context) {
    final colors = _colorsFor(variant, Theme.of(context).colorScheme);
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 7),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [
            colors.background,
            colors.background.withValues(alpha: 0.6),
          ],
        ),
        borderRadius: BorderRadius.circular(999),
        border: Border.all(color: colors.border, width: 1.5),
        boxShadow: [
          BoxShadow(
            color: colors.border.withValues(alpha: 0.2),
            blurRadius: 4,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Text(
        label,
        style: TextStyle(
          color: colors.text,
          fontWeight: FontWeight.w700,
          fontSize: 12,
          letterSpacing: 0.3,
        ),
      ),
    );
  }

  _StatusColors _colorsFor(StatusVariant variant, ColorScheme scheme) {
    switch (variant) {
      case StatusVariant.roleAdmin:
        return _StatusColors(
          background: Colors.red.withValues(alpha: 0.12),
          border: Colors.red.withValues(alpha: 0.32),
          text: Colors.red.shade700,
        );
      case StatusVariant.roleModerator:
        return _StatusColors(
          background: Colors.blue.withValues(alpha: 0.12),
          border: Colors.blue.withValues(alpha: 0.32),
          text: Colors.blue.shade700,
        );
      case StatusVariant.roleClient:
        return _StatusColors(
          background: Colors.grey.withValues(alpha: 0.14),
          border: Colors.grey.withValues(alpha: 0.28),
          text: Colors.grey.shade800,
        );
      case StatusVariant.disabled:
        return _StatusColors(
          background: Colors.red.withValues(alpha: 0.1),
          border: Colors.red.withValues(alpha: 0.25),
          text: Colors.red.shade800,
        );
      case StatusVariant.visible:
        return _StatusColors(
          background: Colors.green.withValues(alpha: 0.12),
          border: Colors.green.withValues(alpha: 0.28),
          text: Colors.green.shade800,
        );
      case StatusVariant.hidden:
        return _StatusColors(
          background: Colors.grey.withValues(alpha: 0.14),
          border: Colors.grey.withValues(alpha: 0.28),
          text: Colors.grey.shade800,
        );
      case StatusVariant.reported:
        return _StatusColors(
          background: Colors.orange.withValues(alpha: 0.14),
          border: Colors.orange.withValues(alpha: 0.34),
          text: Colors.orange.shade800,
        );
      case StatusVariant.pending:
        return _StatusColors(
          background: Colors.deepOrange.withValues(alpha: 0.14),
          border: Colors.deepOrange.withValues(alpha: 0.34),
          text: Colors.deepOrange.shade800,
        );
      case StatusVariant.resolved:
        return _StatusColors(
          background: Colors.teal.withValues(alpha: 0.12),
          border: Colors.teal.withValues(alpha: 0.28),
          text: Colors.teal.shade800,
        );
      case StatusVariant.ignored:
        return _StatusColors(
          background: Colors.grey.withValues(alpha: 0.12),
          border: Colors.grey.withValues(alpha: 0.28),
          text: Colors.grey.shade700,
        );
    }
  }
}

enum StatusVariant {
  roleAdmin,
  roleModerator,
  roleClient,
  disabled,
  visible,
  hidden,
  reported,
  pending,
  resolved,
  ignored,
}

class _StatusColors {
  _StatusColors({
    required this.background,
    required this.border,
    required this.text,
  });
  final Color background;
  final Color border;
  final Color text;
}
