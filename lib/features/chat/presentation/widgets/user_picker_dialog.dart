import 'dart:async';

import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../data/user_directory_repository.dart';
import '../../../profile/application/user_cache_controller.dart';
import '../../../profile/domain/user_summary.dart';
import '../../../social/application/social_providers.dart';

enum UserPickerMode { single, multi }

final _friendUsersProvider =
    StreamProvider.autoDispose<List<AppUserSummary>>((ref) {
  final userRepo = ref.watch(userRepositoryProvider);
  final controller = StreamController<List<AppUserSummary>>();
  StreamSubscription<Map<String, UserSummary>>? userSub;

  void listenUsers(Set<String> ids) {
    userSub?.cancel();
    if (ids.isEmpty) {
      controller.add(const []);
      return;
    }
    userSub = userRepo.watchUsersByIds(ids).listen((map) {
      final users = map.values.map((user) {
        final name = user.displayName?.isNotEmpty == true
            ? user.displayName!
            : (user.email ?? user.uid);
        return AppUserSummary(
          uid: user.uid,
          displayName: name,
          photoUrl: user.photoUrl,
          snapshot: null,
        );
      }).toList()
        ..sort((a, b) => a.displayName.compareTo(b.displayName));
      controller.add(users);
    }, onError: controller.addError);
  }

  ref.listen(friendsStreamProvider, (previous, next) {
    next.whenData((friends) {
      final ids = friends.map((f) => f.friendUid).toSet();
      listenUsers(ids);
    });
  });

  controller.onCancel = () async {
    await userSub?.cancel();
    await controller.close();
  };

  ref.onDispose(() async {
    await userSub?.cancel();
    await controller.close();
  });

  return controller.stream;
});

class UserPickerDialog extends ConsumerStatefulWidget {
  const UserPickerDialog({
    super.key,
    required this.mode,
    this.excludeUid,
  });

  final UserPickerMode mode;
  final String? excludeUid;

  static Future<AppUserSummary?> pickSingle(
    BuildContext context, {
    String? excludeUid,
  }) {
    return showDialog<AppUserSummary>(
      context: context,
      builder: (_) => UserPickerDialog(
        mode: UserPickerMode.single,
        excludeUid: excludeUid ?? FirebaseAuth.instance.currentUser?.uid,
      ),
    );
  }

  static Future<List<AppUserSummary>> pickMulti(
    BuildContext context, {
    String? excludeUid,
  }) async {
    final result = await showDialog<List<AppUserSummary>>(
      context: context,
      builder: (_) => UserPickerDialog(
        mode: UserPickerMode.multi,
        excludeUid: excludeUid ?? FirebaseAuth.instance.currentUser?.uid,
      ),
    );
    return result ?? <AppUserSummary>[];
  }

  @override
  ConsumerState<UserPickerDialog> createState() => _UserPickerDialogState();
}

class _UserPickerDialogState extends ConsumerState<UserPickerDialog> {
  String _query = '';
  final Set<String> _selected = {};
  List<AppUserSummary> _cachedUsers = [];

