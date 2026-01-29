import 'package:emoji_picker_flutter/emoji_picker_flutter.dart';
import 'package:flutter/material.dart';
import '../../domain/message.dart';

class MessageContextMenu extends StatelessWidget {
  const MessageContextMenu({
    super.key,
    required this.message,
    required this.isMe,
    required this.onReact,
    required this.onReply,
    this.onEdit,
    this.onDelete,
    this.onPin,
    this.onUnpin,
    this.isPinned = false,
  });

  final ChatMessage message;
  final bool isMe;
  final Function(String emoji) onReact;
  final VoidCallback onReply;
  final VoidCallback? onEdit;
  final VoidCallback? onDelete;
  final VoidCallback? onPin;
  final VoidCallback? onUnpin;
  final bool isPinned;

  @override
  Widget build(BuildContext context) {
    final emojis = ['❤️', '😂', '👍', '😮', '😢', '😡'];

    return Container(
      padding: const EdgeInsets.symmetric(vertical: 8),
      decoration: BoxDecoration(
        color: Theme.of(context).colorScheme.surface,
        borderRadius: const BorderRadius.vertical(top: Radius.circular(20)),
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          // Emoji reactions
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceAround,
              children: [
                ...emojis.map((e) => GestureDetector(
                      onTap: () => onReact(e),
                      child: Text(e, style: const TextStyle(fontSize: 28)),
                    )),
                IconButton(
                  icon: const Icon(Icons.add_circle_outline),
                  onPressed: () {
                    showModalBottomSheet(
                      context: context,
                      builder: (ctx) => SizedBox(
                        height: 350,
                        child: EmojiPicker(
                          onEmojiSelected: (category, emoji) {
                            onReact(emoji.emoji);
                            Navigator.pop(ctx);
                          },
                          config: const Config(
                            emojiViewConfig: EmojiViewConfig(
                              columns: 7,
                              emojiSizeMax: 32,
                            ),
                          ),
                        ),
                      ),
                    );
                  },
                ),
              ],
            ),
          ),
          const Divider(),
          // Actions
          ListTile(
            leading: const Icon(Icons.reply),
            title: const Text('Trả lời'),
            onTap: onReply,
          ),
          if (isMe && message.type == MessageType.text && !message.isDeleted)
            ListTile(
              leading: const Icon(Icons.edit_outlined),
              title: const Text('Sửa tin nhắn'),
              onTap: onEdit,
            ),
          if (!message.isDeleted && (onPin != null || onUnpin != null))
            ListTile(
              leading: Icon(isPinned ? Icons.push_pin : Icons.push_pin_outlined),
              title: Text(isPinned ? 'Bỏ ghim' : 'Ghim tin nhắn'),
              onTap: isPinned ? onUnpin : onPin,
            ),
          if (isMe && !message.isDeleted)
            ListTile(
              leading: const Icon(Icons.delete_outline, color: Colors.red),
              title: const Text('Gỡ tin nhắn', style: TextStyle(color: Colors.red)),
              onTap: onDelete,
            ),
          const SizedBox(height: 8),
        ],
      ),
    );
  }
}
