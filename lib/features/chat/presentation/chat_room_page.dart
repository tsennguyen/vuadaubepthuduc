import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../profile/application/profile_controller.dart';
import '../../profile/domain/user_ban_guard.dart';
import '../application/chat_room_controller.dart';
import '../domain/message.dart';
import '../data/user_directory_repository.dart';
import '../widgets/chat_message_bubble.dart';
import 'widgets/chat_info_panel.dart';
import 'widgets/chat_input_bar.dart';
import 'widgets/chat_room_header.dart';
import 'chat_list_page.dart';
import 'widgets/report_violation_dialog.dart';

class ChatRoomPage extends ConsumerStatefulWidget {
  const ChatRoomPage({
    super.key,
    required this.chatId,
    this.chat,
  });

  final String chatId;
  final Object? chat;

  @override
  ConsumerState<ChatRoomPage> createState() => _ChatRoomPageState();
}

class _ChatRoomPageState extends ConsumerState<ChatRoomPage> {
  final _scrollController = ScrollController();
  final _searchController = TextEditingController();
  ProviderSubscription<ChatRoomState>? _messagesSub;
  bool _showInfoSidePanel = false;
  bool _isSearchMode = false;
  List<String> _searchResults = [];
  int _currentSearchIndex = 0;

  @override
  void initState() {
    super.initState();
    _messagesSub = ref.listenManual<ChatRoomState>(
      chatRoomControllerProvider(widget.chatId),
      (previous, next) {
        if ((previous?.messages.length ?? 0) != next.messages.length) {
          WidgetsBinding.instance.addPostFrameCallback((_) {
            if (!mounted) return;
            _scrollToBottom();
          });
        }
      },
    );
  }

  @override
  void dispose() {
    _messagesSub?.close();
    _scrollController.dispose();
    _searchController.dispose();
    super.dispose();
  }

  void _toggleSearch() {
    setState(() {
      _isSearchMode = !_isSearchMode;
      if (!_isSearchMode) {
        _searchResults.clear();
        _currentSearchIndex = 0;
        _searchController.clear();
      }
    });
  }

  void _performSearch(String query, List<ChatMessage> messages) {
    if (query.trim().isEmpty) {
      setState(() {
        _searchResults.clear();
        _currentSearchIndex = 0;
      });
      return;
    }

    final results = <String>[];
    final lowerQuery = query.toLowerCase();

    for (final msg in messages) {
      final content = msg.text?.toLowerCase() ?? '';
      if (content.contains(lowerQuery)) {
        results.add(msg.id);
      }
    }

    setState(() {
      _searchResults = results;
      _currentSearchIndex = results.isNotEmpty ? 0 : 0;
    });

    if (results.isNotEmpty) {
      _scrollToMessage(results[0]);
    }
  }

  void _nextSearchResult() {
    if (_searchResults.isEmpty) return;
    setState(() {
      _currentSearchIndex = (_currentSearchIndex + 1) % _searchResults.length;
    });
    _scrollToMessage(_searchResults[_currentSearchIndex]);
  }

  void _previousSearchResult() {
    if (_searchResults.isEmpty) return;
    setState(() {
      _currentSearchIndex = 
          (_currentSearchIndex - 1 + _searchResults.length) % _searchResults.length;
    });
    _scrollToMessage(_searchResults[_currentSearchIndex]);
  }

