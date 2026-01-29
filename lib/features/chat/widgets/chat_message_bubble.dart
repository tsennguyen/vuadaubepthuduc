import 'dart:async';
import 'dart:async';
import 'dart:io';
import 'package:audioplayers/audioplayers.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:path_provider/path_provider.dart';
import 'package:share_plus/share_plus.dart';
import 'package:url_launcher/url_launcher.dart';
import 'package:video_player/video_player.dart';

import '../../../app/l10n.dart';
import '../../../app/language_controller.dart';
import '../application/chat_room_controller.dart';
import '../domain/message.dart';
import '../presentation/widgets/message_context_menu.dart';
import 'chat_theme_colors.dart';

class ChatMessageBubble extends ConsumerWidget {
  const ChatMessageBubble({
    super.key,
    required this.chatId,
    required this.message,
    required this.isMe,
    this.timeLabel,
    this.readCount = 0,
  });

  final String chatId;
  final ChatMessage message;
  final bool isMe;
  final String? timeLabel;
  final int readCount;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final theme = Theme.of(context);
    final s = S(ref.watch(localeProvider));
    final chatAsync = ref.watch(chatStreamProvider(chatId));
    final chatThemeColors = chatAsync.maybeWhen(
      data: (chat) => ChatThemeColors.fromString(chat.theme),
      orElse: () => ChatThemeColors.defaultTheme,
    );
    
    final alignment = isMe ? Alignment.centerRight : Alignment.centerLeft;
    final radius = BorderRadius.only(
      topLeft: const Radius.circular(18),
      topRight: const Radius.circular(18),
      bottomLeft: Radius.circular(isMe ? 18 : 4),
      bottomRight: Radius.circular(isMe ? 4 : 18),
    );

    Widget content;
    if (message.isDeleted) {
      content = Text(
        isMe ? s.youDeletedMessage : s.messageDeleted,
        style: theme.textTheme.bodyMedium?.copyWith(
          color: theme.colorScheme.onSurface.withValues(alpha: 0.5),
          fontStyle: FontStyle.italic,
        ),
      );
    } else {
      switch (message.type) {
        case MessageType.image:
          content = _ImageBubble(message: message, isMe: isMe);
          break;
        case MessageType.video:
          content = _VideoBubble(message: message, isMe: isMe);
          break;
        case MessageType.audio:
          content = _AudioBubble(message: message, isMe: isMe);
          break;
        case MessageType.file:
          content = _FileBubble(message: message, isMe: isMe);
          break;
        case MessageType.sticker:
          content = _StickerBubble(message: message);
          break;
        case MessageType.gif:
          content = _ImageBubble(message: message, isMe: isMe);
          break;
        case MessageType.system:
          content = Text(
            message.text ?? '',
            style: theme.textTheme.bodySmall?.copyWith(
              color: theme.colorScheme.onSurface.withValues(alpha: 0.6),
            ),
          );
          break;
        case MessageType.text:
          content = Text(
            message.text ?? '',
            style: theme.textTheme.bodyMedium?.copyWith(
              color: isMe
                  ? Colors.white
                  : theme.colorScheme.onSurface,
            ),
          );
          break;
      }
    }

