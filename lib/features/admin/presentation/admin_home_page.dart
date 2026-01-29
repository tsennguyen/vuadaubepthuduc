import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:fl_chart/fl_chart.dart';
import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import 'admin_shell_scaffold.dart';
import 'widgets/dashboard_chart.dart';
import '../../../app/theme.dart';

class AdminHomePage extends StatefulWidget {
  const AdminHomePage({super.key});

  @override
  State<AdminHomePage> createState() => _AdminHomePageState();
}

class _DashboardStats {
  const _DashboardStats({
    required this.usersTotal,
    required this.bannedUsers,
    required this.postsTotal,
    required this.reportedPosts,
    required this.recipesTotal,
    required this.healthyRecipes,
    required this.reelsTotal,
    required this.reportsPending,
    required this.reportsResolved,
    required this.chatViolations24h,
    required this.usersLast7Days,
    required this.postsLast7Days,
    required this.recipesLast7Days,
  });

  final int usersTotal;
  final int bannedUsers;
  final int postsTotal;
  final int reportedPosts;
  final int recipesTotal;
  final int healthyRecipes;
  final int reelsTotal;
  final int reportsPending;
  final int reportsResolved;
  final int chatViolations24h;
  final List<int> usersLast7Days;
  final List<int> postsLast7Days;
  final List<int> recipesLast7Days;
}


class _AdminHomePageState extends State<AdminHomePage> {
  late Future<_DashboardStats> _statsFuture;

  @override
  void initState() {
    super.initState();
    _statsFuture = _loadStats();
  }

  Future<_DashboardStats> _loadStats() async {
    final firestore = FirebaseFirestore.instance;
    final since24h =
        Timestamp.fromDate(DateTime.now().subtract(const Duration(hours: 24)));

    try {
      // Get counts for last 7 days
      final List<int> usersLast7Days = [];
      final List<int> postsLast7Days = [];
      final List<int> recipesLast7Days = [];

      for (int i = 6; i >= 0; i--) {
        final dayStart = DateTime.now()
            .subtract(Duration(days: i))
            .copyWith(hour: 0, minute: 0, second: 0, millisecond: 0);
        final dayEnd = dayStart.add(const Duration(days: 1));

        final userCount = await firestore
            .collection('users')
            .where('createdAt',
                isGreaterThanOrEqualTo: Timestamp.fromDate(dayStart))
            .where('createdAt', isLessThan: Timestamp.fromDate(dayEnd))
            .count()
            .get();

        final postCount = await firestore
            .collection('posts')
            .where('createdAt',
                isGreaterThanOrEqualTo: Timestamp.fromDate(dayStart))
            .where('createdAt', isLessThan: Timestamp.fromDate(dayEnd))
            .count()
            .get();

        final recipeCount = await firestore
            .collection('recipes')
            .where('createdAt',
                isGreaterThanOrEqualTo: Timestamp.fromDate(dayStart))
            .where('createdAt', isLessThan: Timestamp.fromDate(dayEnd))
            .count()
            .get();

        usersLast7Days.add(userCount.count ?? 0);
        postsLast7Days.add(postCount.count ?? 0);
        recipesLast7Days.add(recipeCount.count ?? 0);
      }

      final futures = await Future.wait([
        firestore.collection('users').count().get(),
        firestore
            .collection('users')
            .where('isBanned', isEqualTo: true)
            .count()
            .get(),
        firestore.collection('posts').count().get(),
        firestore
            .collection('reports')
            .where('targetType', isEqualTo: 'post')
            .where('status', isEqualTo: 'pending')
            .count()
            .get(),
        firestore.collection('recipes').count().get(),
        firestore
            .collection('recipes')
            .where('tags', arrayContains: 'healthy')
            .count()
            .get(),
        firestore
            .collection('reports')
            .where('status', isEqualTo: 'pending')
            .count()
            .get(),
        firestore
            .collection('reports')
            .where('status', isEqualTo: 'resolved')
            .count()
            .get(),
        firestore
            .collection('chatViolations')
            .where('createdAt', isGreaterThanOrEqualTo: since24h)
            .count()
            .get(),
        firestore.collection('reels').count().get(),
      ]);

      return _DashboardStats(
        usersTotal: futures[0].count ?? 0,
        bannedUsers: futures[1].count ?? 0,
        postsTotal: futures[2].count ?? 0,
        reportedPosts: futures[3].count ?? 0,
        recipesTotal: futures[4].count ?? 0,
        healthyRecipes: futures[5].count ?? 0,
        reportsPending: futures[6].count ?? 0,
        reportsResolved: futures[7].count ?? 0,
        chatViolations24h: futures[8].count ?? 0,
        usersLast7Days: usersLast7Days,
        postsLast7Days: postsLast7Days,
        recipesLast7Days: recipesLast7Days,
        reelsTotal: futures[9].count ?? 0,
      );
    } catch (error) {
      debugPrint('Failed to load dashboard stats: $error');
      rethrow;
    }
  }