  void _scrollToMessage(String messageId) {
    // Simple implementation - in production you'd want to calculate exact position
    // For now, just scroll to bottom/top based on where message likely is
    if (_scrollController.hasClients) {
      _scrollController.animateTo(
        _scrollController.position.maxScrollExtent / 2,
        duration: const Duration(milliseconds: 300),
        curve: Curves.easeInOut,
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final state = ref.watch(chatRoomControllerProvider(widget.chatId));
    final currentUserId = ref.watch(currentUserIdProvider);
    final usersAsync = ref.watch(allUsersStreamProvider);
    final chatAsync = ref.watch(chatStreamProvider(widget.chatId));
    final isLocked =
        (state.isLocked) || (chatAsync.asData?.value.isLocked == true);

    final typingNames = _typingNames(
      state.typing,
      currentUserId,
      usersAsync.asData?.value ?? const [],
    );

    return LayoutBuilder(
      builder: (context, constraints) {
        final isLargeScreen = constraints.maxWidth >= 1000;
        final showSidePanel = isLargeScreen && _showInfoSidePanel;

        return Scaffold(
          body: Row(
            children: [
              if (isLargeScreen)
                Container(
                  width: 320,
                  decoration: BoxDecoration(
                    border: Border(right: BorderSide(color: Theme.of(context).dividerColor.withValues(alpha: 0.1))),
                  ),
                  child: const ChatListPage(),
                ),
              Expanded(
                child: Scaffold(
                  appBar: ChatRoomHeader(
                    chatId: widget.chatId,
                    hideLeading: isLargeScreen,
                    onOpenInfo: () {
                      if (isLargeScreen) {
                        setState(() => _showInfoSidePanel = !_showInfoSidePanel);
                      } else {
                        _showInfoBottomSheet(context);
                      }
                    },
                    onSearch: _toggleSearch,
                    actions: [
                      _ChatOptionsButton(chatId: widget.chatId),
                    ],
                  ),
                  body: Column(
                    children: [
                      if (_isSearchMode)
                        Container(
                          padding: const EdgeInsets.all(8),
                          decoration: BoxDecoration(
                            color: Theme.of(context).colorScheme.surfaceContainerHighest,
                            boxShadow: [
                              BoxShadow(
                                color: Colors.black.withValues(alpha: 0.1),
                                blurRadius: 4,
                                offset: const Offset(0, 2),
                              ),
                            ],
                          ),
                          child: Row(
                            children: [
                              IconButton(
                                icon: const Icon(Icons.close),
                                onPressed: _toggleSearch,
                              ),
                              Expanded(
                                child: TextField(
                                  controller: _searchController,
                                  autofocus: true,
                                  decoration: InputDecoration(
                                    hintText: 'Tìm kiếm tin nhắn...',
                                    border: OutlineInputBorder(
                                      borderRadius: BorderRadius.circular(24),
                                    ),
                                    contentPadding: const EdgeInsets.symmetric(
                                      horizontal: 16,
                                      vertical: 8,
                                    ),
                                  ),
                                  onChanged: (query) => _performSearch(query, state.messages),
                                ),
                              ),
                              if (_searchResults.isNotEmpty) ...[
                                const SizedBox(width: 8),
                                Text(
                                  '${_currentSearchIndex + 1}/${_searchResults.length}',
                                  style: Theme.of(context).textTheme.bodySmall,
                                ),
                                IconButton(
                                  icon: const Icon(Icons.keyboard_arrow_up),
                                  onPressed: _previousSearchResult,
                                ),
                                IconButton(
                                  icon: const Icon(Icons.keyboard_arrow_down),
                                  onPressed: _nextSearchResult,
                                ),
                              ],
                            ],
                          ),
                        ),
                      Expanded(
                        child: state.messages.isEmpty
                            ? Center(
                                child: Padding(
                                  padding: const EdgeInsets.all(16),
                                  child: Text(
                                    state.error != null ? 'Không thể tải tin nhắn' : 'Chưa có tin nhắn',
                                  ),
                                ),
                              )
                            : ListView.builder(
                                reverse: true,
                                controller: _scrollController,
                                padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 12),
                                itemCount: state.messages.length,
                                itemBuilder: (context, index) {
                                  final msg = state.messages[state.messages.length - 1 - index];
                                  final isMe = msg.senderId == currentUserId;
                                  final timeLabel = _formatTime(msg.createdAt);
                                  final isSearchMatch = _searchResults.contains(msg.id);
                                  final isCurrentSearchResult = isSearchMatch && 
                                      _searchResults.isNotEmpty && 
                                      _searchResults[_currentSearchIndex] == msg.id;
                                  
                                  Widget bubble = ChatMessageBubble(
                                    key: ValueKey(msg.id),
                                    chatId: widget.chatId,
                                    message: msg,
                                    isMe: isMe,
                                    timeLabel: timeLabel,
                                    readCount: isMe ? msg.readBy.length : 0,
                                  );

                                  if (isSearchMatch) {
                                    bubble = Container(
                                      decoration: BoxDecoration(
                                        color: isCurrentSearchResult
                                            ? Colors.yellow.withValues(alpha: 0.4)
                                            : Colors.yellow.withValues(alpha: 0.2),
                                        borderRadius: BorderRadius.circular(12),
                                      ),
                                      margin: const EdgeInsets.symmetric(vertical: 2),
                                      child: bubble,
                                    );
                                  }

                                  return bubble;
                                },
                              ),
                      ),
                      if (typingNames.isNotEmpty)
                        Padding(
                          padding: const EdgeInsets.only(left: 16, right: 16, bottom: 6),
                          child: Align(
                            alignment: Alignment.centerLeft,
                            child: _TypingIndicator(
                              label: typingNames.length == 1 ? '${typingNames.first} đang nhập...' : 'Nhiều người đang nhập...',
                            ),
                          ),
                        ),
                      if (state.error != null)
                        Container(
                          margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                          padding: const EdgeInsets.all(12),
                          decoration: BoxDecoration(
                            color: Colors.red.withValues(alpha: 0.1),
                            borderRadius: BorderRadius.circular(8),
                            border: Border.all(color: Colors.red.withValues(alpha: 0.3)),
                          ),
                          child: Row(
                            children: [
                              const Icon(Icons.error_outline, color: Colors.red, size: 20),
                              const SizedBox(width: 12),
                              Expanded(
                                child: Text(
                                  _getErrorMessage(state.error!),
                                  style: Theme.of(context).textTheme.bodySmall?.copyWith(color: Colors.red),
                                ),
                              ),
                              IconButton(
                                icon: const Icon(Icons.refresh, size: 18),
                                onPressed: () => ref.refresh(chatRoomControllerProvider(widget.chatId)),
                              ),
                            ],
                          ),
                        ),
                      const Divider(height: 1),
                      ChatInputBar(
                        isLocked: isLocked,
                        lockedMessage:
                            'Đoạn chat đã bị khoá bởi quản trị viên do vi phạm tiêu chuẩn cộng đồng.',
                        onTextChanged: (v) => ref.read(chatRoomControllerProvider(widget.chatId).notifier).onTextChanged(v),
                        onSendText: (text) async {
                          await ref.read(chatRoomControllerProvider(widget.chatId).notifier).sendText(text);
                        },
                        onSendImage: (file, {caption}) async {
                          await ref.read(chatRoomControllerProvider(widget.chatId).notifier).sendImage(file, caption: caption);
                        },
                        onSendVideo: (file, {caption, durationMs}) async {
                          await ref.read(chatRoomControllerProvider(widget.chatId).notifier).sendVideo(file, caption: caption, durationMs: durationMs);
                        },
                        onSendAudio: (file, {required int durationMs}) async {
                          await ref.read(chatRoomControllerProvider(widget.chatId).notifier).sendAudio(file, durationMs: durationMs);
                        },
                        onSendSticker: (url) async {
                          await ref.read(chatRoomControllerProvider(widget.chatId).notifier).sendSticker(url);
                        },
                        onSendGif: (url) async {
                          await ref.read(chatRoomControllerProvider(widget.chatId).notifier).sendGif(url);
                        },
                        isSending: state.isSending,
                        isUploading: state.isUploading,
                        replyMessage: state.replyMessage,
                        editingMessage: state.editingMessage,
                        onCancelReply: () => ref.read(chatRoomControllerProvider(widget.chatId).notifier).setReplyTo(null),
                        onCancelEdit: () => ref.read(chatRoomControllerProvider(widget.chatId).notifier).cancelEditing(),
                      ),
                    ],
                  ),
                ),
              ),
              if (showSidePanel)
                Container(
                  width: 350,
                  decoration: BoxDecoration(
                    border: Border(left: BorderSide(color: Theme.of(context).dividerColor.withValues(alpha: 0.1))),
                  ),
                  child: ChatInfoPanel(
                    chatId: widget.chatId,
                    onClose: () => setState(() => _showInfoSidePanel = false),
                  ),
                ),
            ],
          ),
        );
      },
    );
  }

  void _showInfoBottomSheet(BuildContext context) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      useSafeArea: true,
      builder: (context) => DraggableScrollableSheet(
        initialChildSize: 0.9,
        minChildSize: 0.5,
        maxChildSize: 1.0,
        expand: false,
        builder: (context, scrollController) => ChatInfoPanel(
          chatId: widget.chatId,
          onClose: () => Navigator.pop(context),
        ),
      ),
    );
  }

  void _scrollToBottom() {
    if (!mounted) return;
    if (!_scrollController.hasClients) return;
    _scrollController.animateTo(
      0,
      duration: const Duration(milliseconds: 200),
      curve: Curves.easeOut,
    );
  }

  String _formatTime(DateTime? time) {
    if (time == null) return '';
    final hh = time.hour.toString().padLeft(2, '0');
    final mm = time.minute.toString().padLeft(2, '0');
    return '$hh:$mm';
  }

  List<String> _typingNames(
    Map<String, bool> typing,
    String? currentUserId,
    List<AppUserSummary> users,
  ) {
    if (typing.isEmpty) return const [];
    final active = typing.entries.where((e) => e.value && e.key != currentUserId).map((e) => e.key).toList();
    if (active.isEmpty) return const [];
    final nameMap = {for (final u in users) u.uid: u.displayName};
    return active.map((uid) => nameMap[uid] ?? uid).toList();
  }

  String _getErrorMessage(Object error) {
    if (error is ChatLockedException) {
      return error.toString();
    }
    if (error is UserBannedException) {
      return error.message;
    }
    final s = error.toString().toLowerCase();
    if (s.contains('permission-denied') || s.contains('insufficient permissions')) {
      return 'Bạn không có quyền truy cập cuộc trò chuyện này. Kiểm tra lại phân quyền Firebase.';
    }
    if (s.contains('network') || s.contains('connection')) {
      return 'Lỗi kết nối mạng. Vui lòng kiểm tra lại.';
    }
    if (s.contains('storage/cors') || s.contains('cors policy')) {
      return 'Lỗi CORS: cần cấu hình CORS cho Firebase Storage (xem implementation_plan.md).';
    }
    return 'Đã xảy ra lỗi: ';
  }
}

