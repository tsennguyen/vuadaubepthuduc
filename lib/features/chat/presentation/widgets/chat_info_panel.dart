import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:image_picker/image_picker.dart';
import 'package:url_launcher/url_launcher.dart';
import '../../../../core/widgets/app_avatar.dart';
import '../../application/chat_room_controller.dart';
import '../../data/chat_repository.dart';
import '../../data/user_directory_repository.dart';
import '../../domain/message.dart';
import '../../../profile/application/profile_controller.dart';
import '../../widgets/chat_message_bubble.dart';
import 'user_picker_dialog.dart';

class ChatInfoPanel extends ConsumerWidget {
  const ChatInfoPanel({
    super.key,
    required this.chatId,
    this.onClose,
  });

  final String chatId;
  final VoidCallback? onClose;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final chatAsync = ref.watch(chatStreamProvider(chatId));

    return chatAsync.when(
      data: (chat) => _InfoContent(chat: chat, onClose: onClose),
      loading: () => const Center(child: CircularProgressIndicator()),
      error: (e, _) => Center(child: Text('Lỗi: $e')),
    );
  }
}

class _InfoContent extends ConsumerStatefulWidget {
  const _InfoContent({required this.chat, this.onClose});
  final Chat chat;
  final VoidCallback? onClose;

  @override
  ConsumerState<_InfoContent> createState() => _InfoContentState();
}

class _InfoContentState extends ConsumerState<_InfoContent> with SingleTickerProviderStateMixin {
  late TabController _tabController;

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 2, vsync: this);
  }

  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final currentUserId = ref.watch(currentUserIdProvider);
    final isAdmin = widget.chat.adminIds.contains(currentUserId);
    final theme = Theme.of(context);

    return Scaffold(
      backgroundColor: theme.colorScheme.surface,
      appBar: widget.onClose != null
          ? AppBar(
              title: const Text('Thông tin'),
              leading: IconButton(
                icon: const Icon(Icons.close_rounded),
                onPressed: widget.onClose,
              ),
              elevation: 0,
              backgroundColor: Colors.transparent,
            )
          : null,
      body: CustomScrollView(
        slivers: [
          SliverToBoxAdapter(
            child: Column(
              children: [
                const SizedBox(height: 24),
                _HeaderSection(chat: widget.chat, isAdmin: isAdmin),
                const Divider(height: 32),
                _SettingsSection(chat: widget.chat, isAdmin: isAdmin),
                const Divider(height: 32),
                _MembersSection(chat: widget.chat, isAdmin: isAdmin),
                const Divider(height: 32),
                _PinnedMessagesSection(chatId: widget.chat.id),
                const Divider(height: 32),
                _MediaTabSection(chatId: widget.chat.id, tabController: _tabController),
                const SizedBox(height: 40),
                if (widget.chat.isGroup)
                  _DangerZone(chat: widget.chat),
                const SizedBox(height: 40),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _HeaderSection extends ConsumerWidget {
  const _HeaderSection({required this.chat, required this.isAdmin});
  final Chat chat;
  final bool isAdmin;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final theme = Theme.of(context);
    
    return Container(
      padding: const EdgeInsets.all(24),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [
            theme.colorScheme.primaryContainer.withValues(alpha: 0.3),
            theme.colorScheme.secondaryContainer.withValues(alpha: 0.2),
          ],
        ),
        borderRadius: BorderRadius.circular(24),
        border: Border.all(
          color: theme.colorScheme.outline.withValues(alpha: 0.1),
        ),
      ),
      margin: const EdgeInsets.symmetric(horizontal: 16),
      child: Column(
        children: [
          _BigAvatar(chat: chat),
          const SizedBox(height: 16),
          Text(
            chat.name?.isNotEmpty == true ? chat.name! : (chat.isGroup ? 'Nhóm không tên' : 'Đoạn chat'),
            style: theme.textTheme.headlineSmall?.copyWith(
              fontWeight: FontWeight.bold,
              color: theme.colorScheme.onSurface,
            ),
            textAlign: TextAlign.center,
          ),
          if (chat.isGroup && isAdmin) ...[
            const SizedBox(height: 8),
            Container(
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  colors: [
                    theme.colorScheme.primary.withValues(alpha: 0.1),
                    theme.colorScheme.secondary.withValues(alpha: 0.1),
                  ],
                ),
                borderRadius: BorderRadius.circular(12),
              ),
              child: TextButton.icon(
                onPressed: () => _showRenameDialog(context, ref, chat),
                icon: Icon(Icons.edit_rounded, size: 16, color: theme.colorScheme.primary),
                label: Text(
                  'Đổi tên nhóm',
                  style: TextStyle(
                    color: theme.colorScheme.primary,
                    fontWeight: FontWeight.w600,
                  ),
                ),
                style: TextButton.styleFrom(
                  padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
                ),
              ),
            ),
          ],
          if (chat.isGroup) ...[
            const SizedBox(height: 12),
            Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Icon(Icons.people_alt_rounded, 
                  size: 16, 
                  color: theme.colorScheme.onSurface.withValues(alpha: 0.6),
                ),
                const SizedBox(width: 6),
                Text(
                  '${chat.memberIds.length} thành viên',
                  style: TextStyle(
                    color: theme.colorScheme.onSurface.withValues(alpha: 0.6),
                    fontSize: 13,
                    fontWeight: FontWeight.w500,
                  ),
                ),
                const SizedBox(width: 12),
                Text(
                  '•',
                  style: TextStyle(
                    color: theme.colorScheme.onSurface.withValues(alpha: 0.3),
                  ),
                ),
                const SizedBox(width: 12),
                Icon(Icons.calendar_today_rounded, 
                  size: 14, 
                  color: theme.colorScheme.onSurface.withValues(alpha: 0.6),
                ),
                const SizedBox(width: 6),
                Text(
                  _formatDate(chat.createdAt),
                  style: TextStyle(
                    color: theme.colorScheme.onSurface.withValues(alpha: 0.6),
                    fontSize: 13,
                    fontWeight: FontWeight.w500,
                  ),
                ),
              ],
            ),
          ],
        ],
      ),
    );
  }

  void _showRenameDialog(BuildContext context, WidgetRef ref, Chat chat) {
    final controller = TextEditingController(text: chat.name);
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Đổi tên nhóm'),
        content: TextField(controller: controller, decoration: const InputDecoration(hintText: 'Tên nhóm mới')),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context), child: const Text('Hủy')),
          TextButton(
            onPressed: () {
              if (controller.text.trim().isNotEmpty) {
                ref.read(chatRoomControllerProvider(chat.id).notifier).renameGroup(controller.text.trim());
                Navigator.pop(context);
              }
            },
            child: const Text('Lưu'),
          ),
        ],
      ),
    );
  }

  String _formatDate(DateTime? date) {
    if (date == null) return 'Không rõ';
    return '${date.day}/${date.month}/${date.year}';
  }
}

