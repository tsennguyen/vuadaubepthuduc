import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'admin_shell_scaffold.dart';
import '../../../app/theme.dart';
import '../../../core/services/ai_moderation_service.dart';
import '../../../core/utils/ai_analysis_helper.dart';
import '../application/admin_chat_moderation_controller.dart';
import '../data/admin_chat_moderation_repository.dart';
import '../widgets/status_badge.dart';
import 'widgets/ai_report_summary.dart';

class AdminChatModerationPage extends ConsumerStatefulWidget {
  const AdminChatModerationPage({super.key});

  @override
  ConsumerState<AdminChatModerationPage> createState() =>
      _AdminChatModerationPageState();
}

class _AdminChatModerationPageState
    extends ConsumerState<AdminChatModerationPage> {
  final _searchController = TextEditingController();
  final _aiService = AiModerationService();
  
  // AI analysis state
  ReportAnalysisResult? _aiAnalysis;
  bool _isAnalyzing = false;

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final state = ref.watch(adminChatModerationControllerProvider);
    final controller = ref.read(adminChatModerationControllerProvider.notifier);
    final theme = Theme.of(context);

    return AdminShell(
      child: Scaffold(
        backgroundColor: theme.colorScheme.surface,
        body: Column(
          children: [
            Container(
              decoration: BoxDecoration(
                color: theme.colorScheme.surface,
                border: Border(
                  bottom: BorderSide(
                    color: theme.colorScheme.outlineVariant.withValues(alpha: 0.5),
                  ),
                ),
              ),
              padding: const EdgeInsets.all(AppSpacing.s16),
              child: _FilterBar(
                state: state,
                searchController: _searchController,
                onStatusChanged: controller.setStatusFilter,
                onSeverityChanged: controller.setSeverityFilter,
                onTimeRangeChanged: controller.setTimeRange,
                onSearchChanged: controller.setSearch,
              ),
            ),
            Expanded(
              child: state.violations.when(
                loading: () => const _LoadingList(),
                error: (err, _) => _ErrorView(
                  message: '$err',
                  onRetry: controller.refresh,
                ),
                data: (violations) {
                  if (violations.isEmpty) {
                    return const Center(child: _EmptyViolationsView());
                  }

                  // Auto-analyze violations on load (for any filter)
                  if (!_isAnalyzing && _aiAnalysis == null && violations.isNotEmpty) {
                    WidgetsBinding.instance.addPostFrameCallback((_) {
                      if (mounted) {
                        _analyzeViolations(violations);
                      }
                    });
                  }

                  return CustomScrollView(
                    slivers: [
                      // AI Summary (show for all filters if we have violations)
                      if (violations.length >= 3) // Only show if enough data
                        SliverToBoxAdapter(
                          child: Padding(
                            padding: const EdgeInsets.all(AppSpacing.s16),
                            child: AiReportSummary(
                              analysis: _aiAnalysis,
                              isLoading: _isAnalyzing,
                              onRefresh: () {
                                if (mounted) {
                                  _analyzeViolations(violations);
                                }
                              },
                            ),
                          ),
                        ),
                        
                      // Violations List
                      SliverPadding(
                        padding: const EdgeInsets.symmetric(horizontal: AppSpacing.s16),
                        sliver: SliverList(
                          delegate: SliverChildBuilderDelegate(
                            (context, index) {
                              final record = violations[index];
                              return Padding(
                                padding: const EdgeInsets.only(bottom: 12),
                                child: _ViolationCard(
                                  record: record,
                                  onActionTap: () => _openActionSheet(context, record),
                                ),
                              );
                            },
                            childCount: violations.length,
                          ),
                        ),
                      ),
                      
                      // Bottom Padding
                      const SliverToBoxAdapter(
                        child: SizedBox(height: 20),
                      ),
                    ],
                  );
                },
              ),
            ),
          ],
        ),
      ),
    );
  }

  void _openActionSheet(BuildContext context, ChatViolationRecord record) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      builder: (_) => _ViolationActionSheet(record: record),
    );
  }

  Future<void> _analyzeViolations(List<ChatViolationRecord> violations) async {
    if (_isAnalyzing) return;
    if (violations.isEmpty) return;

    setState(() {
      _isAnalyzing = true;
      _aiAnalysis = null;
    });

    try {
      final reportData = ChatViolationAnalysisHelper.convertViolationsToReports(
        violations,
      );

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
}

class _FilterBar extends StatelessWidget {
  const _FilterBar({
    required this.state,
    required this.searchController,
    required this.onStatusChanged,
    required this.onSeverityChanged,
    required this.onTimeRangeChanged,
    required this.onSearchChanged,
  });

  final AdminChatModerationState state;
  final TextEditingController searchController;
  final void Function(ChatViolationStatus) onStatusChanged;
  final void Function(ChatViolationSeverity) onSeverityChanged;
  final void Function(ChatViolationTimeRange) onTimeRangeChanged;
  final void Function(String) onSearchChanged;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        // Filters - Wrap for mobile-friendly layout
        Wrap(
          spacing: 8,
          runSpacing: 8,
          children: [
            _FilterChip(
              label: 'Thời gian: ${_timeRangeLabel(state.filter.timeRange)}',
              selected: true,
              onSelected: (_) {}, // Could show a popup menu
              avatar: const Icon(Icons.access_time, size: 16),
              popupItems: [
                ChatViolationTimeRange.last24h,
                ChatViolationTimeRange.last7d,
                ChatViolationTimeRange.last30d,
                ChatViolationTimeRange.all
              ].map((e) => PopupMenuItem(
                    value: e,
                    child: Text(_timeRangeLabel(e)),
                    onTap: () => onTimeRangeChanged(e),
                  )).toList(),
            ),
            _FilterChip(
              label: 'Trạng thái: ${_statusLabel(state.filter.status.name)}',
              selected: state.filter.status != ChatViolationStatus.all,
              onSelected: (_) {},
              avatar: const Icon(Icons.flag_outlined, size: 16),
              popupItems: ChatViolationStatus.values.map((e) {
                 return PopupMenuItem(
                    value: e,
                    child: Text(_statusLabel(e.name)),
                    onTap: () => onStatusChanged(e),
                  );
              }).toList(),
            ),
            _FilterChip(
              label: 'Mức độ: ${_severityLabel(state.filter.severity.name)}',
              selected: state.filter.severity != ChatViolationSeverity.all,
              onSelected: (_) {},
              avatar: const Icon(Icons.warning_amber_rounded, size: 16),
              popupItems: ChatViolationSeverity.values.map((e) {
                 return PopupMenuItem(
                    value: e,
                    child: Text(_severityLabel(e.name)),
                    onTap: () => onSeverityChanged(e),
                  );
              }).toList(),
            ),
          ],
        ),
      ],
    );
  }

  String _timeRangeLabel(ChatViolationTimeRange range) {
    switch (range) {
      case ChatViolationTimeRange.last24h: return '24 giờ qua';
      case ChatViolationTimeRange.last7d: return '7 ngày qua';
      case ChatViolationTimeRange.last30d: return '30 ngày qua';
      case ChatViolationTimeRange.all: return 'Tất cả';
    }
  }

  String _statusLabel(String status) {
     if (status == 'all') return 'Tất cả';
     return _topLevelStatusLabel(status);
  }

  String _severityLabel(String severity) {
     if (severity == 'all') return 'Tất cả';
     final label = severity.toUpperCase();
     if (label == 'CRITICAL') return 'Nghiêm trọng';
     if (label == 'HIGH') return 'Cao';
     if (label == 'MEDIUM') return 'TB';
     if (label == 'LOW') return 'Thấp';
     return label;
  }
}