    return Align(
      alignment: alignment,
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: 4, horizontal: 12),
        child: Column(
          crossAxisAlignment: isMe ? CrossAxisAlignment.end : CrossAxisAlignment.start,
          mainAxisSize: MainAxisSize.min,
          children: [
            GestureDetector(
              onLongPress: () => _showActions(context, ref),
              child: ConstrainedBox(
                constraints: BoxConstraints(
                  maxWidth: MediaQuery.of(context).size.width * 0.75,
                ),
                  child: Container(
                    decoration: message.type == MessageType.sticker ? null : BoxDecoration(
                      gradient: isMe
                          ? chatThemeColors.gradient
                          : LinearGradient(
                              begin: Alignment.topLeft,
                              end: Alignment.bottomRight,
                              colors: [
                                theme.colorScheme.surfaceContainerHighest
                                    .withValues(alpha: 0.95),
                                theme.colorScheme.surfaceContainer
                                    .withValues(alpha: 0.9),
                              ],
                            ),
                      borderRadius: radius,
                    border: Border.all(
                      color: isMe
                          ? chatThemeColors.primaryStart.withValues(alpha: 0.2)
                          : theme.colorScheme.outline.withValues(alpha: 0.1),
                      width: 1,
                    ),
                    boxShadow: [
                      BoxShadow(
                        color: isMe
                            ? chatThemeColors.primaryStart.withValues(alpha: 0.15)
                            : Colors.black.withValues(alpha: 0.05),
                        blurRadius: 8,
                        offset: const Offset(0, 2),
                      ),
                    ],
                  ),
                  child: Padding(
                    padding: message.type == MessageType.sticker
                        ? EdgeInsets.zero
                        : const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
          child: Column(
            crossAxisAlignment: isMe ? CrossAxisAlignment.end : CrossAxisAlignment.start,
            children: [
                        if (message.replyToMessageId != null)
                          _ReplyPreview(replyToId: message.replyToMessageId!, chatId: chatId),
                        content,
                      ],
                    ),
                  ),
                ),
              ),
            ),
            if (message.reactions.isNotEmpty) 
              _ReactionChips(
                reactions: message.reactions, 
                onReact: (e) => ref.read(chatRoomControllerProvider(chatId).notifier).reactToMessage(message.id, e),
              ),
            _buildFooter(context, ref),
          ],
        ),
      ),
    );
  }

  Widget _buildFooter(BuildContext context, WidgetRef ref) {
    final theme = Theme.of(context);
    final s = S(ref.watch(localeProvider));
    final textColor = theme.colorScheme.onSurface;

    return Padding(
      padding: const EdgeInsets.only(top: 4),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        mainAxisAlignment: isMe ? MainAxisAlignment.end : MainAxisAlignment.start,
        children: [
          if (timeLabel != null && timeLabel!.isNotEmpty)
            Text(
              timeLabel!,
              style: theme.textTheme.bodySmall?.copyWith(color: textColor.withValues(alpha: 0.6)),
            ),
          if (message.editedAt != null && !message.isDeleted)
            Padding(
              padding: const EdgeInsets.only(left: 4),
              child: Text(
                s.edited,
                style: theme.textTheme.bodySmall?.copyWith(
                  color: textColor.withValues(alpha: 0.5),
                  fontSize: 10,
                ),
              ),
            ),
          if (isMe) _buildReadReceipt(context, ref),
        ],
      ),
    );
  }

  Widget _buildReadReceipt(BuildContext context, WidgetRef ref) {
    final theme = Theme.of(context);
    final s = S(ref.watch(localeProvider));
    final chatAsync = ref.watch(chatStreamProvider(chatId));

    return chatAsync.when(
      data: (chat) {
        if (chat.isGroup) {
          final count = message.readBy.length - 1; // Exclude sender
          if (count <= 0) return const SizedBox.shrink();
          return Padding(
            padding: const EdgeInsets.only(left: 6),
            child: Text(
              s.seenBy(count),
              style: theme.textTheme.bodySmall?.copyWith(fontSize: 10, color: theme.colorScheme.primary),
            ),
          );
        } else {
          final otherUid = chat.memberIds.firstWhere((id) => id != message.senderId, orElse: () => '');
          final isSeen = message.readBy.containsKey(otherUid);
          return Padding(
            padding: const EdgeInsets.only(left: 6),
            child: Icon(
              isSeen ? Icons.done_all : Icons.check,
              size: 14,
              color: isSeen ? theme.colorScheme.primary : theme.colorScheme.onSurface.withValues(alpha: 0.4),
            ),
          );
        }
      },
      loading: () => const SizedBox.shrink(),
      error: (_, __) => const SizedBox.shrink(),
    );
  }

  void _showActions(BuildContext context, WidgetRef ref) {
    final pinnedIds = ref.read(chatRoomControllerProvider(chatId)).pinnedMessages.map((m) => m.id).toSet();
    final isPinned = pinnedIds.contains(message.id);
    showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (sheetContext) {
        return MessageContextMenu(
          message: message,
          isMe: isMe,
          onReact: (emoji) {
            ref.read(chatRoomControllerProvider(chatId).notifier).reactToMessage(message.id, emoji);
            Navigator.pop(sheetContext);
          },
          onReply: () {
            ref.read(chatRoomControllerProvider(chatId).notifier).setReplyTo(message);
            Navigator.pop(sheetContext);
          },
          onEdit: () {
            ref.read(chatRoomControllerProvider(chatId).notifier).startEditing(message);
            Navigator.pop(sheetContext);
          },
          onDelete: () {
            _showDeleteConfirm(context, ref);
            Navigator.pop(sheetContext);
          },
          onPin: () {
            ref.read(chatRoomControllerProvider(chatId).notifier).pinMessage(message.id);
            Navigator.pop(sheetContext);
          },
          onUnpin: isPinned
              ? () {
                  ref.read(chatRoomControllerProvider(chatId).notifier).unpinMessage(message.id);
                  Navigator.pop(sheetContext);
                }
              : null,
          isPinned: isPinned,
        );
      },
    );
  }

  void _showDeleteConfirm(BuildContext context, WidgetRef ref) {
    final s = S(ref.watch(localeProvider));
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text(s.delete + ' ' + s.messages.toLowerCase()),
        content: Text(s.deletePostConfirm), // Reuse existing key
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx), child: Text(s.cancel)),
          TextButton(
            onPressed: () {
              ref.read(chatRoomControllerProvider(chatId).notifier).softDeleteMessage(message.id);
              Navigator.pop(ctx);
            },
            child: Text(s.delete, style: const TextStyle(color: Colors.red)),
          ),
        ],
      ),
    );
  }
}