class _BigAvatar extends ConsumerWidget {
  const _BigAvatar({required this.chat});
  final Chat chat;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final currentUserId = ref.watch(currentUserIdProvider);
    final theme = Theme.of(context);
    if (currentUserId == null) return const CircleAvatar(radius: 40);

    final isAdmin = chat.isGroup && chat.adminIds.contains(currentUserId);

    return InkWell(
      onTap: isAdmin
          ? () async {
              final picker = ImagePicker();
              final picked = await picker.pickImage(source: ImageSource.gallery);
              if (picked != null) {
                ref.read(chatRoomControllerProvider(chat.id).notifier).changeGroupPhoto(picked);
              }
            }
          : null,
      borderRadius: BorderRadius.circular(50),
      child: Container(
        padding: const EdgeInsets.all(4),
        decoration: BoxDecoration(
          shape: BoxShape.circle,
          gradient: LinearGradient(
            colors: [
              theme.colorScheme.primary,
              theme.colorScheme.secondary,
            ],
          ),
          boxShadow: [
            BoxShadow(
              color: theme.colorScheme.primary.withValues(alpha: 0.3),
              blurRadius: 16,
              offset: const Offset(0, 4),
            ),
          ],
        ),
        child: Stack(
          children: [
            Container(
              padding: const EdgeInsets.all(3),
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: theme.colorScheme.surface,
              ),
              child: AppAvatar(
                url: chat.photoUrl ?? '',
                size: 80,
                fallbackText: chat.name?.isNotEmpty == true ? chat.name![0] : '?',
              ),
            ),
            if (isAdmin)
              Positioned(
                right: 4,
                bottom: 4,
                child: Container(
                  padding: const EdgeInsets.all(8),
                  decoration: BoxDecoration(
                    gradient: LinearGradient(
                      colors: [
                        theme.colorScheme.primary,
                        theme.colorScheme.secondary,
                      ],
                    ),
                    shape: BoxShape.circle,
                    boxShadow: [
                      BoxShadow(
                        color: Colors.black.withValues(alpha: 0.2),
                        blurRadius: 4,
                        offset: const Offset(0, 2),
                      ),
                    ],
                  ),
                  child: const Icon(Icons.camera_alt_rounded, size: 16, color: Colors.white),
                ),
              ),
          ],
        ),
      ),
    );
  }
}

