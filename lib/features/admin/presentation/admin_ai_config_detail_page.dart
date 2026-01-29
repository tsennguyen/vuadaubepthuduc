import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../data/admin_ai_config_repository.dart';
import 'admin_scaffold.dart';

class AdminAiConfigDetailPage extends ConsumerStatefulWidget {
  const AdminAiConfigDetailPage({required this.configId, super.key});

  final String configId;

  @override
  ConsumerState<AdminAiConfigDetailPage> createState() =>
      _AdminAiConfigDetailPageState();
}

class _AdminAiConfigDetailPageState
    extends ConsumerState<AdminAiConfigDetailPage> {
  final _formKey = GlobalKey<FormState>();
  final _nameCtrl = TextEditingController();
  final _descriptionCtrl = TextEditingController();
  final _systemPromptCtrl = TextEditingController();
  final _userTemplateCtrl = TextEditingController();
  final _extraNotesCtrl = TextEditingController();
  final _maxTokensCtrl = TextEditingController();

  String _model = 'gpt-4.1-mini';
  double _temperature = 0.7;
  bool _enabled = true;
  bool _initialized = false;
  bool _saving = false;

  @override
  void dispose() {
    _nameCtrl.dispose();
    _descriptionCtrl.dispose();
    _systemPromptCtrl.dispose();
    _userTemplateCtrl.dispose();
    _extraNotesCtrl.dispose();
    _maxTokensCtrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final configAsync = ref.watch(aiConfigProvider(widget.configId));

    return AdminShell(
      child: configAsync.when(
        data: (config) {
          _ensureInitialValues(config);
          return Form(
            key: _formKey,
            child: Center(
              child: ConstrainedBox(
                constraints: const BoxConstraints(maxWidth: 900),
                child: SingleChildScrollView(
                  padding: const EdgeInsets.all(16),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          Expanded(
                            child: Text(
                              config?.name ?? widget.configId,
                              style: Theme.of(context).textTheme.headlineSmall,
                            ),
                          ),
                          Switch(
                            value: _enabled,
                            onChanged: (value) =>
                                setState(() => _enabled = value),
                          ),
                          const SizedBox(width: 8),
                          Text(_enabled ? 'Enabled' : 'Disabled'),
                        ],
                      ),
                      if (config == null)
                        Padding(
                          padding: const EdgeInsets.only(bottom: 12),
                          child: Text(
                            'Chưa có cấu hình cho "${widget.configId}". Điền thông tin và lưu để tạo mới.',
                            style: Theme.of(context).textTheme.bodyMedium,
                          ),
                        ),
                      const SizedBox(height: 12),
                      TextFormField(
                        controller: _nameCtrl,
                        decoration: const InputDecoration(
                          labelText: 'Tên hiển thị',
                          hintText: 'Ví dụ: Kế hoạch tuần bằng AI',
                        ),
                        validator: _validateRequired,
                      ),
                      const SizedBox(height: 12),
                      TextFormField(
                        controller: _descriptionCtrl,
                        decoration: const InputDecoration(
                          labelText: 'Mô tả',
                          hintText: 'Mô tả ngắn cho admin/dev',
                        ),
                        maxLines: 2,
                      ),
                      const SizedBox(height: 12),
                      _ModelRow(
                        value: _model,
                        temperature: _temperature,
                        maxTokensController: _maxTokensCtrl,
                        onModelChanged: (value) {
                          if (value == null) return;
                          setState(() => _model = value);
                        },
                        onTemperatureChanged: (value) =>
                            setState(() => _temperature = value),
                      ),
                      const SizedBox(height: 12),
                      TextFormField(
                        controller: _systemPromptCtrl,
                        decoration: const InputDecoration(
                          labelText: 'System prompt',
                          alignLabelWithHint: true,
                        ),
                        minLines: 4,
                        maxLines: 12,
                        validator: _validateRequired,
                      ),
                      const SizedBox(height: 12),
                      TextFormField(
                        controller: _userTemplateCtrl,
                        decoration: const InputDecoration(
                          labelText: 'User prompt template',
                          alignLabelWithHint: true,
                          helperText:
                              'Hỗ trợ placeholder {{variable}}. Ví dụ: {{query}}, {{weekDates}}, {{contextJson}}, {{history}}, {{message}}...',
                        ),
                        minLines: 6,
                        maxLines: 14,
                        validator: _validateRequired,
                      ),
                      const SizedBox(height: 12),
                      TextFormField(
                        controller: _extraNotesCtrl,
                        decoration: const InputDecoration(
                          labelText: 'Ghi chú (optional)',
                          alignLabelWithHint: true,
                        ),
                        minLines: 2,
                        maxLines: 6,
                      ),
                      const SizedBox(height: 16),
                      _MetaInfo(config: config),
                      const SizedBox(height: 16),
                      Align(
                        alignment: Alignment.centerRight,
                        child: FilledButton.icon(
                          onPressed: _saving ? null : () => _save(config),
                          icon: _saving
                              ? const SizedBox(
                                  width: 16,
                                  height: 16,
                                  child:
                                      CircularProgressIndicator(strokeWidth: 2),
                                )
                              : const Icon(Icons.save),
                          label: Text(_saving ? 'Đang lưu...' : 'Lưu thay đổi'),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ),
          );
        },
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (err, __) => Center(
          child: Text('Không tải được cấu hình: $err'),
        ),
      ),
    );
  }

  void _ensureInitialValues(AdminAiConfig? config) {
    if (_initialized) return;
    final source = config;
    _nameCtrl.text = source?.name ?? widget.configId;
    _descriptionCtrl.text = source?.description ?? '';
    _systemPromptCtrl.text = source?.systemPrompt ?? '';
    _userTemplateCtrl.text = source?.userPromptTemplate ?? '';
    _extraNotesCtrl.text = source?.extraNotes ?? '';
    _temperature = source?.temperature ?? 0.7;
    _model = source?.model ?? 'gpt-4.1-mini';
    _enabled = source?.enabled ?? true;
    _maxTokensCtrl.text = (source?.maxOutputTokens ?? 1024).toString();
    _initialized = true;
  }

  String? _validateRequired(String? value) {
    final text = value?.trim() ?? '';
    if (text.isEmpty) return 'Trường này là bắt buộc';
    if (text.length > 10000) return 'Nội dung quá dài (>10k ký tự)';
    return null;
  }

  Future<void> _save(AdminAiConfig? current) async {
    if (!_formKey.currentState!.validate()) return;
    final user = FirebaseAuth.instance.currentUser;
    if (user == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Bạn cần đăng nhập để lưu thay đổi.')),
      );
      return;
    }

    final parsedMaxTokens = int.tryParse(_maxTokensCtrl.text.trim()) ?? 256;
    final maxTokens = parsedMaxTokens > 0 ? parsedMaxTokens : 256;
    setState(() => _saving = true);
    try {
      final repo = ref.read(adminAiConfigRepositoryProvider);
      final updaterName = await _resolveUpdaterName(user);
      final payload = AdminAiConfig(
        id: widget.configId,
        name: _nameCtrl.text.trim(),
        description: _descriptionCtrl.text.trim().isEmpty
            ? null
            : _descriptionCtrl.text.trim(),
        model: _model.trim(),
        systemPrompt: _systemPromptCtrl.text.trim(),
        userPromptTemplate: _userTemplateCtrl.text.trim(),
        temperature: _temperature,
        maxOutputTokens: maxTokens,
        enabled: _enabled,
        extraNotes: _extraNotesCtrl.text.trim().isEmpty
            ? null
            : _extraNotesCtrl.text.trim(),
        createdAt: current?.createdAt,
        updatedAt: DateTime.now(),
        updatedByUid: user.uid,
        updatedByName: updaterName,
      );

      await repo.saveConfig(
        payload,
        updatedByUid: user.uid,
        updatedByName: updaterName,
      );

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Đã lưu cấu hình AI cho ${payload.id}')),
        );
      }
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Lưu thất bại: $e')),
      );
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  Future<String?> _resolveUpdaterName(User user) async {
    final displayName = user.displayName?.trim();
    if (displayName != null && displayName.isNotEmpty) return displayName;

    try {
      final snap = await FirebaseFirestore.instance
          .collection('users')
          .doc(user.uid)
          .get();
      final data = snap.data();
      final name = (data?['displayName'] ??
          data?['fullName'] ??
          data?['name'] ??
          data?['email']) as String?;
      if (name != null && name.trim().isNotEmpty) return name.trim();
    } catch (_) {
      // ignore and fallback below
    }
    return user.email;
  }
}

