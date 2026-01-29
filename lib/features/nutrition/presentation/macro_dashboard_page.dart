import 'package:firebase_auth/firebase_auth.dart';
import 'package:fl_chart/fl_chart.dart';
import 'package:flutter/material.dart';

import '../../auth/data/user_repository.dart';
import '../../planner/data/meal_plan_repository.dart';
import '../../recipe/data/recipe_repository.dart';
import '../application/nutrition_calculator.dart';
import '../application/nutrition_summary_service.dart';
import '../domain/nutrition_models.dart';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../application/nutrition_providers.dart';

enum MacroMetric { calories, protein, carbs, fat }

class MacroDashboardPage extends ConsumerStatefulWidget {
  const MacroDashboardPage({super.key});

  @override
  ConsumerState<MacroDashboardPage> createState() => _MacroDashboardPageState();
}

class _MacroDashboardPageState extends ConsumerState<MacroDashboardPage> {
  NutritionSummaryService get _summaryService => ref.read(nutritionSummaryServiceProvider);
  late DateTime _weekStart;
  MacroMetric _metric = MacroMetric.calories;

  late Future<_WeekData> _weekFuture;

  @override
  void initState() {
    super.initState();
    _weekStart = _startOfWeek(DateTime.now());
    _weekFuture = _loadWeek();
  }

  DateTime _startOfWeek(DateTime input) {
    final local = DateTime(input.year, input.month, input.day);
    return local.subtract(Duration(days: local.weekday - 1)); // Monday start
  }

  Future<_WeekData> _loadWeek() async {
    final week = await _summaryService.getWeekTotalMacros(_weekStart);
    final target = await _summaryService.getUserMacroTarget();
    return _WeekData(week: week, target: target);
  }

  void _changeWeek(int deltaDays) {
    setState(() {
      _weekStart = _weekStart.add(Duration(days: deltaDays));
      _weekFuture = _loadWeek();
    });
  }

  void _goThisWeek() {
    setState(() {
      _weekStart = _startOfWeek(DateTime.now());
      _weekFuture = _loadWeek();
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Macro Dashboard'),
      ),
      body: FutureBuilder<_WeekData>(
        future: _weekFuture,
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting) {
            return const Center(child: CircularProgressIndicator());
          }
          if (snapshot.hasError) {
            return _ErrorView(
              message: snapshot.error.toString(),
              onRetry: () => setState(() {
                _weekFuture = _loadWeek();
              }),
            );
          }
          final data = snapshot.data;
          if (data == null || data.week.isEmpty) {
            return const _EmptyView();
          }

          final sortedDays = data.week.keys.toList()
            ..sort((a, b) => a.compareTo(b));
          final values =
              sortedDays.map((d) => data.week[d] ?? Macros.zero).toList();

          final totalWeek =
              values.fold<Macros>(Macros.zero, (sum, m) => sum + m);
          final metricColor =
              _metricColor(_metric, Theme.of(context).colorScheme);

          return SingleChildScrollView(
            padding: const EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                _WeekSelector(
                  weekStart: _weekStart,
                  onPrev: () => _changeWeek(-7),
                  onNext: () => _changeWeek(7),
                  onThisWeek: _goThisWeek,
                ),
                const SizedBox(height: 12),
                _MetricSelector(
                  metric: _metric,
                  onChanged: (m) => setState(() => _metric = m),
                ),
                const SizedBox(height: 12),
                SizedBox(
                  height: 260,
                  child: BarChart(
                    BarChartData(
                      // ignore: prefer_const_constructors
                      gridData: FlGridData(show: true, horizontalInterval: 200),
                      borderData: FlBorderData(show: false),
                      titlesData: FlTitlesData(
                        leftTitles: AxisTitles(
                          sideTitles: SideTitles(
                            showTitles: true,
                            interval:
                                _metric == MacroMetric.calories ? 200 : 20,
                            reservedSize: 44,
                            getTitlesWidget: (value, meta) => Text(
                              value.toInt().toString(),
                              style: const TextStyle(fontSize: 10),
                            ),
                          ),
                        ),
                        bottomTitles: AxisTitles(
                          sideTitles: SideTitles(
                            showTitles: true,
                            getTitlesWidget: (value, meta) {
                              final idx = value.toInt();
                              if (idx < 0 || idx >= sortedDays.length) {
                                return const SizedBox.shrink();
                              }
                              final day = sortedDays[idx];
                              final label = _weekdayLabel(day.weekday);
                              return Text(label,
                                  style: const TextStyle(fontSize: 12));
                            },
                          ),
                        ),
                        topTitles: const AxisTitles(),
                        rightTitles: const AxisTitles(),
                      ),
                      barGroups: List.generate(sortedDays.length, (i) {
                        final macro = values[i];
                        final val = _metricValue(macro, _metric);
                        return BarChartGroupData(
                          x: i,
                          barRods: [
                            BarChartRodData(
                              toY: val,
                              width: 14,
                              borderRadius: BorderRadius.circular(6),
                              color: metricColor,
                            ),
                          ],
                        );
                      }),
                    ),
                  ),
                ),
                const SizedBox(height: 16),
                _SummaryCard(
                  weekTotal: totalWeek,
                  metric: _metric,
                  target: data.target,
                ),
              ],
            ),
          );
        },
      ),
    );
  }
}

class _WeekData {
  _WeekData({required this.week, required this.target});
  final Map<DateTime, Macros> week;
  final Macros? target;
}