class _SettingsSection extends ConsumerWidget {
  const _SettingsSection({required this.chat, required this.isAdmin});
  final Chat chat;
  final bool isAdmin;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return Column(
      children: [
        ListTile(
          leading: const Icon(Icons.palette_outlined),
          title: const Text('Chủ đề'),
          trailing: Container(
            width: 20,
            height: 20,
            decoration: BoxDecoration(
              color: _getThemeColor(chat.theme),
              shape: BoxShape.circle,
            ),
          ),
          onTap: () => _showThemePicker(context, ref, chat.id),
        ),
        ListTile(
          leading: const Icon(Icons.alternate_email),
          title: const Text('Biệt danh'),
          onTap: () => _showNicknamesDialog(context, ref, chat),
        ),
      ],
    );
  }

  Color _getThemeColor(String? theme) {
    switch (theme) {
      case 'sunset': return Colors.orange;
      case 'ocean': return Colors.blue;
      case 'mint': return Colors.green;
      case 'rose': return Colors.pink;
      default: return Colors.blue;
    }
  }

  void _showThemePicker(BuildContext context, WidgetRef ref, String chatId) {
    showModalBottomSheet(
      context: context,
      builder: (context) => Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          const Padding(
            padding: EdgeInsets.all(16),
            child: Text('Chọn chủ đề', style: TextStyle(fontWeight: FontWeight.bold)),
          ),
          Wrap(
            spacing: 16,
            children: ['default', 'mint', 'sunset', 'ocean', 'rose'].map((t) {
              return InkWell(
                onTap: () {
                  ref.read(chatRoomControllerProvider(chatId).notifier).changeTheme(t);
                  Navigator.pop(context);
                },
                child: Padding(
                  padding: const EdgeInsets.all(8.0),
                  child: Column(
                    children: [
                      CircleAvatar(backgroundColor: _getThemeColor(t)),
                      Text(t),
                    ],
                  ),
                ),
              );
            }).toList(),
          ),
          const SizedBox(height: 24),
        ],
      ),
    );
  }

  void _showNicknamesDialog(BuildContext context, WidgetRef ref, Chat chat) {
    final membersAsync = ref.watch(chatMembersProvider(chat.id));
    showDialog(
      context: context,
      builder: (context) => membersAsync.when(
        data: (members) => AlertDialog(
          title: const Text('Chỉnh sửa biệt danh'),
          content: SizedBox(
            width: double.maxFinite,
            child: ListView.builder(
              shrinkWrap: true,
              itemCount: members.length,
              itemBuilder: (context, index) {
                final m = members[index];
                final nickname = chat.nicknames[m.uid];
                return ListTile(
                  leading: AppAvatar(url: m.photoUrl ?? '', size: 32),
                  title: Text(nickname ?? m.displayName),
                  subtitle: nickname != null ? Text(m.displayName) : null,
                  onTap: () => _editNickname(context, ref, chat.id, m),
                );
              },
            ),
          ),
        ),
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (e, _) => Text('Lỗi: $e'),
      ),
    );
  }

  void _editNickname(BuildContext context, WidgetRef ref, String chatId, AppUserSummary user) {
    final controller = TextEditingController();
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: Text('Biệt danh cho ${user.displayName}'),
        content: TextField(controller: controller, decoration: const InputDecoration(hintText: 'Nhập biệt danh')),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context), child: const Text('Xóa')),
          TextButton(
            onPressed: () {
              ref.read(chatRoomControllerProvider(chatId).notifier).setNickname(user.uid, controller.text.trim().isEmpty ? null : controller.text.trim());
              Navigator.pop(context);
            },
            child: const Text('Lưu'),
          ),
        ],
      ),
    );
  }
}

