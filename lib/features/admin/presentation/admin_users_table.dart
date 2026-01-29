import 'package:flutter/material.dart';

import '../data/admin_user_repository.dart';
import '../widgets/status_badge.dart';

class AdminUsersTable extends StatelessWidget {
  const AdminUsersTable({
    super.key,
    required this.users,
    required this.busyUids,
    required this.onRoleChanged,
    required this.onToggleDisabled,
  });

  final List<AdminUser> users;
  final Set<String> busyUids;
  final void Function(AdminUser user, String role) onRoleChanged;
  final void Function(AdminUser user, bool disabled) onToggleDisabled;

  @override
  Widget build(BuildContext context) {
    return SingleChildScrollView(
      scrollDirection: Axis.horizontal,
      child: ConstrainedBox(
        constraints: const BoxConstraints(minWidth: 900),
        child: DataTable(
          columnSpacing: 16,
          headingRowHeight: 48,
          columns: const [
            DataColumn(label: Text('Ảnh')),
            DataColumn(label: Text('Tên')),
            DataColumn(label: Text('Email')),
            DataColumn(label: Text('Quyền')),
            DataColumn(label: Text('TT Khóa')),
            DataColumn(label: Text('Thao tác')),
          ],
          rows: users.map((u) {
            final busy = busyUids.contains(u.uid);
            return DataRow(
              cells: [
                DataCell(
                  CircleAvatar(
                    backgroundImage:
                        u.photoUrl != null && u.photoUrl!.isNotEmpty ? NetworkImage(u.photoUrl!) : null,
                    child: (u.photoUrl == null || u.photoUrl!.isEmpty)
                        ? Text(u.displayName?.substring(0, 1).toUpperCase() ?? '?')
                        : null,
                  ),
                ),
                DataCell(Text(u.displayName ?? '(Chưa có tên)')),
                DataCell(Text(u.email ?? '(Chưa có email)')),
                DataCell(_roleBadge(u.role)),
                DataCell(
                  u.disabled
                      ? const StatusBadge(label: 'Đã khóa', variant: StatusVariant.disabled)
                      : const SizedBox.shrink(),
                ),
                DataCell(
                  Row(
                    children: [
                      DropdownButton<String>(
                        value: u.role,
                        items: const [
                          DropdownMenuItem(value: 'admin', child: Text('Admin')),
                          DropdownMenuItem(value: 'moderator', child: Text('Điều phối viên')),
                          DropdownMenuItem(value: 'client', child: Text('Người dùng')),
                        ],
                        onChanged: busy ? null : (v) => v == null ? null : onRoleChanged(u, v),
                      ),
                      const SizedBox(width: 8),
                      Switch(
                        value: u.disabled,
                        onChanged: busy ? null : (v) => onToggleDisabled(u, v),
                      ),
                    ],
                  ),
                ),
              ],
            );
          }).toList(),
        ),
      ),
    );
  }

  Widget _roleBadge(String role) {
    switch (role) {
      case 'admin':
        return const StatusBadge(label: 'Admin', variant: StatusVariant.roleAdmin);
      case 'moderator':
      case 'mod':
        return const StatusBadge(label: 'Điều phối viên', variant: StatusVariant.roleModerator);
      default:
        return const StatusBadge(label: 'Người dùng', variant: StatusVariant.roleClient);
    }
  }
}