class _FilterChip<T> extends StatelessWidget {
  final String label;
  final bool selected;
  final ValueChanged<bool> onSelected;
  final List<PopupMenuEntry<T>>? popupItems;
  final Widget? avatar;

  const _FilterChip({
    required this.label,
    required this.selected,
    required this.onSelected,
    this.popupItems,
    this.avatar,
  });

  @override
  Widget build(BuildContext context) {
    if (popupItems != null) {
      return PopupMenuButton<T>(
        itemBuilder: (_) => popupItems!,
        child: InputChip(
          label: Text(label),
          selected: selected,
          onSelected: null,
          isEnabled: true,
          avatar: avatar,
          deleteIcon: const Icon(Icons.arrow_drop_down, size: 18),
          onDeleted: () {}, // Hack to show drop down arrow
        ),
      );
    }
    return FilterChip(
      label: Text(label),
      selected: selected,
      onSelected: onSelected,
      avatar: avatar,
    );
  }
}


class _ViolationCard extends StatelessWidget {
  const _ViolationCard({
    required this.record,
    required this.onActionTap,
  });

  final ChatViolationRecord record;
  final VoidCallback onActionTap;

  @override
  Widget build(BuildContext context) {
    final v = record.violation;
    final user = record.offender;
    final chat = record.chat;
    final theme = Theme.of(context);
    final isCritical = v.severity.toLowerCase() == 'high' || v.severity.toLowerCase() == 'critical';

    return Card(
      elevation: 0,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(12),
        side: BorderSide(
          color: theme.colorScheme.outlineVariant.withValues(alpha: 0.6),
        ),
      ),
      color: isCritical 
        ? theme.colorScheme.errorContainer.withValues(alpha: 0.05) 
        : theme.colorScheme.surface,
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Header: Severity + Date
            Row(
              children: [
                 _SeverityIndicator(severity: v.severity),
                 const SizedBox(width: 8),
                 Text(
                   _translateType(v.type),
                   style: theme.textTheme.labelMedium?.copyWith(
                     color: theme.colorScheme.secondary,
                     fontWeight: FontWeight.bold,
                   ),
                 ),
                 const Spacer(),
                 Text(
                   _timeLabel(v.createdAt),
                   style: theme.textTheme.bodySmall?.copyWith(
                     color: theme.colorScheme.onSurfaceVariant,
                   ),
                 ),
              ],
            ),
            const SizedBox(height: 12),
            
            // Title & Reason
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Wrap(
                        spacing: 6,
                        runSpacing: 6,
                        children: v.violationCategories.map((c) {
                          return Text(
                            _formatReason(c),
                            style: theme.textTheme.titleMedium?.copyWith(
                              fontWeight: FontWeight.bold,
                            ),
                          );
                        }).toList(),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        v.messageSummary,
                        style: theme.textTheme.bodyMedium?.copyWith(
                          color: theme.colorScheme.onSurface,
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
            const SizedBox(height: 16),

             // Info Box
             Container(
               padding: const EdgeInsets.all(12),
               decoration: BoxDecoration(
                 color: theme.colorScheme.surfaceContainerHighest.withValues(alpha: 0.3),
                 borderRadius: BorderRadius.circular(8),
               ),
               child: Row(
                 crossAxisAlignment: CrossAxisAlignment.center,
                 children: [
                    // User Info
                    Expanded(
                      flex: 4,
                      child: Row(
                        children: [
                          CircleAvatar(
                            radius: 16,
                            backgroundColor: theme.colorScheme.primaryContainer,
                            backgroundImage: user?.photoUrl != null
                              ? NetworkImage(user!.photoUrl!)
                              : null,
                            child: user?.photoUrl == null
                              ? Text(
                                  _avatarLabel(user, v.offenderId),
                                  style: TextStyle(
                                    fontSize: 12, 
                                    color: theme.colorScheme.onPrimaryContainer
                                  ),
                                )
                              : null,
                          ),
                          const SizedBox(width: 10),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  user?.displayName ?? 'Người dùng',
                                  style: theme.textTheme.labelLarge?.copyWith(fontWeight: FontWeight.bold),
                                  maxLines: 1,
                                  overflow: TextOverflow.ellipsis,
                                ),
                                Text(
                                  _shortId(v.offenderId),
                                  style: theme.textTheme.bodySmall?.copyWith(
                                    color: theme.colorScheme.onSurfaceVariant,
                                    fontSize: 10
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ],
                      ),
                    ),
                    
                    Container(
                      width: 1, 
                      height: 24, 
                      color: theme.colorScheme.outlineVariant, 
                      margin: const EdgeInsets.symmetric(horizontal: 8)
                    ),
                    
                    // Chat Info
                    Expanded(
                      flex: 3,
                      child: Row(
                        children: [
                           Icon(
                             chat?.isGroup == true ? Icons.groups_outlined : Icons.chat_bubble_outline, 
                             size: 16,
                             color: theme.colorScheme.secondary,
                           ),
                           const SizedBox(width: 6),
                           Expanded(
                             child: Text(
                               chat?.name ?? (chat?.isGroup == true ? 'Nhóm' : 'Tin nhắn'),
                               style: theme.textTheme.labelMedium,
                               maxLines: 1,
                               overflow: TextOverflow.ellipsis,
                             ),
                           ),
                        ],
                      ),
                    ),
                 ],
               ),
             ),

            const SizedBox(height: 16),
            
            // Footer: Button + Status
            Row(
              mainAxisAlignment: MainAxisAlignment.end,
              children: [
                StatusBadge(
                  label: _topLevelStatusLabel(v.status),
                  variant: _statusVariant(v.status),
                ),
                const Spacer(),
                FilledButton.tonalIcon(
                  onPressed: onActionTap,
                  icon: const Icon(Icons.settings, size: 18),
                  label: const Text('Xử lý'),
                  style: FilledButton.styleFrom(
                    padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 0),
                  ),
                ),
              ],
            )
          ],
        ),
      ),
    );
  }

  String _formatReason(String raw) {
    String clean = raw.replaceAll(RegExp(r'[\[\]]'), ''); // remove []
    if (clean.toUpperCase() == 'USER_REPORT') return 'Người dùng báo cáo';
    if (clean.isEmpty) return 'Vi phạm';
    // Capitalize first letter
    return clean[0].toUpperCase() + clean.substring(1);
  }
  
  String _translateType(String type) {
    if (type == 'message') return 'Tin nhắn';
    if (type == 'image') return 'Hình ảnh';
    if (type == 'video') return 'Video';
    return type.toUpperCase();
  }
}

