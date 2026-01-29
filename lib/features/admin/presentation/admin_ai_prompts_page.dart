import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../app/theme.dart';
import '../application/ai_config_controller.dart';
import '../data/ai_config_repository.dart';
import 'admin_shell_scaffold.dart';

class AdminAiPromptsPage extends ConsumerStatefulWidget {
  const AdminAiPromptsPage({super.key});

  @override
  ConsumerState<AdminAiPromptsPage> createState() => _AdminAiPromptsPageState();
}

class _AdminAiPromptsPageState extends ConsumerState<AdminAiPromptsPage> {
  final _searchController = TextEditingController();
  String _searchQuery = '';

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final state = ref.watch(aiConfigListControllerProvider);

    return AdminShell(
      child: Scaffold(
        floatingActionButton: FloatingActionButton.extended(
          onPressed: () => _showCreateConfigDialog(context),
          icon: const Icon(Icons.add),
          label: const Text('Tạo config mới'),
        ),
        body: SafeArea(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Padding(
                padding: const EdgeInsets.all(AppSpacing.s16),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                'Quản lý AI Prompts',
                                style: Theme.of(context).textTheme.headlineSmall,
                              ),
                              const SizedBox(height: AppSpacing.s4),
                              Text(
                                'Tùy chỉnh prompts cho các tính năng AI: gợi ý tìm kiếm, lập kế hoạch tuần, shopping list...',
                                style: Theme.of(context)
                                    .textTheme
                                    .bodyMedium
                                    ?.copyWith(
                                      color: Theme.of(context)
                                          .colorScheme
                                          .onSurface
                                          .withValues(alpha: 0.7),
                                    ),
                              ),
                            ],
                          ),
                        ),
                        const SizedBox(width: AppSpacing.s16),
                        IconButton.filledTonal(
                          onPressed: () => _showBulkActionsDialog(context),
                          icon: const Icon(Icons.more_vert),
                          tooltip: 'Thêm tùy chọn',
                        ),
                      ],
                    ),
                    const SizedBox(height: AppSpacing.s16),
                    // Search bar
                    TextField(
                      controller: _searchController,
                      decoration: InputDecoration(
                        hintText: 'Tìm kiếm config...',
                        prefixIcon: const Icon(Icons.search),
                        suffixIcon: _searchQuery.isNotEmpty
                            ? IconButton(
                                icon: const Icon(Icons.clear),
                                onPressed: () {
                                  _searchController.clear();
                                  setState(() => _searchQuery = '');
                                },
                              )
                            : null,
                      ),
                      onChanged: (value) {
                        setState(() => _searchQuery = value);
                      },
                    ),
                  ],
                ),
              ),
              Expanded(
                child: state.configs.when(
                  loading: () => const Center(child: CircularProgressIndicator()),
                  error: (err, _) => _ErrorView(message: err.toString()),
                  data: (configs) {
                    if (configs.isEmpty) {
                      return const _EmptyView();
                    }

                    // Filter configs
                    final filtered = configs.where((c) {
                      if (_searchQuery.isEmpty) return true;
                      final query = _searchQuery.toLowerCase();
                      return (c.name?.toLowerCase().contains(query) ?? false) ||
                          c.id.toLowerCase().contains(query) ||
                          (c.description?.toLowerCase().contains(query) ?? false);
                    }).toList();

                    if (filtered.isEmpty) {
                      return Center(
                        child: Column(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Icon(
                              Icons.search_off,
                              size: 48,
                              color: Theme.of(context)
                                  .colorScheme
                                  .onSurface
                                  .withValues(alpha: 0.3),
                            ),
                            const SizedBox(height: AppSpacing.s16),
                            Text(
                              'Không tìm thấy config',
                              style: Theme.of(context).textTheme.titleMedium,
                            ),
                          ],
                        ),
                      );
                    }

                    return Column(
                      children: [
                        // Stats
                        _StatsBar(configs: configs),
                        const SizedBox(height: AppSpacing.s8),
                        // List
                        Expanded(
                          child: ListView.separated(
                            padding: const EdgeInsets.all(AppSpacing.s16),
                            itemCount: filtered.length,
                            separatorBuilder: (_, __) =>
                                const SizedBox(height: AppSpacing.s12),
                            itemBuilder: (context, index) {
                              final config = filtered[index];
                              return _AiConfigCard(config: config);
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
        ),
      ),
    );
  }

  void _showCreateConfigDialog(BuildContext context) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Tạo config mới'),
        content: const Text(
          'Tính năng này đang được phát triển.\n\nHiện tại, bạn có thể:\n'
          '1. Khởi tạo configs mặc định\n'
          '2. Chỉnh sửa configs hiện có\n'
          '3. Tạo mới trực tiếp trong Firestore console',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Đóng'),
          ),
        ],
      ),
    );
  }

  void _showBulkActionsDialog(BuildContext context) async {
    final controller = ref.read(aiConfigListControllerProvider.notifier);

    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Tùy chọn'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            ListTile(
              leading: const Icon(Icons.refresh),
              title: const Text('Làm mới'),
              onTap: () {
                Navigator.pop(context);
                // The stream will auto-refresh
              },
            ),
            ListTile(
              leading: const Icon(Icons.add_circle_outline),
              title: const Text('Khởi tạo defaults'),
              onTap: () async {
                Navigator.pop(context);
                try {
                  await controller.seedDefaults();
                  if (context.mounted) {
                    ScaffoldMessenger.of(context).showSnackBar(
                      const SnackBar(
                        content: Text('Đã khởi tạo AI configs mặc định'),
                      ),
                    );
                  }
                } catch (e) {
                  if (context.mounted) {
                    ScaffoldMessenger.of(context).showSnackBar(
                      SnackBar(content: Text('Lỗi: $e')),
                    );
                  }
                }
              },
            ),
          ],
        ),
      ),
    );
  }
}