class _ModelRow extends StatelessWidget {
  const _ModelRow({
    required this.value,
    required this.temperature,
    required this.maxTokensController,
    required this.onModelChanged,
    required this.onTemperatureChanged,
  });

  final String value;
  final double temperature;
  final TextEditingController maxTokensController;
  final ValueChanged<String?> onModelChanged;
  final ValueChanged<double> onTemperatureChanged;

  @override
  Widget build(BuildContext context) {
    final items = <DropdownMenuItem<String>>[
      const DropdownMenuItem(
          value: 'gpt-4.1-mini', child: Text('gpt-4.1-mini')),
      const DropdownMenuItem(value: 'gpt-4.1', child: Text('gpt-4.1')),
      const DropdownMenuItem(value: 'gpt-4o-mini', child: Text('gpt-4o-mini')),
      const DropdownMenuItem(
          value: 'gpt-3.5-turbo', child: Text('gpt-3.5-turbo')),
      const DropdownMenuItem(
          value: 'gemini-1.5-pro', child: Text('gemini-1.5-pro')),
      const DropdownMenuItem(
          value: 'gemini-2.0-flash', child: Text('gemini-2.0-flash')),
    ];
    if (items.where((item) => item.value == value).isEmpty) {
      items.add(DropdownMenuItem(value: value, child: Text(value)));
    }

    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Expanded(
          child: DropdownButtonFormField<String>(
            initialValue: value,
            items: items,
            onChanged: onModelChanged,
            decoration: const InputDecoration(labelText: 'Model'),
          ),
        ),
        const SizedBox(width: 12),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  const Text('Temperature'),
                  const SizedBox(width: 8),
                  Text(temperature.toStringAsFixed(2)),
                ],
              ),
              Slider(
                value: temperature.clamp(0, 2),
                onChanged: onTemperatureChanged,
                min: 0,
                max: 2,
                divisions: 40,
              ),
            ],
          ),
        ),
        const SizedBox(width: 12),
        Expanded(
          child: TextFormField(
            controller: maxTokensController,
            decoration: const InputDecoration(
              labelText: 'Max output tokens',
              helperText: 'Số token tối đa cho mỗi request',
            ),
            keyboardType: TextInputType.number,
            inputFormatters: [FilteringTextInputFormatter.digitsOnly],
            validator: (value) {
              final parsed = int.tryParse((value ?? '').trim());
              if (parsed == null || parsed <= 0) return 'Phải là số > 0';
              return null;
            },
          ),
        ),
      ],
    );
  }
}

class _MetaInfo extends StatelessWidget {
  const _MetaInfo({this.config});

  final AdminAiConfig? config;

  @override
  Widget build(BuildContext context) {
    final updatedText = [
      if (config?.updatedByName != null) config!.updatedByName,
      if (config?.updatedAt != null)
        'lúc ${config!.updatedAt!.toLocal().toString().split('.').first}',
    ].whereType<String>().join(' ');

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'Cập nhật lần cuối: ${updatedText.isEmpty ? 'Chưa có' : updatedText}',
          style: Theme.of(context).textTheme.bodyMedium,
        ),
        if (config?.createdAt != null)
          Text(
            'Tạo lúc: ${config!.createdAt!.toLocal().toString().split('.').first}',
            style: Theme.of(context).textTheme.bodyMedium,
          ),
      ],
    );
  }
}