class _ViolationActionSheet extends ConsumerStatefulWidget {
  const _ViolationActionSheet({required this.record});

  final ChatViolationRecord record;

  @override
  ConsumerState<_ViolationActionSheet> createState() =>
      _ViolationActionSheetState();
}

class _ViolationActionSheetState
    extends ConsumerState<_ViolationActionSheet> {
  late final TextEditingController _notesController;
  final TextEditingController _muteDaysController = TextEditingController();
  late Future<ChatViolationMetrics> _metricsFuture;

  @override
  void initState() {
    super.initState();
    _notesController =
        TextEditingController(text: widget.record.violation.notes ?? '');
    _metricsFuture = ref
        .read(adminChatModerationControllerProvider.notifier)
        .fetchMetrics(
          offenderId: widget.record.violation.offenderId,
          chatId: widget.record.violation.chatId,
        );
  }

  @override
  void dispose() {
    _notesController.dispose();
    _muteDaysController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final v = widget.record.violation;
    final user = widget.record.offender;
    final chat = widget.record.chat;
    final controller = ref.read(adminChatModerationControllerProvider.notifier);
    final state = ref.watch(adminChatModerationControllerProvider);
    final currentAdmin = FirebaseAuth.instance.currentUser?.uid;

    return Container(
      decoration: BoxDecoration(
        color: theme.colorScheme.surface,
        borderRadius: const BorderRadius.vertical(top: Radius.circular(20)),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.1),
            blurRadius: 10,
            offset: const Offset(0, -2),
          ),
        ],
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          // Drag handle
          Center(
            child: Container(
              margin: const EdgeInsets.only(top: 12, bottom: 8),
              width: 32,
              height: 4,
              decoration: BoxDecoration(
                color: theme.colorScheme.outlineVariant,
                borderRadius: BorderRadius.circular(2),
              ),
            ),
          ),
          
          Expanded(
            child: ListView(
              padding: const EdgeInsets.all(24),
              children: [
                // Header Title
                Row(
                  children: [
                    Icon(Icons.shield, color: theme.colorScheme.primary),
                    const SizedBox(width: 8),
                    Text(
                      'Chi tiết vi phạm',
                      style: theme.textTheme.headlineSmall,
                    ),
                    const Spacer(),
                    IconButton(
                      icon: const Icon(Icons.close),
                      onPressed: () => Navigator.of(context).pop(),
                    ),
                  ],
                ),
                const SizedBox(height: 24),

                // Stats Row
                FutureBuilder<ChatViolationMetrics>(
                  future: _metricsFuture,
                  builder: (context, snapshot) {
                     if (!snapshot.hasData) return const LinearProgressIndicator();
                     final m = snapshot.data!;
                     return Row(
                       children: [
                         _StatItem(label: '7 ngày', value: '${m.userViolations7d} vi phạm', icon: Icons.history),
                         const SizedBox(width: 12),
                         _StatItem(label: 'Tổng cộng', value: '${m.userViolationsAllTime} vi phạm', icon: Icons.person_off),
                       ],
                     );
                  },
                ),
                const SizedBox(height: 24),

                // Evidence Box
                _buildEvidenceBox(v, theme),
                const SizedBox(height: 24),

                // Admin Note Input
                TextField(
                  controller: _notesController,
                  maxLines: 3,
                  decoration: InputDecoration(
                    labelText: 'Ghi chú xử lý (Nội bộ)',
                    hintText: 'Nhập lý do xử lý hoặc ghi chú cho admin khác...',
                    border: const OutlineInputBorder(),
                    filled: true,
                    fillColor: theme.colorScheme.surfaceContainerLow,
                  ),
                ),
                const SizedBox(height: 24),

                // Actions Section
                Text('Hành động', style: theme.textTheme.titleMedium?.copyWith(fontWeight: FontWeight.bold)),
                const SizedBox(height: 12),
                
                // Group 1: Non-punitive
                Row(
                  children: [
                    Expanded(
                      child: OutlinedButton.icon(
                        icon: const Icon(Icons.check_circle_outline),
                        label: const Text('Đã xem / Bỏ qua'),
                        onPressed: state.actionInProgress
                          ? null 
                          : () async {
                             await controller.ignoreViolation(
                               violation: v,
                               notes: _notesController.text.trim(),
                               reviewerId: currentAdmin,
                             );
                             if (context.mounted) Navigator.pop(context);
                          },
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: FilledButton.tonalIcon(
                         icon: const Icon(Icons.warning_amber),
                         label: const Text('Cảnh cáo'),
                         onPressed: state.actionInProgress
                           ? null
                           : () async {
                              await controller.warnViolation(
                                violation: v,
                                notes: _notesController.text.trim(),
                                reviewerId: currentAdmin,
                              );
                              if (context.mounted) Navigator.pop(context);
                           },
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 12),
                
                // Group 2: Punitive (Mute/Ban)
                Card(
                   elevation: 0,
                   color: theme.colorScheme.errorContainer.withValues(alpha: 0.1),
                   shape: RoundedRectangleBorder(
                     borderRadius: BorderRadius.circular(12),
                     side: BorderSide(color: theme.colorScheme.error.withValues(alpha: 0.2)),
                   ),
                   child: Padding(
                     padding: const EdgeInsets.all(16),
                     child: Column(
                       crossAxisAlignment: CrossAxisAlignment.start,
                       children: [
                         Text(
                           'Xử phạt nghiêm trọng', 
                           style: theme.textTheme.labelLarge?.copyWith(
                             color: theme.colorScheme.error,
                             fontWeight: FontWeight.bold
                           ),
                         ),
                         const SizedBox(height: 12),
                         Row(
                           children: [
                             Expanded(
                               flex: 2,
                               child: TextField(
                                 controller: _muteDaysController,
                                 keyboardType: TextInputType.number,
                                 decoration: const InputDecoration(
                                   labelText: 'Ngày',
                                   isDense: true,
                                   border: OutlineInputBorder(),
                                 ),
                               ),
                             ),
                             const SizedBox(width: 12),
                             Expanded(
                               flex: 3,
                               child: FilledButton.icon(
                                  style: FilledButton.styleFrom(
                                    backgroundColor: theme.colorScheme.error,
                                    foregroundColor: theme.colorScheme.onError,
                                  ),
                                  icon: const Icon(Icons.volume_off),
                                  label: const Text('Cấm Chat'),
                                  onPressed: state.actionInProgress ? null : () async {
                                     final days = int.tryParse(_muteDaysController.text.trim());
                                     String extra = '';
                                     if (days != null && days > 0) extra = 'Cấm $days ngày. ';
                                     
                                     await controller.updateStatus(
                                       violationId: v.id,
                                       status: ChatViolationStatus.muted,
                                       notes: '$extra${_notesController.text}'.trim(),
                                       reviewerId: currentAdmin,
                                     );
                                     if (context.mounted) Navigator.pop(context);
                                  },
                               ),
                             ),
                             const SizedBox(width: 8),
                             Expanded(
                               flex: 3,
                               child: OutlinedButton.icon(
                                 style: OutlinedButton.styleFrom(
                                   foregroundColor: theme.colorScheme.error,
                                   side: BorderSide(color: theme.colorScheme.error),
                                 ),
                                 icon: const Icon(Icons.block),
                                 label: Text(user?.isBanned == true ? 'Gỡ Ban' : 'Ban User'),
                                 onPressed: state.actionInProgress ? null : () {
                                    // Calls logic defined in previous implementation, adapted inline here or extracted method
                                    _confirmBan(
                                      context,
                                      controller: controller,
                                      ban: user?.isBanned != true,
                                      violation: v,
                                      notesController: _notesController,
                                      currentAdmin: currentAdmin,
                                    );
                                 },
                               ),
                             ),
                           ],
                         ),
                       ],
                     ),
                   ),
                ),
                
                const SizedBox(height: 24),
                // Lock chat danger zone
                if (chat != null) ...[
                  const SizedBox(height: 24),
                  Text('Quản lý Chat',
                      style: theme.textTheme.titleMedium
                          ?.copyWith(fontWeight: FontWeight.bold)),
                  const SizedBox(height: 12),
                  Row(
                    children: [
                      Expanded(
                        child: OutlinedButton.icon(
                          onPressed: state.actionInProgress
                              ? null
                              : () async {
                                  if (chat.isLocked) {
                                    await controller.unlockChat(
                                      chatId: chat.id,
                                      violationId: v.id,
                                      reviewerId: currentAdmin,
                                    );
                                  } else {
                                    await controller.lockChatFromViolation(
                                      violation: v,
                                      reviewerId: currentAdmin,
                                    );
                                  }
                                  if (context.mounted) Navigator.pop(context);
                                },
                          icon: Icon(chat.isLocked
                              ? Icons.lock_open
                              : Icons.lock_outline),
                          label: Text(chat.isLocked
                              ? 'Mở khóa Chat'
                              : 'Khóa Chat'),
                          style: OutlinedButton.styleFrom(
                            foregroundColor: theme.colorScheme.onSurfaceVariant,
                          ),
                        ),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: OutlinedButton.icon(
                          onPressed: state.actionInProgress
                              ? null
                              : () => _confirmDeleteChat(
                                    context,
                                    controller: controller,
                                    chatId: chat.id,
                                    violationId: v.id,
                                    reviewerId: currentAdmin,
                                  ),
                          icon: const Icon(Icons.delete_outline),
                          label: const Text('Xóa nhóm/Chat'),
                          style: OutlinedButton.styleFrom(
                            foregroundColor: theme.colorScheme.error,
                            side: BorderSide(color: theme.colorScheme.error),
                          ),
                        ),
                      ),
                    ],
                  ),
                ],
                 const SizedBox(height: 48), // Bottom padding
              ],
            ),
          ),
        ],
      ),
    );
  }

  Future<void> _confirmDeleteChat(
    BuildContext context, {
    required AdminChatModerationController controller,
    required String chatId,
    required String violationId,
    required String? reviewerId,
  }) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Xóa cuộc trò chuyện?'),
        content: const Text(
            'Hành động này không thể hoàn tác. Nhóm chat và tin nhắn sẽ bị xóa vĩnh viễn.'),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(false),
            child: const Text('Huỷ'),
          ),
          FilledButton(
            onPressed: () => Navigator.of(context).pop(true),
            style: FilledButton.styleFrom(
                backgroundColor: Theme.of(context).colorScheme.error),
            child: const Text('Xóa vĩnh viễn'),
          ),
        ],
      ),
    );

    if (confirmed == true && context.mounted) {
      await controller.deleteChat(
        chatId: chatId,
        violationId: violationId,
        reviewerId: reviewerId,
      );
      if (context.mounted) Navigator.pop(context);
    }
  }

  Widget _buildEvidenceBox(ChatViolation v, ThemeData theme) {
     if (v.evidenceMessages.isEmpty) {
       return Card(
         child: Padding(
           padding: const EdgeInsets.all(16),
           child: Text('Không có tin nhắn ngữ cảnh.', style: theme.textTheme.bodyMedium),
         ),
       );
     }
     
     return Container(
       decoration: BoxDecoration(
          color: theme.colorScheme.surfaceContainerHigh,
          borderRadius: BorderRadius.circular(12),
       ),
       padding: const EdgeInsets.all(16),
       child: Column(
         crossAxisAlignment: CrossAxisAlignment.start,
         children: [
           Text('Đoạn chat (Bằng chứng)', style: theme.textTheme.labelMedium?.copyWith(color: theme.colorScheme.primary)),
           const SizedBox(height: 12),
           ...v.evidenceMessages.map((msg) {
              final sender = msg['senderId']?.toString().substring(0, 5) ?? 'User';
              final text = msg['text']?.toString() ?? '';
              
              return Padding(
                padding: const EdgeInsets.only(bottom: 8),
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    CircleAvatar(radius: 10, child: Text(sender[0], style: const TextStyle(fontSize: 10))),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Container(
                        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                        decoration: BoxDecoration(
                           color: theme.colorScheme.surface,
                           borderRadius: BorderRadius.circular(12).copyWith(topLeft: Radius.zero),
                        ),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                             Text(sender, style: TextStyle(fontSize: 10, color: theme.colorScheme.secondary, fontWeight: FontWeight.bold)),
                             const SizedBox(height: 2),
                             Text(text, style: theme.textTheme.bodyMedium),
                          ],
                        ),
                      ),
                    ),
                  ],
                ),
              );
           }),
         ],
       ),
     );
  }
  
  Future<void> _confirmBan(
    BuildContext context, {
    required AdminChatModerationController controller,
    required bool ban,
    required ChatViolation violation,
    required TextEditingController notesController,
    required String? currentAdmin,
  }) async {
    final navigator = Navigator.of(context);

    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: Text(ban ? 'Cấm người dùng?' : 'Gỡ cấm người dùng?'),
        content: Text(
          ban
              ? 'Hành động này sẽ ngăn người dùng đăng nhập và sử dụng ứng dụng. Bạn có chắc chắn?'
              : 'Cho phép người dùng hoạt động trở lại?',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(false),
            child: const Text('Huỷ'),
          ),
          FilledButton(
            onPressed: () => Navigator.of(context).pop(true),
            style: FilledButton.styleFrom(backgroundColor: ban ? Colors.red : null),
            child: Text(ban ? 'Cấm vĩnh viễn' : 'Gỡ cấm'),
          ),
        ],
      ),
    );
    if (confirmed != true) return;

    if (ban) {
      await controller.banUserFromViolation(
        violation: violation,
        reason:
            notesController.text.trim().isEmpty ? null : notesController.text.trim(),
        reviewerId: currentAdmin,
      );
    } else {
      await controller.unbanUser(violation.offenderId);
      await controller.ignoreViolation(
        violation: violation,
        notes: notesController.text.trim(),
        reviewerId: currentAdmin,
      );
    }
    if (!mounted) return;
    navigator.pop();
  }
}