class _StatsBar extends StatelessWidget {
  const _StatsBar({required this.configs});

  final List<AiConfig> configs;

  @override
  Widget build(BuildContext context) {
    final enabled = configs.where((c) => c.enabled).length;
    final disabled = configs.length - enabled;

    return Container(
      margin: const EdgeInsets.symmetric(horizontal: AppSpacing.s16),
      padding: const EdgeInsets.all(AppSpacing.s12),
      decoration: BoxDecoration(
        color: Theme.of(context)
            .colorScheme
            .primaryContainer
            .withValues(alpha: 0.3),
        borderRadius: BorderRadius.circular(AppRadii.medium),
      ),
      child: Row(
        children: [
          Expanded(
            child: _StatChip(
              label: 'Tổng',
              value: configs.length.toString(),
              icon: Icons.settings_suggest_outlined,
              color: Theme.of(context).colorScheme.primary,
            ),
          ),
          const SizedBox(width: AppSpacing.s8),
          Expanded(
            child: _StatChip(
              label: 'Đang bật',
              value: enabled.toString(),
              icon: Icons.check_circle_outline,
              color: Colors.green,
            ),
          ),
          const SizedBox(width: AppSpacing.s8),
          Expanded(
            child: _StatChip(
              label: 'Đang tắt',
              value: disabled.toString(),
              icon: Icons.block_outlined,
              color: Colors.orange,
            ),
          ),
        ],
      ),
    );
  }
}

class _StatChip extends StatelessWidget {
  const _StatChip({
    required this.label,
    required this.value,
    required this.icon,
    required this.color,
  });

  final String label;
  final String value;
  final IconData icon;
  final Color color;

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Icon(icon, size: 16, color: color),
        const SizedBox(width: 6),
        Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              value,
              style: Theme.of(context).textTheme.titleMedium?.copyWith(
                    fontWeight: FontWeight.bold,
                    color: color,
                  ),
            ),
            Text(
              label,
              style: Theme.of(context).textTheme.bodySmall,
            ),
          ],
        ),
      ],
    );
  }
}

class _AiConfigCard extends ConsumerWidget {
  const _AiConfigCard({required this.config});

  final AiConfig config;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final controller = ref.read(aiConfigListControllerProvider.notifier);
    final theme = Theme.of(context);

