import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../app/theme.dart';
import 'admin_shell_scaffold.dart';
import 'widgets/admin_page_actions.dart';
import '../application/admin_settings_controller.dart';
import '../data/admin_settings_repository.dart';

class AdminSettingsPage extends ConsumerStatefulWidget {
  const AdminSettingsPage({super.key});

  @override
  ConsumerState<AdminSettingsPage> createState() => _AdminSettingsPageState();
}

class _AdminSettingsPageState extends ConsumerState<AdminSettingsPage> {
  final _guidelinesCtrl = TextEditingController();
  final _warningCtrl = TextEditingController();
  final _muteCtrl = TextEditingController();
  final _banCtrl = TextEditingController();
  final _autoHideCtrl = TextEditingController();

  String _language = 'vi';
  bool _aiModerationEnabled = true;
  bool _allowAlcohol = true;
  bool _allowMeat = true;
  bool _requireNutrition = false;
  bool _initialized = false;

  @override
  void dispose() {
    _guidelinesCtrl.dispose();
    _warningCtrl.dispose();
    _muteCtrl.dispose();
    _banCtrl.dispose();
    _autoHideCtrl.dispose();
    super.dispose();
  }

  void _apply(AdminSettings settings) {
    if (_initialized) return;
    _guidelinesCtrl.text = settings.communityGuidelines;
    _warningCtrl.text = settings.violationThresholds.warningCount.toString();
    _muteCtrl.text = settings.violationThresholds.muteCount.toString();
    _banCtrl.text = settings.violationThresholds.banCount.toString();
    _autoHideCtrl.text = settings.reportSettings.autoHideAfterReports.toString();

    _language = settings.aiLanguage;
    _aiModerationEnabled = settings.aiModerationEnabled;
    _allowAlcohol = settings.recipeContentRules.allowAlcohol;
    _allowMeat = settings.recipeContentRules.allowMeat;
    _requireNutrition = settings.recipeContentRules.requireNutritionForPublic;
    _initialized = true;
  }

  @override
  Widget build(BuildContext context) {
    final state = ref.watch(adminSettingsControllerProvider);
    final controller = ref.read(adminSettingsControllerProvider.notifier);

    return AdminShell(
      actions: [
        AdminPageActions(
          onRefresh: controller.refresh,
        ),
      ],
      child: SafeArea(
        child: state.settings.when(
          loading: () => const Center(child: CircularProgressIndicator()),
          error: (err, _) => _ErrorView(
            message: '$err',
            onRetry: controller.refresh,
          ),
          data: (settings) {
            final current = settings ?? AdminSettings.defaults();
            _apply(current);
            return SingleChildScrollView(
              padding: const EdgeInsets.all(AppSpacing.s16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'Cài đặt Admin',
                    style: Theme.of(context).textTheme.headlineSmall,
                  ),
                  const SizedBox(height: AppSpacing.s8),
                  Text(
                    'Quản lý chính sách cộng đồng và kiểm duyệt AI.',
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
                  const SizedBox(height: AppSpacing.s16),
                  _GuidelinesCard(controller: _guidelinesCtrl),
                  const SizedBox(height: AppSpacing.s12),
                  _AiModerationCard(
                    language: _language,
                    enabled: _aiModerationEnabled,
                    onEnabledChanged: (v) => setState(() => _aiModerationEnabled = v),
                    onLanguageChanged: (v) => setState(() => _language = v ?? 'vi'),
                    warningCtrl: _warningCtrl,
                    muteCtrl: _muteCtrl,
                    banCtrl: _banCtrl,
                  ),
                  const SizedBox(height: AppSpacing.s12),
                  _RecipeRulesCard(
                    allowAlcohol: _allowAlcohol,
                    allowMeat: _allowMeat,
                    requireNutrition: _requireNutrition,
                    onAllowAlcoholChanged: (v) =>
                        setState(() => _allowAlcohol = v),
                    onAllowMeatChanged: (v) =>
                        setState(() => _allowMeat = v),
                    onRequireNutritionChanged: (v) =>
                        setState(() => _requireNutrition = v),
                  ),
                  const SizedBox(height: AppSpacing.s12),
                  _ReportSettingsCard(
                    autoHideCtrl: _autoHideCtrl,
                  ),
                  const SizedBox(height: AppSpacing.s16),
                  Align(
                    alignment: Alignment.centerRight,
                    child: FilledButton.icon(
                      onPressed: state.saving
                          ? null
                          : () async {
                              await _save(controller, current);
                            },
                      icon: state.saving
                          ? const SizedBox(
                              width: 16,
                              height: 16,
                              child: CircularProgressIndicator(strokeWidth: 2),
                            )
                          : const Icon(Icons.save_rounded),
                      label: Text(state.saving ? 'Đang lưu...' : 'Lưu thay đổi'),
                    ),
                  ),
                ],
              ),
            );
          },
        ),
      ),
    );
  }

  Future<void> _save(
    AdminSettingsController controller,
    AdminSettings current,
  ) async {
    final warning = int.tryParse(_warningCtrl.text.trim()) ??
        current.violationThresholds.warningCount;
    final mute =
        int.tryParse(_muteCtrl.text.trim()) ?? current.violationThresholds.muteCount;
    final ban =
        int.tryParse(_banCtrl.text.trim()) ?? current.violationThresholds.banCount;
    final autoHide = int.tryParse(_autoHideCtrl.text.trim()) ??
        current.reportSettings.autoHideAfterReports;

    final payload = AdminSettings(
      communityGuidelines: _guidelinesCtrl.text.trim(),
      aiModerationEnabled: _aiModerationEnabled,
      aiLanguage: _language,
      violationThresholds: ViolationThresholds(
        warningCount: warning,
        muteCount: mute,
        banCount: ban,
      ),
      recipeContentRules: RecipeContentRules(
        allowAlcohol: _allowAlcohol,
        allowMeat: _allowMeat,
        requireNutritionForPublic: _requireNutrition,
      ),
      reportSettings: ReportSettings(autoHideAfterReports: autoHide),
      updatedAt: current.updatedAt,
      updatedBy: FirebaseAuth.instance.currentUser?.uid,
    );

    try {
      await controller.save(
        payload,
        updatedBy: FirebaseAuth.instance.currentUser?.uid ?? 'admin',
      );
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Đã lưu thay đổi settings')),
      );
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Lưu thất bại: $e')),
      );
    }
  }
}

