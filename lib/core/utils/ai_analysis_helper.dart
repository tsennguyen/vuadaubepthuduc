import '../../features/admin/data/admin_chat_moderation_repository.dart';
import '../../features/admin/data/admin_report_repository.dart';
import '../services/ai_moderation_service.dart';

/// Helper to convert ChatViolation to ReportData for AI analysis
class ChatViolationAnalysisHelper {
  static List<ReportData> convertViolationsToReports(
    List<ChatViolationRecord> violations,
  ) {
    return violations.map((record) {
      final v = record.violation;
      final reason = _formatCategories(v.violationCategories);
      final note = 'Severity: ${v.severity}';

      return ReportData(
        id: v.id,
        targetType: 'chat_message',
        targetId: v.messageId,
        reason: reason.isNotEmpty ? reason : 'Unknown violation',
        note: note,
        reporterId: 'ai_system',
        createdAt: v.createdAt,
      );
    }).toList();
  }

  static String _formatCategories(List<String> categories) {
    if (categories.isEmpty) return '';
    return categories.join(', ');
  }

  /// Convert AdminReport to ReportData for AI analysis
  static List<ReportData> convertReportsToData(List<AdminReport> reports) {
    return reports.map((r) {
      final reasonText = r.reasonText?.trim();
      final reason =
          (reasonText != null && reasonText.isNotEmpty) ? reasonText : r.reasonCode;
      final note = (reasonText == null || reasonText.isEmpty) ? null : r.reasonCode;

      return ReportData(
        id: r.id,
        targetType: r.targetType,
        targetId: r.targetId,
        reason: reason,
        note: note,
        reporterId: r.reporterId,
        createdAt: r.createdAt,
      );
    }).toList();
  }
}
