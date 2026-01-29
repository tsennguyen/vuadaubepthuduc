import 'dart:async';

import 'package:flutter/material.dart';

import '../data/admin_chat_repository.dart';
import 'admin_scaffold.dart';
import 'widgets/admin_page_actions.dart';

class AdminChatsPage extends StatefulWidget {
  const AdminChatsPage({super.key});

  @override
  State<AdminChatsPage> createState() => _AdminChatsPageState();
}

class _AdminChatsPageState extends State<AdminChatsPage> {
  late final AdminChatRepository _repository;

  ChatTypeFilter _typeFilter = ChatTypeFilter.all;
  final _userIdController = TextEditingController();
  Timer? _debounce;
  String _userIdFilter = '';

  late Stream<List<ChatSummary>> _chatsStream;
  String? _selectedChatId;

  @override
  void initState() {
    super.initState();
    _repository = FirestoreAdminChatRepository();
    _chatsStream = _repository.watchChats(
      typeFilter: _typeFilter,
      userIdFilter: _userIdFilter,
    );
    _userIdController.addListener(_onUserIdChanged);
  }

  void _onUserIdChanged() {
    _debounce?.cancel();
    _debounce = Timer(const Duration(milliseconds: 300), () {
      final next = _userIdController.text.trim();
      if (next == _userIdFilter) return;
      if (!mounted) return;
      setState(() {
        _userIdFilter = next;
        _chatsStream = _repository.watchChats(
          typeFilter: _typeFilter,
          userIdFilter: _userIdFilter,
        );
      });
    });
  }

  void _setTypeFilter(ChatTypeFilter next) {
    if (next == _typeFilter) return;
    setState(() {
      _typeFilter = next;
      _chatsStream = _repository.watchChats(
        typeFilter: _typeFilter,
        userIdFilter: _userIdFilter,
      );
    });
  }

  @override
  void dispose() {
    _debounce?.cancel();
    _userIdController
      ..removeListener(_onUserIdChanged)
      ..dispose();
    super.dispose();
  }

  void _selectChat(ChatSummary chat) {
    setState(() {
      _selectedChatId = chat.id;
    });
  }

  @override
  Widget build(BuildContext context) {
    return AdminShell(
      actions: const [
        AdminPageActions(),
      ],
      child: LayoutBuilder(
        builder: (context, constraints) {
          final isWide = constraints.maxWidth >= 900;
          final leftPanel = _ChatsPanel(
            chatsStream: _chatsStream,
            typeFilter: _typeFilter,
            onTypeFilterChanged: _setTypeFilter,
            userIdController: _userIdController,
            selectedChatId: _selectedChatId,
            onSelectChat: _selectChat,
          );

          final rightPanel = _MessagesPanel(
            repository: _repository,
            chatId: _selectedChatId,
          );

          if (isWide) {
            return Row(
              children: [
                SizedBox(width: 360, child: leftPanel),
                const VerticalDivider(width: 1),
                Expanded(child: rightPanel),
              ],
            );
          }

          return Column(
            children: [
              SizedBox(height: 320, child: leftPanel),
              const Divider(height: 1),
              Expanded(child: rightPanel),
            ],
          );
        },
      ),
    );
  }
}

class _ChatsPanel extends StatelessWidget {
  const _ChatsPanel({
    required this.chatsStream,
    required this.typeFilter,
    required this.onTypeFilterChanged,
    required this.userIdController,
    required this.selectedChatId,
    required this.onSelectChat,
  });

  final Stream<List<ChatSummary>> chatsStream;
  final ChatTypeFilter typeFilter;
  final ValueChanged<ChatTypeFilter> onTypeFilterChanged;
  final TextEditingController userIdController;
  final String? selectedChatId;
  final ValueChanged<ChatSummary> onSelectChat;

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        _ChatFilters(
          typeFilter: typeFilter,
          onTypeFilterChanged: onTypeFilterChanged,
          userIdController: userIdController,
        ),
        Expanded(
          child: StreamBuilder<List<ChatSummary>>(
            stream: chatsStream,
            builder: (context, snapshot) {
              if (snapshot.hasError) {
                return _ErrorView(message: '${snapshot.error}');
              }
              if (!snapshot.hasData) {
                return const Center(child: CircularProgressIndicator());
              }

              final chats = snapshot.data ?? const <ChatSummary>[];
              if (chats.isEmpty) {
                return const Center(child: Text('No chats found.'));
              }

              return ListView.separated(
                padding: const EdgeInsets.all(12),
                itemCount: chats.length,
                separatorBuilder: (_, __) => const SizedBox(height: 8),
                itemBuilder: (context, index) {
                  final chat = chats[index];
                  final selected = selectedChatId == chat.id;
                  return _ChatTile(
                    chat: chat,
                    selected: selected,
                    onTap: () => onSelectChat(chat),
                  );
                },
              );
            },
          ),
        ),
      ],
    );
  }
}

class _ChatFilters extends StatelessWidget {
  const _ChatFilters({
    required this.typeFilter,
    required this.onTypeFilterChanged,
    required this.userIdController,
  });

  final ChatTypeFilter typeFilter;
  final ValueChanged<ChatTypeFilter> onTypeFilterChanged;
  final TextEditingController userIdController;

