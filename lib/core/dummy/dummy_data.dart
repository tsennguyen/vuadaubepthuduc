class DummyUser {
  DummyUser({
    required this.id,
    required this.name,
    required this.avatarUrl,
    this.bio,
  });

  final String id;
  final String name;
  final String avatarUrl;
  final String? bio;
}

class DummyPost {
  DummyPost({
    required this.id,
    required this.title,
    required this.content,
    required this.authorId,
    required this.likes,
    required this.comments,
    required this.shares,
  });

  final String id;
  final String title;
  final String content;
  final String authorId;
  final int likes;
  final int comments;
  final int shares;
}

class DummyRecipe {
  DummyRecipe({
    required this.id,
    required this.title,
    required this.imageUrl,
    required this.rating,
    required this.tags,
    required this.ingredients,
    required this.steps,
  });

  final String id;
  final String title;
  final String imageUrl;
  final double rating;
  final List<String> tags;
  final List<String> ingredients;
  final List<String> steps;
}

class DummyChat {
  DummyChat({
    required this.id,
    required this.name,
    required this.lastMessage,
    required this.time,
    required this.memberIds,
  });

  final String id;
  final String name;
  final String lastMessage;
  final DateTime time;
  final List<String> memberIds;
}

class DummyMessage {
  DummyMessage({
    required this.id,
    required this.chatId,
    required this.senderId,
    required this.text,
    required this.time,
  });

  final String id;
  final String chatId;
  final String senderId;
  final String text;
  final DateTime time;
}

class DummyLeaderboardEntry {
  DummyLeaderboardEntry({
    required this.userId,
    required this.score,
  });

  final String userId;
  final int score;
}

final dummyUsers = <DummyUser>[
  DummyUser(
    id: 'u1',
    name: 'Chef An',
    avatarUrl: 'https://i.pravatar.cc/150?img=3',
    bio: 'Đầu bếp thích món Á.',
  ),
  DummyUser(
    id: 'u2',
    name: 'Chef Bình',
    avatarUrl: 'https://i.pravatar.cc/150?img=4',
    bio: 'Đam mê fusion food.',
  ),
  DummyUser(
    id: 'u3',
    name: 'Chef Cúc',
    avatarUrl: 'https://i.pravatar.cc/150?img=5',
    bio: 'Món Việt truyền thống.',
  ),
  DummyUser(
    id: 'u4',
    name: 'Chef Dũng',
    avatarUrl: 'https://i.pravatar.cc/150?img=6',
  ),
  DummyUser(
    id: 'u5',
    name: 'Chef Em',
    avatarUrl: 'https://i.pravatar.cc/150?img=7',
  ),
];

final dummyPosts = List.generate(
  10,
  (i) => DummyPost(
    id: 'p$i',
    title: 'Mẹo nấu ăn số $i',
    content: 'Chia sẻ nhanh về mẹo nấu ăn số $i với các nguyên liệu quen thuộc.',
    authorId: dummyUsers[i % dummyUsers.length].id,
    likes: 20 + i,
    comments: 5 + i,
    shares: 3 + i,
  ),
);

final dummyRecipes = List.generate(
  10,
  (i) => DummyRecipe(
    id: 'r$i',
    title: 'Công thức ${['Phở', 'Bún bò', 'Cơm tấm', 'Bánh xèo', 'Mì Quảng'][i % 5]} #$i',
    imageUrl: 'https://source.unsplash.com/600x40${i % 10}/?food',
    rating: 3.5 + (i % 3) * 0.5,
    tags: ['Việt', 'Nhanh', if (i.isEven) 'Healthy'],
    ingredients: ['Thịt', 'Rau', 'Gia vị', 'Nước dùng'],
    steps: ['Sơ chế nguyên liệu', 'Nấu món ăn', 'Trình bày và thưởng thức'],
  ),
);

final dummyChats = <DummyChat>[
  DummyChat(
    id: 'c1',
    name: 'Chef An',
    lastMessage: 'Hẹn cuối tuần nấu phở nhé!',
    time: DateTime.now().subtract(const Duration(minutes: 5)),
    memberIds: ['u1', 'u2'],
  ),
  DummyChat(
    id: 'c2',
    name: 'Nhóm Fusion',
    lastMessage: 'Cùng brainstorm món mới.',
    time: DateTime.now().subtract(const Duration(hours: 2)),
    memberIds: ['u1', 'u3', 'u4'],
  ),
];

final dummyMessages = <DummyMessage>[
  DummyMessage(
    id: 'm1',
    chatId: 'c1',
    senderId: 'u1',
    text: 'Hello, chuẩn bị món mới chưa?',
    time: DateTime.now().subtract(const Duration(minutes: 6)),
  ),
  DummyMessage(
    id: 'm2',
    chatId: 'c1',
    senderId: 'u2',
    text: 'Yes, cuối tuần gặp nhé!',
    time: DateTime.now().subtract(const Duration(minutes: 4)),
  ),
  DummyMessage(
    id: 'm3',
    chatId: 'c2',
    senderId: 'u3',
    text: 'Ý tưởng về món fusion mới.',
    time: DateTime.now().subtract(const Duration(minutes: 20)),
  ),
  DummyMessage(
    id: 'm4',
    chatId: 'c2',
    senderId: 'u1',
    text: 'Nghe hay đó.',
    time: DateTime.now().subtract(const Duration(minutes: 15)),
  ),
];

final dummyLeaderboardWeek = <DummyLeaderboardEntry>[
  DummyLeaderboardEntry(userId: 'u1', score: 120),
  DummyLeaderboardEntry(userId: 'u2', score: 100),
  DummyLeaderboardEntry(userId: 'u3', score: 90),
];

final dummyLeaderboardMonth = <DummyLeaderboardEntry>[
  DummyLeaderboardEntry(userId: 'u2', score: 450),
  DummyLeaderboardEntry(userId: 'u1', score: 400),
  DummyLeaderboardEntry(userId: 'u4', score: 300),
];

DummyUser findUser(String id) =>
    dummyUsers.firstWhere((u) => u.id == id, orElse: () => dummyUsers.first);
