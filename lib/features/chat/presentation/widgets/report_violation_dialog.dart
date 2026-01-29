import 'dart:io';
import 'package:flutter/foundation.dart';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:image_picker/image_picker.dart';

import '../../data/chat_repository.dart';
import '../../domain/message.dart';

class ReportViolationDialog extends ConsumerStatefulWidget {
  const ReportViolationDialog({
    super.key,
    required this.targetId,
    required this.targetType,
    required this.chatId,
    required this.onReport,
  });

  final String targetId;
  final String targetType; // 'chat' or 'user'
  final String chatId;
  final Future<void> Function(
    String reasonCode,
    String reasonText,
    List<Map<String, dynamic>> evidenceMessages,
    List<String> evidenceImages, // Paths/URLs
  ) onReport;

  @override
  ConsumerState<ReportViolationDialog> createState() =>
      _ReportViolationDialogState();
}

class _ReportViolationDialogState extends ConsumerState<ReportViolationDialog> {
  String? _selectedReason;
  List<Map<String, dynamic>> _selectedMessages = [];
  List<XFile> _selectedImages = [];
  final _reasonController = TextEditingController();

  final List<String> _reasons = [
    'Nội dung nhạy cảm',
    'Làm phiền',
    'Lừa đảo',
    'Lý do khác',
  ];

  @override
  void dispose() {
    _reasonController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Dialog.fullscreen(
      child: Scaffold(
        appBar: AppBar(
          title: const Text('Báo xấu'),
          leading: IconButton(
            icon: const Icon(Icons.close),
            onPressed: () => Navigator.of(context).pop(),
          ),
          actions: [
            TextButton(
              onPressed: (_selectedReason == null)
                  ? null
                  : () async {
                      if (_selectedReason == null) return;
                      // Determine code
                      String code = _selectedReason!;
                      if (code == 'Nội dung nhạy cảm') code = 'sensitive';
                      if (code == 'Làm phiền') code = 'spam';
                      if (code == 'Lừa đảo') code = 'scam';
                      if (code == 'Lý do khác') code = 'other';

                       final imagePaths = _selectedImages.map((e) => e.path).toList();
                       final navigator = Navigator.of(context);

                       await widget.onReport(
                         code,
                         _reasonController.text.trim(),
                         _selectedMessages,
                         imagePaths, 
                       );
                       if (!mounted) return;
                       navigator.pop();
                     },
              child: const Text('Gửi'),
            ),
          ],
        ),
        body: SingleChildScrollView(
          padding: const EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'Chọn lý do báo xấu',
                style: theme.textTheme.titleMedium?.copyWith(
                  fontWeight: FontWeight.bold,
                ),
              ),
              const SizedBox(height: 12),
               ..._reasons.map((reason) => RadioListTile<String>(
                     title: Text(reason),
                     value: reason,
                     // ignore: deprecated_member_use
                     groupValue: _selectedReason,
                     // ignore: deprecated_member_use
                     onChanged: (val) {
                      setState(() {
                        _selectedReason = val;
                      });
                    },
                    contentPadding: EdgeInsets.zero,
                  )),
              if (_selectedReason == 'Lý do khác')
                 TextField(
                    controller: _reasonController,
                    decoration: const InputDecoration(
                      hintText: 'Nhập lý do cụ thể...',
                      border: OutlineInputBorder(),
                    ),
                    maxLines: 3,
                 ),

              const Divider(height: 32),
              Text(
                'Đính kèm bằng chứng (Tùy chọn)',
                style: theme.textTheme.titleMedium?.copyWith(
                  fontWeight: FontWeight.bold,
                ),
              ),
              const SizedBox(height: 4),
              Text(
                'Bạn có thể đính kèm tin nhắn và tải ảnh liên quan để làm rõ vi phạm.',
                style: theme.textTheme.bodySmall,
              ),
              const SizedBox(height: 16),

              _buildSelectorItem(
                context,
                title: 'Tin nhắn (${_selectedMessages.length}/10)',
                icon: Icons.message_outlined,
                onTap: () => _openMessagePicker(context),
              ),
              const SizedBox(height: 8),
              _buildSelectorItem(
                context,
                title: 'Ảnh (${_selectedImages.length}/5)',
                icon: Icons.image_outlined,
                onTap: () => _openImagePicker(context),
              ),

              if (_selectedImages.isNotEmpty) ...[
                 const SizedBox(height: 12),
                 SizedBox(
                   height: 80,
                   child: ListView.separated(
                     scrollDirection: Axis.horizontal,
                     itemCount: _selectedImages.length,
                     separatorBuilder: (_, __) => const SizedBox(width: 8),
                     itemBuilder: (ctx, idx) {
                        return Stack(
                          children: [
                             kIsWeb
                                 ? Image.network(
                                     _selectedImages[idx].path,
                                     width: 80,
                                     height: 80,
                                     fit: BoxFit.cover,
                                   )
                                 : Image.file(
                                     File(_selectedImages[idx].path),
                                     width: 80,
                                     height: 80,
                                     fit: BoxFit.cover,
                                   ),
                            Positioned(
                              top: 0,
                              right: 0,
                              child: GestureDetector(
                                onTap: () {
                                  setState(() {
                                    _selectedImages.removeAt(idx);
                                  });
                                },
                                child: Container(
                                  color: Colors.black54,
                                  child: const Icon(Icons.close, color: Colors.white, size: 20),
                                ),
                              ),
                            ),
                          ],
                        );
                     },
                   ),
                 ),
              ],
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildSelectorItem(BuildContext context, {
    required String title,
    required IconData icon,
    required VoidCallback onTap,
  }) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(8),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
        decoration: BoxDecoration(
          border: Border.all(color: Colors.grey.withValues(alpha: 0.3)),
          borderRadius: BorderRadius.circular(8),
        ),
        child: Row(
          children: [
            Icon(icon, color: Colors.grey),
            const SizedBox(width: 12),
            Expanded(child: Text(title, style: Theme.of(context).textTheme.bodyLarge)),
            const Icon(Icons.chevron_right, color: Colors.grey),
          ],
        ),
      ),
    );
  }