class _MembersSection extends ConsumerWidget {
  const _MembersSection({required this.chat, required this.isAdmin});
  final Chat chat;
  final bool isAdmin;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final membersAsync = ref.watch(chatMembersProvider(chat.id));
    final currentUserId = ref.watch(currentUserIdProvider);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Padding(
          padding: EdgeInsets.all(16.0),
          child: Text('Thành viên', style: TextStyle(fontWeight: FontWeight.bold)),
        ),
        membersAsync.when(
          data: (members) => Column(
            children: [
              ...members.map((m) {
                final isMemberAdmin = chat.adminIds.contains(m.uid);
                final isMe = m.uid == currentUserId;
                return ListTile(
                  leading: AppAvatar(url: m.photoUrl ?? '', size: 40),
                  title: Text(chat.nicknames[m.uid] ?? m.displayName),
                  subtitle: chat.nicknames[m.uid] != null ? Text(m.displayName) : null,
                  trailing: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      if (chat.isGroup && isMemberAdmin)
                        const Chip(label: Text('Quản trị', style: TextStyle(fontSize: 10))),
                      if (chat.isGroup && isAdmin && !isMe)
                        PopupMenuButton<String>(
                          onSelected: (val) {
                            if (val == 'promote') ref.read(chatRoomControllerProvider(chat.id).notifier).promoteToAdmin(m.uid);
                            if (val == 'demote') ref.read(chatRoomControllerProvider(chat.id).notifier).demoteAdmin(m.uid);
                            if (val == 'remove') ref.read(chatRoomControllerProvider(chat.id).notifier).removeMember(m.uid);
                          },
                          itemBuilder: (context) => [
                            if (!isMemberAdmin) const PopupMenuItem(value: 'promote', child: Text('Đặt làm quản trị')),
                            if (isMemberAdmin) const PopupMenuItem(value: 'demote', child: Text('Gỡ quản trị')),
                            const PopupMenuItem(value: 'remove', child: Text('Xóa khỏi nhóm', style: TextStyle(color: Colors.red))),
                          ],
                        ),
                    ],
                  ),
                );
              }),
              if (chat.isGroup && isAdmin)
                ListTile(
                  leading: const CircleAvatar(child: Icon(Icons.add)),
                  title: const Text('Thêm thành viên'),
                  onTap: () async {
                    final currentUserId = ref.read(currentUserIdProvider);
                    if (currentUserId == null) return;

                    final selectedUsers = await UserPickerDialog.pickMulti(
                      context,
                      excludeUid: currentUserId,
                    );
                    if (!context.mounted) return;

                    final newMemberIds = selectedUsers
                        .map((u) => u.uid)
                        .where(
                          (id) =>
                              id.isNotEmpty && !chat.memberIds.contains(id),
                        )
                        .toList();
                    if (newMemberIds.isEmpty) return;

                    try {
                      await ref
                          .read(chatRoomControllerProvider(chat.id).notifier)
                          .addMembers(newMemberIds);
                      if (!context.mounted) return;
                      ScaffoldMessenger.of(context).showSnackBar(
                        SnackBar(
                          content: Text(
                              'Đã thêm ${newMemberIds.length} thành viên vào nhóm'),
                        ),
                      );
                    } catch (e) {
                      if (!context.mounted) return;
                      ScaffoldMessenger.of(context).showSnackBar(
                        SnackBar(content: Text('Lỗi: $e')),
                      );
                    }
                  },
                ),
            ],
          ),
          loading: () => const LinearProgressIndicator(),
          error: (e, _) => Text('Lỗi: $e'),
        ),
      ],
    );
  }
}


