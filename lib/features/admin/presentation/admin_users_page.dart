import 'dart:async';

import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../data/admin_user_repository.dart';
import 'admin_scaffold.dart';
import 'widgets/admin_page_actions.dart';
import 'widgets/ban_user_dialog.dart';

class AdminUsersPage extends StatefulWidget {
  const AdminUsersPage({super.key});

  @override
  State<AdminUsersPage> createState() => _AdminUsersPageState();
}

class _AdminUsersPageState extends State<AdminUsersPage> {
  late final AdminUserRepository _repository;
  late Stream<List<AdminUser>> _usersStream;

  final _searchController = TextEditingController();
  Timer? _debounce;
  String _query = '';

  final Set<String> _busyUids = <String>{};

  @override
  void initState() {
    super.initState();
    _repository = FirestoreAdminUserRepository();
    _usersStream = _repository.watchUsers();
    _searchController.addListener(_onSearchChanged);
  }

  void _onSearchChanged() {
    _debounce?.cancel();
    _debounce = Timer(const Duration(milliseconds: 300), () {
      final next = _searchController.text.trim();
      if (next == _query) return;
      if (!mounted) return;
      setState(() {
        _query = next;
        _usersStream = _repository.watchUsers(query: _query);
      });
    });
  }

  void _retry() {
    setState(() {
      _usersStream = _repository.watchUsers(query: _query);
    });
  }

