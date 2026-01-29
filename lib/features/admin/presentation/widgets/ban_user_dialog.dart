import 'package:flutter/material.dart';

class BanUserDialog extends StatefulWidget {
  const BanUserDialog({
    required this.userName,
    required this.currentBanReason,
    required this.currentBanUntil,
    super.key,
  });

  final String userName;
  final String? currentBanReason;
  final DateTime? currentBanUntil;

  @override
  State<BanUserDialog> createState() => _BanUserDialogState();
}

class _BanUserDialogState extends State<BanUserDialog> {
  final _reasonController = TextEditingController();
  bool _isPermanent = true;
  DateTime? _banUntil;

  @override
  void initState() {
    super.initState();
    _reasonController.text = widget.currentBanReason ?? '';
    _banUntil = widget.currentBanUntil;
    _isPermanent = _banUntil == null;
  }

  @override
  void dispose() {
    _reasonController.dispose();
    super.dispose();
  }

  Future<void> _selectDate() async {
    final now = DateTime.now();
    final picked = await showDatePicker(
      context: context,
      initialDate: _banUntil ?? now.add(const Duration(days: 7)),
      firstDate: now,
      lastDate: now.add(const Duration(days: 365)),
      helpText: 'Chọn ngày hết hạn ban',
    );
    if (picked != null) {
      setState(() {
        _banUntil = picked;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    
    return AlertDialog(
      title: Text('Cấm người dùng: ${widget.userName}'),
      content: SingleChildScrollView(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Lý do cấm',
              style: theme.textTheme.titleSmall,
            ),
            const SizedBox(height: 8),
            TextField(
              controller: _reasonController,
              decoration: const InputDecoration(
                hintText: 'Nhập lý do cấm người dùng này...',
                border: OutlineInputBorder(),
              ),
              maxLines: 3,
              maxLength: 200,
            ),
            const SizedBox(height: 16),
            Text(
              'Thời hạn',
              style: theme.textTheme.titleSmall,
            ),
            const SizedBox(height: 8),
            SegmentedButton<bool>(
              segments: const [
                ButtonSegment(
                  value: true,
                  label: Text('Vĩnh viễn'),
                  icon: Icon(Icons.block),
                ),
                ButtonSegment(
                  value: false,
                  label: Text('Tạm thời'),
                  icon: Icon(Icons.schedule),
                ),
              ],
              selected: {_isPermanent},
              onSelectionChanged: (values) {
                final value = values.first;
                setState(() {
                  _isPermanent = value;
                  if (_isPermanent) _banUntil = null;
                });
              },
            ),
            if (!_isPermanent) ...[
              const SizedBox(height: 8),
              OutlinedButton.icon(
                onPressed: _selectDate,
                icon: const Icon(Icons.calendar_today),
                label: Text(
                  _banUntil == null
                      ? 'Chọn ngày hết hạn'
                      : 'Hết hạn: ${_banUntil!.day}/${_banUntil!.month}/${_banUntil!.year}',
                ),
              ),
            ],
            const SizedBox(height: 16),
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: theme.colorScheme.errorContainer.withValues(alpha: 0.3),
                borderRadius: BorderRadius.circular(8),
                border: Border.all(
                  color: theme.colorScheme.error.withValues(alpha: 0.5),
                ),
              ),
              child: Row(
                children: [
                  Icon(
                    Icons.warning_rounded,
                    color: theme.colorScheme.error,
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Text(
                      'Người dùng sẽ bị đăng xuất ngay lập tức và không thể đăng nhập lại.',
                      style: theme.textTheme.bodySmall?.copyWith(
                        color: theme.colorScheme.error,
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.of(context).pop(),
          child: const Text('Hủy'),
        ),
        FilledButton(
          onPressed: () {
            final reason = _reasonController.text.trim();
            if (reason.isEmpty) {
              ScaffoldMessenger.of(context).showSnackBar(
                const SnackBar(content: Text('Vui lòng nhập lý do cấm')),
              );
              return;
            }
            if (!_isPermanent && _banUntil == null) {
              ScaffoldMessenger.of(context).showSnackBar(
                const SnackBar(content: Text('Vui lòng chọn ngày hết hạn')),
              );
              return;
            }
            Navigator.of(context).pop({
              'reason': reason,
              'until': _isPermanent ? null : _banUntil,
            });
          },
          style: FilledButton.styleFrom(
            backgroundColor: theme.colorScheme.error,
          ),
          child: const Text('Xác nhận cấm'),
        ),
      ],
    );
  }
}