  @override
  Widget build(BuildContext context) {
    final usersAsync = ref.watch(_friendUsersProvider);
    final theme = Theme.of(context);

    return Dialog(
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(28)),
      elevation: 12,
      child: Container(
        width: 450,
        height: 600,
        decoration: BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
            colors: [
              theme.colorScheme.surface,
              theme.colorScheme.surfaceContainerHighest,
            ],
          ),
          borderRadius: BorderRadius.circular(28),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Header
            Container(
              padding: const EdgeInsets.all(24),
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  colors: [
                    theme.colorScheme.primaryContainer.withValues(alpha: 0.4),
                    theme.colorScheme.secondaryContainer.withValues(alpha: 0.3),
                  ],
                ),
                borderRadius: const BorderRadius.only(
                  topLeft: Radius.circular(28),
                  topRight: Radius.circular(28),
                ),
              ),
              child: Row(
                children: [
                  Container(
                    padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(
                      gradient: LinearGradient(
                        colors: [
                          theme.colorScheme.primary,
                          theme.colorScheme.secondary,
                        ],
                      ),
                      borderRadius: BorderRadius.circular(16),
                      boxShadow: [
                        BoxShadow(
                          color: theme.colorScheme.primary.withValues(alpha: 0.3),
                          blurRadius: 8,
                          offset: const Offset(0, 4),
                        ),
                      ],
                    ),
                    child: Icon(
                      widget.mode == UserPickerMode.single 
                          ? Icons.person_add_rounded 
                          : Icons.group_add_rounded, 
                      color: Colors.white, 
                      size: 24,
                    ),
                  ),
                  const SizedBox(width: 16),
                  Expanded(
                    child: Text(
                      widget.mode == UserPickerMode.single ? 'Chọn người dùng' : 'Chọn thành viên',
                      style: theme.textTheme.headlineSmall?.copyWith(
                        fontWeight: FontWeight.bold,
                        color: theme.colorScheme.onSurface,
                      ),
                    ),
                  ),
                  IconButton(
                    icon: Icon(Icons.close_rounded, color: theme.colorScheme.onSurface),
                    onPressed: () => Navigator.of(context).pop(),
                  ),
                ],
              ),
            ),
            
            // Search Bar
            Padding(
              padding: const EdgeInsets.all(20),
              child: TextField(
                decoration: InputDecoration(
                  hintText: 'Tìm theo tên...',
                  filled: true,
                  fillColor: theme.colorScheme.surfaceContainerHighest.withValues(alpha: 0.5),
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(20),
                    borderSide: BorderSide.none,
                  ),
                  focusedBorder: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(20),
                    borderSide: BorderSide(
                      color: theme.colorScheme.primary,
                      width: 2,
                    ),
                  ),
                  prefixIcon: Icon(Icons.search_rounded, color: theme.colorScheme.primary),
                  contentPadding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
                ),
                onChanged: (value) => setState(() => _query = value),
              ),
            ),
            
            // Selected count for multi mode
            if (widget.mode == UserPickerMode.multi && _selected.isNotEmpty)
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 20),
                child: Container(
                  padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                  decoration: BoxDecoration(
                    gradient: LinearGradient(
                      colors: [
                        theme.colorScheme.primary.withValues(alpha: 0.1),
                        theme.colorScheme.secondary.withValues(alpha: 0.1),
                      ],
                    ),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(Icons.check_circle_rounded, 
                        color: theme.colorScheme.primary, 
                        size: 18,
                      ),
                      const SizedBox(width: 8),
                      Text(
                        'Đã chọn ${_selected.length} người',
                        style: TextStyle(
                          color: theme.colorScheme.primary,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            
            const SizedBox(height: 8),
            
            // User List
            Expanded(
              child: usersAsync.when(
                data: (users) {
                  _cachedUsers = users;
                  
                  final lower = _query.toLowerCase();
                  final filtered = users.where((u) {
                    if (widget.excludeUid != null &&
                        widget.excludeUid!.isNotEmpty &&
                        u.uid == widget.excludeUid) {
                      return false;
                    }
                    if (lower.isEmpty) return true;
                    return u.displayName.toLowerCase().contains(lower);
                  }).toList();

                  if (filtered.isEmpty) {
                    return Center(
                      child: Column(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Icon(
                            Icons.people_outline_rounded,
                            size: 64,
                            color: theme.colorScheme.onSurface.withValues(alpha: 0.3),
                          ),
                          const SizedBox(height: 16),
                          Text(
                            'Không có bạn bè',
                            style: TextStyle(
                              color: theme.colorScheme.onSurface.withValues(alpha: 0.6),
                              fontSize: 16,
                            ),
                          ),
                        ],
                      ),
                    );
                  }

                  return ListView.separated(
                    padding: const EdgeInsets.symmetric(horizontal: 12),
                    itemCount: filtered.length,
                    separatorBuilder: (_, __) => const SizedBox(height: 4),
                    itemBuilder: (context, index) {
                      final user = filtered[index];
                      final selected = _selected.contains(user.uid);
                      
                      return Material(
                        color: Colors.transparent,
                        child: InkWell(
                          onTap: () {
                            if (widget.mode == UserPickerMode.single) {
                              Navigator.of(context).pop(user);
                            } else {
                              _toggle(user.uid);
                            }
                          },
                          borderRadius: BorderRadius.circular(16),
                          child: Container(
                            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 12),
                            decoration: BoxDecoration(
                              gradient: selected
                                  ? LinearGradient(
                                      colors: [
                                        theme.colorScheme.primaryContainer.withValues(alpha: 0.3),
                                        theme.colorScheme.secondaryContainer.withValues(alpha: 0.2),
                                      ],
                                    )
                                  : null,
                              borderRadius: BorderRadius.circular(16),
                              border: Border.all(
                                color: selected 
                                    ? theme.colorScheme.primary.withValues(alpha: 0.5)
                                    : Colors.transparent,
                                width: 2,
                              ),
                            ),
                            child: Row(
                              children: [
                                Stack(
                                  children: [
                                    CircleAvatar(
                                      radius: 24,
                                      backgroundImage: user.photoUrl != null
                                          ? NetworkImage(user.photoUrl!)
                                          : null,
                                      backgroundColor: theme.colorScheme.primaryContainer,
                                      child: user.photoUrl == null
                                          ? Text(
                                              user.displayName.isNotEmpty
                                                  ? user.displayName[0].toUpperCase()
                                                  : '?',
                                              style: TextStyle(
                                                color: theme.colorScheme.onPrimaryContainer,
                                                fontWeight: FontWeight.bold,
                                                fontSize: 18,
                                              ),
                                            )
                                          : null,
                                    ),
                                    if (selected)
                                      Positioned(
                                        right: 0,
                                        bottom: 0,
                                        child: Container(
                                          padding: const EdgeInsets.all(2),
                                          decoration: BoxDecoration(
                                            color: theme.colorScheme.primary,
                                            shape: BoxShape.circle,
                                            border: Border.all(
                                              color: theme.colorScheme.surface,
                                              width: 2,
                                            ),
                                          ),
                                          child: const Icon(
                                            Icons.check_rounded,
                                            color: Colors.white,
                                            size: 14,
                                          ),
                                        ),
                                      ),
                                  ],
                                ),
                                const SizedBox(width: 12),
                                Expanded(
                                  child: Text(
                                    user.displayName.isNotEmpty ? user.displayName : user.uid,
                                    style: theme.textTheme.titleMedium?.copyWith(
                                      fontWeight: selected ? FontWeight.w600 : FontWeight.w500,
                                    ),
                                    maxLines: 1,
                                    overflow: TextOverflow.ellipsis,
                                  ),
                                ),
                                if (widget.mode == UserPickerMode.multi)
                                  Checkbox(
                                    value: selected,
                                    onChanged: (_) => _toggle(user.uid),
                                    shape: RoundedRectangleBorder(
                                      borderRadius: BorderRadius.circular(6),
                                    ),
                                  ),
                              ],
                            ),
                          ),
                        ),
                      );
                    },
                  );
                },
                loading: () => const Center(child: CircularProgressIndicator()),
                error: (e, __) => Center(
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(
                        Icons.error_outline_rounded,
                        size: 64,
                        color: theme.colorScheme.error,
                      ),
                      const SizedBox(height: 16),
                      Text(
                        'Lỗi tải danh sách',
                        style: TextStyle(color: theme.colorScheme.error),
                      ),
                    ],
                  ),
                ),
              ),
            ),
            
            // Action Buttons
            Container(
              padding: const EdgeInsets.all(20),
              decoration: BoxDecoration(
                color: theme.colorScheme.surface,
                borderRadius: const BorderRadius.only(
                  bottomLeft: Radius.circular(28),
                  bottomRight: Radius.circular(28),
                ),
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withValues(alpha: 0.05),
                    blurRadius: 10,
                    offset: const Offset(0, -4),
                  ),
                ],
              ),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.end,
                children: [
                  if (widget.mode == UserPickerMode.single)
                    TextButton(
                      onPressed: () => Navigator.of(context).pop(),
                      style: TextButton.styleFrom(
                        padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(12),
                        ),
                      ),
                      child: Text(
                        'Hủy',
                        style: TextStyle(
                          color: theme.colorScheme.onSurface.withValues(alpha: 0.6),
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    )
                  else ...[
                    TextButton(
                      onPressed: () => Navigator.of(context).pop(),
                      style: TextButton.styleFrom(
                        padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(12),
                        ),
                      ),
                      child: Text(
                        'Hủy',
                        style: TextStyle(
                          color: theme.colorScheme.onSurface.withValues(alpha: 0.6),
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ),
                    const SizedBox(width: 12),
                    Container(
                      decoration: BoxDecoration(
                        gradient: LinearGradient(
                          colors: [
                            theme.colorScheme.primary,
                            theme.colorScheme.secondary,
                          ],
                        ),
                        borderRadius: BorderRadius.circular(12),
                        boxShadow: [
                          BoxShadow(
                            color: theme.colorScheme.primary.withValues(alpha: 0.4),
                            blurRadius: 8,
                            offset: const Offset(0, 4),
                          ),
                        ],
                      ),
                      child: ElevatedButton(
                        onPressed: () {
                          final selected = _cachedUsers
                              .where((u) => _selected.contains(u.uid))
                              .toList(growable: false);
                          Navigator.of(context).pop(selected);
                        },
                        style: ElevatedButton.styleFrom(
                          backgroundColor: Colors.transparent,
                          shadowColor: Colors.transparent,
                          padding: const EdgeInsets.symmetric(horizontal: 32, vertical: 12),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(12),
                          ),
                        ),
                        child: const Text(
                          'Xong',
                          style: TextStyle(
                            color: Colors.white,
                            fontWeight: FontWeight.bold,
                            fontSize: 15,
                          ),
                        ),
                      ),
                    ),
                  ],
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  void _toggle(String uid) {
    setState(() {
      if (_selected.contains(uid)) {
        _selected.remove(uid);
      } else {
        _selected.add(uid);
      }
    });
  }
}
