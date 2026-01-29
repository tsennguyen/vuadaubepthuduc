import 'dart:async';

import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../profile/application/profile_controller.dart';
import '../data/firebase_friend_repository.dart';
import '../domain/friend_models.dart';
import '../domain/friend_repository.dart';

final friendRepositoryProvider = Provider<FriendRepository>((ref) {
  final banGuard = ref.watch(userBanGuardProvider);
  return FirebaseFriendRepository(userBanGuard: banGuard);
});

final friendsStreamProvider =
    StreamProvider.autoDispose<List<Friend>>((ref) {
  final repo = ref.watch(friendRepositoryProvider);
  final uid = ref.watch(currentUserIdProvider);
  if (uid == null) return Stream<List<Friend>>.value(const []);
  return repo.watchFriends();
});

final incomingFriendRequestsProvider =
    StreamProvider.autoDispose<List<FriendRequest>>((ref) {
  final repo = ref.watch(friendRepositoryProvider);
  final uid = ref.watch(currentUserIdProvider);
  if (uid == null) return Stream<List<FriendRequest>>.value(const []);
  return repo.watchIncomingRequests();
});

final outgoingFriendRequestsProvider =
    StreamProvider.autoDispose<List<FriendRequest>>((ref) {
  final repo = ref.watch(friendRepositoryProvider);
  final uid = ref.watch(currentUserIdProvider);
  if (uid == null) return Stream<List<FriendRequest>>.value(const []);
  return repo.watchOutgoingRequests();
});

enum RelationshipStatus {
  none,
  following,
  pendingSent,
  pendingReceived,
  friends,
}

class RelationshipState {
  const RelationshipState({
    required this.status,
    this.pendingRequest,
    this.isFollowing = false,
    this.isFriend = false,
  });

  final RelationshipStatus status;
  final FriendRequest? pendingRequest;
  final bool isFollowing;
  final bool isFriend;
}

final relationshipProvider =
    StreamProvider.autoDispose.family<RelationshipState, String>(
        (ref, otherUid) {
  final currentUid = ref.watch(currentUserIdProvider);
  if (currentUid == null || otherUid.isEmpty || currentUid == otherUid) {
    return Stream<RelationshipState>.value(
      const RelationshipState(
        status: RelationshipStatus.none,
        isFollowing: false,
        isFriend: false,
      ),
    );
  }

  final repo = ref.watch(friendRepositoryProvider);
  final controller = StreamController<RelationshipState>();

  FriendRequest? incoming;
  FriendRequest? outgoing;
  var isFollowing = false;
  var isFriend = false;

  void emit() {
    RelationshipStatus status = RelationshipStatus.none;
    FriendRequest? pending;

    if (isFriend) {
      status = RelationshipStatus.friends;
      isFollowing = true;
    } else if (incoming?.status == FriendRequestStatus.pending) {
      status = RelationshipStatus.pendingReceived;
      pending = incoming;
    } else if (outgoing?.status == FriendRequestStatus.pending) {
      status = RelationshipStatus.pendingSent;
      pending = outgoing;
    } else if (isFollowing) {
      status = RelationshipStatus.following;
    }

    if (!controller.isClosed) {
      controller.add(
        RelationshipState(
          status: status,
          pendingRequest: pending,
          isFollowing: isFollowing || isFriend,
          isFriend: isFriend,
        ),
      );
    }
  }

  final followSub = repo.watchIsFollowing(otherUid).listen(
    (value) {
      isFollowing = value;
      emit();
    },
    onError: controller.addError,
  );

  final incomingSub = repo.watchIncomingRequests().listen(
    (requests) {
      incoming = _findRequest(
        requests,
        requesterId: otherUid,
        targetId: currentUid,
      );
      emit();
    },
    onError: controller.addError,
  );

  final outgoingSub = repo.watchOutgoingRequests().listen(
    (requests) {
      outgoing = _findRequest(
        requests,
        requesterId: currentUid,
        targetId: otherUid,
      );
      emit();
    },
    onError: controller.addError,
  );

  final friendSub = repo.watchFriends().listen(
    (friends) {
      isFriend = friends.any((f) => f.friendUid == otherUid);
      emit();
    },
    onError: controller.addError,
  );

  controller.onCancel = () async {
    await followSub.cancel();
    await incomingSub.cancel();
    await outgoingSub.cancel();
    await friendSub.cancel();
    await controller.close();
  };

  return controller.stream;
});

FriendRequest? _findRequest(
  List<FriendRequest> requests, {
  required String? requesterId,
  required String? targetId,
}) {
  for (final req in requests) {
    if (req.status != FriendRequestStatus.pending) continue;
    if (req.requesterId == requesterId && req.targetId == targetId) {
      return req;
    }
  }
  return null;
}