class _GuidelinesCard extends StatelessWidget {
  const _GuidelinesCard({required this.controller});

  final TextEditingController controller;

  @override
  Widget build(BuildContext context) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(AppSpacing.s16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Tiêu chuẩn cộng đồng',
              style: Theme.of(context).textTheme.titleMedium,
            ),
            const SizedBox(height: AppSpacing.s8),
            TextField(
              controller: controller,
              minLines: 3,
              maxLines: 8,
              decoration: const InputDecoration(
                hintText: 'Nhập hướng dẫn cộng đồng...',
              ),
            ),
            const SizedBox(height: AppSpacing.s12),
            Text(
              'Preview',
              style: Theme.of(context).textTheme.bodySmall,
            ),
            const SizedBox(height: 6),
            ValueListenableBuilder<TextEditingValue>(
              valueListenable: controller,
              builder: (context, value, _) {
                final preview = value.text.trim();
                return Container(
                  width: double.infinity,
                  padding: const EdgeInsets.all(AppSpacing.s12),
                  decoration: BoxDecoration(
                    color: Theme.of(context)
                        .colorScheme
                        .surfaceContainerHighest
                        .withValues(alpha: 0.4),
                    borderRadius: BorderRadius.circular(AppRadii.medium),
                  ),
                  child: Text(
                    preview.isEmpty ? 'Chưa có nội dung' : preview,
                    style: Theme.of(context).textTheme.bodyMedium,
                  ),
                );
              },
            ),
          ],
        ),
      ),
    );
  }
}

class _AiModerationCard extends StatelessWidget {
  const _AiModerationCard({
    required this.language,
    required this.enabled,
    required this.onEnabledChanged,
    required this.onLanguageChanged,
    required this.warningCtrl,
    required this.muteCtrl,
    required this.banCtrl,
  });

  final String language;
  final bool enabled;
  final ValueChanged<bool> onEnabledChanged;
  final ValueChanged<String?> onLanguageChanged;
  final TextEditingController warningCtrl;
  final TextEditingController muteCtrl;
  final TextEditingController banCtrl;