class _ReplyPreview extends ConsumerWidget {
  const _ReplyPreview({required this.replyToId, required this.chatId});

  final String replyToId;
  final String chatId;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final theme = Theme.of(context);
    final s = S(ref.watch(localeProvider));
    return Container(
      width: double.infinity,
      margin: const EdgeInsets.only(bottom: 8),
      padding: const EdgeInsets.all(8),
      decoration: BoxDecoration(
        color: theme.colorScheme.surface.withValues(alpha: 0.1),
        borderRadius: BorderRadius.circular(10),
      ),
      child: Row(
        children: [
          Icon(Icons.reply, size: 16, color: theme.colorScheme.primary),
          const SizedBox(width: 6),
          Expanded(
            child: Text(
              s.replying,
              style: theme.textTheme.bodySmall?.copyWith(
                color: theme.colorScheme.onSurface.withValues(alpha: 0.7),
                fontStyle: FontStyle.italic,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _ReactionChips extends StatelessWidget {
  const _ReactionChips({required this.reactions, required this.onReact});
  final Map<String, String> reactions;
  final Function(String) onReact;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final counts = <String, int>{};
    for (final e in reactions.values) {
      counts[e] = (counts[e] ?? 0) + 1;
    }

    return Padding(
      padding: const EdgeInsets.only(top: 4),
      child: Wrap(
        spacing: 6,
        children: counts.entries.map((entry) {
          return GestureDetector(
            onTap: () => onReact(entry.key),
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                  colors: [
                    theme.colorScheme.primaryContainer.withValues(alpha: 0.8),
                    theme.colorScheme.secondaryContainer.withValues(alpha: 0.7),
                  ],
                ),
                borderRadius: BorderRadius.circular(14),
                border: Border.all(
                  color: theme.colorScheme.primary.withValues(alpha: 0.2),
                  width: 1,
                ),
                boxShadow: [
                  BoxShadow(
                    color: theme.colorScheme.primary.withValues(alpha: 0.1),
                    blurRadius: 4,
                    offset: const Offset(0, 2),
                  ),
                ],
              ),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(entry.key, style: const TextStyle(fontSize: 14)),
                  const SizedBox(width: 4),
                  Text(
                    '${entry.value}',
                    style: TextStyle(
                      fontSize: 11,
                      fontWeight: FontWeight.w600,
                      color: theme.colorScheme.primary,
                    ),
                  ),
                ],
              ),
            ),
          );
        }).toList(),
      ),
    );
  }
}

class _ImageBubble extends StatelessWidget {
  const _ImageBubble({required this.message, required this.isMe});