  Future<void> _refresh() async {
    setState(() {
      _statsFuture = _loadStats();
    });
    await _statsFuture;
  }

  String _formatNumber(int value) {
    if (value >= 1000000) return '${(value / 1000000).toStringAsFixed(1)}M';
    if (value >= 1000) return '${(value / 1000).toStringAsFixed(1)}k';
    return value.toString();
  }

  @override
  Widget build(BuildContext context) {
    return AdminShell(
      actions: [
        IconButton(
          tooltip: 'Về trang chính',
          onPressed: () => context.go('/'),
          icon: const Icon(Icons.home_rounded),
        ),
        IconButton(
          tooltip: 'Làm mới',
          onPressed: _refresh,
          icon: const Icon(Icons.refresh_rounded),
        ),
        const SizedBox(width: 8),
      ],
      child: RefreshIndicator(
        onRefresh: _refresh,
        child: FutureBuilder<_DashboardStats>(
          future: _statsFuture,
          builder: (context, snapshot) {
            final stats = snapshot.data;
            final hasError = snapshot.hasError;
            return CustomScrollView(
              physics: const AlwaysScrollableScrollPhysics(),
              slivers: [
                if (hasError)
                  SliverToBoxAdapter(
                    child: Padding(
                      padding: const EdgeInsets.all(AppSpacing.s16),
                      child: _ErrorBanner(
                        message: '${snapshot.error}',
                        onRetry: _refresh,
                      ),
                    ),
                  ),
                if (stats == null && !hasError)
                  const SliverToBoxAdapter(
                    child: Padding(
                      padding: EdgeInsets.all(AppSpacing.s16),
                      child: LinearProgressIndicator(),
                    ),
                  ),
                if (stats != null) ...[
                  // Metric Cards
                  SliverPadding(
                    padding: const EdgeInsets.all(AppSpacing.s16),
                    sliver: SliverLayoutBuilder(
                      builder: (context, constraints) {
                        final cards = _buildCards(context, stats);
                        return SliverGrid(
                          gridDelegate:
                              const SliverGridDelegateWithFixedCrossAxisCount(
                            crossAxisCount: 2,
                            crossAxisSpacing: AppSpacing.s16,
                            mainAxisSpacing: AppSpacing.s16,
                            childAspectRatio: 1.25,
                          ),
                          delegate: SliverChildBuilderDelegate(
                            (context, index) => cards[index],
                            childCount: cards.length,
                          ),
                        );
                      },
                    ),
                  ),
                  // Charts Section
                  SliverPadding(
                    padding: const EdgeInsets.symmetric(
                      horizontal: AppSpacing.s16,
                    ),
                    sliver: SliverLayoutBuilder(
                      builder: (context, constraints) {
                        final isWide = constraints.crossAxisExtent >= 900;
                        return SliverGrid(
                          gridDelegate:
                              SliverGridDelegateWithFixedCrossAxisCount(
                            crossAxisCount: isWide ? 2 : 1,
                            crossAxisSpacing: AppSpacing.s16,
                            mainAxisSpacing: AppSpacing.s16,
                            childAspectRatio: isWide ? 1.3 : 0.9,
                          ),
                          delegate: SliverChildListDelegate([
                            DashboardChart(
                              title: 'Người dùng mới (7 ngày)',
                              child: _buildLineChart(
                                context,
                                stats.usersLast7Days,
                                Colors.blue,
                              ),
                            ),
                            DashboardChart(
                              title: 'Bài viết mới (7 ngày)',
                              child: _buildLineChart(
                                context,
                                stats.postsLast7Days,
                                Colors.orange,
                              ),
                            ),
                            DashboardChart(
                              title: 'Công thức mới (7 ngày)',
                              child: _buildLineChart(
                                context,
                                stats.recipesLast7Days,
                                Colors.green,
                              ),
                            ),
                            DashboardChart(
                              title: 'Phân bổ Reports',
                              child: _buildPieChart(
                                context,
                                stats.reportsPending,
                                stats.reportsResolved,
                              ),
                            ),
                          ]),
                        );
                      },
                    ),
                  ),
                ],
                const SliverToBoxAdapter(
                  child: SizedBox(height: AppSpacing.s24),
                ),
              ],
            );
          },
        ),
      ),
    );
  }