  @override
  Widget build(BuildContext context) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(AppSpacing.s16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Expanded(
                  child: Text(
                    'AI moderation',
                    style: Theme.of(context).textTheme.titleMedium,
                  ),
                ),
                Switch(
                  value: enabled,
                  onChanged: onEnabledChanged,
                ),
              ],
            ),
            const SizedBox(height: AppSpacing.s8),
            DropdownButtonFormField<String>(
              initialValue: language,
              decoration: const InputDecoration(labelText: 'Ngôn ngữ AI'),
              items: const [
                DropdownMenuItem(value: 'vi', child: Text('Tiếng Việt')),
                DropdownMenuItem(value: 'en', child: Text('English')),
                DropdownMenuItem(value: 'vi-en', child: Text('Song ngữ')),
              ],
              onChanged: onLanguageChanged,
            ),
            const SizedBox(height: AppSpacing.s12),
            Wrap(
              spacing: AppSpacing.s12,
              runSpacing: AppSpacing.s12,
              children: [
                SizedBox(
                  width: 180,
                  child: TextField(
                    controller: warningCtrl,
                    keyboardType: TextInputType.number,
                    decoration: const InputDecoration(
                      labelText: 'Ngưỡng cảnh báo',
                      helperText: 'Số vi phạm trước khi cảnh cáo',
                    ),
                  ),
                ),
                SizedBox(
                  width: 180,
                  child: TextField(
                    controller: muteCtrl,
                    keyboardType: TextInputType.number,
                    decoration: const InputDecoration(
                      labelText: 'Ngưỡng làm ngơ (Mute)',
                      helperText: 'Số vi phạm trước khi bị ẩn (mute)',
                    ),
                  ),
                ),
                SizedBox(
                  width: 180,
                  child: TextField(
                    controller: banCtrl,
                    keyboardType: TextInputType.number,
                    decoration: const InputDecoration(
                      labelText: 'Ngưỡng cấm (Ban)',
                      helperText: 'Số vi phạm trước khi bị cấm (ban)',
                    ),
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

class _RecipeRulesCard extends StatelessWidget {
  const _RecipeRulesCard({
    required this.allowAlcohol,
    required this.allowMeat,
    required this.requireNutrition,
    required this.onAllowAlcoholChanged,
    required this.onAllowMeatChanged,
    required this.onRequireNutritionChanged,
  });

  final bool allowAlcohol;
  final bool allowMeat;
  final bool requireNutrition;
  final ValueChanged<bool> onAllowAlcoholChanged;
  final ValueChanged<bool> onAllowMeatChanged;
  final ValueChanged<bool> onRequireNutritionChanged;

  @override
  Widget build(BuildContext context) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(AppSpacing.s16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Nội dung món ăn',
              style: Theme.of(context).textTheme.titleMedium,
            ),
            const SizedBox(height: AppSpacing.s12),
            SwitchListTile(
              value: allowAlcohol,
              title: const Text('Cho phép món có rượu'),
              onChanged: onAllowAlcoholChanged,
            ),
            SwitchListTile(
              value: allowMeat,
              title: const Text('Cho phép món mặn (thịt)'),
              onChanged: onAllowMeatChanged,
            ),
            SwitchListTile(
              value: requireNutrition,
              title: const Text('Bắt buộc nhập dinh dưỡng trước khi public'),
              onChanged: onRequireNutritionChanged,
            ),
          ],
        ),
      ),
    );
  }
}

class _ReportSettingsCard extends StatelessWidget {
  const _ReportSettingsCard({required this.autoHideCtrl});

  final TextEditingController autoHideCtrl;

  @override
  Widget build(BuildContext context) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(AppSpacing.s16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Báo cáo nội dung',
              style: Theme.of(context).textTheme.titleMedium,
            ),
            const SizedBox(height: AppSpacing.s12),
            SizedBox(
              width: 220,
              child: TextField(
                controller: autoHideCtrl,
                keyboardType: TextInputType.number,
                decoration: const InputDecoration(
                  labelText: 'Tự động ẩn bài sau X báo cáo',
                ),
              ),
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
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          const Icon(Icons.error_outline),
          const SizedBox(height: AppSpacing.s8),
          Text(message, textAlign: TextAlign.center),
          const SizedBox(height: AppSpacing.s8),
          ElevatedButton.icon(
            onPressed: onRetry,
            icon: const Icon(Icons.refresh),
            label: const Text('Thử lại'),
          ),
        ],
      ),
    );
  }
}