  final ChatMessage message;
  final bool isMe;

  @override
  Widget build(BuildContext context) {
    final url = message.attachmentUrl ?? '';
    final caption = message.text ?? '';
    final theme = Theme.of(context);

    return Column(
      crossAxisAlignment: isMe ? CrossAxisAlignment.end : CrossAxisAlignment.start,
      children: [
        GestureDetector(
          onTap: () {
            if (url.isEmpty) return;
            Navigator.push(
              context,
              MaterialPageRoute(
                builder: (_) => FullScreenImageViewer(url: url, tag: 'chat_img_${message.id}'),
              ),
            );
          },
          child: Hero(
            tag: 'chat_img_${message.id}',
            child: ClipRRect(
              borderRadius: BorderRadius.circular(12),
              child: url.isNotEmpty
                  ? Image.network(
                      url,
                      fit: BoxFit.cover,
                      height: 220,
                      width: 260,
                    )
                  : Container(
                      height: 120,
                      width: 200,
                      color: Colors.black26,
                      alignment: Alignment.center,
                      child: const Icon(Icons.broken_image_outlined),
                    ),
            ),
          ),
        ),
        if (caption.isNotEmpty)
          Padding(
            padding: const EdgeInsets.only(top: 6, left: 4, right: 4),
            child: Text(
              caption,
              style: theme.textTheme.bodyMedium?.copyWith(
                color: isMe ? theme.colorScheme.onPrimary : theme.colorScheme.onSurface,
              ),
            ),
          ),
      ],
    );
  }
}

class _VideoBubble extends StatelessWidget {
  const _VideoBubble({required this.message, required this.isMe});

  final ChatMessage message;
  final bool isMe;

  @override
  Widget build(BuildContext context) {
    final thumb = message.attachmentThumbUrl ?? '';
    final caption = message.text ?? '';
    final theme = Theme.of(context);

    return Column(
      crossAxisAlignment: isMe ? CrossAxisAlignment.end : CrossAxisAlignment.start,
      children: [
        GestureDetector(
          onTap: () {
            final url = message.attachmentUrl;
            if (url == null || url.isEmpty) return;
            Navigator.of(context).push(
              MaterialPageRoute(builder: (_) => FullScreenVideoPlayer(url: url, tag: 'vid_${message.id}')),
            );
          },
          child: Hero(
            tag: 'vid_${message.id}',
            child: Stack(
              alignment: Alignment.center,
              children: [
                ClipRRect(
                  borderRadius: BorderRadius.circular(12),
                  child: thumb.isNotEmpty
                      ? Image.network(
                          thumb,
                          fit: BoxFit.cover,
                          height: 220,
                          width: 260,
                        )
                      : Container(
                          height: 220,
                          width: 260,
                          color: Colors.black12,
                          alignment: Alignment.center,
                          child: const Icon(Icons.videocam_outlined, size: 48),
                        ),
                ),
                Container(
                  decoration: BoxDecoration(
                    color: Colors.black.withValues(alpha: 0.5),
                    shape: BoxShape.circle,
                  ),
                  padding: const EdgeInsets.all(12),
                  child: const Icon(Icons.play_arrow, color: Colors.white, size: 36),
                ),
              ],
            ),
          ),
        ),
        if (caption.isNotEmpty)
          Padding(
            padding: const EdgeInsets.only(top: 6, left: 4, right: 4),
            child: Text(
              caption,
              style: theme.textTheme.bodyMedium?.copyWith(
                color: isMe ? theme.colorScheme.onPrimary : theme.colorScheme.onSurface,
              ),
            ),
          ),
      ],
    );
  }
}

class _AudioBubble extends StatefulWidget {
  const _AudioBubble({required this.message, required this.isMe});