class _StatItem extends StatelessWidget {
  final String label;
  final String value;
  final IconData icon;
  
  const _StatItem({required this.label, required this.value, required this.icon});
  
  @override
  Widget build(BuildContext context) {
    return Expanded(
      child: Container(
        padding: const EdgeInsets.all(12),
        decoration: BoxDecoration(
          color: Theme.of(context).colorScheme.secondaryContainer.withValues(alpha: 0.5),
          borderRadius: BorderRadius.circular(8),
        ),
        child: Column(
          children: [
            Icon(icon, size: 20, color: Theme.of(context).colorScheme.primary),
            const SizedBox(height: 4),
            Text(value, style: Theme.of(context).textTheme.titleMedium?.copyWith(fontWeight: FontWeight.bold)),
            Text(label, style: Theme.of(context).textTheme.bodySmall),
          ],
        ),
      ),
    );
  }
}

class _SeverityIndicator extends StatelessWidget {
  final String severity;
  const _SeverityIndicator({required this.severity});
  
  @override
  Widget build(BuildContext context) {
     Color color;
     String label = severity.toUpperCase();
     switch (label) {
       case 'CRITICAL': color = Colors.red; break;
       case 'HIGH': color = Colors.orange; break;
       case 'MEDIUM': color = Colors.amber; break;
       default: color = Colors.green;
     }
     
     return Container(
       padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
       decoration: BoxDecoration(
         color: color.withValues(alpha: 0.2),
         borderRadius: BorderRadius.circular(4),
         border: Border.all(color: color.withValues(alpha: 0.5), width: 1),
       ),
       child: Text(
         label == 'CRITICAL' ? 'NGHIÊM TRỌNG' : 
         label == 'HIGH' ? 'CAO' :
         label == 'MEDIUM' ? 'TB' : 'THẤP',
         style: TextStyle(color: color.withValues(alpha: 1), fontSize: 10, fontWeight: FontWeight.bold),
       ),
     );
  }
}