class _MediaTabSection extends StatelessWidget {
  const _MediaTabSection({required this.chatId, required this.tabController});
  final String chatId;
  final TabController tabController;

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        TabBar(
          controller: tabController,
          tabs: const [Tab(text: 'Hình ảnh/Video'), Tab(text: 'File')],
        ),
        SizedBox(
          height: 300,
          child: TabBarView(
            controller: tabController,
            children: [
              _MediaGrid(chatId: chatId),
              _FileList(chatId: chatId),
            ],
          ),
        ),
      ],
    );
  }
}

class _MediaGrid extends ConsumerWidget {
  const _MediaGrid({required this.chatId});
  final String chatId;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final state = ref.watch(chatRoomControllerProvider(chatId));
    final media = state.messages.where((m) => m.type == MessageType.image || m.type == MessageType.video).toList();

    if (media.isEmpty) return const Center(child: Text('Chưa có phương tiện'));

    return GridView.builder(
      padding: const EdgeInsets.all(8),
      gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(crossAxisCount: 3, crossAxisSpacing: 4, mainAxisSpacing: 4),
      itemCount: media.length,
      itemBuilder: (context, index) {
        final m = media[index];
        final isVideo = m.type == MessageType.video;
        final imageUrl = isVideo 
            ? (m.attachmentThumbUrl ?? m.attachmentUrl ?? '')
            : (m.attachmentUrl ?? '');
        
        return InkWell(
          onTap: () {
            final url = m.attachmentUrl;
            if (url == null || url.isEmpty) return;

            // Navigate to fullscreen viewer
            if (isVideo) {
              Navigator.of(context).push(
                MaterialPageRoute(
                  builder: (_) => FullScreenVideoPlayer(
                    url: url,
                    tag: 'info_video_${m.id}',
                  ),
                ),
              );
            } else {
              Navigator.of(context).push(
                MaterialPageRoute(
                  builder: (_) => FullScreenImageViewer(
                    url: url,
                    tag: 'info_img_${m.id}',
                  ),
                ),
              );
            }
          },
          child: Stack(
            fit: StackFit.expand,
            children: [
              if (imageUrl.isNotEmpty)
                Image.network(
                  imageUrl,
                  fit: BoxFit.cover,
                  errorBuilder: (_, __, ___) => Container(
                    color: Theme.of(context).colorScheme.surfaceContainerHighest,
                    child: Icon(
                      Icons.broken_image_outlined,
                      color: Theme.of(context).colorScheme.onSurfaceVariant,
                    ),
                  ),
                )
              else
                Container(
                  color: Theme.of(context).colorScheme.surfaceContainerHighest,
                  child: Icon(
                    Icons.image_not_supported_outlined,
                    color: Theme.of(context).colorScheme.onSurfaceVariant,
                  ),
                ),
              if (isVideo)
                const Center(child: Icon(Icons.play_circle_outline, color: Colors.white, size: 32)),
            ],
          ),
        );
      },
    );
  }
}

class _FileList extends ConsumerWidget {
  const _FileList({required this.chatId});
  final String chatId;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final state = ref.watch(chatRoomControllerProvider(chatId));
    final files = state.messages.where((m) => m.type == MessageType.file).toList();

    if (files.isEmpty) return const Center(child: Text('Chưa có file'));

    return ListView.builder(
      itemCount: files.length,
      itemBuilder: (context, index) {
        final f = files[index];
        return ListTile(
          leading: const Icon(Icons.insert_drive_file_outlined),
          title: Text(f.text ?? 'File đính kèm'),
          onTap: () async {
            final url = f.attachmentUrl;
            if (url == null || url.isEmpty) return;
            
            final uri = Uri.tryParse(url);
            if (uri != null) {
              try {
                await launchUrl(uri, mode: LaunchMode.externalApplication);
              } catch (e) {
                if (context.mounted) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(content: Text('Không thể mở file')),
                  );
                }
              }
            }
          },
        );
      },
    );
  }
}