  final ChatMessage message;
  final bool isMe;

  @override
  State<_AudioBubble> createState() => _AudioBubbleState();
}

class _AudioBubbleState extends State<_AudioBubble> {
  late final AudioPlayer _player;
  Duration _duration = Duration.zero;
  bool _playing = false;

  @override
  void initState() {
    super.initState();
    _player = AudioPlayer();
    _player.onDurationChanged.listen((d) {
      setState(() => _duration = d);
    });
    _player.onPlayerStateChanged.listen((state) {
      setState(() => _playing = state == PlayerState.playing);
    });
  }

  @override
  void dispose() {
    _player.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final durationMs = widget.message.durationMs ?? _duration.inMilliseconds;
    final label = durationMs > 0 ? _format(Duration(milliseconds: durationMs)) : _format(_duration);
    final theme = Theme.of(context);
    final color = widget.isMe ? theme.colorScheme.onPrimary : theme.colorScheme.onSurface;

    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        IconButton(
          onPressed: _toggle,
          icon: Icon(
            _playing ? Icons.pause_circle_filled : Icons.play_circle_filled,
            color: color,
            size: 32,
          ),
          padding: EdgeInsets.zero,
          constraints: const BoxConstraints(),
        ),
        const SizedBox(width: 8),
        Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              width: 120,
              height: 3,
              decoration: BoxDecoration(
                color: color.withValues(alpha: 0.3),
                borderRadius: BorderRadius.circular(2),
              ),
              alignment: Alignment.centerLeft,
              child: _playing
                  ? Container(
                      width: 40, // Simple static bar for now
                      decoration: BoxDecoration(
                        color: color,
                        borderRadius: BorderRadius.circular(2),
                      ),
                    )
                  : null,
            ),
            const SizedBox(height: 4),
            Text(
              label,
              style: theme.textTheme.bodySmall?.copyWith(color: color.withValues(alpha: 0.7), fontSize: 10),
            ),
          ],
        ),
      ],
    );
  }

  Future<void> _toggle() async {
    final url = widget.message.attachmentUrl;
    if (url == null || url.isEmpty) return;
    if (_playing) {
      await _player.pause();
    } else {
      await _player.play(UrlSource(url));
    }
  }

  String _format(Duration d) {
    final mm = d.inMinutes.remainder(60).toString().padLeft(2, '0');
    final ss = d.inSeconds.remainder(60).toString().padLeft(2, '0');
    return '$mm:$ss';
  }
}

class _FileBubble extends StatelessWidget {
  const _FileBubble({required this.message, required this.isMe});

  final ChatMessage message;
  final bool isMe;