    return Card(
      child: ExpansionTile(
        leading: Icon(
          _getIconForFeature(config.id),
          color: config.enabled
              ? theme.colorScheme.primary
              : theme.colorScheme.onSurface.withValues(alpha: 0.4),
        ),
        title: Text(
          config.name ?? config.id,
          style: theme.textTheme.titleMedium?.copyWith(
            color: config.enabled
                ? theme.colorScheme.onSurface
                : theme.colorScheme.onSurface.withValues(alpha: 0.6),
          ),
        ),
        subtitle: config.description != null
            ? Text(
                config.description!,
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
              )
            : null,
        trailing: Switch(
          value: config.enabled,
          onChanged: (value) {
            controller.toggleEnabled(config.id, value);
          },
        ),
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(
              AppSpacing.s16,
              0,
              AppSpacing.s16,
              AppSpacing.s16,
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Expanded(
                      child: _InfoChip(
                        label: 'Model',
                        value: config.model,
                        icon: Icons.hub_outlined,
                      ),
                    ),
                    const SizedBox(width: AppSpacing.s8),
                    Expanded(
                      child: _InfoChip(
                        label: 'Temp',
                        value: config.temperature.toStringAsFixed(1),
                        icon: Icons.thermostat_outlined,
                      ),
                    ),
                    const SizedBox(width: AppSpacing.s8),
                    Expanded(
                      child: _InfoChip(
                        label: 'Max tokens',
                        value: config.maxOutputTokens.toString(),
                        icon: Icons.memory_outlined,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: AppSpacing.s16),
                _PromptSection(
                  title: 'System Prompt',
                  content: config.systemPrompt,
                ),
                const SizedBox(height: AppSpacing.s12),
                _PromptSection(
                  title: 'User Prompt Template',
                  content: config.userPromptTemplate,
                ),
                const SizedBox(height: AppSpacing.s16),
                Row(
                  mainAxisAlignment: MainAxisAlignment.end,
                  children: [
                    TextButton.icon(
                      onPressed: () => _showResetDialog(context, controller),
                      icon: const Icon(Icons.restore_outlined),
                      label: const Text('Reset về mặc định'),
                    ),
                    const SizedBox(width: AppSpacing.s8),
                    FilledButton.icon(
                      onPressed: () => _showEditDialog(context, config, controller),
                      icon: const Icon(Icons.edit_outlined),
                      label: const Text('Chỉnh sửa'),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  void _showEditDialog(
      BuildContext context, AiConfig config, AiConfigListController controller) {
    showDialog(
      context: context,
      builder: (context) => _EditAiConfigDialog(
        config: config,
        controller: controller,
      ),
    );
  }

  void _showResetDialog(
      BuildContext context, AiConfigListController controller) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Reset về mặc định?'),
        content: Text(
            'Bạn có chắc muốn xóa config này về mặc định từ functions?\n\nFeature ID: ${config.id}'),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(),
            child: const Text('Hủy'),
          ),
          FilledButton(
            onPressed: () async {
              // Delete config, functions sẽ tự dùng defaults
              await FirestoreAiConfigRepository().deleteConfig(config.id);
              if (context.mounted) Navigator.of(context).pop();
            },
            child: const Text('Reset'),
          ),
        ],
      ),
    );
  }

  IconData _getIconForFeature(String id) {
    switch (id) {
      case 'search':
        return Icons.search_rounded;
      case 'recipe_suggest':
        return Icons.lightbulb_outline_rounded;
      case 'meal_plan':
        return Icons.calendar_today_rounded;
      case 'nutrition':
        return Icons.analytics_outlined;
      case 'chef_chat':
        return Icons.chat_bubble_outline_rounded;
      case 'chat_moderation':
        return Icons.shield_outlined;
      case 'report_moderation':
        return Icons.flag_outlined;
      case 'recipe_enrich':
        return Icons.auto_awesome_outlined;
      default:
        return Icons.settings_suggest_outlined;
    }
  }
}

class _InfoChip extends StatelessWidget {
  const _InfoChip({
    required this.label,
    required this.value,
    required this.icon,
  });

  final String label;
  final String value;
  final IconData icon;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(
        horizontal: AppSpacing.s12,
        vertical: AppSpacing.s8,
      ),
      decoration: BoxDecoration(
        color: Theme.of(context)
            .colorScheme
            .surfaceContainerHighest
            .withValues(alpha: 0.6),
        borderRadius: BorderRadius.circular(AppRadii.small),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 16),
          const SizedBox(width: 6),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  label,
                  style: Theme.of(context).textTheme.labelSmall,
                ),
                Text(
                  value,
                  style: Theme.of(context).textTheme.bodySmall?.copyWith(
                        fontWeight: FontWeight.w600,
                      ),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _PromptSection extends StatelessWidget {
  const _PromptSection({
    required this.title,
    required this.content,
  });

  final String title;
  final String content;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          title,
          style: Theme.of(context).textTheme.titleSmall,
        ),
        const SizedBox(height: AppSpacing.s8),
        Container(
          width: double.infinity,
          padding: const EdgeInsets.all(AppSpacing.s12),
          decoration: BoxDecoration(
            color: Theme.of(context).colorScheme.surfaceContainerHigh,
            borderRadius: BorderRadius.circular(AppRadii.medium),
          ),
          child: SelectableText(
            content,
            style: Theme.of(context).textTheme.bodySmall?.copyWith(
                  fontFamily: 'monospace',
                  fontSize: 12,
                ),
          ),
        ),
      ],
    );
  }
}