  Future<void> _updateRole({
    required AdminUser user,
    required String newRole,
    required String? currentAdminUid,
  }) async {
    if (user.role == newRole) return;
    final isSelf = currentAdminUid != null && user.uid == currentAdminUid;
    if (isSelf) return;

    setState(() => _busyUids.add(user.uid));
    try {
      await _repository.updateUserRole(user.uid, newRole);
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Cập nhật quyền thất bại: $e')),
      );
    } finally {
      if (mounted) {
        setState(() => _busyUids.remove(user.uid));
      }
    }
  }

  Future<void> _toggleDisabled({
    required AdminUser user,
    required bool disabled,
    required String? currentAdminUid,
  }) async {
    if (user.disabled == disabled) return;
    final isSelf = currentAdminUid != null && user.uid == currentAdminUid;
    if (isSelf) return;

    setState(() => _busyUids.add(user.uid));
    try {
      await _repository.toggleUserDisabled(user.uid, disabled);
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Cập nhật trạng thái khóa thất bại: $e')),
      );
    } finally {
      if (mounted) {
        setState(() => _busyUids.remove(user.uid));
      }
    }
  }

  Future<void> _banUser({
    required AdminUser user,
    required String? currentAdminUid,
  }) async {
    final isSelf = currentAdminUid != null && user.uid == currentAdminUid;
    if (isSelf) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Không thể tự cấm chính mình')),
      );
      return;
    }

    // Import dialog at top: import 'widgets/ban_user_dialog.dart';
    final result = await showDialog<Map<String, dynamic>>(
      context: context,
      builder: (context) => BanUserDialog(
        userName: user.displayName ?? user.email ?? user.uid,
        currentBanReason: user.banReason,
        currentBanUntil: user.banUntil,
      ),
    );

    if (result == null || !mounted) return;

    setState(() => _busyUids.add(user.uid));
    try {
      await _repository.setBanStatus(
        user.uid,
        isBanned: true,
        banReason: result['reason'] as String?,
        banUntil: result['until'] as DateTime?,
      );
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Đã cấm người dùng thành công')),
      );
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Cấm người dùng thất bại: $e')),
      );
    } finally {
      if (mounted) {
        setState(() => _busyUids.remove(user.uid));
      }
    }
  }

  Future<void> _unbanUser({
    required AdminUser user,
    required String? currentAdminUid,
  }) async {
    setState(() => _busyUids.add(user.uid));
    try {
      await _repository.setBanStatus(
        user.uid,
        isBanned: false,
      );
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Đã bỏ cấm người dùng')),
      );
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Bỏ cấm thất bại: $e')),
      );
    } finally {
      if (mounted) {
        setState(() => _busyUids.remove(user.uid));
      }
    }
  }

  Future<void> _copyUid(String uid) async {
    await Clipboard.setData(ClipboardData(text: uid));
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text('Đã sao chép UID')),
    );
  }

  @override
  void dispose() {
    _debounce?.cancel();
    _searchController
      ..removeListener(_onSearchChanged)
      ..dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final currentAdminUid = FirebaseAuth.instance.currentUser?.uid;
    return AdminShell(
      actions: [
        AdminPageActions(
          onRefresh: _retry,
        ),
      ],
      child: Column(
        children: [
          _SearchBar(
            controller: _searchController,
            onClear: () => _searchController.clear(),
          ),
          Expanded(
            child: StreamBuilder<List<AdminUser>>(
              stream: _usersStream,
              builder: (context, snapshot) {
                if (snapshot.hasError) {
                  return _ErrorView(
                    message: '${snapshot.error}',
                    onRetry: _retry,
                  );
                }

                if (!snapshot.hasData) {
                  return const Center(child: CircularProgressIndicator());
                }

                final users = snapshot.data ?? const <AdminUser>[];
                if (users.isEmpty) {
                  return const Center(child: Text('Không tìm thấy người dùng nào.'));
                }

                return LayoutBuilder(
                  builder: (context, constraints) {
                    final useTable = constraints.maxWidth >= 900;
                    if (useTable) {
                      return _UsersTable(
                        users: users,
                        currentAdminUid: currentAdminUid,
                        busyUids: _busyUids,
                        onRoleChanged: (user, role) => _updateRole(
                          user: user,
                          newRole: role,
                          currentAdminUid: currentAdminUid,
                        ),
                        onDisabledChanged: (user, disabled) => _toggleDisabled(
                          user: user,
                          disabled: disabled,
                          currentAdminUid: currentAdminUid,
                        ),
                        onBanUser: (user) => _banUser(
                          user: user,
                          currentAdminUid: currentAdminUid,
                        ),
                        onUnbanUser: (user) => _unbanUser(
                          user: user,
                          currentAdminUid: currentAdminUid,
                        ),
                        onCopyUid: _copyUid,
                      );
                    }

                    return _UsersList(
                      users: users,
                      currentAdminUid: currentAdminUid,
                      busyUids: _busyUids,
                      onRoleChanged: (user, role) => _updateRole(
                        user: user,
                        newRole: role,
                        currentAdminUid: currentAdminUid,
                      ),
                      onDisabledChanged: (user, disabled) => _toggleDisabled(
                        user: user,
                        disabled: disabled,
                        currentAdminUid: currentAdminUid,
                      ),
                      onBanUser: (user) => _banUser(
                        user: user,
                        currentAdminUid: currentAdminUid,
                      ),
                      onUnbanUser: (user) => _unbanUser(
                        user: user,
                        currentAdminUid: currentAdminUid,
                      ),
                      onCopyUid: _copyUid,
                    );
                  },
                );
              },
            ),
          ),
        ],
      ),
    );
  }
}

class _SearchBar extends StatelessWidget {
  const _SearchBar({
    required this.controller,
    required this.onClear,
  });

  final TextEditingController controller;
  final VoidCallback onClear;

  @override
  Widget build(BuildContext context) {
    return Material(
      elevation: 0,
      child: Padding(
        padding: const EdgeInsets.fromLTRB(16, 16, 16, 8),
        child: ValueListenableBuilder<TextEditingValue>(
          valueListenable: controller,
          builder: (context, value, _) {
            return TextField(
              controller: controller,
              decoration: InputDecoration(
                prefixIcon: const Icon(Icons.search),
                hintText: 'Tìm kiếm theo email hoặc tên hiển thị',
                border: const OutlineInputBorder(),
                suffixIcon: value.text.isEmpty
                    ? null
                    : IconButton(
                        tooltip: 'Xóa',
                        onPressed: onClear,
                        icon: const Icon(Icons.clear),
                      ),
              ),
            );
          },
        ),
      ),
    );
  }
}

