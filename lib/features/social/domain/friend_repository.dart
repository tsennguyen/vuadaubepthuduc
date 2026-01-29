import 'friend_models.dart';

abstract class FriendRepository {
  // Follow
  Future<void> followUser(String targetUid);
  Future<void> unfollowUser(String targetUid);
  Stream<bool> watchIsFollowing(String targetUid);

  // Friend request
  Future<void> sendFriendRequest(String targetUid);
  Future<void> cancelFriendRequest(String requestId);
  Future<void> acceptFriendRequest(String requestId);
  Future<void> rejectFriendRequest(String requestId);

  Stream<List<FriendRequest>> watchIncomingRequests(); // targetId = currentUser
  Stream<List<FriendRequest>> watchOutgoingRequests(); // requesterId = currentUser

  // Friends
  Stream<List<Friend>> watchFriends();
  Future<bool> isFriend(String otherUid);
  Future<void> removeFriend(String otherUid);
  
  // Get friend IDs for filtering
  Future<List<String>> getFriendIds();
}
