import 'package:flutter/material.dart';

import '../data/admin_report_repository.dart';
import '../data/user_name_resolver.dart';
import '../widgets/status_badge.dart';

class AdminReportsTable extends StatefulWidget {
  const AdminReportsTable({
    super.key,
    required this.reports,
    required this.busyIds,
    required this.onAction,
    this.header,
  });

  final List<AdminReport> reports;
  final Set<String> busyIds;
  final void Function(AdminReport report, String action) onAction;
  final Widget? header;

  @override
  State<AdminReportsTable> createState() => _AdminReportsTableState();
}

class _AdminReportsTableState extends State<AdminReportsTable> {
  final _resolver = UserNameResolver();
  final Map<String, String> _reporterNames = {};

  @override
  void initState() {
    super.initState();
    _loadReporterNames();
  }

  @override
  void didUpdateWidget(AdminReportsTable oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.reports != widget.reports) {
      _loadReporterNames();
    }
  }

  Future<void> _loadReporterNames() async {
    final reporterIds =
        widget.reports.map((r) => r.reporterId).toSet().toList();
    final names = await _resolver.getUserNames(reporterIds);
    if (mounted) {
      setState(() {
        _reporterNames.clear();
        _reporterNames.addAll(names);
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) {
        if (constraints.maxWidth < 800) {
          return _buildMobileView();
        }
        return _buildDesktopView(context);
      },
    );
  }

  Widget _buildMobileView() {
    if (widget.reports.isEmpty) {
      return const Center(child: Text('Không tìm thấy báo cáo'));
    }
    final headerCount = widget.header != null ? 1 : 0;
    
    return ListView.separated(
      padding: const EdgeInsets.all(12),
      itemCount: widget.reports.length + headerCount,
      separatorBuilder: (context, index) => const SizedBox(height: 12),
      itemBuilder: (context, index) {
        if (widget.header != null && index == 0) {
          return widget.header!;
        }
        
        final reportIndex = index - headerCount;
        final r = widget.reports[reportIndex];
        final busy = widget.busyIds.contains(r.id);
        final reporterName = _reporterNames[r.reporterId] ?? 'Đang tải...';

        return Card(
          elevation: 2,
          shape:
              RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
          child: Padding(
            padding: const EdgeInsets.all(12),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Container(
                      padding: const EdgeInsets.symmetric(
                          horizontal: 8, vertical: 4),
                      decoration: BoxDecoration(
                        color: _getTargetColor(r.targetType)
                            .withValues(alpha: 0.15),
                        borderRadius: BorderRadius.circular(4),
                        border: Border.all(
                          color: _getTargetColor(r.targetType)
                              .withValues(alpha: 0.3),
                        ),
                      ),
                      child: Text(
                        '${r.targetType.toUpperCase()} #${r.targetId.substring(0, r.targetId.length > 6 ? 6 : r.targetId.length)}',
                        style: TextStyle(
                          fontSize: 10,
                          fontWeight: FontWeight.w700,
                          color: _getTargetColor(r.targetType),
                          letterSpacing: 0.5,
                        ),
                      ),
                    ),
                    const Spacer(),
                    _statusBadge(r.status),
                  ],
                ),
                const SizedBox(height: 12),
                Text(
                  'Lý do:',
                  style: TextStyle(
                    fontSize: 12,
                    fontWeight: FontWeight.bold,
                    color: Colors.grey[600],
                  ),
                ),
                Text(
                  r.reasonText?.isNotEmpty == true
                      ? r.reasonText!
                      : r.reasonCode,
                  style: const TextStyle(
                      fontWeight: FontWeight.w500, fontSize: 15),
                ),
                const SizedBox(height: 8),
                Row(
                  children: [
                    CircleAvatar(
                      radius: 10,
                      backgroundColor:
                          Theme.of(context).colorScheme.primaryContainer,
                      child: Icon(
                        Icons.person,
                        size: 12,
                        color: Theme.of(context)
                            .colorScheme
                            .onPrimaryContainer,
                      ),
                    ),
                    const SizedBox(width: 6),
                    Expanded(
                      child: Text(
                        reporterName,
                        style: const TextStyle(
                            fontWeight: FontWeight.w600, fontSize: 13),
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                    Text(
                      _formatDate(r.createdAt),
                      style:
                          TextStyle(color: Colors.grey[600], fontSize: 12),
                    ),
                  ],
                ),
                const Divider(height: 24),
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    TextButton.icon(
                      onPressed:
                          busy ? null : () => widget.onAction(r, 'view'),
                      icon: const Icon(Icons.visibility, size: 18),
                      label: const Text('Xem'),
                    ),
                    Row(
                      children: [
                        IconButton(
                          onPressed: busy
                              ? null
                              : () => widget.onAction(r, 'resolve'),
                          icon: const Icon(Icons.check_circle, size: 20),
                          tooltip: 'Giải quyết',
                          style: IconButton.styleFrom(
                            backgroundColor: Theme.of(context).colorScheme.primaryContainer.withValues(alpha: 0.3),
                            foregroundColor: Theme.of(context).colorScheme.primary,
                          ),
                        ),
                        const SizedBox(width: 8),
                        IconButton(
                          onPressed: busy
                              ? null
                              : () => widget.onAction(r, 'ignore'),
                          icon: const Icon(Icons.block, size: 20),
                          tooltip: 'Bỏ qua',
                          style: IconButton.styleFrom(
                            backgroundColor: Theme.of(context).colorScheme.surfaceContainerHighest,
                            foregroundColor: Theme.of(context).colorScheme.outline,
                          ),
                        ),
                      ],
                    )
                  ],
                ),
              ],
            ),
          ),
        );
      },
    );
  }

  Widget _buildDesktopView(BuildContext context) {
    return SingleChildScrollView(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          if (widget.header != null)
            Padding(
              padding: const EdgeInsets.only(bottom: 16),
              child: widget.header!,
            ),
          SingleChildScrollView(
            scrollDirection: Axis.horizontal,
          child: ConstrainedBox(
            constraints: const BoxConstraints(minWidth: 960),
            child: DataTable(
          columnSpacing: 14,
          headingRowHeight: 48,
          headingRowColor: WidgetStateProperty.resolveWith(
            (states) => Theme.of(context)
                .colorScheme
                .primaryContainer
                .withValues(alpha: 0.3),
          ),
          columns: const [
            DataColumn(
              label: Text(
                'Đối tượng',
                style: TextStyle(fontWeight: FontWeight.w700),
              ),
            ),
            DataColumn(
              label: Text(
                'Lý do',
                style: TextStyle(fontWeight: FontWeight.w700),
              ),
            ),
            DataColumn(
              label: Text(
                'Người báo cáo',
                style: TextStyle(fontWeight: FontWeight.w700),
              ),
            ),
            DataColumn(
              label: Text(
                'Ngày tạo',
                style: TextStyle(fontWeight: FontWeight.w700),
              ),
            ),
            DataColumn(
              label: Text(
                'Trạng thái',
                style: TextStyle(fontWeight: FontWeight.w700),
              ),
            ),
            DataColumn(
              label: Text(
                'Thao tác',
                style: TextStyle(fontWeight: FontWeight.w700),
              ),
            ),
          ],
          rows: widget.reports.map((r) {
            final busy = widget.busyIds.contains(r.id);
            final reporterName = _reporterNames[r.reporterId] ?? 'Đang tải...';

            return DataRow(
              cells: [
                DataCell(
                  Container(
                    padding:
                        const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                    decoration: BoxDecoration(
                      color: _getTargetColor(r.targetType).withValues(alpha: 0.15),
                      borderRadius: BorderRadius.circular(4),
                      border: Border.all(
                        color: _getTargetColor(r.targetType).withValues(alpha: 0.3),
                      ),
                    ),
                    child: Text(
                      '${r.targetType.toUpperCase()} #${r.targetId.substring(0, r.targetId.length > 8 ? 8 : r.targetId.length)}',
                      style: TextStyle(
                        fontSize: 11,
                        fontWeight: FontWeight.w700,
                        color: _getTargetColor(r.targetType),
                        letterSpacing: 0.5,
                      ),
                    ),
                  ),
                ),
                DataCell(
                  SizedBox(
                    width: 200,
                    child: Text(
                      r.reasonText?.isNotEmpty == true
                          ? r.reasonText!
                          : r.reasonCode,
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(fontWeight: FontWeight.w500),
                    ),
                  ),
                ),
                DataCell(
                  Row(
                    children: [
                      CircleAvatar(
                        radius: 12,
                        backgroundColor: Theme.of(context)
                            .colorScheme
                            .primaryContainer,
                        child: Icon(
                          Icons.person,
                          size: 14,
                          color: Theme.of(context).colorScheme.onPrimaryContainer,
                        ),
                      ),
                      const SizedBox(width: 6),
                      Text(
                        reporterName,
                        style: const TextStyle(fontWeight: FontWeight.w600),
                      ),
                    ],
                  ),
                ),
                DataCell(Text(_formatDate(r.createdAt))),
                DataCell(_statusBadge(r.status)),
                DataCell(
                  SizedBox(
                    width: 240,
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Tooltip(
                          message: 'Xem chi tiết báo cáo',
                          child: IconButton(
                            onPressed:
                                busy ? null : () => widget.onAction(r, 'view'),
                            icon: const Icon(Icons.visibility, size: 18),
                            style: IconButton.styleFrom(
                              backgroundColor: Theme.of(context).colorScheme.secondaryContainer.withValues(alpha: 0.3),
                              foregroundColor: Theme.of(context).colorScheme.secondary,
                              padding: const EdgeInsets.all(8),
                            ),
                          ),
                        ),
                        const SizedBox(width: 4),
                        Tooltip(
                          message: 'Đánh dấu đã xử lý',
                          child: IconButton(
                            onPressed: busy
                                ? null
                                : () => widget.onAction(r, 'resolve'),
                            icon: const Icon(Icons.check_circle, size: 18),
                            style: IconButton.styleFrom(
                              backgroundColor: Theme.of(context).colorScheme.primaryContainer.withValues(alpha: 0.3),
                              foregroundColor: Theme.of(context).colorScheme.primary,
                              padding: const EdgeInsets.all(8),
                            ),
                          ),
                        ),
                        const SizedBox(width: 4),
                        Tooltip(
                          message: 'Bỏ qua báo cáo',
                          child: IconButton(
                            onPressed:
                                busy ? null : () => widget.onAction(r, 'ignore'),
                            icon: const Icon(Icons.block, size: 18),
                            style: IconButton.styleFrom(
                              backgroundColor: Theme.of(context).colorScheme.surfaceContainerHighest,
                              foregroundColor: Theme.of(context).colorScheme.outline,
                              padding: const EdgeInsets.all(8),
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ],
            );
          }).toList(),
        ),
      ),
    ),
        ],
      ),
    );
  }

  Color _getTargetColor(String targetType) {
    switch (targetType.toLowerCase()) {
      case 'post':
        return Colors.blue.shade700;
      case 'recipe':
        return Colors.green.shade700;
      case 'message':
        return Colors.purple.shade700;
      case 'user':
        return Colors.orange.shade700;
      default:
        return Colors.grey.shade700;
    }
  }

  Widget _statusBadge(String status) {
    final normalized = status.toLowerCase();
    if (normalized == 'resolved') {
      return const StatusBadge(
          label: 'Đã xử lý', variant: StatusVariant.resolved);
    }
    if (normalized == 'ignored') {
      return const StatusBadge(label: 'Đã bỏ qua', variant: StatusVariant.ignored);
    }
    return const StatusBadge(label: 'Chờ xử lý', variant: StatusVariant.pending);
  }

  String _formatDate(DateTime date) {
    return '${date.day.toString().padLeft(2, '0')}/${date.month.toString().padLeft(2, '0')}/${date.year}';
  }
}