class _ErrorView extends StatelessWidget {
  const _ErrorView({required this.message, required this.onRetry});

  final String message;
  final VoidCallback onRetry;

  @override
  Widget build(BuildContext context) {
    return Center(
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 520),
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(
                'Không tải được danh sách người dùng',
                style: Theme.of(context).textTheme.titleMedium,
              ),
              const SizedBox(height: 8),
              Text(message, textAlign: TextAlign.center),
              const SizedBox(height: 12),
              ElevatedButton.icon(
                onPressed: onRetry,
                icon: const Icon(Icons.refresh),
                label: const Text('Thử lại'),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

typedef _RoleChanged = void Function(AdminUser user, String role);
typedef _DisabledChanged = void Function(AdminUser user, bool disabled);
typedef _UserAction = void Function(AdminUser user);

class _UsersTable extends StatelessWidget {
  const _UsersTable({
    required this.users,
    required this.currentAdminUid,
    required this.busyUids,
    required this.onRoleChanged,
    required this.onDisabledChanged,
    required this.onBanUser,
    required this.onUnbanUser,
    required this.onCopyUid,
  });

  final List<AdminUser> users;
  final String? currentAdminUid;
  final Set<String> busyUids;
  final _RoleChanged onRoleChanged;
  final _DisabledChanged onDisabledChanged;
  final _UserAction onBanUser;
  final _UserAction onUnbanUser;
  final Future<void> Function(String uid) onCopyUid;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return SingleChildScrollView(
      padding: const EdgeInsets.all(16),
      child: SingleChildScrollView(
        scrollDirection: Axis.horizontal,
        child: DataTable(
          columns: const [
            DataColumn(label: Text('Ảnh')),
            DataColumn(label: Text('Tên')),
            DataColumn(label: Text('Email')),
            DataColumn(label: Text('Quyền')),
            DataColumn(label: Text('TT Khóa')),
            DataColumn(label: Text('TT Ban')),
            DataColumn(label: Text('Thao tác')),
          ],
          rows: [
            for (final user in users)
              _buildRow(
                context: context,
                theme: theme,
                user: user,
              ),
          ],
        ),
      ),
    );
  }

  DataRow _buildRow({
    required BuildContext context,
    required ThemeData theme,
    required AdminUser user,
  }) {
    final isSelf = currentAdminUid != null && user.uid == currentAdminUid;
    final isBusy = busyUids.contains(user.uid);
    final canEdit = !isSelf && !isBusy;

    final roleValue = FirestoreAdminUserRepository.allowedRoles.contains(user.role)
        ? user.role
        : 'client';

    final rowColor = isSelf
        ? theme.colorScheme.primaryContainer.withValues(alpha: 0.35)
        : null;

    return DataRow(
      color: rowColor == null ? null : WidgetStatePropertyAll(rowColor),
      cells: [
        DataCell(_Avatar(photoUrl: user.photoUrl, label: _avatarLabel(user))),
        DataCell(Text(_displayName(user))),
        DataCell(Text(user.email?.trim().isNotEmpty == true ? user.email! : '—')),
        DataCell(
          DropdownButton<String>(
            value: roleValue,
            isDense: true,
            onChanged:
                canEdit ? (v) => v == null ? null : onRoleChanged(user, v) : null,
            items: const [
              DropdownMenuItem(value: 'admin', child: Text('Admin')),
              DropdownMenuItem(value: 'moderator', child: Text('Điều phối viên')),
              DropdownMenuItem(value: 'client', child: Text('Người dùng')),
            ],
          ),
        ),
        DataCell(
          Tooltip(
            message: isSelf ? 'Không thể tự khóa chính mình' : '',
            child: Switch.adaptive(
              value: user.disabled,
              onChanged: canEdit ? (v) => onDisabledChanged(user, v) : null,
            ),
          ),
        ),
        DataCell(
          user.isBanned
              ? Tooltip(
                  message: user.banReason ?? 'Đã bị cấm',
                  child: Chip(
                    avatar: const Icon(Icons.block, size: 16),
                    label: Text(
                      user.banUntil != null
                          ? 'Tạm thời'
                          : 'Vĩnh viễn',
                      style: theme.textTheme.bodySmall,
                    ),
                    backgroundColor: theme.colorScheme.errorContainer,
                    side: BorderSide(
                      color: theme.colorScheme.error.withValues(alpha: 0.5),
                    ),
                  ),
                )
              : const Text('—'),
        ),
        DataCell(
          Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              if (!isSelf && !user.isBanned)
                IconButton(
                  tooltip: 'Cấm người dùng',
                  onPressed: canEdit ? () => onBanUser(user) : null,
                  icon: const Icon(Icons.block),
                  color: theme.colorScheme.error,
                ),
              if (user.isBanned)
                IconButton(
                  tooltip: 'Bỏ cấm',
                  onPressed: canEdit ? () => onUnbanUser(user) : null,
                  icon: const Icon(Icons.check_circle),
                  color: theme.colorScheme.primary,
                ),
              IconButton(
                tooltip: 'Sao chép UID',
                onPressed: () => onCopyUid(user.uid),
                icon: const Icon(Icons.copy),
              ),
              if (isBusy)
                const SizedBox(
                  width: 18,
                  height: 18,
                  child: CircularProgressIndicator(strokeWidth: 2),
                ),
            ],
          ),
        ),
      ],
    );
  }