class _EditAiConfigDialog extends StatefulWidget {
  const _EditAiConfigDialog({
    required this.config,
    required this.controller,
  });

  final AiConfig config;
  final AiConfigListController controller;

  @override
  State<_EditAiConfigDialog> createState() => _EditAiConfigDialogState();
}

class _EditAiConfigDialogState extends State<_EditAiConfigDialog> {
  late final TextEditingController _systemPromptCtrl;
  late final TextEditingController _userPromptCtrl;
  late final TextEditingController _modelCtrl;
  late final TextEditingController _tempCtrl;
  late final TextEditingController _maxTokensCtrl;

  @override
  void initState() {
    super.initState();
    _systemPromptCtrl = TextEditingController(text: widget.config.systemPrompt);
    _userPromptCtrl = TextEditingController(text: widget.config.userPromptTemplate);
    _modelCtrl = TextEditingController(text: widget.config.model);
    _tempCtrl = TextEditingController(text: widget.config.temperature.toString());
    _maxTokensCtrl =
        TextEditingController(text: widget.config.maxOutputTokens.toString());
  }

  @override
  void dispose() {
    _systemPromptCtrl.dispose();
    _userPromptCtrl.dispose();
    _modelCtrl.dispose();
    _tempCtrl.dispose();
    _maxTokensCtrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Dialog(
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 700, maxHeight: 700),
        child: Padding(
          padding: const EdgeInsets.all(AppSpacing.s24),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Expanded(
                    child: Text(
                      'Chỉnh sửa: ${widget.config.name ?? widget.config.id}',
                      style: Theme.of(context).textTheme.titleLarge,
                    ),
                  ),
                  IconButton(
                    onPressed: () => Navigator.pop(context),
                    icon: const Icon(Icons.close),
                  ),
                ],
              ),
              const SizedBox(height: AppSpacing.s16),
              Expanded(
                child: SingleChildScrollView(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      TextField(
                        controller: _modelCtrl,
                        decoration: const InputDecoration(
                          labelText: 'Model',
                          hintText: 'gpt-4.1-mini',
                        ),
                      ),
                      const SizedBox(height: AppSpacing.s12),
                      Row(
                        children: [
                          Expanded(
                            child: TextField(
                              controller: _tempCtrl,
                              decoration: const InputDecoration(
                                labelText: 'Temperature',
                                hintText: '0.7',
                              ),
                              keyboardType: TextInputType.number,
                            ),
                          ),
                          const SizedBox(width: AppSpacing.s12),
                          Expanded(
                            child: TextField(
                              controller: _maxTokensCtrl,
                              decoration: const InputDecoration(
                                labelText: 'Max Output Tokens',
                                hintText: '1024',
                              ),
                              keyboardType: TextInputType.number,
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: AppSpacing.s16),
                      TextField(
                        controller: _systemPromptCtrl,
                        minLines: 5,
                        maxLines: 10,
                        decoration: const InputDecoration(
                          labelText: 'System Prompt',
                          helperText:
                              'Hướng dẫn hệ thống cho AI, định nghĩa vai trò và nhiệm vụ',
                        ),
                      ),
                      const SizedBox(height: AppSpacing.s16),
                      TextField(
                        controller: _userPromptCtrl,
                        minLines: 5,
                        maxLines: 10,
                        decoration: const InputDecoration(
                          labelText: 'User Prompt Template',
                          helperText:
                              'Template cho input người dùng, dùng {{variable}} cho placeholders',
                        ),
                      ),
                    ],
                  ),
                ),
              ),
              const SizedBox(height: AppSpacing.s16),
              Row(
                mainAxisAlignment: MainAxisAlignment.end,
                children: [
                  TextButton(
                    onPressed: () => Navigator.pop(context),
                    child: const Text('Hủy'),
                  ),
                  const SizedBox(width: AppSpacing.s8),
                  FilledButton.icon(
                    onPressed: _save,
                    icon: const Icon(Icons.save_outlined),
                    label: const Text('Lưu'),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }

  Future<void> _save() async {
    final updates = <String, dynamic>{
      'model': _modelCtrl.text.trim(),
      'systemPrompt': _systemPromptCtrl.text.trim(),
      'userPromptTemplate': _userPromptCtrl.text.trim(),
      'temperature': double.tryParse(_tempCtrl.text.trim()) ?? 0.7,
      'maxOutputTokens': int.tryParse(_maxTokensCtrl.text.trim()) ?? 1024,
    };

    try {
      await widget.controller.updateConfig(widget.config.id, updates);
      if (!mounted) return;
      Navigator.pop(context);
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Đã lưu AI config')),
      );
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Lỗi: $e')),
      );
    }
  }
}

class _EmptyView extends ConsumerWidget {
  const _EmptyView();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final controller = ref.read(aiConfigListControllerProvider.notifier);
    final state = ref.watch(aiConfigListControllerProvider);