class _WeekSelector extends StatelessWidget {
  const _WeekSelector({
    required this.weekStart,
    required this.onPrev,
    required this.onNext,
    required this.onThisWeek,
  });

  final DateTime weekStart;
  final VoidCallback onPrev;
  final VoidCallback onNext;
  final VoidCallback onThisWeek;

  @override
  Widget build(BuildContext context) {
    final end = weekStart.add(const Duration(days: 6));
    String two(int n) => n.toString().padLeft(2, '0');
    final range =
        '${two(weekStart.day)}/${two(weekStart.month)} - ${two(end.day)}/${two(end.month)}';

    return Row(
      children: [
        IconButton(
          onPressed: onPrev,
          icon: const Icon(Icons.chevron_left),
        ),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.center,
            children: [
              const Text('Tuần'),
              Text(
                range,
                style: Theme.of(context).textTheme.titleMedium,
              ),
            ],
          ),
        ),
        IconButton(
          onPressed: onNext,
          icon: const Icon(Icons.chevron_right),
        ),
        TextButton(onPressed: onThisWeek, child: const Text('Tuần này')),
      ],
    );
  }
}

class _MetricSelector extends StatelessWidget {
  const _MetricSelector({required this.metric, required this.onChanged});

  final MacroMetric metric;
  final ValueChanged<MacroMetric> onChanged;

  @override
  Widget build(BuildContext context) {
    return Wrap(
      spacing: 8,
      children: [
        ChoiceChip(
          label: const Text('Calories'),
          selected: metric == MacroMetric.calories,
          onSelected: (_) => onChanged(MacroMetric.calories),
        ),
        ChoiceChip(
          label: const Text('Protein'),
          selected: metric == MacroMetric.protein,
          onSelected: (_) => onChanged(MacroMetric.protein),
        ),
        ChoiceChip(
          label: const Text('Carbs'),
          selected: metric == MacroMetric.carbs,
          onSelected: (_) => onChanged(MacroMetric.carbs),
        ),
        ChoiceChip(
          label: const Text('Fat'),
          selected: metric == MacroMetric.fat,
          onSelected: (_) => onChanged(MacroMetric.fat),
        ),
      ],
    );
  }
}

class _SummaryCard extends StatelessWidget {
  const _SummaryCard({
    required this.weekTotal,
    required this.metric,
    required this.target,
  });

  final Macros weekTotal;
  final MacroMetric metric;
  final Macros? target;

  @override
  Widget build(BuildContext context) {
    final metricLabel = _metricLabel(metric);
    final weekValue = _metricValue(weekTotal, metric);
    final targetValue = target == null
        ? null
        : _metricValue(target!, metric) * 7; // target per week
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(12),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Tổng tuần (${metricLabel.toLowerCase()})',
              style: Theme.of(context).textTheme.titleMedium,
            ),
            const SizedBox(height: 8),
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text('${weekValue.toStringAsFixed(0)} ${_metricUnit(metric)}'),
                if (targetValue != null)
                  Text(
                    'Target: ${targetValue.toStringAsFixed(0)} ${_metricUnit(metric)}',
                    style: TextStyle(
                        color: Theme.of(context).colorScheme.secondary),
                  ),
              ],
            ),
            if (targetValue == null) ...[
              const SizedBox(height: 6),
              Text(
                'Bạn chưa thiết lập mục tiêu macro cho mình. Vào trang cài đặt để thiết lập nhé!',
                style: Theme.of(context).textTheme.bodySmall,
              ),
            ],
          ],
        ),
      ),
    );
  }
}

class _EmptyView extends StatelessWidget {
  const _EmptyView();

  @override
  Widget build(BuildContext context) {
    return const Center(
      child: Padding(
        padding: EdgeInsets.all(24),
        child: Text(
          'Chưa có dữ liệu macro trong tuần này.',
          textAlign: TextAlign.center,
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
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(
              'Không tải được dữ liệu.\n$message',
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 12),
            FilledButton.icon(
              onPressed: onRetry,
              icon: const Icon(Icons.refresh),
              label: const Text('Thử lại'),
            ),
          ],
        ),
      ),
    );
  }
}

double _metricValue(Macros macros, MacroMetric metric) {
  switch (metric) {
    case MacroMetric.calories:
      return macros.calories;
    case MacroMetric.protein:
      return macros.protein;
    case MacroMetric.carbs:
      return macros.carbs;
    case MacroMetric.fat:
      return macros.fat;
  }
}

Color _metricColor(MacroMetric metric, ColorScheme scheme) {
  switch (metric) {
    case MacroMetric.calories:
      return scheme.primary;
    case MacroMetric.protein:
      return Colors.teal;
    case MacroMetric.carbs:
      return Colors.amber.shade700;
    case MacroMetric.fat:
      return Colors.pinkAccent;
  }
}

String _metricLabel(MacroMetric metric) {
  switch (metric) {
    case MacroMetric.calories:
      return 'Calories';
    case MacroMetric.protein:
      return 'Protein';
    case MacroMetric.carbs:
      return 'Carbs';
    case MacroMetric.fat:
      return 'Fat';
  }
}

String _metricUnit(MacroMetric metric) {
  switch (metric) {
    case MacroMetric.calories:
      return 'kcal';
    case MacroMetric.protein:
    case MacroMetric.carbs:
    case MacroMetric.fat:
      return 'g';
  }
}

String _weekdayLabel(int weekday) {
  const labels = ['T2', 'T3', 'T4', 'T5', 'T6', 'T7', 'CN'];
  return labels[(weekday - 1).clamp(0, 6)];
}
