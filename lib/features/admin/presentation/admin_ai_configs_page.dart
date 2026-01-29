import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../data/admin_ai_config_repository.dart';
import 'admin_scaffold.dart';

class AdminAiConfigsPage extends ConsumerWidget {
  const AdminAiConfigsPage({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final configsAsync = ref.watch(aiConfigsProvider);

    return AdminShell(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Text(
                  'Prompt AI',
                  style: Theme.of(context).textTheme.headlineSmall,
                ),
                const Spacer(),
                FilledButton.icon(
                  onPressed: () => _promptCreate(context),
                  icon: const Icon(Icons.add),
                  label: const Text('Thêm cấu hình'),
                ),
              ],
            ),
            const SizedBox(height: 16),
            Expanded(
              child: configsAsync.when(
                data: (configs) {
                  if (configs.isEmpty) {
                    return const Center(
                      child:
                          Text('Chưa có cấu hình AI nào. Thêm mới để bắt đầu.'),
                    );
                  }

                  return ListView.separated(
                    itemCount: configs.length,
                    separatorBuilder: (_, __) => const Divider(height: 1),
                    itemBuilder: (context, index) {
                      final config = configs[index];
                      return _ConfigTile(config: config);
                    },
                  );
                },
                error: (err, __) => Center(
                  child: Text('Không tải được danh sách: $err'),
                ),
                loading: () => const Center(child: CircularProgressIndicator()),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Future<void> _promptCreate(BuildContext context) async {
    final controller = TextEditingController();
    final result = await showDialog<String>(
      context: context,
      builder: (context) {
        return AlertDialog(
          title: const Text('Tạo cấu hình mới'),
          content: TextField(
            controller: controller,
            decoration: const InputDecoration(
              labelText: 'ID (ví dụ: search, meal_plan)',
              hintText: 'Chỉ chứa chữ, số, gạch dưới',
            ),
            autofocus: true,
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(context).pop(),
              child: const Text('Huỷ'),
            ),
            FilledButton(
              onPressed: () {
                final id = controller.text.trim();
                if (id.isEmpty) return;
                Navigator.of(context).pop(id);
              },
              child: const Text('Tạo'),
            ),
          ],
        );
      },
    );

    final id = result?.trim();
    if (id == null || id.isEmpty) return;
    if (!context.mounted) return;
    context.go('/admin/ai-configs/${id.toLowerCase()}');
  }
}

class _ConfigTile extends StatelessWidget {
  const _ConfigTile({required this.config});

  final AdminAiConfig config;

  @override
  Widget build(BuildContext context) {
    final title = config.name?.isNotEmpty == true ? config.name! : config.id;
    final subtitle = config.description ?? '';
    final updatedByParts = <String>[];
    if (config.updatedByName != null) {
      updatedByParts.add(config.updatedByName!);
    }
    if (config.updatedAt != null) {
      updatedByParts
          .add(config.updatedAt!.toLocal().toString().split('.').first);
    }
    final updatedBy = updatedByParts.join(' • ');

    return ListTile(
      leading: Icon(
        config.enabled ? Icons.check_circle : Icons.pause_circle_filled,
        color: config.enabled
            ? Theme.of(context).colorScheme.primary
            : Theme.of(context).colorScheme.outline,
      ),
      title: Text(title),
      subtitle: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          if (subtitle.isNotEmpty) Text(subtitle),
          if (updatedBy.isNotEmpty)
            Text(
              updatedBy,
              style: Theme.of(context).textTheme.bodySmall,
            ),
        ],
      ),
      trailing: Wrap(
        spacing: 8,
        crossAxisAlignment: WrapCrossAlignment.center,
        children: [
          Chip(
            label: Text(config.model),
            visualDensity: VisualDensity.compact,
          ),
          Chip(
            label: Text(config.enabled ? 'Enabled' : 'Disabled'),
            backgroundColor: config.enabled
                ? Theme.of(context).colorScheme.secondaryContainer
                : Theme.of(context).colorScheme.surfaceContainerHighest,
            visualDensity: VisualDensity.compact,
          ),
          const Icon(Icons.chevron_right),
        ],
      ),
      onTap: () => context.go('/admin/ai-configs/${config.id}'),
    );
  }
}
