import 'package:flutter/material.dart';

import '../../../core/dummy/dummy_data.dart';
import '../../../core/widgets/app_avatar.dart';

class LeaderboardPage extends StatefulWidget {
  const LeaderboardPage({super.key});

  @override
  State<LeaderboardPage> createState() => _LeaderboardPageState();
}

class _LeaderboardPageState extends State<LeaderboardPage> with SingleTickerProviderStateMixin {
  late final TabController _tabController;

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 2, vsync: this);
  }

  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Bảng xếp hạng'),
        bottom: TabBar(
          controller: _tabController,
          tabs: const [
            Tab(text: 'Tuần'),
            Tab(text: 'Tháng'),
          ],
        ),
      ),
      body: TabBarView(
        controller: _tabController,
        children: [
          _LeaderboardList(entries: dummyLeaderboardWeek),
          _LeaderboardList(entries: dummyLeaderboardMonth),
        ],
      ),
    );
  }
}

class _LeaderboardList extends StatelessWidget {
  const _LeaderboardList({required this.entries});

  final List<DummyLeaderboardEntry> entries;

  @override
  Widget build(BuildContext context) {
    return ListView.builder(
      itemCount: entries.length,
      itemBuilder: (context, index) {
        final entry = entries[index];
        final user = findUser(entry.userId);
        return ListTile(
          leading: CircleAvatar(
            backgroundColor: Colors.deepOrange.shade100,
            child: Text('${index + 1}'),
          ),
          title: Text(user.name),
          subtitle: Text('Điểm: ${entry.score}'),
          trailing: AppAvatar(url: user.avatarUrl, size: 36),
        );
      },
    );
  }
}