  List<Widget> _buildCards(BuildContext context, _DashboardStats stats) {
    return [
      _MetricCard(
        title: 'Người dùng',
        value: _formatNumber(stats.usersTotal),
        trailingLabel: '${stats.bannedUsers} bị khóa',
        trailingColor: Colors.red.shade400,
        icon: Icons.people_alt_rounded,
        color: Colors.blue.shade500,
        onTap: () => context.go('/admin/users'),
      ),
      _MetricCard(
        title: 'Bài viết',
        value: _formatNumber(stats.postsTotal),
        trailingLabel: '${stats.reportedPosts} bị report',
        trailingColor: Colors.orange.shade700,
        icon: Icons.article_rounded,
        color: Colors.orange.shade500,
        onTap: () => context.go('/admin/content'),
      ),
      _MetricCard(
        title: 'Công thức',
        value: _formatNumber(stats.recipesTotal),
        trailingLabel: '${stats.healthyRecipes} healthy',
        trailingColor: Colors.green.shade600,
        icon: Icons.restaurant_menu_rounded,
        color: Colors.green.shade500,
        onTap: () => context.go('/admin/content'),
      ),
      _MetricCard(
        title: 'Reels',
        value: _formatNumber(stats.reelsTotal),
        icon: Icons.movie_filter_rounded,
        color: Colors.purple.shade500,
        onTap: () => context.go('/admin/content'),
      ),
      _MetricCard(
        title: 'Báo cáo',
        value: _formatNumber(stats.reportsPending),
        trailingLabel: '${stats.reportsResolved} đã xử lý',
        trailingColor: Colors.green.shade700,
        icon: Icons.flag_rounded,
        color: Colors.purple.shade500,
        onTap: () => context.go('/admin/reports'),
      ),
      _MetricCard(
        title: 'Vi phạm Chat',
        value: _formatNumber(stats.chatViolations24h),
        trailingLabel: '24h',
        trailingColor: Colors.grey.shade600,
        icon: Icons.shield_rounded,
        color: Colors.red.shade500,
        onTap: () => context.go('/admin/chats'),
      ),
    ];
  }

