enum MessageType { text, image, video, audio, file, system, sticker, gif }

MessageType messageTypeFromString(String? value) {
  switch ((value ?? '').toLowerCase()) {
    case 'image':
      return MessageType.image;
    case 'video':
      return MessageType.video;
    case 'audio':
      return MessageType.audio;
    case 'file':
      return MessageType.file;
    case 'system':
      return MessageType.system;
    case 'sticker':
      return MessageType.sticker;
    case 'gif':
      return MessageType.gif;
    case 'text':
    default:
      return MessageType.text;
  }
}

String messageTypeToString(MessageType type) {
  switch (type) {
    case MessageType.text:
      return 'text';
    case MessageType.image:
      return 'image';
    case MessageType.video:
      return 'video';
    case MessageType.audio:
      return 'audio';
    case MessageType.file:
      return 'file';
    case MessageType.system:
      return 'system';
    case MessageType.sticker:
      return 'sticker';
    case MessageType.gif:
      return 'gif';
  }
}

class ChatMessage {
  ChatMessage({
    required this.id,
    required this.chatId,
    required this.senderId,
    required this.type,
    this.text,
    this.attachmentUrl,
    this.attachmentThumbUrl,
    this.durationMs,
    required this.createdAt,
    this.editedAt,
    this.deletedAt,
    this.reactions = const {},
    this.readBy = const {},
    this.replyToMessageId,
    this.systemType,
    this.snapshot,
  });

  final String id;
  final String chatId;
  final String senderId;
  final MessageType type;
  final String? text;
  final String? attachmentUrl;
  final String? attachmentThumbUrl;
  final int? durationMs;
  final DateTime? createdAt;
  final DateTime? editedAt;
  final DateTime? deletedAt;
  final Map<String, String> reactions;
  final Map<String, DateTime?> readBy;
  final String? replyToMessageId;
  final String? systemType;
  final Object? snapshot;

  bool get isDeleted => deletedAt != null;
}
