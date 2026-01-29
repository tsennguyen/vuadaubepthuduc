import 'package:flutter/material.dart';
import '../../app/l10n.dart';

class TimeUtils {
  /// Formats minutes into a human-readable duration string.
  /// Example: 180 -> "3h", 90 -> "1h 30m", 2880 -> "2 ngày"
  static String formatDuration(int? minutes, BuildContext context) {
    if (minutes == null || minutes <= 0) return '--';
    
    final s = S.of(context);
    final isVi = s.isVi;

    if (minutes < 60) {
      return '$minutes ${s.minutes}';
    }

    final int daysCount = minutes ~/ 1440;
    final int remainingAfterDays = minutes % 1440;
    final int hoursCount = remainingAfterDays ~/ 60;
    final int remainingMinutes = remainingAfterDays % 60;

    String result = '';

    if (daysCount > 0) {
      result += '$daysCount ${s.days} ';
    }

    if (hoursCount > 0) {
      result += '$hoursCount ${s.hours} ';
    }

    if (remainingMinutes > 0 && daysCount == 0) { // Only show minutes if less than a day
      result += '$remainingMinutes ${s.minutes}';
    }

    return result.trim();
  }

  /// Formats a DateTime into a relative time string (e.g., "5 minutes ago")
  static String formatTimeAgo(DateTime? dateTime, BuildContext context, {bool compact = false}) {
    if (dateTime == null) return '';
    
    final s = S.of(context);
    final diff = DateTime.now().difference(dateTime);

    if (diff.inSeconds < 60) {
      return compact ? (s.isVi ? 'vừa xong' : 'now') : s.justNow;
    } else if (diff.inMinutes < 60) {
      if (compact) {
        return '${diff.inMinutes}${s.isVi ? 'phút' : 'm'}';
      }
      return '${diff.inMinutes} ${s.minutesAgo}';
    } else if (diff.inHours < 24) {
      if (compact) {
        return '${diff.inHours}${s.isVi ? 'giờ' : 'h'}';
      }
      return '${diff.inHours} ${s.hoursAgo}';
    } else if (diff.inDays < 7) {
      if (compact) {
        return '${diff.inDays}${s.isVi ? 'ngày' : 'd'}';
      }
      return '${diff.inDays} ${s.daysAgo}';
    } else {
      // For older dates, show day/month/year
      return '${dateTime.day}/${dateTime.month}/${dateTime.year}';
    }
  }
}