  Widget _buildLineChart(BuildContext context, List<int> data, Color color) {
    if (data.isEmpty) {
      return const Center(child: Text('Không có dữ liệu'));
    }

    final spots = List.generate(
      data.length,
      (i) => FlSpot(i.toDouble(), data[i].toDouble()),
    );

    final maxY = data.reduce((a, b) => a > b ? a : b).toDouble();

    return LineChart(
      LineChartData(
        gridData: FlGridData(
          show: true,
          drawVerticalLine: false,
          horizontalInterval: maxY > 0 ? maxY / 4 : 1,
          getDrawingHorizontalLine: (value) {
            return FlLine(
              color: Theme.of(context)
                  .colorScheme
                  .onSurface
                  .withValues(alpha: 0.1),
              strokeWidth: 1,
            );
          },
        ),
        titlesData: FlTitlesData(
          show: true,
          rightTitles: const AxisTitles(
            sideTitles: SideTitles(showTitles: false),
          ),
          topTitles: const AxisTitles(
            sideTitles: SideTitles(showTitles: false),
          ),
          bottomTitles: AxisTitles(
            sideTitles: SideTitles(
              showTitles: true,
              reservedSize: 30,
              interval: 1,
              getTitlesWidget: (value, meta) {
                final days = ['T2', 'T3', 'T4', 'T5', 'T6', 'T7', 'CN'];
                final index = value.toInt();
                if (index >= 0 && index < days.length) {
                  return Padding(
                    padding: const EdgeInsets.only(top: 8.0),
                    child: Text(
                      days[index],
                      style: Theme.of(context).textTheme.bodySmall,
                    ),
                  );
                }
                return const Text('');
              },
            ),
          ),
          leftTitles: AxisTitles(
            sideTitles: SideTitles(
              showTitles: true,
              interval: maxY > 0 ? maxY / 4 : 1,
              reservedSize: 40,
              getTitlesWidget: (value, meta) {
                return Text(
                  value.toInt().toString(),
                  style: Theme.of(context).textTheme.bodySmall,
                );
              },
            ),
          ),
        ),
        borderData: FlBorderData(show: false),
        minX: 0,
        maxX: 6,
        minY: 0,
        maxY: (maxY * 1.2).ceilToDouble(),
        lineBarsData: [
          LineChartBarData(
            spots: spots,
            isCurved: true,
            color: color,
            barWidth: 3,
            isStrokeCapRound: true,
            dotData: FlDotData(
              show: true,
              getDotPainter: (spot, percent, barData, index) {
                return FlDotCirclePainter(
                  radius: 4,
                  color: color,
                  strokeWidth: 2,
                  strokeColor: Theme.of(context).colorScheme.surface,
                );
              },
            ),
            belowBarData: BarAreaData(
              show: true,
              color: color.withValues(alpha: 0.1),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildPieChart(
    BuildContext context,
    int pending,
    int resolved,
  ) {
    final total = pending + resolved;
    if (total == 0) {
      return const Center(child: Text('Không có dữ liệu'));
    }

    return PieChart(
      PieChartData(
        sectionsSpace: 2,
        centerSpaceRadius: 50,
        sections: [
          PieChartSectionData(
            color: Colors.orange.shade400,
            value: pending.toDouble(),
            title: '$pending\nChờ xử lý',
            radius: 80,
            titleStyle: Theme.of(context).textTheme.bodyMedium?.copyWith(
                  fontWeight: FontWeight.w700,
                  color: Colors.white,
                ),
          ),
          PieChartSectionData(
            color: Colors.green.shade400,
            value: resolved.toDouble(),
            title: '$resolved\nĐã xử lý',
            radius: 80,
            titleStyle: Theme.of(context).textTheme.bodyMedium?.copyWith(
                  fontWeight: FontWeight.w700,
                  color: Colors.white,
                ),
          ),
        ],
      ),
    );
  }
}

class _MetricCard extends StatelessWidget {
  const _MetricCard({
    required this.title,
    required this.value,
    required this.icon,
    required this.color,
    this.trailingLabel,
    this.trailingColor,
    this.onTap,
  });

  final String title;
  final String value;
  final IconData icon;
  final Color color;
  final String? trailingLabel;
  final Color? trailingColor;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;

    return Card(
      elevation: 0,
      clipBehavior: Clip.antiAlias,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(AppRadii.large),
        side: BorderSide(
          color: colorScheme.outline.withValues(alpha: 0.1),
          width: 1,
        ),
      ),
      color: colorScheme.surface,
      child: InkWell(
        onTap: onTap,
        child: Padding(
          padding: const EdgeInsets.all(AppSpacing.s16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisSize: MainAxisSize.min,
            children: [
              Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Container(
                    padding: const EdgeInsets.all(8),
                    decoration: BoxDecoration(
                      color: color.withValues(alpha: 0.1),
                      borderRadius: BorderRadius.circular(AppRadii.medium),
                    ),
                    child: Icon(
                      icon,
                      color: color,
                      size: 18,
                    ),
                  ),
                  const Spacer(),
                  if (trailingLabel != null)
                    Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 6,
                        vertical: 3,
                      ),
                      decoration: BoxDecoration(
                        color: (trailingColor ?? colorScheme.primary)
                            .withValues(alpha: 0.08),
                        borderRadius: BorderRadius.circular(AppRadii.small),
                      ),
                      child: Text(
                        trailingLabel!,
                        style: theme.textTheme.labelSmall?.copyWith(
                          color: trailingColor ?? colorScheme.primary,
                          fontWeight: FontWeight.w700,
                          fontSize: 9,
                        ),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                ],
              ),
              const Spacer(),
              Text(
                value,
                style: theme.textTheme.headlineSmall?.copyWith(
                  fontWeight: FontWeight.w900,
                  color: colorScheme.onSurface,
                  letterSpacing: -1,
                  height: 1,
                ),
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
              ),
              const SizedBox(height: 2),
              Text(
                title,
                style: theme.textTheme.titleSmall?.copyWith(
                  fontWeight: FontWeight.w700,
                  color: colorScheme.onSurface.withValues(alpha: 0.8),
                  height: 1.2,
                  fontSize: 13,
                ),
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _ErrorBanner extends StatelessWidget {
  const _ErrorBanner({required this.message, required this.onRetry});

  final String message;
  final VoidCallback onRetry;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Card(
      color: theme.colorScheme.errorContainer,
      child: Padding(
        padding: const EdgeInsets.all(AppSpacing.s12),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Icon(Icons.error_outline),
            const SizedBox(width: AppSpacing.s12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'Không tải được số liệu',
                    style: theme.textTheme.titleMedium,
                  ),
                  const SizedBox(height: 4),
                  Text(message, style: theme.textTheme.bodyMedium),
                ],
              ),
            ),
            TextButton.icon(
              onPressed: onRetry,
              icon: const Icon(Icons.refresh_rounded),
              label: const Text('Thử lại'),
            ),
          ],
        ),
      ),
    );
  }
}