class _TypingIndicator extends StatefulWidget {
  const _TypingIndicator({required this.label});

  final String label;

  @override
  State<_TypingIndicator> createState() => _TypingIndicatorState();
}

class _TypingIndicatorState extends State<_TypingIndicator> with SingleTickerProviderStateMixin {
  late final AnimationController _controller;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 900),
    )..repeat();
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
          decoration: BoxDecoration(
            color: Theme.of(context).colorScheme.surfaceContainerHighest,
            borderRadius: BorderRadius.circular(14),
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              AnimatedBuilder(
                animation: _controller,
                builder: (context, child) {
                  final value = _controller.value;
                  return Row(
                    mainAxisSize: MainAxisSize.min,
                    children: List.generate(3, (i) {
                      final phase = (value + i * 0.2) % 1.0;
                      final opacity = 0.3 + 0.7 * phase;
                      return Padding(
                        padding: const EdgeInsets.symmetric(horizontal: 2),
                        child: Opacity(
                          opacity: opacity.clamp(0.3, 1.0),
                          child: const CircleAvatar(
                            radius: 3,
                            backgroundColor: Colors.grey,
                          ),
                        ),
                      );
                    }),
                  );
                },
              ),
              const SizedBox(width: 8),
              Text(
                widget.label,
                style: Theme.of(context).textTheme.bodySmall?.copyWith(color: Colors.grey),
              ),
            ],
          ),
        ),
      ],
    );
  }
}

