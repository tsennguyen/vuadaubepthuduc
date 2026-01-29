import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:go_router/go_router.dart';
import '../../../core/services/ai_moderation_service.dart';
import '../data/admin_report_repository.dart';
import 'admin_scaffold.dart';
import 'admin_reports_table.dart';
import 'widgets/admin_page_actions.dart';
import 'widgets/ai_report_summary.dart';

class AdminReportsPage extends StatefulWidget {
  const AdminReportsPage({super.key});

  @override
  State<AdminReportsPage> createState() => _AdminReportsPageState();
}

class _AdminReportsPageState extends State<AdminReportsPage> {
  late final AdminReportRepository _repository;
  late final AiModerationService _aiService;
  ReportStatusFilter _filter = ReportStatusFilter.pending;
  late Stream<List<AdminReport>> _reportsStream;

  final Set<String> _busyIds = <String>{};
  
  // AI analysis state
  ReportAnalysisResult? _aiAnalysis;
  bool _isAnalyzing = false;

  @override
  void initState() {
    super.initState();
    _repository = FirestoreAdminReportRepository();
    _aiService = AiModerationService();
    _reportsStream = _repository.watchReports(_filter);
  }

  void _setFilter(ReportStatusFilter filter) {
    if (filter == _filter) return;
    setState(() {
      _filter = filter;
      _reportsStream = _repository.watchReports(_filter);
    });
  }

  void _retry() {
    setState(() {
      _reportsStream = _repository.watchReports(_filter);
    });
  }

  Future<void> _updateStatus(AdminReport report, String status) async {
    if (_busyIds.contains(report.id)) return;
    if (report.status == status) return;

    setState(() => _busyIds.add(report.id));
    try {
      await _repository.updateReportStatus(report.id, status);
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Cập nhật trạng thái thất bại: $e')),
      );
    } finally {
      if (mounted) {
        setState(() => _busyIds.remove(report.id));
      }
    }
  }

