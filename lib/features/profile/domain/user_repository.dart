import 'user_summary.dart';

abstract class UserRepository {
  Stream<UserSummary?> watchUser(String uid);
  Future<UserSummary?> getUserOnce(String uid);
  Stream<Map<String, UserSummary>> watchUsersByIds(Set<String> uids);
}