  @override
  Widget build(BuildContext context) {
    final url = message.attachmentUrl ?? '';
    final label = message.text?.isNotEmpty == true
        ? message.text!
        : (url.isNotEmpty ? url.split('/').last : 'Tập tin đính kèm');
    final theme = Theme.of(context);
    final color = isMe ? theme.colorScheme.onPrimary : theme.colorScheme.onSurface;

    return InkWell(
      onTap: () async {
        if (url.isEmpty) return;
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
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(
            padding: const EdgeInsets.all(8),
            decoration: BoxDecoration(
              color: color.withValues(alpha: 0.1),
              shape: BoxShape.circle,
            ),
            child: Icon(Icons.insert_drive_file, color: color, size: 20),
          ),
          const SizedBox(width: 8),
          Flexible(
            child: Text(
              label,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: theme.textTheme.bodyMedium?.copyWith(
                color: color,
                fontWeight: FontWeight.w500,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class FullScreenImageViewer extends StatelessWidget {
  const FullScreenImageViewer({required this.url, required this.tag});
  final String url;
  final String tag;

  Future<void> _saveImage(BuildContext context) async {
    try {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Đang tải hình ảnh...')),
      );
      final uri = Uri.parse(url);
      final request = await HttpClient().getUrl(uri);
      final response = await request.close();
      final bytes = await response.fold<List<int>>([], (a, b) => a..addAll(b));

      final tempDir = await getTemporaryDirectory();
      final fileName = '${DateTime.now().millisecondsSinceEpoch}.jpg';
      final file = File('${tempDir.path}/$fileName');
      await file.writeAsBytes(bytes);

      if (context.mounted) {
        final box = context.findRenderObject() as RenderBox?;
        await Share.shareXFiles(
          [XFile(file.path)],
          sharePositionOrigin: box != null ? box.localToGlobal(Offset.zero) & box.size : null,
        );
      }
    } catch (e) {
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Không thể tải ảnh: $e')),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.black,
      body: Stack(
        children: [
          Dismissible(
            key: const Key('image_viewer_dismiss'),
            direction: DismissDirection.vertical,
            onDismissed: (_) => Navigator.pop(context),
            child: Center(
              child: Hero(
                tag: tag,
                child: InteractiveViewer(
                  minScale: 0.1,
                  maxScale: 5.0,
                  child: Image.network(url, fit: BoxFit.contain),
                ),
              ),
            ),
          ),
          SafeArea(
            child: Positioned(
              top: 0,
              left: 0,
              right: 0,
              child: AppBar(
                backgroundColor: Colors.transparent,
                elevation: 0,
                leading: IconButton(
                  icon: const Icon(Icons.close, color: Colors.white),
                  onPressed: () => Navigator.pop(context),
                ),
                actions: [
                  IconButton(
                    icon: const Icon(Icons.download, color: Colors.white),
                    onPressed: () => _saveImage(context),
                    tooltip: 'Lưu ảnh',
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class FullScreenVideoPlayer extends StatefulWidget {
  const FullScreenVideoPlayer({required this.url, required this.tag});
  final String url;
  final String tag;

  @override
  State<FullScreenVideoPlayer> createState() => _FullScreenVideoPlayerState();
}

class _FullScreenVideoPlayerState extends State<FullScreenVideoPlayer> {
  late final VideoPlayerController _controller;
  bool _initialized = false;
  bool _showControls = true;
  Timer? _hideTimer;

  @override
  void initState() {
    super.initState();
    _controller = VideoPlayerController.networkUrl(Uri.parse(widget.url))
      ..initialize().then((_) {
        if (mounted) {
          setState(() => _initialized = true);
          _controller.play();
          _startHideTimer();
        }
      });
    _controller.addListener(_onVideoValueChange);
  }

  void _onVideoValueChange() {
    if (mounted) setState(() {});
  }

  void _startHideTimer() {
    _hideTimer?.cancel();
    _hideTimer = Timer(const Duration(seconds: 3), () {
      if (mounted && _controller.value.isPlaying) {
        setState(() => _showControls = false);
      }
    });
  }

  void _toggleControls() {
    setState(() {
      _showControls = !_showControls;
      if (_showControls) _startHideTimer();
    });
  }

  void _seek(int seconds) {
    final current = _controller.value.position;
    final newPos = current + Duration(seconds: seconds);
    _controller.seekTo(newPos);
    _startHideTimer();
  }

  Future<void> _saveVideo(BuildContext context) async {
    try {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Đang tải video...')),
      );
      final uri = Uri.parse(widget.url);
      final request = await HttpClient().getUrl(uri);
      final response = await request.close();
      final bytes = await response.fold<List<int>>([], (a, b) => a..addAll(b));

      final tempDir = await getTemporaryDirectory();
      final fileName = '${DateTime.now().millisecondsSinceEpoch}.mp4';
      final file = File('${tempDir.path}/$fileName');
      await file.writeAsBytes(bytes);

      if (context.mounted) {
        final box = context.findRenderObject() as RenderBox?;
        await Share.shareXFiles(
          [XFile(file.path)],
          sharePositionOrigin: box != null ? box.localToGlobal(Offset.zero) & box.size : null,
        );
      }
    } catch (e) {
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Không thể tải video: $e')),
        );
      }
    }
  }

  @override
  void dispose() {
    _controller.removeListener(_onVideoValueChange);
    _controller.dispose();
    _hideTimer?.cancel();
    super.dispose();
  }

  String _formatDuration(Duration d) {
    final mm = d.inMinutes.remainder(60).toString().padLeft(2, '0');
    final ss = d.inSeconds.remainder(60).toString().padLeft(2, '0');
    return '$mm:$ss';
  }

  @override
  Widget build(BuildContext context) {
    final value = _controller.value;
    final position = value.position;
    final duration = value.duration;

    return Scaffold(
      backgroundColor: Colors.black,
      body: Dismissible(
        key: const Key('video_dismiss'),
        direction: DismissDirection.vertical,
        onDismissed: (_) => Navigator.pop(context),
        child: GestureDetector(
          onTap: _toggleControls,
          child: Stack(
            alignment: Alignment.center,
            children: [
              Center(
                child: Hero(
                  tag: widget.tag,
                  child: _initialized
                      ? AspectRatio(
                          aspectRatio: value.aspectRatio,
                          child: VideoPlayer(_controller),
                        )
                      : const CircularProgressIndicator(color: Colors.black),
                ),
              ),
              if (_initialized && _showControls) ...[
                IgnorePointer(child: Container(color: Colors.black45)),
                // Center Controls
                Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    IconButton(
                      icon: const Icon(Icons.replay_10, color: Colors.white, size: 36),
                      onPressed: () => _seek(-10),
                    ),
                    const SizedBox(width: 20),
                    IconButton(
                      iconSize: 64,
                      icon: Icon(
                        value.isPlaying ? Icons.pause_circle_filled : Icons.play_circle_filled,
                        color: Colors.white,
                      ),
                      onPressed: () {
                        setState(() {
                          if (value.isPlaying) {
                            _controller.pause();
                            _hideTimer?.cancel();
                          } else {
                            if (position >= duration) {
                              _controller.seekTo(Duration.zero);
                            }
                            _controller.play();
                            _startHideTimer();
                          }
                        });
                      },
                    ),
                    const SizedBox(width: 20),
                    IconButton(
                      icon: const Icon(Icons.forward_10, color: Colors.white, size: 36),
                      onPressed: () => _seek(10),
                    ),
                  ],
                ),
                // Top Bar
                Positioned(
                  top: 0,
                  left: 0,
                  right: 0,
                  child: AppBar(
                    backgroundColor: Colors.transparent,
                    elevation: 0,
                    leading: IconButton(
                      icon: const Icon(Icons.arrow_back, color: Colors.white),
                      onPressed: () => Navigator.pop(context),
                    ),
                    actions: [
                      IconButton(
                        icon: const Icon(Icons.download, color: Colors.white),
                        onPressed: () => _saveVideo(context),
                        tooltip: 'Lưu video',
                      ),
                    ],
                  ),
                ),
                // Bottom Bar
                Positioned(
                  bottom: 20,
                  left: 20,
                  right: 20,
                  child: Row(
                    children: [
                      Text(
                        _formatDuration(position),
                        style: const TextStyle(color: Colors.white),
                      ),
                      Expanded(
                        child: Slider(
                          value: position.inMilliseconds.toDouble(),
                          min: 0.0,
                          max: duration.inMilliseconds.toDouble(),
                          activeColor: Colors.red,
                          inactiveColor: Colors.white24,
                          onChanged: (val) {
                            _hideTimer?.cancel();
                            _controller.seekTo(Duration(milliseconds: val.toInt()));
                          },
                          onChangeEnd: (_) => _startHideTimer(),
                        ),
                      ),
                      Text(
                        _formatDuration(duration),
                        style: const TextStyle(color: Colors.white),
                      ),
                    ],
                  ),
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }
}

class _StickerBubble extends StatelessWidget {
  const _StickerBubble({required this.message});

  final ChatMessage message;

  @override
  Widget build(BuildContext context) {
    return Image.network(
      message.attachmentUrl ?? '',
      width: 140,
      height: 140,
      fit: BoxFit.contain,
      errorBuilder: (_, __, ___) => const Icon(Icons.broken_image, size: 40),
    );
  }
}