// Helpers
String _avatarLabel(AdminChatUser? user, String uid) {
    final source = user?.displayName ?? user?.email ?? uid;
    return source.isNotEmpty ? source[0].toUpperCase() : '?';
}

String _shortId(String id) {
  if (id.length <= 6) return id;
  return '${id.substring(0, 4)}…${id.substring(id.length - 2)}';
}

String _timeLabel(DateTime createdAt) {
    final now = DateTime.now();
    final diff = now.difference(createdAt);
    if (diff.inMinutes < 60) {
      return '${diff.inMinutes}p trước';
    } else if (diff.inHours < 24) {
      return '${diff.inHours}h trước';
    } else {
      return '${diff.inDays}d trước';
    }
}

String _topLevelStatusLabel(String status) {
  switch (status.toLowerCase()) {
    case 'pending': return 'Chờ xử lý';
    case 'warning': return 'Đã cảnh cáo';
    case 'muted': return 'Đã ẩn';
    case 'banned': return 'Đã cấm';
    case 'ignored': return 'Đã bỏ qua';
    case 'resolved': return 'Đã xử lý';
    default: return status;
  }
}

StatusVariant _statusVariant(String status) {
  final normalized = status.toLowerCase();
  switch (normalized) {
    case 'pending':
      return StatusVariant.pending;
    case 'warning':
      return StatusVariant.reported;
    case 'muted':
      return StatusVariant.disabled;
    case 'banned':
      return StatusVariant.disabled;
    case 'chat_locked':
      return StatusVariant.disabled;
    case 'chat_unlocked':
      return StatusVariant.resolved;
    case 'ignored':
    default:
      return StatusVariant.ignored;
  }
}