    return Center(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(
            Icons.settings_suggest_outlined,
            size: 64,
            color: Theme.of(context)
                .colorScheme
                .onSurface
                .withValues(alpha: 0.3),
          ),
          const SizedBox(height: AppSpacing.s16),
          Text(
            'Chưa có AI config nào',
            style: Theme.of(context).textTheme.titleMedium,
          ),
          const SizedBox(height: AppSpacing.s8),
          Text(
            'Các config sẽ được tự động tạo từ defaults trong Functions',
            style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                  color: Theme.of(context)
                      .colorScheme
                      .onSurface
                      .withValues(alpha: 0.6),
                ),
            textAlign: TextAlign.center,
          ),
          const SizedBox(height: AppSpacing.s24),
          FilledButton.icon(
            onPressed: state.isLoading
                ? null
                : () async {
                    try {
                      await controller.seedDefaults();
                      if (context.mounted) {
                        ScaffoldMessenger.of(context).showSnackBar(
                          const SnackBar(
                            content: Text('Đã khởi tạo AI configs mặc định'),
                          ),
                        );
                      }
                    } catch (e) {
                      if (context.mounted) {
                        ScaffoldMessenger.of(context).showSnackBar(
                          SnackBar(content: Text('Lỗi: $e')),
                        );
                      }
                    }
                  },
            icon: state.isLoading
                ? const SizedBox(
                    width: 16,
                    height: 16,
                    child: CircularProgressIndicator(
                      strokeWidth: 2,
                      color: Colors.white,
                    ),
                  )
                : const Icon(Icons.add_circle_outline),
            label: Text(
                state.isLoading ? 'Đang khởi tạo...' : 'Khởi tạo configs mặc định'),
          ),
        ],
      ),
    );
  }
}

class _ErrorView extends StatelessWidget {
  const _ErrorView({required this.message});

  final String message;

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(
            Icons.error_outline,
            size: 48,
            color: Theme.of(context).colorScheme.error,
          ),
          const SizedBox(height: AppSpacing.s16),
          Text(
            'Lỗi tải AI configs',
            style: Theme.of(context).textTheme.titleMedium,
          ),
          const SizedBox(height: AppSpacing.s8),
          Text(
            message,
            style: Theme.of(context).textTheme.bodySmall,
            textAlign: TextAlign.center,
          ),
        ],
      ),
    );
  }
}