// ignore: unused_element
Future<void> _openReasonText(AdminReport report) async {
    final text = report.reasonText?.trim();
    if (text == null || text.isEmpty) return;

    await showDialog<void>(
      context: context,
      builder: (context) {
        return AlertDialog(
          title: const Text('Chi tiết báo cáo'),
          content: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 560),
            child: SingleChildScrollView(child: Text(text)),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(context).pop(),
              child: const Text('Đóng'),
            ),
          ],
        );
      },
    );
  }

  Future<void> _openTarget(AdminReport report) async {
    await showDialog<void>(
      context: context,
      builder: (context) => _ReportTargetDialog(report: report),
    );
  }

  Future<void> _analyzeReports(List<AdminReport> reports) async {
    if (_isAnalyzing) return;
    if (reports.isEmpty) return;

    setState(() {
      _isAnalyzing = true;
      _aiAnalysis = null;
    });

    try {
      final reportData = reports.map((r) {
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

      final result = await _aiService.analyzeReports(reports: reportData);
      
      if (mounted) {
        setState(() {
          _aiAnalysis = result;
        });
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Lỗi phân tích AI: $e')),
        );
      }
    } finally {
      if (mounted) {
        setState(() {
          _isAnalyzing = false;
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return AdminShell(
      actions: [
        AdminPageActions(
          onRefresh: _retry,
        ),
      ],
      child: Column(
        children: [
          _FilterBar(
            value: _filter,
            onChanged: _setFilter,
            onRetry: _retry,
          ),
          Expanded(
            child: StreamBuilder<List<AdminReport>>(
              stream: _reportsStream,
              builder: (context, snapshot) {
                if (snapshot.hasError) {
                  return _ErrorView(
                    message: '${snapshot.error}',
                    onRetry: _retry,
                  );
                }
                if (!snapshot.hasData) {
                  return const Center(child: CircularProgressIndicator());
                }

                final reports = snapshot.data ?? const <AdminReport>[];
                if (reports.isEmpty) {
                  return const Center(child: Text('Không tìm thấy báo cáo nào.'));
                }


                // Auto-analyze reports on load (for any filter)
                if (!_isAnalyzing && _aiAnalysis == null && reports.isNotEmpty) {
                  // Schedule after build
                  WidgetsBinding.instance.addPostFrameCallback((_) {
                    if (mounted) {
                      _analyzeReports(reports);
                    }
                  });
                }

                return Column(
                  children: [
                    // Reports Table with Integrated AI Header
                    Expanded(
                      child: AdminReportsTable(
                        reports: reports,
                        busyIds: _busyIds,
                        header: reports.length >= 3
                            ? Padding(
                                padding: const EdgeInsets.only(bottom: 4),
                                child: AiReportSummary(
                                  analysis: _aiAnalysis,
                                  isLoading: _isAnalyzing,
                                  onRefresh: () {
                                    if (mounted) {
                                      _analyzeReports(reports);
                                    }
                                  },
                                ),
                              )
                            : null,
                        onAction: (report, action) {
                          switch (action) {
                            case 'view':
                              _openTarget(report);
                              break;
                            case 'resolve':
                              _updateStatus(report, 'resolved');
                              break;
                            case 'ignore':
                              _updateStatus(report, 'ignored');
                              break;
                          }
                        },
                      ),
                    ),
                  ],
                );
              },
            ),
          ),
        ],
      ),
    );
  }
}


class _FilterBar extends StatelessWidget {
  const _FilterBar({
    required this.value,
    required this.onChanged,
    required this.onRetry,
  });

  final ReportStatusFilter value;
  final ValueChanged<ReportStatusFilter> onChanged;
  final VoidCallback onRetry;

  @override
  Widget build(BuildContext context) {
    return Material(
      color: Theme.of(context).colorScheme.surface,
      child: Padding(
        padding: const EdgeInsets.fromLTRB(16, 16, 16, 8),
        child: Row(
          children: [
            const Icon(Icons.filter_list),
            const SizedBox(width: 8),
            const Text('Trạng thái:'),
            const SizedBox(width: 12),
            DropdownButton<ReportStatusFilter>(
              value: value,
              onChanged: (v) => v == null ? null : onChanged(v),
              items: const [
                DropdownMenuItem(
                  value: ReportStatusFilter.all,
                  child: Text('Tất cả'),
                ),
                DropdownMenuItem(
                  value: ReportStatusFilter.pending,
                  child: Text('Chờ xử lý'),
                ),
                DropdownMenuItem(
                  value: ReportStatusFilter.resolved,
                  child: Text('Đã xử lý'),
                ),
                DropdownMenuItem(
                  value: ReportStatusFilter.ignored,
                  child: Text('Đã bỏ qua'),
                ),
              ],
            ),
            const Spacer(),
            IconButton(
              tooltip: 'Làm mới',
              onPressed: onRetry,
              icon: const Icon(Icons.refresh),
            ),
          ],
        ),
      ),
    );
  }
}

class _ErrorView extends StatelessWidget {
  const _ErrorView({required this.message, required this.onRetry});

  final String message;
  final VoidCallback onRetry;

  @override
  Widget build(BuildContext context) {
    return Center(
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 560),
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(
                'Không tải được báo cáo',
                style: Theme.of(context).textTheme.titleMedium,
              ),
              const SizedBox(height: 8),
              Text(message, textAlign: TextAlign.center),
              const SizedBox(height: 12),
              ElevatedButton.icon(
                onPressed: onRetry,
                icon: const Icon(Icons.refresh),
                label: const Text('Thử lại'),
              ),
              const SizedBox(height: 8),
              const Text(
                'Mẹo: Có thể yêu cầu Firestore composite indexes.',
                textAlign: TextAlign.center,
              ),
            ],
          ),
        ),
      ),
    );
  }
}

// ignore: unused_element
typedef _ReportAction = void Function(AdminReport report);

// ignore: unused_element
class _StatusChip extends StatelessWidget {
  const _StatusChip({required this.status});

  final String status;

  @override
  Widget build(BuildContext context) {
    final normalized = status.trim().toLowerCase();
    final (label, color) = switch (normalized) {
      'pending' => ('Chờ xử lý', Theme.of(context).colorScheme.tertiaryContainer),
      'resolved' => ('Đã xử lý', Theme.of(context).colorScheme.primaryContainer),
      'ignored' => ('Đã bỏ qua', Theme.of(context).colorScheme.surfaceContainerHighest),
      _ => (status, Theme.of(context).colorScheme.surfaceContainerHighest),
    };

    return Chip(
      label: Text(label),
      backgroundColor: color,
      visualDensity: VisualDensity.compact,
    );
  }
}

