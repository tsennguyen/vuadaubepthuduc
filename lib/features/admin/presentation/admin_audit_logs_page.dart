import 'dart:convert';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:timeago/timeago.dart' as timeago;

import '../../../app/theme.dart';
import '../data/admin_audit_repository.dart';
import 'admin_shell_scaffold.dart';

enum _AuditTimeFilter { all, last24h, last7d, last30d }

class AdminAuditLogsPage extends StatefulWidget {
  const AdminAuditLogsPage({super.key});

  @override
  State<AdminAuditLogsPage> createState() => _AdminAuditLogsPageState();
}

class _AdminAuditLogsPageState extends State<AdminAuditLogsPage> {
  late final AdminAuditRepository _repository;

  String? _typeFilter; // null => all
  _AuditTimeFilter _timeFilter = _AuditTimeFilter.all;

  DateTime? _from;
  DateTime? _to;

  late Stream<List<AuditLog>> _stream;

  static const _knownTypes = <String>[
    'reportCreated',
    'adminChangeRole',
    'adminHidePost',
    'adminDeletePost',
    'adminResolveReport',
  ];

  @override
  void initState() {
    super.initState();
    _repository = FirestoreAdminAuditRepository();
    timeago.setLocaleMessages('vi', timeago.ViMessages());
    _rebuildStream();
  }

  void _rebuildStream() {
    _stream = _repository.watchAuditLogs(
      typeFilter: _typeFilter,
      from: _from,
      to: _to,
    );
  }

  void _setTypeFilter(String? value) {
    if (value == _typeFilter) return;
    setState(() {
      _typeFilter = value;
      _rebuildStream();
    });
  }

  void _setTimeFilter(_AuditTimeFilter value) {
    if (value == _timeFilter) return;
    setState(() {
      _timeFilter = value;
      final now = DateTime.now();
      switch (value) {
        case _AuditTimeFilter.all:
          _from = null;
          _to = null;
        case _AuditTimeFilter.last24h:
          _from = now.subtract(const Duration(hours: 24));
          _to = null;
        case _AuditTimeFilter.last7d:
          _from = now.subtract(const Duration(days: 7));
          _to = null;
        case _AuditTimeFilter.last30d:
          _from = now.subtract(const Duration(days: 30));
          _to = null;
      }
      _rebuildStream();
    });
  }

  void _retry() {
    setState(_rebuildStream);
  }

  Future<void> _openMetadata(AuditLog log) async {
    await showDialog<void>(
      context: context,
      builder: (context) => _MetadataDialog(log: log),
    );
  }

  @override
  Widget build(BuildContext context) {
    return AdminShell(
      child: StreamBuilder<List<AuditLog>>(
        stream: _stream,
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

          final logs = snapshot.data ?? const <AuditLog>[];

          return CustomScrollView(
            slivers: [
              // Filter Bar
              SliverToBoxAdapter(
                child: _FilterBar(
                  typeFilter: _typeFilter,
                  onTypeFilterChanged: _setTypeFilter,
                  timeFilter: _timeFilter,
                  onTimeFilterChanged: _setTimeFilter,
                  onRetry: _retry,
                  totalLogs: logs.length,
                ),
              ),

              // Logs List
              if (logs.isEmpty)
                const SliverFillRemaining(
                  child: Center(
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Icon(Icons.history, size: 64, color: Colors.grey),
                        SizedBox(height: 16),
                        Text(
                          'Không có nhật ký nào',
                          style: TextStyle(
                            fontSize: 16,
                            color: Colors.grey,
                          ),
                        ),
                      ],
                    ),
                  ),
                )
              else
                SliverPadding(
                  padding: const EdgeInsets.all(AppSpacing.s16),
                  sliver: SliverList(
                    delegate: SliverChildBuilderDelegate(
                      (context, index) {
                        final log = logs[index];
                        return Padding(
                          padding: const EdgeInsets.only(bottom: AppSpacing.s12),
                          child: _AuditLogCard(
                            log: log,
                            onTap: () => _openMetadata(log),
                          ),
                        );
                      },
                      childCount: logs.length,
                    ),
                  ),
                ),
            ],
          );
        },
      ),
    );
  }
}

class _FilterBar extends StatelessWidget {
  const _FilterBar({
    required this.typeFilter,
    required this.onTypeFilterChanged,
    required this.timeFilter,
    required this.onTimeFilterChanged,
    required this.onRetry,
    required this.totalLogs,
  });