class _DangerZone extends ConsumerWidget {
  const _DangerZone({required this.chat});
  final Chat chat;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final currentUserId = ref.watch(currentUserIdProvider);
    return Column(
      children: [
        SwitchListTile(
          secondary: Icon(
            chat.mutedBy.contains(currentUserId) ? Icons.notifications_off : Icons.notifications_none,
            color: chat.mutedBy.contains(currentUserId) ? Colors.orange : null,
          ),
          title: const Text('Tắt thông báo'),
          value: chat.mutedBy.contains(currentUserId),
          onChanged: (_) => ref.read(chatRoomControllerProvider(chat.id).notifier).toggleMute(),
        ),
        ListTile(
          leading: const Icon(Icons.exit_to_app, color: Colors.red),
          title: const Text('Rời nhóm', style: TextStyle(color: Colors.red)),
          onTap: () => _showLeaveConfirm(context, ref, chat),
        ),
      ],
    );
  }

  void _showLeaveConfirm(BuildContext context, WidgetRef ref, Chat chat) {
    final currentUserId = ref.watch(currentUserIdProvider);
    final isAdmin = chat.adminIds.contains(currentUserId);
    final isLastAdmin = isAdmin && chat.adminIds.length == 1 && chat.memberIds.length > 1;

    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Rời nhóm?'),
        content: Text(isLastAdmin ? 'Bạn là quản trị viên cuối cùng. Hãy chuyển quyền trước khi rời nhóm.' : 'Bạn có chắc chắn muốn rời nhóm này?'),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context), child: const Text('Hủy')),
          if (!isLastAdmin)
            TextButton(
              onPressed: () {
                ref.read(chatRoomControllerProvider(chat.id).notifier).leaveGroup();
                Navigator.pop(context); // Close dialog
                context.pop(); // Go back to chat list
              },
              child: const Text('Rời', style: TextStyle(color: Colors.red)),
            ),
        ],
      ),
    );
  }
}
class _PinnedMessagesSection extends ConsumerWidget {
  const _PinnedMessagesSection({required this.chatId});
  final String chatId;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final state = ref.watch(chatRoomControllerProvider(chatId));
    final pinnedMessages = state.pinnedMessages;

    if (pinnedMessages.isEmpty) {
      return const SizedBox.shrink();
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
          child: Row(
            children: [
              const Icon(Icons.push_pin, size: 20),
              const SizedBox(width: 8),
              Text(
                'Tin nhắn đã ghim (${pinnedMessages.length})',
                style: const TextStyle(
                  fontWeight: FontWeight.bold,
                  fontSize: 16,
                ),
              ),
            ],
          ),
        ),
        ListView.builder(
          shrinkWrap: true,
          physics: const NeverScrollableScrollPhysics(),
          itemCount: pinnedMessages.length,
          itemBuilder: (context, index) {
            final msg = pinnedMessages[index];
            return ListTile(
              leading: const Icon(Icons.push_pin_outlined, size: 20),
              title: Text(
                _getMessagePreview(msg),
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
              ),
              subtitle: Text(
                _formatTimestamp(msg.createdAt),
                style: const TextStyle(fontSize: 12),
              ),
              trailing: IconButton(
                icon: const Icon(Icons.close, size: 18),
                onPressed: () {
                  ref.read(chatRoomControllerProvider(chatId).notifier).unpinMessage(msg.id);
                },
              ),
              onTap: () {
                // TODO: Scroll to message in chat
                Navigator.pop(context); // Close info panel
              },
            );
          },
        ),
      ],
    );
  }

  String _getMessagePreview(ChatMessage m) {
    if (m.isDeleted) return 'Tin nhắn đã bị gỡ';
    switch (m.type) {
      case MessageType.text:
        return m.text ?? '';
      case MessageType.image:
        return '📷 Ảnh';
      case MessageType.video:
        return '🎥 Video';
      case MessageType.audio:
        return '🎤 Tin nhắn thoại';
      case MessageType.file:
        return '📎 File đính kèm';
      case MessageType.sticker:
        return '😊 Nhãn dán';
      case MessageType.gif:
        return 'GIF';
      default:
        return '';
    }
  }

  String _formatTimestamp(DateTime? dt) {
    if (dt == null) return '';
    final now = DateTime.now();
    final diff = now.difference(dt);
    
    if (diff.inDays > 0) {
      return '${dt.day}/${dt.month}/${dt.year}';
    } else if (diff.inHours > 0) {
      return '${diff.inHours}h trước';
    } else if (diff.inMinutes > 0) {
      return '${diff.inMinutes}m trước';
    } else {
      return 'Vừa xong';
    }
  }
}
