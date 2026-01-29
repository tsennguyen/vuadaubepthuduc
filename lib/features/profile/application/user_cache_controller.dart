import 'dart:async';

import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../domain/user_repository.dart';
import '../domain/user_summary.dart';
import '../infrastructure/firestore_user_repository.dart';

class UserCacheController extends StateNotifier<Map<String, UserSummary>> {
  UserCacheController(this._repository) : super(const {});

  final UserRepository _repository;
  final Set<String> _watching = <String>{};
  final List<StreamSubscription<Map<String, UserSummary>>> _subs = [];

  UserSummary? getUser(String uid) => state[uid];

  void preload(Set<String> uids) {
    final targets =
        uids.where((id) => id.isNotEmpty && !_watching.contains(id)).toSet();
    if (targets.isEmpty) return;
    _watching.addAll(targets);

    final sub = _repository.watchUsersByIds(targets).listen((map) {
      if (map.isEmpty) return;
      state = {...state, ...map};
    });
    _subs.add(sub);
  }

  @override
  void dispose() {
    super.dispose();
    for (final sub in _subs) {
      sub.cancel();
    }
  }
}

final userRepositoryProvider = Provider<UserRepository>((ref) {
  return FirestoreUserRepository();
});

final userCacheProvider =
    StateNotifierProvider<UserCacheController, Map<String, UserSummary>>((ref) {
  final repo = ref.watch(userRepositoryProvider);
  return UserCacheController(repo);
});