class _ErrorView extends StatelessWidget {
  const _ErrorView({required this.message, required this.onRetry});

  final String message;
  final VoidCallback onRetry;

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(Icons.error_outline, size: 48, color: Theme.of(context).colorScheme.error),
          const SizedBox(height: 16),
          Text('Đã xảy ra lỗi tải dữ liệu', style: Theme.of(context).textTheme.titleMedium),
          Text(message, textAlign: TextAlign.center, style: Theme.of(context).textTheme.bodySmall),
          const SizedBox(height: 16),
          FilledButton.icon(
            onPressed: onRetry,
            icon: const Icon(Icons.refresh_rounded),
            label: const Text('Thử lại'),
          ),
        ],
      ),
    );
  }
}

class _LoadingList extends StatelessWidget {
  const _LoadingList();

  @override
  Widget build(BuildContext context) {
    return ListView.separated(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      itemBuilder: (_, __) => Card(
        elevation: 0,
        color: Theme.of(context).colorScheme.surfaceContainerHighest.withValues(alpha: 0.3),
        child: const SizedBox(height: 120),
      ),
      separatorBuilder: (_, __) => const SizedBox(height: 12),
      itemCount: 4,
    );
  }
}

class _EmptyViolationsView extends StatelessWidget {
  const _EmptyViolationsView();

  @override
  Widget build(BuildContext context) {
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        Icon(Icons.check_circle_outline,
            size: 64, color: Theme.of(context).colorScheme.primary.withValues(alpha: 0.5)),
        const SizedBox(height: 16),
        Text('Tuyệt vời! Không có vi phạm nào.', 
           style: Theme.of(context).textTheme.titleMedium?.copyWith(color: Theme.of(context).colorScheme.secondary)),
      ],
    );
  }
}
