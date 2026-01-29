import 'package:cloud_functions/cloud_functions.dart';

/// Service for AI-powered report moderation
class AiModerationService {
  AiModerationService({FirebaseFunctions? functions})
      : _functions = functions ??
            FirebaseFunctions.instanceFor(region: 'asia-southeast1');

  final FirebaseFunctions _functions;

  HttpsCallable get _analyzeReports =>
      _functions.httpsCallable('aiAnalyzeReports');

  /// Analyze multiple reports and get AI summary with priority classification
  Future<ReportAnalysisResult> analyzeReports({
    required List<ReportData> reports,
  }) async {
    try {
      final reportsJson = reports
          .map((r) => {
                'id': r.id,
                'targetType': r.targetType,
                'targetId': r.targetId,
                'reason': r.reason,
                if (r.note != null && r.note!.isNotEmpty) 'note': r.note,
                'reporterId': r.reporterId,
                'createdAt': r.createdAt.toIso8601String(),
              })
          .toList();

      final result = await _analyzeReports.call<Map<String, dynamic>>({
        'reports': reportsJson,
      });

      final data = (result.data as Map<String, dynamic>?) ?? {};
      return ReportAnalysisResult.fromJson(data);
    } on FirebaseFunctionsException catch (e) {
      // Handle permission denied specifically
      if (e.code == 'permission-denied' || e.code == 'unauthenticated') {
        throw Exception(
          'Bạn không có quyền sử dụng tính năng này. '
          'Vui lòng đăng xuất và đăng nhập lại với tài khoản admin.'
        );
      }
      // General Firebase Functions error
      throw Exception('Lỗi phân tích AI: ${e.message ?? e.code}');
    } catch (e) {
      throw Exception('Không thể phân tích báo cáo: $e');
    }
  }
}

/// Data class for report input
class ReportData {
  const ReportData({
    required this.id,
    required this.targetType,
    required this.targetId,
    required this.reason,
    required this.reporterId,
    required this.createdAt,
    this.note,
  });

  final String id;
  final String targetType;
  final String targetId;
  final String reason;
  final String? note;
  final String reporterId;
  final DateTime createdAt;
}

/// Result from AI report analysis
class ReportAnalysisResult {
  const ReportAnalysisResult({
    required this.summary,
    required this.priorityCounts,
    required this.topReports,
  });

  final String summary;
  final PriorityCounts priorityCounts;
  final List<TopReport> topReports;

  factory ReportAnalysisResult.fromJson(Map<String, dynamic> json) {
    return ReportAnalysisResult(
      summary: json['summary'] as String? ?? 'Không có tóm tắt',
      priorityCounts: PriorityCounts.fromJson(
        (json['priorityCounts'] as Map<String, dynamic>?) ?? {},
      ),
      topReports: ((json['topReports'] as List<dynamic>?) ?? [])
          .whereType<Map<String, dynamic>>()
          .map((e) => TopReport.fromJson(e))
          .toList(),
    );
  }
}

/// Priority counts breakdown
class PriorityCounts {
  const PriorityCounts({
    required this.urgent,
    required this.high,
    required this.medium,
    required this.low,
  });

  final int urgent;
  final int high;
  final int medium;
  final int low;

  int get total => urgent + high + medium + low;

  factory PriorityCounts.fromJson(Map<String, dynamic> json) {
    return PriorityCounts(
      urgent: (json['urgent'] as num?)?.toInt() ?? 0,
      high: (json['high'] as num?)?.toInt() ?? 0,
      medium: (json['medium'] as num?)?.toInt() ?? 0,
      low: (json['low'] as num?)?.toInt() ?? 0,
    );
  }
}

/// Top severe report
class TopReport {
  const TopReport({
    required this.reportId,
    required this.severity,
    required this.reason,
  });

  final String reportId;
  final String severity;
  final String reason;

  factory TopReport.fromJson(Map<String, dynamic> json) {
    return TopReport(
      reportId: json['reportId'] as String? ?? '',
      severity: json['severity'] as String? ?? 'unknown',
      reason: json['reason'] as String? ?? '',
    );
  }
}