  final String? typeFilter;
  final ValueChanged<String?> onTypeFilterChanged;
  final _AuditTimeFilter timeFilter;
  final ValueChanged<_AuditTimeFilter> onTimeFilterChanged;
  final VoidCallback onRetry;
  final int totalLogs;

  static const _knownTypes = _AdminAuditLogsPageState._knownTypes;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(AppSpacing.s16),
      decoration: BoxDecoration(
        color: Theme.of(context).colorScheme.surface,
        border: Border(
          bottom: BorderSide(
            color: Theme.of(context).dividerColor.withValues(alpha: 0.1),
          ),
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(
                Icons.receipt_long_rounded,
                color: Theme.of(context).colorScheme.primary,
              ),
              const SizedBox(width: AppSpacing.s8),
              Text(
                'Nhật ký hệ thống',
                style: Theme.of(context).textTheme.titleLarge?.copyWith(
                      fontWeight: FontWeight.bold,
                    ),
              ),
              const Spacer(),
              Container(
                padding: const EdgeInsets.symmetric(
                  horizontal: AppSpacing.s12,
                  vertical: AppSpacing.s4,
                ),
                decoration: BoxDecoration(
                  color: Theme.of(context).colorScheme.primaryContainer,
                  borderRadius: BorderRadius.circular(AppRadius.r12),
                ),
                child: Text(
                  '$totalLogs mục',
                  style: TextStyle(
                    color: Theme.of(context).colorScheme.onPrimaryContainer,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: AppSpacing.s16),
          Wrap(
            spacing: AppSpacing.s12,
            runSpacing: AppSpacing.s12,
            crossAxisAlignment: WrapCrossAlignment.center,
            children: [
              // Type Filter
              Container(
                padding: const EdgeInsets.symmetric(
                  horizontal: AppSpacing.s12,
                  vertical: AppSpacing.s4,
                ),
                decoration: BoxDecoration(
                  color: Theme.of(context).colorScheme.surfaceContainerHighest,
                  borderRadius: BorderRadius.circular(AppRadius.r8),
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(
                      Icons.filter_list_rounded,
                      size: 18,
                      color: Theme.of(context).colorScheme.onSurfaceVariant,
                    ),
                    const SizedBox(width: AppSpacing.s8),
                    Text(
                      'Loại:',
                      style: TextStyle(
                        color: Theme.of(context).colorScheme.onSurfaceVariant,
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                    const SizedBox(width: AppSpacing.s8),
                    DropdownButton<String?>(
                      value: typeFilter,
                      onChanged: onTypeFilterChanged,
                      underline: const SizedBox.shrink(),
                      isDense: true,
                      items: [
                        const DropdownMenuItem<String?>(
                          value: null,
                          child: Text('Tất cả'),
                        ),
                        ..._knownTypes.map(
                          (t) => DropdownMenuItem<String?>(
                            value: t,
                            child: Text(_getActionLabel(t)),
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),

              // Time Filter
              Container(
                padding: const EdgeInsets.symmetric(
                  horizontal: AppSpacing.s12,
                  vertical: AppSpacing.s4,
                ),
                decoration: BoxDecoration(
                  color: Theme.of(context).colorScheme.surfaceContainerHighest,
                  borderRadius: BorderRadius.circular(AppRadius.r8),
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(
                      Icons.schedule_rounded,
                      size: 18,
                      color: Theme.of(context).colorScheme.onSurfaceVariant,
                    ),
                    const SizedBox(width: AppSpacing.s8),
                    Text(
                      'Thời gian:',
                      style: TextStyle(
                        color: Theme.of(context).colorScheme.onSurfaceVariant,
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                    const SizedBox(width: AppSpacing.s8),
                    DropdownButton<_AuditTimeFilter>(
                      value: timeFilter,
                      onChanged: (v) => v == null ? null : onTimeFilterChanged(v),
                      underline: const SizedBox.shrink(),
                      isDense: true,
                      items: const [
                        DropdownMenuItem(
                          value: _AuditTimeFilter.all,
                          child: Text('Tất cả'),
                        ),
                        DropdownMenuItem(
                          value: _AuditTimeFilter.last24h,
                          child: Text('24 giờ qua'),
                        ),
                        DropdownMenuItem(
                          value: _AuditTimeFilter.last7d,
                          child: Text('7 ngày qua'),
                        ),
                        DropdownMenuItem(
                          value: _AuditTimeFilter.last30d,
                          child: Text('30 ngày qua'),
                        ),
                      ],
                    ),
                  ],
                ),
              ),

              // Refresh Button
              IconButton.filledTonal(
                tooltip: 'Làm mới',
                onPressed: onRetry,
                icon: const Icon(Icons.refresh_rounded),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

class _AuditLogCard extends StatelessWidget {
  const _AuditLogCard({
    required this.log,
    required this.onTap,
  });

  final AuditLog log;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final actionInfo = _getActionInfo(log.type);
    final targetInfo = _getTargetInfo(log);

    return Card(
      elevation: 0,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(AppRadius.r12),
        side: BorderSide(
          color: Theme.of(context).dividerColor.withValues(alpha: 0.1),
        ),
      ),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(AppRadius.r12),
        child: Padding(
          padding: const EdgeInsets.all(AppSpacing.s16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Header
              Row(
                children: [
                  // Action Icon
                  Container(
                    padding: const EdgeInsets.all(AppSpacing.s8),
                    decoration: BoxDecoration(
                      color: actionInfo.color.withValues(alpha: 0.1),
                      borderRadius: BorderRadius.circular(AppRadius.r8),
                    ),
                    child: Icon(
                      actionInfo.icon,
                      size: 20,
                      color: actionInfo.color,
                    ),
                  ),
                  const SizedBox(width: AppSpacing.s12),

                  // Action Label & Time
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          actionInfo.label,
                          style: Theme.of(context).textTheme.titleMedium?.copyWith(
                                fontWeight: FontWeight.w600,
                              ),
                        ),
                        const SizedBox(height: 2),
                        Text(
                          timeago.format(log.createdAt, locale: 'vi'),
                          style: Theme.of(context).textTheme.bodySmall?.copyWith(
                                color: Theme.of(context).colorScheme.onSurfaceVariant,
                              ),
                        ),
                      ],
                    ),
                  ),

                  // Open Button
                  IconButton(
                    onPressed: onTap,
                    icon: Icon(
                      Icons.arrow_forward_ios_rounded,
                      size: 16,
                      color: Theme.of(context).colorScheme.onSurfaceVariant,
                    ),
                  ),
                ],
              ),

              const SizedBox(height: AppSpacing.s12),
              const Divider(height: 1),
              const SizedBox(height: AppSpacing.s12),

              // Details
              _DetailRow(
                icon: Icons.person_outline_rounded,
                label: 'Người thực hiện',
                value: log.actorId?.isNotEmpty == true ? log.actorId! : 'Hệ thống',
              ),
              const SizedBox(height: AppSpacing.s8),
              _DetailRow(
                icon: targetInfo.icon,
                label: 'Đối tượng',
                value: targetInfo.label,
                valueColor: targetInfo.color,
              ),

              // Metadata preview
              if (log.metadata.isNotEmpty) ...[
                const SizedBox(height: AppSpacing.s8),
                _MetadataPreview(metadata: log.metadata),
              ],
            ],
          ),
        ),
      ),
    );
  }
}

class _DetailRow extends StatelessWidget {
  const _DetailRow({
    required this.icon,
    required this.label,
    required this.value,
    this.valueColor,
  });

  final IconData icon;
  final String label;
  final String value;
  final Color? valueColor;

  @override
  Widget build(BuildContext context) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Icon(
          icon,
          size: 18,
          color: Theme.of(context).colorScheme.onSurfaceVariant,
        ),
        const SizedBox(width: AppSpacing.s8),
        Expanded(
          child: RichText(
            text: TextSpan(
              style: Theme.of(context).textTheme.bodyMedium,
              children: [
                TextSpan(
                  text: '$label: ',
                  style: TextStyle(
                    color: Theme.of(context).colorScheme.onSurfaceVariant,
                  ),
                ),
                TextSpan(
                  text: value,
                  style: TextStyle(
                    fontWeight: FontWeight.w500,
                    color: valueColor ?? Theme.of(context).colorScheme.onSurface,
                  ),
                ),
              ],
            ),
          ),
        ),
      ],
    );
  }
}

class _MetadataPreview extends StatelessWidget {
  const _MetadataPreview({required this.metadata});

  final Map<String, dynamic> metadata;

  @override
  Widget build(BuildContext context) {
    final preview = _getReadableMetadata(metadata);

    return Container(
      padding: const EdgeInsets.all(AppSpacing.s12),
      decoration: BoxDecoration(
        color: Theme.of(context).colorScheme.surfaceContainerHighest.withValues(alpha: 0.5),
        borderRadius: BorderRadius.circular(AppRadius.r8),
      ),
      child: Row(
        children: [
          Icon(
            Icons.data_object_rounded,
            size: 16,
            color: Theme.of(context).colorScheme.onSurfaceVariant,
          ),
          const SizedBox(width: AppSpacing.s8),
          Expanded(
            child: Text(
              preview,
              style: Theme.of(context).textTheme.bodySmall?.copyWith(
                    color: Theme.of(context).colorScheme.onSurfaceVariant,
                    fontFamily: 'monospace',
                  ),
              maxLines: 2,
              overflow: TextOverflow.ellipsis,
            ),
          ),
        ],
      ),
    );
  }

  String _getReadableMetadata(Map<String, dynamic> data) {
    if (data.isEmpty) return 'Không có dữ liệu';

    final entries = data.entries.take(3).map((e) {
      final value = e.value.toString();
      return '${e.key}: ${value.length > 30 ? "${value.substring(0, 30)}..." : value}';
    }).join(' • ');

    if (data.length > 3) {
      return '$entries • (+${data.length - 3} khác)';
    }
    return entries;
  }
}

class _MetadataDialog extends StatelessWidget {
  const _MetadataDialog({required this.log});

  final AuditLog log;

  @override
  Widget build(BuildContext context) {
    final actionInfo = _getActionInfo(log.type);
    final safe = _toJsonEncodable({
      'id': log.id,
      'type': log.type,
      'actorId': log.actorId,
      'targetType': log.targetType,
      'targetId': log.targetId,
      'createdAt': log.createdAt.toIso8601String(),
      'metadata': log.metadata,
    });

    final pretty = const JsonEncoder.withIndent('  ').convert(safe);

    return Dialog(
      child: Container(
        constraints: const BoxConstraints(maxWidth: 800, maxHeight: 700),
        child: Column(
          children: [
            // Header
            Container(
              padding: const EdgeInsets.all(AppSpacing.s20),
              decoration: BoxDecoration(
                color: actionInfo.color.withValues(alpha: 0.1),
                border: Border(
                  bottom: BorderSide(
                    color: Theme.of(context).dividerColor.withValues(alpha: 0.1),
                  ),
                ),
              ),
              child: Row(
                children: [
                  Container(
                    padding: const EdgeInsets.all(AppSpacing.s12),
                    decoration: BoxDecoration(
                      color: actionInfo.color.withValues(alpha: 0.2),
                      borderRadius: BorderRadius.circular(AppRadius.r12),
                    ),
                    child: Icon(
                      actionInfo.icon,
                      color: actionInfo.color,
                      size: 28,
                    ),
                  ),
                  const SizedBox(width: AppSpacing.s16),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'Chi tiết nhật ký',
                          style: Theme.of(context).textTheme.titleLarge?.copyWith(
                                fontWeight: FontWeight.bold,
                              ),
                        ),
                        const SizedBox(height: 4),
                        Text(
                          actionInfo.label,
                          style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                                color: Theme.of(context).colorScheme.onSurfaceVariant,
                              ),
                        ),
                      ],
                    ),
                  ),
                  IconButton(
                    onPressed: () => Navigator.of(context).pop(),
                    icon: const Icon(Icons.close_rounded),
                  ),
                ],
              ),
            ),

            // Content
            Expanded(
              child: SingleChildScrollView(
                padding: const EdgeInsets.all(AppSpacing.s20),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    // Info Grid
                    _InfoGrid(log: log),
                    const SizedBox(height: AppSpacing.s24),
                    const Divider(),
                    const SizedBox(height: AppSpacing.s24),

                    // JSON Data
                    Text(
                      'Dữ liệu JSON',
                      style: Theme.of(context).textTheme.titleMedium?.copyWith(
                            fontWeight: FontWeight.bold,
                          ),
                    ),
                    const SizedBox(height: AppSpacing.s12),
                    Container(
                      padding: const EdgeInsets.all(AppSpacing.s16),
                      decoration: BoxDecoration(
                        color: Theme.of(context).colorScheme.surfaceContainerHighest,
                        borderRadius: BorderRadius.circular(AppRadius.r12),
                      ),
                      child: SelectableText(
                        pretty,
                        style: const TextStyle(
                          fontFamily: 'monospace',
                          fontSize: 13,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ),

            // Actions
            Container(
              padding: const EdgeInsets.all(AppSpacing.s16),
              decoration: BoxDecoration(
                border: Border(
                  top: BorderSide(
                    color: Theme.of(context).dividerColor.withValues(alpha: 0.1),
                  ),
                ),
              ),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.end,
                children: [
                  FilledButton.tonalIcon(
                    onPressed: () => Clipboard.setData(ClipboardData(text: pretty)),
                    icon: const Icon(Icons.copy_rounded),
                    label: const Text('Sao chép JSON'),
                  ),
                  const SizedBox(width: AppSpacing.s12),
                  FilledButton(
                    onPressed: () => Navigator.of(context).pop(),
                    child: const Text('Đóng'),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _InfoGrid extends StatelessWidget {
  const _InfoGrid({required this.log});

  final AuditLog log;

  @override
  Widget build(BuildContext context) {
    final targetInfo = _getTargetInfo(log);

    return Column(
      children: [
        _InfoItem(
          icon: Icons.fingerprint_rounded,
          label: 'ID',
          value: log.id,
        ),
        const SizedBox(height: AppSpacing.s12),
        _InfoItem(
          icon: Icons.person_outline_rounded,
          label: 'Người thực hiện',
          value: log.actorId?.isNotEmpty == true ? log.actorId! : 'Hệ thống',
        ),
        const SizedBox(height: AppSpacing.s12),
        _InfoItem(
          icon: targetInfo.icon,
          label: 'Đối tượng',
          value: targetInfo.label,
        ),
        const SizedBox(height: AppSpacing.s12),
        _InfoItem(
          icon: Icons.access_time_rounded,
          label: 'Thời gian',
          value: _formatFullDate(log.createdAt),
        ),
      ],
    );
  }
}

class _InfoItem extends StatelessWidget {
  const _InfoItem({
    required this.icon,
    required this.label,
    required this.value,
  });

  final IconData icon;
  final String label;
  final String value;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(AppSpacing.s16),
      decoration: BoxDecoration(
        color: Theme.of(context).colorScheme.surfaceContainerHighest.withValues(alpha: 0.5),
        borderRadius: BorderRadius.circular(AppRadius.r8),
      ),
      child: Row(
        children: [
          Icon(
            icon,
            size: 20,
            color: Theme.of(context).colorScheme.primary,
          ),
          const SizedBox(width: AppSpacing.s12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  label,
                  style: Theme.of(context).textTheme.bodySmall?.copyWith(
                        color: Theme.of(context).colorScheme.onSurfaceVariant,
                      ),
                ),
                const SizedBox(height: 2),
                SelectableText(
                  value,
                  style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                        fontWeight: FontWeight.w500,
                      ),
                ),
              ],
            ),
          ),
        ],
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
          padding: const EdgeInsets.all(AppSpacing.s16),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(
                Icons.error_outline_rounded,
                size: 64,
                color: Theme.of(context).colorScheme.error,
              ),
              const SizedBox(height: AppSpacing.s16),
              Text(
                'Không tải được nhật ký',
                style: Theme.of(context).textTheme.titleLarge?.copyWith(
                      fontWeight: FontWeight.bold,
                    ),
              ),
              const SizedBox(height: AppSpacing.s8),
              Text(
                message,
                textAlign: TextAlign.center,
                style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                      color: Theme.of(context).colorScheme.onSurfaceVariant,
                    ),
              ),
              const SizedBox(height: AppSpacing.s16),
              FilledButton.icon(
                onPressed: onRetry,
                icon: const Icon(Icons.refresh_rounded),
                label: const Text('Thử lại'),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

// Helper functions

class _ActionInfo {
  const _ActionInfo({
    required this.label,
    required this.icon,
    required this.color,
  });

  final String label;
  final IconData icon;
  final Color color;
}

_ActionInfo _getActionInfo(String type) {
  switch (type) {
    case 'reportCreated':
      return const _ActionInfo(
        label: 'Tạo báo cáo vi phạm',
        icon: Icons.flag_rounded,
        color: Colors.orange,
      );
    case 'adminChangeRole':
      return const _ActionInfo(
        label: 'Thay đổi vai trò người dùng',
        icon: Icons.admin_panel_settings_rounded,
        color: Colors.purple,
      );
    case 'adminHidePost':
      return const _ActionInfo(
        label: 'Ẩn bài viết',
        icon: Icons.visibility_off_rounded,
        color: Colors.red,
      );
    case 'adminDeletePost':
      return const _ActionInfo(
        label: 'Xóa bài viết',
        icon: Icons.delete_rounded,
        color: Colors.red,
      );
    case 'adminResolveReport':
      return const _ActionInfo(
        label: 'Giải quyết báo cáo',
        icon: Icons.check_circle_rounded,
        color: Colors.green,
      );
    default:
      return _ActionInfo(
        label: type,
        icon: Icons.info_rounded,
        color: Colors.blue,
      );
  }
}

class _TargetInfo {
  const _TargetInfo({
    required this.label,
    required this.icon,
    required this.color,
  });

  final String label;
  final IconData icon;
  final Color color;
}

_TargetInfo _getTargetInfo(AuditLog log) {
  final t = log.targetType?.trim();
  final id = log.targetId?.trim();

  if ((t == null || t.isEmpty) && (id == null || id.isEmpty)) {
    return const _TargetInfo(
      label: 'Không xác định',
      icon: Icons.help_outline_rounded,
      color: Colors.grey,
    );
  }

  IconData icon;
  Color color;

  switch (t) {
    case 'recipe':
      icon = Icons.restaurant_menu_rounded;
      color = Colors.green;
      break;
    case 'post':
      icon = Icons.article_rounded;
      color = Colors.blue;
      break;
    case 'user':
      icon = Icons.person_rounded;
      color = Colors.purple;
      break;
    case 'chat':
      icon = Icons.chat_rounded;
      color = Colors.orange;
      break;
    default:
      icon = Icons.label_rounded;
      color = Colors.grey;
  }

  if (t == null || t.isEmpty) {
    return _TargetInfo(label: id!, icon: icon, color: color);
  }
  if (id == null || id.isEmpty) {
    return _TargetInfo(label: _getTargetTypeLabel(t), icon: icon, color: color);
  }

  return _TargetInfo(
    label: '${_getTargetTypeLabel(t)}: ${id.substring(0, id.length > 12 ? 12 : id.length)}...',
    icon: icon,
    color: color,
  );
}

String _getTargetTypeLabel(String type) {
  switch (type) {
    case 'recipe':
      return 'Công thức';
    case 'post':
      return 'Bài viết';
    case 'user':
      return 'Người dùng';
    case 'chat':
      return 'Trò chuyện';
    default:
      return type;
  }
}

String _getActionLabel(String type) {
  switch (type) {
    case 'reportCreated':
      return 'Tạo báo cáo';
    case 'adminChangeRole':
      return 'Đổi vai trò';
    case 'adminHidePost':
      return 'Ẩn bài viết';
    case 'adminDeletePost':
      return 'Xóa bài viết';
    case 'adminResolveReport':
      return 'Giải quyết báo cáo';
    default:
      return type;
  }
}

String _formatFullDate(DateTime dateTime) {
  final weekday = ['CN', 'T2', 'T3', 'T4', 'T5', 'T6', 'T7'][dateTime.weekday % 7];
  String two(int n) => n.toString().padLeft(2, '0');
  return '$weekday, ${two(dateTime.day)}/${two(dateTime.month)}/${dateTime.year} '
      'lúc ${two(dateTime.hour)}:${two(dateTime.minute)}:${two(dateTime.second)}';
}

Object? _toJsonEncodable(Object? value) {
  if (value == null) return null;

  if (value is String || value is num || value is bool) return value;
  if (value is DateTime) return value.toIso8601String();
  if (value is Timestamp) return value.toDate().toIso8601String();
  if (value is DocumentReference) return value.path;

  if (value is List) {
    return value.map(_toJsonEncodable).toList();
  }

  if (value is Map) {
    final out = <String, Object?>{};
    for (final entry in value.entries) {
      out[entry.key.toString()] = _toJsonEncodable(entry.value);
    }
    return out;
  }

  return value.toString();
}
