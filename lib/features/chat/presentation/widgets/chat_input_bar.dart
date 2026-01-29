import 'dart:async';
import 'dart:io' as io;
import 'package:emoji_picker_flutter/emoji_picker_flutter.dart';
import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:image_picker/image_picker.dart';
import 'package:path_provider/path_provider.dart';
import 'package:record/record.dart';
import 'package:video_player/video_player.dart';

import '../../domain/message.dart';

typedef SendText = Future<void> Function(String text);
typedef SendImage = Future<void> Function(XFile file, {String? caption});
typedef SendVideo = Future<void> Function(
  XFile file, {
  String? caption,
  int? durationMs,
});
typedef SendAudio = Future<void> Function(XFile file, {required int durationMs});
typedef SendSticker = Future<void> Function(String url);
typedef SendGif = Future<void> Function(String url);

class ChatInputBar extends StatefulWidget {
  const ChatInputBar({
    super.key,
    required this.onTextChanged,
    required this.onSendText,
    required this.onSendImage,
    required this.onSendVideo,
    required this.onSendAudio,
    required this.onSendSticker,
    required this.onSendGif,
    this.isSending = false,
    this.isUploading = false,
    this.replyMessage,
    this.editingMessage,
    this.onCancelReply,
    this.onCancelEdit,
    this.isLocked = false,
    this.lockedMessage,
  });

  final ValueChanged<String> onTextChanged;
  final SendText onSendText;
  final SendImage onSendImage;
  final SendVideo onSendVideo;
  final SendAudio onSendAudio;
  final SendSticker onSendSticker;
  final SendGif onSendGif;
  final bool isSending;
  final bool isUploading;
  final ChatMessage? replyMessage;
  final ChatMessage? editingMessage;
  final VoidCallback? onCancelReply;
  final VoidCallback? onCancelEdit;
  final bool isLocked;
  final String? lockedMessage;

  @override
  State<ChatInputBar> createState() => _ChatInputBarState();
}

class _ChatInputBarState extends State<ChatInputBar> {
  final _controller = TextEditingController();
  final _focusNode = FocusNode();
  final _picker = ImagePicker();
  final _recorder = Record();
  
  bool _showEmoji = false;
  bool _showSticker = false;
  bool _showGif = false;
  
  bool _isRecording = false;
  String? _recordPath;
  DateTime? _recordStart;
  Timer? _recordTimer;
  Duration _recordDuration = Duration.zero;

  @override
  void didUpdateWidget(ChatInputBar oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (widget.editingMessage != null &&
        widget.editingMessage != oldWidget.editingMessage) {
      _controller.text = widget.editingMessage!.text ?? '';
      _controller.selection = TextSelection.fromPosition(
        TextPosition(offset: _controller.text.length),
      );
    } else if (widget.editingMessage == null &&
        oldWidget.editingMessage != null) {
      _controller.clear();
    }
  }

  @override
  void dispose() {
    _controller.dispose();
    _focusNode.dispose();
    _recorder.dispose();
    _recordTimer?.cancel();
    super.dispose();
  }

  bool get _canSend =>
      _controller.text.trim().isNotEmpty &&
      !widget.isSending &&
      !widget.isUploading &&
      !widget.isLocked;

  void _resetPickers() {
    setState(() {
      _showEmoji = false;
      _showSticker = false;
      _showGif = false;
    });
  }

  void _toggleEmoji() {
    if (widget.isLocked) return;
    setState(() {
      _showEmoji = !_showEmoji;
      _showSticker = false;
      _showGif = false;
    });
    if (_showEmoji) FocusScope.of(context).unfocus();
  }

  void _toggleSticker() {
    if (widget.isLocked) return;
    setState(() {
      _showSticker = !_showSticker;
      _showEmoji = false;
      _showGif = false;
    });
    if (_showSticker) FocusScope.of(context).unfocus();
  }