  Future<void> _openImagePicker(BuildContext context) async {
    final picker = ImagePicker();
    final List<XFile> images = await picker.pickMultiImage(limit: 5 - _selectedImages.length);
    if (images.isNotEmpty) {
      setState(() {
        _selectedImages.addAll(images);
        if (_selectedImages.length > 5) {
          _selectedImages = _selectedImages.sublist(0, 5);
        }
      });
    }
  }

  void _openMessagePicker(BuildContext context) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      useSafeArea: true,
      builder: (ctx) => _MessagePickerSheet(
        chatId: widget.chatId,
        initialSelection: _selectedMessages,
        onSelectionChanged: (selected) {
          setState(() {
            _selectedMessages = selected;
          });
        },
      ),
    );
  }
}

class _MessagePickerSheet extends ConsumerStatefulWidget {
  const _MessagePickerSheet({
    required this.chatId,
    required this.initialSelection,
    required this.onSelectionChanged,
  });

  final String chatId;
  final List<Map<String, dynamic>> initialSelection;
  final ValueChanged<List<Map<String, dynamic>>> onSelectionChanged;

  @override
  ConsumerState<_MessagePickerSheet> createState() => __MessagePickerSheetState();
}

class __MessagePickerSheetState extends ConsumerState<_MessagePickerSheet> {
  late Set<String> _selectedIds;
  List<Map<String, dynamic>> _selectedItems = [];

  @override
  void initState() {
    super.initState();
    _selectedItems = List.from(widget.initialSelection);
    _selectedIds = widget.initialSelection.map((m) => m['id'] as String).toSet();
  }

  void _toggle(Map<String, dynamic> msg) {
    final id = msg['id'] as String;
    setState(() {
      if (_selectedIds.contains(id)) {
        _selectedIds.remove(id);
        _selectedItems.removeWhere((m) => m['id'] == id);
      } else {
        if (_selectedIds.length >= 10) return; // Limit 10
        _selectedIds.add(id);
        _selectedItems.add(msg);
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    final repo = ref.watch(chatRepositoryProvider);
    return Scaffold(
      appBar: AppBar(
        title: Text('Chọn tin nhắn (${_selectedIds.length}/10)'),
        leading: IconButton(
          icon: const Icon(Icons.close),
          onPressed: () => Navigator.of(context).pop(),
        ),
        actions: [
          TextButton(
             onPressed: () {
               widget.onSelectionChanged(_selectedItems);
               Navigator.of(context).pop();
             },
             child: const Text('Xong'),
          ),
        ],
      ),
      body: StreamBuilder<List<ChatMessage>>(
        stream: repo.watchMessages(widget.chatId),
        builder: (context, snapshot) {
          final messages = snapshot.data ?? const <ChatMessage>[];
          if (messages.isEmpty) return const Center(child: Text('Không có tin nhắn nào'));

          // Reverse to show like chat (bottom up) or just list? 
          // Chat is usually reversed. Let's assume repo returns chronologically or reverse.
          // Usually watchChatMessages returns descending (newest first).
          // We can display list.
          
          return ListView.builder(
            itemCount: messages.length,
            itemBuilder: (ctx, index) {
              final msg = messages[index];
              final isSelected = _selectedIds.contains(msg.id);
              return ListTile(
                leading: Checkbox(
                  value: isSelected,
                  onChanged: (_) => _toggle({
                    'id': msg.id,
                    'text': msg.text,
                    'senderId': msg.senderId,
                    'createdAt': msg.createdAt?.millisecondsSinceEpoch ?? 0,
                    'type': _msgTypeToString(msg),
                  }),
                ),
                title: Text(msg.text ?? '[${_msgTypeToString(msg)}]'), // Accessing text? Abstract ChatMessage usually has fields.
                subtitle: Text('${msg.senderId} • ${_formatTime(msg.createdAt)}'),
                onTap: () => _toggle({
                    'id': msg.id,
                    'text': msg.text,
                    'senderId': msg.senderId,
                    'createdAt': msg.createdAt?.millisecondsSinceEpoch ?? 0,
                    'type': _msgTypeToString(msg),
                }),
              );
            },
          );
        },
      ),
    );
  }

  String _formatTime(DateTime? dt) {
    if (dt == null) return '';
    final mm = dt.minute.toString().padLeft(2, '0');
    return '${dt.hour}:$mm';
  }

  String _msgTypeToString(ChatMessage msg) {
    return messageTypeToString(msg.type);
  }
}