  @override
  Widget build(BuildContext context) {
    return Material(
      color: Theme.of(context).colorScheme.surface,
      child: Padding(
        padding: const EdgeInsets.fromLTRB(12, 12, 12, 8),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                const Icon(Icons.filter_list),
                const SizedBox(width: 8),
                const Text('Type:'),
                const SizedBox(width: 12),
                DropdownButton<ChatTypeFilter>(
                  value: typeFilter,
                  onChanged: (v) => v == null ? null : onTypeFilterChanged(v),
                  items: const [
                    DropdownMenuItem(
                      value: ChatTypeFilter.all,
                      child: Text('All'),
                    ),
                    DropdownMenuItem(
                      value: ChatTypeFilter.dm,
                      child: Text('DM'),
                    ),
                    DropdownMenuItem(
                      value: ChatTypeFilter.group,
                      child: Text('Group'),
                    ),
                  ],
                ),
              ],
            ),
            const SizedBox(height: 8),
            ValueListenableBuilder<TextEditingValue>(
              valueListenable: userIdController,
              builder: (context, value, _) {
                return TextField(
                  controller: userIdController,
                  decoration: InputDecoration(
                    prefixIcon: const Icon(Icons.person_search_outlined),
                    hintText: 'Filter by userId (optional)',
                    border: const OutlineInputBorder(),
                    suffixIcon: value.text.isEmpty
                        ? null
                        : IconButton(
                            tooltip: 'Clear',
                            onPressed: userIdController.clear,
                            icon: const Icon(Icons.clear),
                          ),
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

class _ChatTile extends StatelessWidget {
  const _ChatTile({
    required this.chat,
    required this.selected,
    required this.onTap,
  });

  final ChatSummary chat;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final title = _chatTitle(chat);
    final subtitle = _chatSubtitle(chat);
    final leadingIcon = chat.type == 'group'
        ? Icons.group_outlined
        : Icons.person_outline;

    return ListTile(
      selected: selected,
      selectedTileColor: theme.colorScheme.primaryContainer.withValues(alpha: 0.35),
      tileColor: theme.colorScheme.surfaceContainerHighest.withValues(alpha: 0.35),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      leading: CircleAvatar(child: Icon(leadingIcon)),
      title: Text(
        title,
        maxLines: 1,
        overflow: TextOverflow.ellipsis,
      ),
      subtitle: Text(
        subtitle,
        maxLines: 2,
        overflow: TextOverflow.ellipsis,
      ),
      onTap: onTap,
    );
  }

  String _chatTitle(ChatSummary chat) {
    final type = chat.type.trim().toLowerCase();
    if (type == 'group') {
      final name = chat.name?.trim();
      if (name != null && name.isNotEmpty) return name;
      return 'Group ${_shortId(chat.id)}';
    }

    final members = chat.memberIds;
    if (members.isEmpty) return 'DM ${_shortId(chat.id)}';
    if (members.length == 1) return 'DM: ${members.first}';
    return 'DM: ${members.take(2).join(', ')}';
  }

  String _chatSubtitle(ChatSummary chat) {
    final parts = <String>[];
    parts.add(chat.type.trim().isEmpty ? 'unknown' : chat.type.trim());
    parts.add('${chat.memberIds.length} member(s)');
    final last = chat.lastMessageAt;
    parts.add('last: ${last == null ? '—' : _formatDate(last)}');
    return parts.join(' • ');
  }

  String _shortId(String id) {
    if (id.length <= 6) return id;
    return id.substring(0, 6);
  }
}

class _MessagesPanel extends StatelessWidget {
  const _MessagesPanel({
    required this.repository,
    required this.chatId,
  });

  final AdminChatRepository repository;
  final String? chatId;

  @override
  Widget build(BuildContext context) {
    final id = chatId;
    if (id == null || id.isEmpty) {
      return const Center(child: Text('Chọn một cuộc trò chuyện để xem'));
    }

    return StreamBuilder<List<AdminMessage>>(
      stream: repository.watchMessages(id),
      builder: (context, snapshot) {
        if (snapshot.hasError) {
          return _ErrorView(message: '${snapshot.error}');
        }
        if (!snapshot.hasData) {
          return const Center(child: CircularProgressIndicator());
        }

        final messages = snapshot.data ?? const <AdminMessage>[];
        if (messages.isEmpty) {
          return const Center(child: Text('No messages.'));
        }

        return ListView.separated(
          padding: const EdgeInsets.all(16),
          itemCount: messages.length,
          separatorBuilder: (_, __) => const SizedBox(height: 10),
          itemBuilder: (context, index) {
            final msg = messages[index];
            return _MessageBubble(message: msg);
          },
        );
      },
    );
  }
}

class _MessageBubble extends StatelessWidget {
  const _MessageBubble({required this.message});

  final AdminMessage message;

  @override
  Widget build(BuildContext context) {
    final bodyText =
        message.text.isNotEmpty ? message.text : '[${message.type}]';
    final theme = Theme.of(context);
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(12),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Expanded(
                  child: Text(
                    message.senderId.isNotEmpty ? message.senderId : '-',
                    style: theme.textTheme.titleSmall,
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
                const SizedBox(width: 12),
                Text(
                  _formatDate(message.createdAt),
                  style: theme.textTheme.bodySmall,
                ),
              ],
            ),
            const SizedBox(height: 8),
            Text(bodyText),
          ],
        ),
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
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 560),
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(
                'Something went wrong',
                style: Theme.of(context).textTheme.titleMedium,
              ),
              const SizedBox(height: 8),
              Text(message, textAlign: TextAlign.center),
              const SizedBox(height: 8),
              const Text(
                'Tip: Query may require Firestore composite indexes.',
                textAlign: TextAlign.center,
              ),
            ],
          ),
        ),
      ),
    );
  }
}

String _formatDate(DateTime dateTime) {
  String two(int n) => n.toString().padLeft(2, '0');
  return '${two(dateTime.day)}/${two(dateTime.month)}/${dateTime.year} '
      '${two(dateTime.hour)}:${two(dateTime.minute)}';
}
