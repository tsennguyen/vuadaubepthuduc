import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../data/chat_repository.dart';

final authUserIdProvider = Provider<String?>(
  (ref) => FirebaseAuth.instance.currentUser?.uid,
);

final chatListProvider = StreamProvider.autoDispose<List<ChatSummary>>(
  (ref) {
    final currentUserId = ref.watch(authUserIdProvider);
    final repo = ref.watch(chatRepositoryProvider);
    if (currentUserId == null) {
      return const Stream<List<ChatSummary>>.empty();
    }
    return repo.watchUserChats(currentUserId);
  },
);