class _ChatOptionsButton extends ConsumerWidget {
  const _ChatOptionsButton({required this.chatId});
  final String chatId;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final chatAsync = ref.watch(chatStreamProvider(chatId));
    final controller = ref.read(chatRoomControllerProvider(chatId).notifier);
    final currentUserId = ref.watch(currentUserIdProvider);

    return chatAsync.when(
      data: (chat) {
        final isGroup = chat.isGroup;
        final isAdmin = chat.adminIds.contains(currentUserId);

        return PopupMenuButton<String>(
          icon: const Icon(Icons.more_vert),
          onSelected: (value) async {
            if (value == 'leave') {
               final confirm = await _showConfirm(context, 'Rời nhóm', 'Bạn có chắc chắn muốn rời nhóm?');
               if (confirm) controller.leaveGroup();
            } else if (value == 'delete_group') {
               final confirm = await _showConfirm(context, 'Xóa nhóm', 'Hành động này không thể hoàn tác.');
               if (confirm) {
                  await controller.deleteChat();
                  if (context.mounted) context.go('/chat');
               }
            } else if (value == 'delete_chat') {
                final confirm = await _showConfirm(context, 'Xóa cuộc trò chuyện', 'Bạn có chắc chắn?');
                if (confirm) {
                   await controller.deleteChat();
                   if (context.mounted) context.go('/chat');
                }
            } else if (value == 'block') {
                final peerId = chat.memberIds.firstWhere((id) => id != currentUserId, orElse: () => '');
                if (peerId.isNotEmpty) {
                    final confirm = await _showConfirm(context, 'Chặn người dùng', 'Bạn sẽ không nhận được tin nhắn từ họ nữa.');
                    if (confirm) controller.blockUser(peerId);
                }
            } else if (value == 'report') {
                _showReportDialog(context, controller, isGroup ? 'group' : 'chat', chatId);
            }
          },
          itemBuilder: (context) => [
            const PopupMenuItem(
              value: 'report',
              child: Text('Báo cáo'),
            ),
            if (isGroup) ...[
              const PopupMenuItem(
                value: 'leave',
                child: Text('Rời nhóm'),
              ),
              if (isAdmin)
                const PopupMenuItem(
                  value: 'delete_group',
                  child: Text('Xóa nhóm'),
                ),
            ] else ...[
               const PopupMenuItem(
                 value: 'block',
                 child: Text('Chặn người dùng'),
               ),
               const PopupMenuItem(
                 value: 'delete_chat',
                 child: Text('Xóa cuộc trò chuyện'),
               ),
            ],
          ],
        );
      },
      loading: () => const SizedBox.shrink(),
      error: (_, __) => const SizedBox.shrink(),
    );
  }

  Future<bool> _showConfirm(BuildContext context, String title, String content) async {
    return await showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: Text(title),
        content: Text(content),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context, false), child: const Text('Hủy')),
          TextButton(onPressed: () => Navigator.pop(context, true), child: const Text('Đồng ý')),
        ],
      ),
    ) ?? false;
  }

  void _showReportDialog(BuildContext context, ChatRoomController controller, String type, String targetId) {
    showDialog(
      context: context,
      useSafeArea: false,
      builder: (context) => ReportViolationDialog(
        targetId: targetId,
        targetType: type,
        chatId: targetId,
        onReport: (reasonCode, reasonText, msgs, images) async {
           await controller.report(
             reasonCode,
             targetId,
             reasonText,
             evidenceMessages: msgs,
             evidenceImagePaths: images,
           );
           if (context.mounted) {
             ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Đã gửi báo cáo')));
           }
        },
      ),
    );
  }
}
