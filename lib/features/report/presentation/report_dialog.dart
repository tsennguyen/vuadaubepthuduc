import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../data/report_repository.dart';
import '../domain/report_models.dart';
import '../../profile/domain/user_ban_guard.dart';

class ReportDialog extends StatefulWidget {
  final String targetType; // 'post' | 'recipe' | 'message' | 'user'
  final String targetId;
  final String? chatId;

  const ReportDialog({
    super.key,
    required this.targetType,
    required this.targetId,
    this.chatId,
  });

  @override
  State<ReportDialog> createState() => _ReportDialogState();
}

class _ReportDialogState extends State<ReportDialog> {
  static const _reasons = <MapEntry<String, String>>[
    MapEntry('spam', 'Spam / Quảng cáo.'),
    MapEntry('inappropriate', 'Nội dung phản cảm.'),
    MapEntry('violence', 'Bạo lực / máu me.'),
    MapEntry('fake_info', 'Thông tin sai lệch.'),
    MapEntry('hate', 'Thù hằn / phân biệt.'),
    MapEntry('other', 'Khác.'),
  ];

  final TextEditingController _noteController = TextEditingController();
  String? _selectedReasonCode;
  bool _isSubmitting = false;

  @override
  void dispose() {
    _noteController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Consumer(
      builder: (context, ref, _) {
        final reportRepository = ref.read(reportRepositoryProvider);

        return AlertDialog(
          title: const Text('Báo cáo nội dung'),
          content: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                DropdownButtonFormField<String>(
                  initialValue: _selectedReasonCode,
                  decoration: const InputDecoration(
                    labelText: 'Lý do',
                    border: OutlineInputBorder(),
                  ),
                  items: _reasons
                      .map(
                        (opt) => DropdownMenuItem<String>(
                          value: opt.key,
                          child: Text(opt.value),
                        ),
                      )
                      .toList(),
                  onChanged: _isSubmitting
                      ? null
                      : (value) => setState(() => _selectedReasonCode = value),
                ),
                const SizedBox(height: 12),
                TextField(
                  controller: _noteController,
                  enabled: !_isSubmitting,
                  decoration: const InputDecoration(
                    labelText: 'Mô tả thêm (tuỳ chọn)',
                    border: OutlineInputBorder(),
                  ),
                  maxLines: 5,
                  maxLength: 500,
                  textInputAction: TextInputAction.newline,
                ),
              ],
            ),
          ),
          actions: [
            TextButton(
              onPressed:
                  _isSubmitting ? null : () => Navigator.of(context).pop(),
              child: const Text('Huỷ'),
            ),
            FilledButton(
              onPressed: _isSubmitting
                  ? null
                  : () => _submit(
                        context: context,
                        reportRepository: reportRepository,
                      ),
              child: _isSubmitting
                  ? const SizedBox(
                      width: 18,
                      height: 18,
                      child: CircularProgressIndicator(strokeWidth: 2),
                    )
                  : const Text('Gửi báo cáo'),
            ),
          ],
        );
      },
    );
  }

  Future<void> _submit({
    required BuildContext context,
    required ReportRepository reportRepository,
  }) async {
    final messenger = ScaffoldMessenger.of(context);
    final navigator = Navigator.of(context);

    final selectedReasonCode = _selectedReasonCode;
    if (selectedReasonCode == null || selectedReasonCode.isEmpty) {
      messenger.showSnackBar(
        const SnackBar(content: Text('Vui lòng chọn lý do báo cáo.')),
      );
      return;
    }

    final noteText = _noteController.text.trim();

    setState(() => _isSubmitting = true);
    try {
      await reportRepository.createReport(
        CreateReportInput(
          targetType: widget.targetType,
          targetId: widget.targetId,
          chatId: widget.chatId,
          reasonCode: selectedReasonCode,
          reasonText: noteText.isEmpty ? null : noteText,
        ),
      );

      if (!mounted) return;
      navigator.pop();
      messenger.showSnackBar(
        const SnackBar(
          content: Text(
            'Đã gửi báo cáo, cảm ơn bạn đã đóng góp cho cộng đồng an toàn hơn.',
          ),
        ),
      );
    } catch (e) {
      if (!mounted) return;
      if (e is UserBannedException) {
        messenger.showSnackBar(SnackBar(content: Text(e.message)));
      } else {
        messenger.showSnackBar(
          const SnackBar(
            content: Text('Khong the gui bao cao, vui long thu lai.'),
          ),
        );
      }
    } finally {
      if (mounted) setState(() => _isSubmitting = false);
    }
  }
}



