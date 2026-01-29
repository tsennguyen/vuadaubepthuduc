import 'package:flutter/material.dart';

import '../data/admin_content_repository.dart';
import '../data/user_name_resolver.dart';
import '../widgets/status_badge.dart';

class AdminContentTable extends StatefulWidget {
  const AdminContentTable({
    super.key,
    required this.items,
    required this.busyIds,
    required this.onAction,
  });

  final List<AdminContentItem> items;
  final Set<String> busyIds;
  final void Function(AdminContentItem item, String action) onAction;

  @override
  State<AdminContentTable> createState() => _AdminContentTableState();
}

class _AdminContentTableState extends State<AdminContentTable> {
  final _resolver = UserNameResolver();
  final Map<String, String> _authorNames = {};

  @override
  void initState() {
    super.initState();
    _loadAuthorNames();
  }

  @override
  void didUpdateWidget(AdminContentTable oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.items != widget.items) {
      _loadAuthorNames();
    }
  }

  Future<void> _loadAuthorNames() async {
    final authorIds =
        widget.items.map((item) => item.authorId).toSet().toList();
    final names = await _resolver.getUserNames(authorIds);
    if (mounted) {
      setState(() {
        _authorNames.clear();
        _authorNames.addAll(names);
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
    if (widget.items.isEmpty) {
      return const Center(child: Text('Không tìm thấy nội dung'));
    }
    return ListView.separated(
      padding: const EdgeInsets.all(12),
      itemCount: widget.items.length,
      separatorBuilder: (context, index) => const SizedBox(height: 12),
      itemBuilder: (context, index) {
        final item = widget.items[index];
        final busy = widget.busyIds.contains('${item.type}-${item.id}');
        final authorName = _authorNames[item.authorId] ?? 'Đang tải...';

        return Card(
          elevation: 2,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
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
                        color: item.type == AdminContentType.post
                            ? Colors.blue.shade100
                            : Colors.green.shade100,
                        borderRadius: BorderRadius.circular(4),
                      ),
                      child: Text(
                        item.type == AdminContentType.post ? 'Bài viết' : 'Công thức',
                        style: TextStyle(
                          fontSize: 12,
                          fontWeight: FontWeight.w600,
                          color: item.type == AdminContentType.post
                              ? Colors.blue.shade700
                              : Colors.green.shade700,
                        ),
                      ),
                    ),
                    const SizedBox(width: 8),
                    _statusBadge(item),
                    const Spacer(),
                    if (item.reportsCount > 0)
                      Container(
                        padding: const EdgeInsets.symmetric(
                            horizontal: 8, vertical: 2),
                        decoration: BoxDecoration(
                          color: Colors.red.shade100,
                          borderRadius: BorderRadius.circular(12),
                        ),
                        child: Row(
                          children: [
                            const Icon(Icons.flag,
                                size: 12, color: Colors.red),
                            const SizedBox(width: 4),
                            Text(
                              '${item.reportsCount}',
                              style: TextStyle(
                                fontSize: 12,
                                fontWeight: FontWeight.bold,
                                color: Colors.red.shade900,
                              ),
                            ),
                          ],
                        ),
                      ),
                  ],
                ),
                const SizedBox(height: 8),
                Text(
                  item.title,
                  style: const TextStyle(
                      fontWeight: FontWeight.bold, fontSize: 16),
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                ),
                const SizedBox(height: 8),
                Row(
                  children: [
                    Icon(Icons.person, size: 14, color: Colors.grey[600]),
                    const SizedBox(width: 4),
                    Expanded(
                      child: Text(
                        authorName,
                        style: TextStyle(
                            color: Colors.grey[700], fontSize: 13),
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                    Text(
                      _formatDate(item.createdAt),
                      style: TextStyle(color: Colors.grey[600], fontSize: 12),
                    ),
                  ],
                ),
                const Divider(height: 24),
                Row(
                  mainAxisAlignment: MainAxisAlignment.end,
                  children: [
                    TextButton.icon(
                      onPressed: busy
                          ? null
                          : () => widget.onAction(item.copyWith(authorName: authorName), 'view'),
                      icon: const Icon(Icons.visibility, size: 18),
                      label: const Text('Xem'),
                    ),
                    const SizedBox(width: 8),
                    TextButton.icon(
                      onPressed: busy
                          ? null
                          : () => widget.onAction(item.copyWith(authorName: authorName), 'toggle'),
                      icon: Icon(
                        item.hidden
                            ? Icons.visibility
                            : Icons.visibility_off,
                        size: 18,
                      ),
                      label: Text(item.hidden ? 'Hiện' : 'Ẩn'),
                      style: TextButton.styleFrom(
                        foregroundColor: item.hidden ? Colors.green : Colors.orange,
                      ),
                    ),
                    const SizedBox(width: 8),
                    IconButton(
                      onPressed: busy
                          ? null
                          : () => widget.onAction(item.copyWith(authorName: authorName), 'delete'),
                      icon: const Icon(Icons.delete, size: 20),
                      style: IconButton.styleFrom(
                        foregroundColor: Colors.red,
                        backgroundColor: Colors.red.shade50,
                      ),
                    ),
                  ],
                )
              ],
            ),
          ),
        );
      },
    );
  }

  Widget _buildDesktopView(BuildContext context) {
    return SingleChildScrollView(
      scrollDirection: Axis.horizontal,
      child: ConstrainedBox(
        constraints: const BoxConstraints(minWidth: 960),
        child: DataTable(
          columnSpacing: 16,
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
                'Loại',
                style: TextStyle(fontWeight: FontWeight.w700),
              ),
            ),
            DataColumn(
              label: Text(
                'Tiêu đề',
                style: TextStyle(fontWeight: FontWeight.w700),
              ),
            ),
            DataColumn(
              label: Text(
                'Tác giả',
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
                'Báo cáo',
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
          rows: widget.items.map((item) {
            final status = _statusBadge(item);
            final busy = widget.busyIds.contains('${item.type}-${item.id}');
            final authorName = _authorNames[item.authorId] ?? 'Đang tải...';

            return DataRow(
              cells: [
                DataCell(
                  Container(
                    padding:
                        const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                    decoration: BoxDecoration(
                      color: item.type == AdminContentType.post
                          ? Colors.blue.shade100
                          : Colors.green.shade100,
                      borderRadius: BorderRadius.circular(4),
                    ),
                    child: Text(
                      item.type == AdminContentType.post ? 'Bài viết' : 'Công thức',
                      style: TextStyle(
                        fontWeight: FontWeight.w600,
                        color: item.type == AdminContentType.post
                            ? Colors.blue.shade700
                            : Colors.green.shade700,
                      ),
                    ),
                  ),
                ),
                DataCell(
                  Text(
                    item.title,
                    style: const TextStyle(fontWeight: FontWeight.w500),
                  ),
                ),
                DataCell(
                  Row(
                    children: [
                      const Icon(Icons.person, size: 16),
                      const SizedBox(width: 4),
                      Text(
                        authorName,
                        style: const TextStyle(fontWeight: FontWeight.w600),
                      ),
                    ],
                  ),
                ),
                DataCell(Text(_formatDate(item.createdAt))),
                DataCell(status),
                DataCell(
                  Container(
                    padding:
                        const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                    decoration: BoxDecoration(
                      color: item.reportsCount > 0
                          ? Colors.red.shade100
                          : Colors.grey.shade100,
                      borderRadius: BorderRadius.circular(4),
                    ),
                    child: Text(
                      '${item.reportsCount}',
                      style: TextStyle(
                        fontWeight: FontWeight.w700,
                        color: item.reportsCount > 0
                            ? Colors.red.shade700
                            : Colors.grey.shade700,
                      ),
                    ),
                  ),
                ),
                DataCell(
                  SizedBox(
                    width: 240,
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Tooltip(
                          message: 'Xem',
                          child: IconButton(
                            onPressed: busy
                                ? null
                                : () => widget.onAction(item.copyWith(authorName: authorName), 'view'),
                            icon: const Icon(Icons.visibility, size: 18),
                            style: IconButton.styleFrom(
                              backgroundColor: Colors.blue.shade50,
                              foregroundColor: Colors.blue.shade700,
                              padding: const EdgeInsets.all(8),
                            ),
                          ),
                        ),
                        const SizedBox(width: 4),
                        Tooltip(
                          message: item.hidden ? 'Hiện nội dung' : 'Ẩn nội dung',
                          child: IconButton(
                            onPressed: busy
                                ? null
                                : () => widget.onAction(item.copyWith(authorName: authorName), 'toggle'),
                            icon: Icon(
                              item.hidden
                                  ? Icons.visibility
                                  : Icons.visibility_off,
                              size: 18,
                            ),
                            style: IconButton.styleFrom(
                              backgroundColor: Colors.orange.shade50,
                              foregroundColor: Colors.orange.shade700,
                              padding: const EdgeInsets.all(8),
                            ),
                          ),
                        ),
                        const SizedBox(width: 4),
                        Tooltip(
                          message: 'Xóa',
                          child: IconButton(
                            onPressed: busy
                                ? null
                                : () => widget.onAction(item.copyWith(authorName: authorName), 'delete'),
                            icon: const Icon(Icons.delete, size: 18),
                            style: IconButton.styleFrom(
                              backgroundColor: Colors.red.shade50,
                              foregroundColor: Colors.red.shade700,
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
    );
  }

  Widget _statusBadge(AdminContentItem item) {
    if (item.isHiddenPendingReview) {
      return const StatusBadge(
          label: 'Chờ duyệt', variant: StatusVariant.pending);
    }
    if (item.hidden) {
      return const StatusBadge(label: 'Đã ẩn', variant: StatusVariant.hidden);
    }
    if (item.reportsCount > 0) {
      return const StatusBadge(
          label: 'Bị báo cáo', variant: StatusVariant.reported);
    }
    return const StatusBadge(label: 'Hiển thị', variant: StatusVariant.visible);
  }

  String _formatDate(DateTime date) {
    return '${date.day.toString().padLeft(2, '0')}/${date.month.toString().padLeft(2, '0')}/${date.year}';
  }
}
