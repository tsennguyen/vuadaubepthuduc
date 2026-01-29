import 'package:firebase_auth/firebase_auth.dart';

import '../data/profile_repository.dart';

class UserBannedException implements Exception {
  UserBannedException(this.profile)
      : message = buildBanMessage(profile);

  final AppUserProfile profile;
  final String message;

  @override
  String toString() => message;
}

class UserBanGuard {
  UserBanGuard({
    required ProfileRepository profileRepository,
    FirebaseAuth? auth,
  })  : _profileRepository = profileRepository,
        _auth = auth ?? FirebaseAuth.instance;

  final ProfileRepository _profileRepository;
  final FirebaseAuth _auth;

  AppUserProfile? _cachedProfile;
  DateTime? _lastFetchedAt;

  Future<void> ensureNotBanned() async {
    final profile = await _loadProfile();
    if (profile == null) return;
    if (isUserBanned(profile)) {
      throw UserBannedException(profile);
    }
  }

  Future<AppUserProfile?> _loadProfile() async {
    final uid = _auth.currentUser?.uid;
    if (uid == null) return null;

    final now = DateTime.now();
    if (_cachedProfile != null &&
        _cachedProfile!.uid == uid &&
        _lastFetchedAt != null &&
        now.difference(_lastFetchedAt!) < const Duration(seconds: 30)) {
      return _cachedProfile;
    }

    final profile = await _profileRepository.fetchProfile(uid);
    _cachedProfile = profile;
    _lastFetchedAt = now;
    return profile;
  }
}

bool isUserBanned(AppUserProfile? user) {
  if (user == null) return false;
  final until = user.banUntil;
  final hasFutureBan = until != null && until.isAfter(DateTime.now());
  return user.isBanned || hasFutureBan;
}

String buildBanMessage(AppUserProfile user) {
  final until = user.banUntil;
  final expiry = until != null
      ? _formatDateTime(until)
      : 'vo thoi han';
  final reason = (user.banReason ?? '').trim();
  final reasonText = reason.isNotEmpty ? ' Ly do: $reason.' : '';
  return 'Tai khoan cua ban dang bi han che do vi pham tieu chuan cong dong. Het han: $expiry.$reasonText';
}

String _formatDateTime(DateTime dateTime) {
  final local = dateTime.toLocal();
  String two(int n) => n.toString().padLeft(2, '0');
  return '${two(local.day)}/${two(local.month)}/${local.year} ${two(local.hour)}:${two(local.minute)}';
}