class _ReportTargetDialog extends StatelessWidget {
  const _ReportTargetDialog({required this.report});

  final AdminReport report;

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: const Text('Đối tượng'),
      content: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 720),
        child: _TargetContent(report: report),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.of(context).pop(),
          child: const Text('Đóng'),
        ),
      ],
    );
  }
}

class _TargetContent extends StatelessWidget {
  const _TargetContent({required this.report});

  final AdminReport report;

  @override
  Widget build(BuildContext context) {
    final type = report.targetType;

    if (type == 'post') {
      return _DocPreview(
        title: '[Post] ${report.targetId}',
        docFuture: FirebaseFirestore.instance
            .collection('posts')
            .doc(report.targetId)
            .get(),
        openManagerLocation: '/admin/content',
      );
    }

    if (type == 'recipe') {
      return _DocPreview(
        title: '[Recipe] ${report.targetId}',
        docFuture: FirebaseFirestore.instance
            .collection('recipes')
            .doc(report.targetId)
            .get(),
        openManagerLocation: '/admin/content',
      );
    }

    if (type == 'reel') {
      return _DocPreview(
        title: '[Reel] ${report.targetId}',
        docFuture: FirebaseFirestore.instance
            .collection('reels')
            .doc(report.targetId)
            .get(),
        openManagerLocation: '/admin/content',
      );
    }

    if (type == 'user') {
      return _DocPreview(
        title: '[User] ${report.targetId}',
        docFuture:
            FirebaseFirestore.instance.collection('users').doc(report.targetId).get(),
        openManagerLocation: '/admin/users',
      );
    }

    if (type == 'message') {
      final chatId = report.chatId;
      if (chatId == null || chatId.isEmpty) {
        return _UnknownTarget(report: report);
      }

      return _DocPreview(
        title: '[Msg] $chatId/${report.targetId}',
        docFuture: FirebaseFirestore.instance
            .collection('chats')
            .doc(chatId)
            .collection('messages')
            .doc(report.targetId)
            .get(),
      );
    }

    return _UnknownTarget(report: report);
  }
}

class _DocPreview extends StatelessWidget {
  const _DocPreview({
    required this.title,
    required this.docFuture,
    this.openManagerLocation,
  });

  final String title;
  final Future<DocumentSnapshot<Map<String, dynamic>>> docFuture;
  final String? openManagerLocation;