  String _displayName(AdminUser user) {
    final name = user.displayName?.trim();
    if (name != null && name.isNotEmpty) return name;
    return '(No name)';
  }

  String _avatarLabel(AdminUser user) {
    final name = user.displayName?.trim();
    if (name != null && name.isNotEmpty) return name;
    final email = user.email?.trim();
    if (email != null && email.isNotEmpty) return email;
    return user.uid;
  }
}

class _UsersList extends StatelessWidget {
  const _UsersList({
    required this.users,
    required this.currentAdminUid,
    required this.busyUids,
    required this.onRoleChanged,
    required this.onDisabledChanged,
    required this.onBanUser,
    required this.onUnbanUser,
    required this.onCopyUid,
  });

  final List<AdminUser> users;
  final String? currentAdminUid;
  final Set<String> busyUids;
  final _RoleChanged onRoleChanged;
  final _DisabledChanged onDisabledChanged;
  final _UserAction onBanUser;
  final _UserAction onUnbanUser;
  final Future<void> Function(String uid) onCopyUid;

  @override
  Widget build(BuildContext context) {
    return ListView.separated(
      padding: const EdgeInsets.all(16),
      itemCount: users.length,
      separatorBuilder: (_, __) => const SizedBox(height: 12),
      itemBuilder: (context, index) {
        final user = users[index];
        final isSelf = currentAdminUid != null && user.uid == currentAdminUid;
        final isBusy = busyUids.contains(user.uid);
        final canEdit = !isSelf && !isBusy;

        final roleValue =
            FirestoreAdminUserRepository.allowedRoles.contains(user.role)
                ? user.role
                : 'client';

        final theme = Theme.of(context);
        final cardColor = isSelf
            ? theme.colorScheme.primaryContainer.withValues(alpha: 0.35)
            : null;

        return Card(
          color: cardColor,
          child: Padding(
            padding: const EdgeInsets.all(12),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    _Avatar(
                      photoUrl: user.photoUrl,
                      label: user.displayName ?? user.email ?? user.uid,
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            user.displayName?.trim().isNotEmpty == true
                                ? user.displayName!
                                : '(Chưa có tên)',
                            style: theme.textTheme.titleMedium,
                          ),
                          const SizedBox(height: 2),
                          Text(
                            user.email?.trim().isNotEmpty == true ? user.email! : '—',
                            style: theme.textTheme.bodyMedium,
                          ),
                        ],
                      ),
                    ),
                    IconButton(
                      tooltip: 'Sao chép UID',
                      onPressed: () => onCopyUid(user.uid),
                      icon: const Icon(Icons.copy),
                    ),
                  ],
                ),
                const SizedBox(height: 12),
                Wrap(
                  spacing: 12,
                  runSpacing: 8,
                  crossAxisAlignment: WrapCrossAlignment.center,
                  children: [
                    Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        const Text('Quyền:'),
                        const SizedBox(width: 8),
                        DropdownButton<String>(
                          value: roleValue,
                          isDense: true,
                          onChanged: canEdit
                              ? (v) => v == null ? null : onRoleChanged(user, v)
                              : null,
                          items: const [
                            DropdownMenuItem(
                              value: 'admin',
                              child: Text('Admin'),
                            ),
                            DropdownMenuItem(
                              value: 'moderator',
                              child: Text('Điều phối viên'),
                            ),
                            DropdownMenuItem(
                              value: 'client',
                              child: Text('Người dùng'),
                            ),
                          ],
                        ),
                      ],
                    ),
                    Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Text(user.disabled ? 'Đã khóa' : 'Hoạt động'),
                        const SizedBox(width: 8),
                        Tooltip(
                          message: isSelf ? 'Không thể tự khóa chính mình' : '',
                          child: Switch.adaptive(
                            value: user.disabled,
                            onChanged:
                                canEdit ? (v) => onDisabledChanged(user, v) : null,
                          ),
                        ),
                      ],
                    ),
                    if (user.isBanned)
                      Tooltip(
                        message: user.banReason ?? 'Đã bị cấm',
                        child: Chip(
                          avatar: const Icon(Icons.block, size: 16),
                          label: Text(
                            user.banUntil != null
                                ? 'Ban tạm thời'
                                : 'Ban vĩnh viễn',
                          ),
                          backgroundColor: theme.colorScheme.errorContainer,
                          side: BorderSide(
                            color: theme.colorScheme.error.withValues(alpha: 0.5),
                          ),
                        ),
                      ),
                    if (!isSelf && !user.isBanned && canEdit)
                      ElevatedButton.icon(
                        onPressed: () => onBanUser(user),
                        icon: const Icon(Icons.block, size: 18),
                        label: const Text('Cấm'),
                        style: ElevatedButton.styleFrom(
                          backgroundColor: theme.colorScheme.errorContainer,
                          foregroundColor: theme.colorScheme.error,
                        ),
                      ),
                    if (user.isBanned && canEdit)
                      ElevatedButton.icon(
                        onPressed: () => onUnbanUser(user),
                        icon: const Icon(Icons.check_circle, size: 18),
                        label: const Text('Bỏ cấm'),
                        style: ElevatedButton.styleFrom(
                          backgroundColor: theme.colorScheme.primaryContainer,
                          foregroundColor: theme.colorScheme.primary,
                        ),
                      ),
                    if (isBusy)
                      const SizedBox(
                        width: 18,
                        height: 18,
                        child: CircularProgressIndicator(strokeWidth: 2),
                      ),
                  ],
                ),
              ],
            ),
          ),
        );
      },
    );
  }
}

class _Avatar extends StatelessWidget {
  const _Avatar({required this.photoUrl, required this.label});

  final String? photoUrl;
  final String label;

  @override
  Widget build(BuildContext context) {
    final url = photoUrl?.trim();
    final letter = label.trim().isNotEmpty ? label.trim()[0].toUpperCase() : '?';

    if (url != null && url.isNotEmpty) {
      return CircleAvatar(backgroundImage: NetworkImage(url));
    }
    return CircleAvatar(child: Text(letter));
  }
}
