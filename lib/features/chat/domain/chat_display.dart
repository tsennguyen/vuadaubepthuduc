import '../data/chat_repository.dart';
import '../data/user_directory_repository.dart';

class ChatDisplayInfo {
  final String title;
  final String? subtitle;
  final String? avatarUrl;
  final bool isGroup;
  final String? peerUserId;
  final List<String> groupAvatarUrls;

  ChatDisplayInfo({
    required this.title,
    this.subtitle,
    this.avatarUrl,
    required this.isGroup,
    this.peerUserId,
    this.groupAvatarUrls = const [],
  });
}

ChatDisplayInfo buildChatDisplayInfo({
  required Chat chat,
  required String currentUserId,
  Map<String, AppUserSummary> membersById = const {},
}) {
  final isGroup = chat.isGroup;
  String title;
  String? avatarUrl;
  String? subtitle;
  String? peerUserId;
  List<String> groupAvatarUrls = [];

  final otherMemberIds =
      chat.memberIds.where((id) => id != currentUserId).toList();

  if (isGroup) {
    title = chat.name?.isNotEmpty == true ? chat.name! : 'Nhóm';
    if (title == 'Nhóm' && otherMemberIds.isNotEmpty) {
       // Optional: generate name from members if nameless? 
       // Current requirement says: "chat.name" ... fallback to group name.
       // The user said: "if chat.isGroup -> use chat.name, chat.photoUrl, members count."
       // So if chat.name is null, we might want a better fallback or just "Nhóm".
    }
    
    subtitle = '${chat.memberIds.length} thành viên';

    if (chat.photoUrl != null && chat.photoUrl!.isNotEmpty) {
      avatarUrl = chat.photoUrl;
    } else {
      for (final uid in otherMemberIds) {
        final user = membersById[uid];
        final photo = user?.photoUrl;
        if (photo != null && photo.isNotEmpty) {
          groupAvatarUrls.add(photo);
        }
        if (groupAvatarUrls.length >= 2) break;
      }
    }
  } else {
    // 1-1 Chat
    peerUserId = otherMemberIds.isNotEmpty
        ? otherMemberIds.first
        : (chat.memberIds.isNotEmpty ? chat.memberIds.first : currentUserId);

    final peerUser = membersById[peerUserId];
    
    // Priority: Nickname -> DisplayName -> Fallback
    final nickname = chat.nicknames[peerUserId];
    if (nickname != null && nickname.isNotEmpty) {
      title = nickname;
    } else {
      title = peerUser?.displayName ?? '';
    }
    
    // If title is still empty (peerUser not found yet or no display name)
    if (title.isEmpty) {
        // Fallback checks
        if (chat.name != null && chat.name!.isNotEmpty) {
             title = chat.name!;
        } else {
             title = 'Người dùng';
        }
    }

    avatarUrl = peerUser?.photoUrl ?? chat.photoUrl;
  }

  return ChatDisplayInfo(
    title: title,
    subtitle: subtitle,
    avatarUrl: avatarUrl,
    isGroup: isGroup,
    peerUserId: peerUserId,
    groupAvatarUrls: groupAvatarUrls,
  );
}