  @override
  Widget build(BuildContext context) {
    return FutureBuilder<DocumentSnapshot<Map<String, dynamic>>>(
      future: docFuture,
      builder: (context, snapshot) {
        if (snapshot.hasError) {
          return Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(title, style: Theme.of(context).textTheme.titleMedium),
              const SizedBox(height: 8),
              Text('Tải thất bại: ${snapshot.error}'),
              const SizedBox(height: 12),
              _CopyRow(text: title),
              if (openManagerLocation != null) ...[
                const SizedBox(height: 12),
                FilledButton.tonalIcon(
                  onPressed: () => _openManager(context),
                  icon: const Icon(Icons.open_in_new),
                  label: const Text('Mở quản lý'),
                ),
              ],
            ],
          );
        }

        if (!snapshot.hasData) {
          return const Padding(
            padding: EdgeInsets.all(12),
            child: Center(child: CircularProgressIndicator()),
          );
        }

        final doc = snapshot.data!;
        final data = doc.data();

        if (!doc.exists || data == null) {
          return Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(title, style: Theme.of(context).textTheme.titleMedium),
              const SizedBox(height: 8),
              const Text('Không tìm thấy tài liệu (có thể đã bị xóa).'),
              const SizedBox(height: 12),
              _CopyRow(text: title),
              if (openManagerLocation != null) ...[
                const SizedBox(height: 12),
                FilledButton.tonalIcon(
                  onPressed: () => _openManager(context),
                  icon: const Icon(Icons.open_in_new),
                  label: const Text('Mở quản lý'),
                ),
              ],
            ],
          );
        }

        final preview = _buildPreview(data);
        return Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(title, style: Theme.of(context).textTheme.titleMedium),
            const SizedBox(height: 8),
            ...preview,
            const SizedBox(height: 12),
            _CopyRow(text: doc.reference.path),
            if (openManagerLocation != null) ...[
              const SizedBox(height: 12),
              FilledButton.tonalIcon(
                onPressed: () => _openManager(context),
                icon: const Icon(Icons.open_in_new),
                label: const Text('Mở quản lý'),
              ),
            ],
          ],
        );
      },
    );
  }

  void _openManager(BuildContext context) {
    final location = openManagerLocation;
    if (location == null) return;
    Navigator.of(context).pop();
    context.go(location);
  }

  List<Widget> _buildPreview(Map<String, dynamic> data) {
    final title = (data['title'] as String?)?.trim();
    final authorId = (data['authorId'] as String?)?.trim();
    final status = data['status'] as String?;
    final text = (data['text'] as String?)?.trim();
    final body = (data['body'] as String?)?.trim() ??
        (data['description'] as String?)?.trim() ??
        (data['content'] as String?)?.trim();

    final widgets = <Widget>[];
    if (title != null && title.isNotEmpty) widgets.add(Text('Tiêu đề: $title'));
    if (authorId != null && authorId.isNotEmpty) {
      widgets.add(Text('AuthorId: $authorId'));
    }
    if (status != null && status.trim().isNotEmpty) {
      widgets.add(Text('Trạng thái: ${status.trim()}'));
    }
    if (text != null && text.isNotEmpty) widgets.add(Text('Nội dung: $text'));
    if (body != null && body.isNotEmpty) {
      widgets.add(
        Text(
          'Nội dung: ${body.length > 300 ? '${body.substring(0, 300)}…' : body}',
        ),
      );
    }
    if (widgets.isEmpty) {
      widgets.add(const Text('Không có nội dung để xem trước.'));
    }
    return widgets;
  }
}

class _UnknownTarget extends StatelessWidget {
  const _UnknownTarget({required this.report});

  final AdminReport report;

  @override
  Widget build(BuildContext context) {
    return Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'Loại đối tượng không hỗ trợ: ${report.targetType}',
          style: Theme.of(context).textTheme.titleMedium,
        ),
        const SizedBox(height: 8),
        Text('targetId: ${report.targetId}'),
        if (report.chatId?.isNotEmpty == true) Text('chatId: ${report.chatId}'),
        const SizedBox(height: 12),
        _CopyRow(text: _formatTarget(report)),
      ],
    );
  }
}

class _CopyRow extends StatelessWidget {
  const _CopyRow({required this.text});

  final String text;

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Expanded(
          child: Text(
            text,
            overflow: TextOverflow.ellipsis,
          ),
        ),
        IconButton(
          tooltip: 'Sao chép',
          onPressed: () => Clipboard.setData(ClipboardData(text: text)),
          icon: const Icon(Icons.copy),
        ),
      ],
    );
  }
}

String _formatTarget(AdminReport report) {
  final type = report.targetType;
  if (type == 'post') return '[Post] ${report.targetId}';
  if (type == 'recipe') return '[Recipe] ${report.targetId}';
  if (type == 'user') return '[User] ${report.targetId}';
  if (type == 'message') {
    final chatId = report.chatId?.trim();
    if (chatId != null && chatId.isNotEmpty) {
      return '[Msg] $chatId/${report.targetId}';
    }
    return '[Msg] ${report.targetId}';
  }
  return '[${report.targetType}] ${report.targetId}';
}

// ignore: unused_element
String _reasonLabel(String reasonCode) {
  switch (reasonCode.trim().toLowerCase()) {
    case 'spam':
      return 'Spam';
    case 'inappropriate':
      return 'Không phù hợp';
    case 'violence':
      return 'Bạo lực';
    case 'fake_info':
      return 'Thông tin sai lệch';
    case 'hate':
      return 'Thù ghét';
    case 'other':
      return 'Khác';
    default:
      return reasonCode.isEmpty ? '—' : reasonCode;
  }
}

// ignore: unused_element
String _formatDate(DateTime dateTime) {
  String two(int n) => n.toString().padLeft(2, '0');
  return '${two(dateTime.day)}/${two(dateTime.month)}/${dateTime.year} '
      '${two(dateTime.hour)}:${two(dateTime.minute)}';
}