  void _toggleGif() {
    if (widget.isLocked) return;
    setState(() {
      _showGif = !_showGif;
      _showEmoji = false;
      _showSticker = false;
    });
    if (_showGif) FocusScope.of(context).unfocus();
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final iconColor = theme.colorScheme.primary;

    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        if (widget.isLocked)
          Container(
            width: double.infinity,
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
            color: theme.colorScheme.errorContainer.withValues(alpha: 0.2),
            child: Row(
              children: [
                const Icon(Icons.lock, size: 18),
                const SizedBox(width: 10),
                Expanded(
                  child: Text(
                    widget.lockedMessage ??
                        'Đoạn chat đã bị khóa bởi quản trị viên do vi phạm tiêu chuẩn cộng đồng.',
                    style: theme.textTheme.bodySmall,
                  ),
                ),
              ],
            ),
          ),
        if (widget.replyMessage != null) _buildReplyPreview(),
        if (widget.editingMessage != null) _buildEditPreview(),
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 8),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.end,
            children: [
              if (!_isRecording) ...[
                // Mic
                GestureDetector(
                  onLongPressStart: (widget.isUploading || kIsWeb || widget.isLocked)
                      ? null
                      : (_) => _startRecord(),
                  onLongPressEnd: (widget.isUploading || kIsWeb || widget.isLocked)
                      ? null
                      : (_) => _stopRecord(send: true),
                  onLongPressCancel: (widget.isUploading || kIsWeb || widget.isLocked)
                      ? null
                      : _cancelRecord,
                  onLongPressUp: (widget.isUploading || kIsWeb || widget.isLocked)
                      ? null
                      : () => _stopRecord(send: true),
                  child: IconButton(
                    icon: const Icon(Icons.mic_rounded),
                    color: iconColor,
                    onPressed: widget.isLocked
                        ? null
                        : () {
                            ScaffoldMessenger.of(context).showSnackBar(
                              const SnackBar(
                                content: Text('Nhấn và giữ để ghi âm, thả để gửi'),
                                duration: Duration(seconds: 1),
                              ),
                            );
                          },
                  ),
                ),
                // Media
                IconButton(
                  icon: const Icon(Icons.image_rounded),
                  color: iconColor,
                  onPressed: (widget.isUploading || widget.isLocked)
                      ? null
                      : _handlePickMedia,
                ),
                // Sticker
                IconButton(
                  icon: const Icon(Icons.sticky_note_2_rounded),
                  color: _showSticker ? theme.colorScheme.primary : iconColor,
                  onPressed: _toggleSticker,
                ),
                // GIF
                IconButton(
                  icon: const Icon(Icons.gif_box_rounded),
                  color: _showGif ? theme.colorScheme.primary : iconColor,
                  onPressed: _toggleGif,
                ),
              ],

              // Input
              Expanded(
                child: AnimatedContainer(
                  duration: const Duration(milliseconds: 200),
                  margin: const EdgeInsets.only(left: 4, right: 8),
                  decoration: BoxDecoration(
                    color: _isRecording
                        ? theme.colorScheme.errorContainer.withValues(alpha: 0.2)
                        : theme.colorScheme.surfaceContainerHighest.withValues(alpha: 0.5),
                    borderRadius: BorderRadius.circular(24),
                    border: Border.all(
                      color: _isRecording
                          ? theme.colorScheme.error.withValues(alpha: 0.5)
                          : Colors.transparent,
                    ),
                  ),
                  child: _isRecording
                      ? _buildRecordingUI()
                      : Row(
                          children: [
                            Expanded(child: _buildTextField()),
                            IconButton(
                              icon: Icon(
                                Icons.sentiment_satisfied_rounded,
                                color: _showEmoji
                                    ? theme.colorScheme.primary
                                    : theme.colorScheme.onSurfaceVariant,
                              ),
                              onPressed: _toggleEmoji,
                            ),
                          ],
                        ),
                ),
              ),

              // Send
              if (_controller.text.trim().isNotEmpty && !_isRecording)
                Container(
                  margin: const EdgeInsets.only(bottom: 4),
                  child: IconButton(
                    onPressed: _canSend ? _handleSendText : null,
                    icon: widget.isSending
                        ? SizedBox(
                            width: 20,
                            height: 20,
                            child: CircularProgressIndicator(
                              strokeWidth: 2,
                              color: theme.colorScheme.primary,
                            ),
                          )
                        : Icon(Icons.send_rounded, color: theme.colorScheme.primary),
                  ),
                ),
            ],
          ),
        ),
        
        // Pickers
        if (_showEmoji)
          SizedBox(
            height: 280,
            child: EmojiPicker(
              key: const ValueKey('chat-emoji-picker'),
              onEmojiSelected: (_, emoji) {
                final text = _controller.text;
                final selection = _controller.selection;
                final newText = text.replaceRange(selection.start, selection.end, emoji.emoji);
                _controller.text = newText;
                _controller.selection = TextSelection.fromPosition(
                  TextPosition(offset: selection.start + emoji.emoji.length),
                );
                widget.onTextChanged(newText);
                setState(() {});
              },
              config: const Config(
                emojiViewConfig: EmojiViewConfig(
                  columns: 7,
                  emojiSizeMax: 28,
                ),
              ),
            ),
          ),
        if (_showSticker)
           SizedBox(
            height: 280,
            child: _StickerPicker(onSelect: (url) {
              widget.onSendSticker(url);
              _resetPickers();
            }),
          ),
        if (_showGif)
           SizedBox(
            height: 280,
            child: _GifPicker(onSelect: (url) {
              widget.onSendGif(url);
              _resetPickers();
            }),
          ),
      ],
    );
  }

  Widget _buildTextField() {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 2),
      child: TextField(
        key: const ValueKey('chat_message_input'),
        enabled: !widget.isLocked,
        controller: _controller,
        focusNode: _focusNode,
        minLines: 1,
        maxLines: 5,
        textInputAction: TextInputAction.newline,
        onTap: () {
          _resetPickers();
        },
        onChanged: (val) {
          if (!widget.isLocked) {
            widget.onTextChanged(val);
            setState(() {});
          }
        },
        style: Theme.of(context).textTheme.bodyMedium,
        decoration: InputDecoration(
          hintText: 'Nhập tin...',
          hintStyle: TextStyle(
            color: Theme.of(context).colorScheme.onSurfaceVariant.withValues(alpha: 0.6),
          ),
          border: InputBorder.none,
          isDense: true,
          contentPadding: const EdgeInsets.symmetric(vertical: 10),
        ),
      ),
    );
  }

  Widget _buildRecordingUI() {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      child: Row(
        children: [
          Icon(Icons.mic, color: Theme.of(context).colorScheme.error, size: 20),
          const SizedBox(width: 8),
          Text(
            _formatDuration(_recordDuration),
            style: TextStyle(
              fontWeight: FontWeight.bold,
              color: Theme.of(context).colorScheme.error,
              fontSize: 16,
            ),
          ),
          const SizedBox(width: 8),
          const Spacer(),
          Text(
            'Thả để gửi, vuốt để hủy',
            style: Theme.of(context).textTheme.bodySmall?.copyWith(
              fontStyle: FontStyle.italic,
              color: Theme.of(context).colorScheme.error.withValues(alpha: 0.8),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildReplyPreview() {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      decoration: BoxDecoration(
        color: Theme.of(context).colorScheme.surfaceContainerHighest.withValues(alpha: 0.5),
        border: Border(bottom: BorderSide(color: Theme.of(context).dividerColor.withValues(alpha: 0.1))),
      ),
      child: Row(
        children: [
          const Icon(Icons.reply, size: 20),
          const SizedBox(width: 8),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  'Đang trả lời',
                  style: Theme.of(context).textTheme.bodySmall?.copyWith(fontWeight: FontWeight.bold),
                ),
                Text(
                  _getMessagePreview(widget.replyMessage!),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: Theme.of(context).textTheme.bodySmall,
                ),
              ],
            ),
          ),
          IconButton(
            icon: const Icon(Icons.close, size: 18),
            onPressed: widget.onCancelReply,
          ),
        ],
      ),
    );
  }

  Widget _buildEditPreview() {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      decoration: BoxDecoration(
        color: Theme.of(context).colorScheme.surfaceContainerHighest.withValues(alpha: 0.5),
        border: Border(bottom: BorderSide(color: Theme.of(context).dividerColor.withValues(alpha: 0.1))),
      ),
      child: Row(
        children: [
          const Icon(Icons.edit, size: 20),
          const SizedBox(width: 8),
          const Expanded(
            child: Text(
              'Đang chỉnh sửa',
              style: TextStyle(fontWeight: FontWeight.bold, fontSize: 12),
            ),
          ),
          IconButton(
            icon: const Icon(Icons.close, size: 18),
            onPressed: widget.onCancelEdit,
          ),
        ],
      ),
    );
  }

  String _getMessagePreview(ChatMessage m) {
    switch (m.type) {
      case MessageType.text:
        return m.text ?? '';
      case MessageType.image:
        return 'Ảnh';
      case MessageType.video:
        return 'Video';
      case MessageType.audio:
        return 'Tin nhắn thoại';
      case MessageType.file:
        return 'Tập tin';
      case MessageType.sticker:
        return 'Nhãn dán';
      case MessageType.gif:
        return 'GIF';
      default:
        return '';
    }
  }

  Future<void> _handleSendText() async {
    if (widget.isLocked) return;
    final text = _controller.text.trim();
    if (text.isEmpty) return;
    _controller.clear();
    setState(() {});
    await widget.onSendText(text);
  }

  Future<void> _handlePickImage() async {
    if (widget.isLocked) return;
    final picked = await _picker.pickImage(source: ImageSource.gallery);
    if (picked == null || !mounted) return;
    
    final caption = await _showCaptionSheet(
      context: context,
      preview: kIsWeb
          ? Image.network(picked.path, fit: BoxFit.cover)
          : Image.file(io.File(picked.path), fit: BoxFit.cover),
    );
    if (caption != null && mounted) {
      await widget.onSendImage(picked, caption: caption);
    }
  }

  Future<void> _handlePickVideo() async {
    if (widget.isLocked) return;
    final picked = await _picker.pickVideo(source: ImageSource.gallery);
    if (picked == null || !mounted) return;
    
    final duration = await _videoDuration(picked);
    if (!mounted) return;
    final caption = await _showCaptionSheet(
      context: context,
      preview: Container(
        height: 160,
        color: Colors.black12,
        alignment: Alignment.center,
        child: const Icon(Icons.videocam_outlined, size: 48),
      ),
    );
    if (caption != null && mounted) {
      await widget.onSendVideo(picked, caption: caption, durationMs: duration?.inMilliseconds);
    }
  }

  Future<void> _handlePickMedia() async {
    showModalBottomSheet(
      context: context,
      builder: (ctx) => SafeArea(
        child: Wrap(
          children: [
            ListTile(
              leading: const Icon(Icons.photo_library),
              title: const Text('Chọn ảnh'),
              onTap: () {
                Navigator.pop(ctx);
                _handlePickImage();
              },
            ),
            ListTile(
              leading: const Icon(Icons.video_library),
              title: const Text('Chọn video'),
              onTap: () {
                Navigator.pop(ctx);
                _handlePickVideo();
              },
            ),
             ListTile(
              leading: const Icon(Icons.camera_alt),
              title: const Text('Chụp ảnh'),
              onTap: () async {
                Navigator.pop(ctx);
                if (widget.isLocked) return;
                final picked = await _picker.pickImage(source: ImageSource.camera);
                if (picked == null || !mounted) return;

                final caption = await _showCaptionSheet(
                  context: context,
                  preview: kIsWeb
                      ? Image.network(picked.path, fit: BoxFit.cover)
                      : Image.file(io.File(picked.path), fit: BoxFit.cover),
                );
                if (caption != null && mounted) {
                  await widget.onSendImage(picked, caption: caption);
                }
              },
            ),
          ],
        ),
      ),
    );
  }

  void _startRecord() async {
    if (widget.isLocked) return;
    if (kIsWeb) return;
    final hasPerm = await _recorder.hasPermission();
    if (!hasPerm) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Cần quyền micro để ghi âm')),
        );
      }
      return;
    }

    final dir = await getTemporaryDirectory();
    final path = '${dir.path}/voice_${DateTime.now().millisecondsSinceEpoch}.m4a';
    _recordPath = path;
    await _recorder.start(path: path);
    HapticFeedback.mediumImpact();
    
    setState(() {
      _isRecording = true;
      _recordDuration = Duration.zero;
      _recordStart = DateTime.now();
    });

    _recordTimer = Timer.periodic(const Duration(seconds: 1), (timer) {
      setState(() {
        _recordDuration = DateTime.now().difference(_recordStart!);
      });
    });
  }

  Future<void> _stopRecord({required bool send}) async {
    if (!_isRecording) return;
    _recordTimer?.cancel();
    final path = await _recorder.stop();
    final duration = _recordDuration;
    
    setState(() {
      _isRecording = false;
      _recordDuration = Duration.zero;
      _recordStart = null;
    });

    if (!send) {
      final filePath = path ?? _recordPath;
      if (filePath != null) {
        final file = io.File(filePath);
        if (await file.exists()) await file.delete();
      }
    } else if (path != null && duration.inMilliseconds >= 600) {
      await widget.onSendAudio(XFile(path), durationMs: duration.inMilliseconds);
    }

    _recordPath = null;
  }

  Future<void> _cancelRecord() async {
    await _stopRecord(send: false);
  }

  String _formatDuration(Duration d) {
    final mm = d.inMinutes.remainder(60).toString().padLeft(2, '0');
    final ss = d.inSeconds.remainder(60).toString().padLeft(2, '0');
    return '$mm:$ss';
  }

  Future<Duration?> _videoDuration(XFile file) async {
    try {
      final controller = VideoPlayerController.networkUrl(Uri.parse(file.path));
      await controller.initialize();
      final duration = controller.value.duration;
      await controller.dispose();
      return duration;
    } catch (_) {
      return null;
    }
  }

  Future<String?> _showCaptionSheet({
    required BuildContext context,
    required Widget preview,
  }) async {
    final captionController = TextEditingController();
    return await showModalBottomSheet<String>(
      context: context,
      isScrollControlled: true,
      builder: (ctx) => Padding(
        padding: EdgeInsets.only(
          left: 16, right: 16, top: 16,
          bottom: MediaQuery.of(ctx).viewInsets.bottom + 16,
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            SizedBox(height: 160, child: preview),
            const SizedBox(height: 12),
            TextField(
              key: const ValueKey('chat_caption_input'),
              controller: captionController,
              decoration: const InputDecoration(labelText: 'Thêm chú thích...'),
            ),
            const SizedBox(height: 12),
            Row(
              mainAxisAlignment: MainAxisAlignment.end,
              children: [
                TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('Hủy')),
                const SizedBox(width: 8),
                FilledButton(
                  onPressed: () => Navigator.pop(ctx, captionController.text.trim()),
                  child: const Text('Gửi'),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

class _StickerPicker extends StatelessWidget {
  const _StickerPicker({required this.onSelect});
  final ValueChanged<String> onSelect;

  static const _stickers = [
    'https://cdn-icons-png.flaticon.com/128/742/742751.png',
    'https://cdn-icons-png.flaticon.com/128/742/742752.png',
    'https://cdn-icons-png.flaticon.com/128/742/742920.png',
    'https://cdn-icons-png.flaticon.com/128/742/742760.png',
    'https://cdn-icons-png.flaticon.com/128/742/742824.png',
    'https://cdn-icons-png.flaticon.com/128/742/742921.png',
    'https://cdn-icons-png.flaticon.com/128/742/742745.png',
    'https://cdn-icons-png.flaticon.com/128/742/742878.png',
  ];

  @override
  Widget build(BuildContext context) {
    return Container(
      color: Theme.of(context).cardColor,
      child: GridView.builder(
        padding: const EdgeInsets.all(8),
        gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
          crossAxisCount: 4,
          crossAxisSpacing: 8,
          mainAxisSpacing: 8,
        ),
        itemCount: _stickers.length,
        itemBuilder: (context, index) {
          final url = _stickers[index];
          return InkWell(
            onTap: () => onSelect(url),
            borderRadius: BorderRadius.circular(8),
            child: Image.network(url, fit: BoxFit.contain),
          );
        },
      ),
    );
  }
}

class _GifPicker extends StatelessWidget {
  const _GifPicker({required this.onSelect});
  final ValueChanged<String> onSelect;

  static const _gifs = [
    'https://media.giphy.com/media/26tPplGWjN0xLyq36/giphy.gif',
    'https://media.giphy.com/media/3o7TKr3nzbh5WgCFxe/giphy.gif',
    'https://media.giphy.com/media/l0HlHJGHe3yAMhdQY/giphy.gif',
    'https://media.giphy.com/media/3o6Zt481isNVuQI1l6/giphy.gif',
    'https://media.giphy.com/media/dzaUX7CAG0Ihi/giphy.gif',
    'https://media.giphy.com/media/JIX9t2j0ZTN9S/giphy.gif',
  ];

  @override
  Widget build(BuildContext context) {
    return Container(
      color: Theme.of(context).cardColor,
      child: GridView.builder(
        padding: const EdgeInsets.all(8),
        gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
          crossAxisCount: 2,
          crossAxisSpacing: 8,
          mainAxisSpacing: 8,
          childAspectRatio: 1.5,
        ),
        itemCount: _gifs.length,
        itemBuilder: (context, index) {
          final url = _gifs[index];
          return InkWell(
            onTap: () => onSelect(url),
            borderRadius: BorderRadius.circular(8),
            child: ClipRRect(
              borderRadius: BorderRadius.circular(8),
              child: Image.network(url, fit: BoxFit.cover),
            ),
          );
        },
      ),
    );
  }
}
