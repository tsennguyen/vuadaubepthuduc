#!/usr/bin/env python3
# Fix planner_page.dart - replace horizontal scroll with vertical layout

import re

# Read file
with open(r"g:\Final-Year\LTDD\VuaDauBepThuDuc\lib\features\planner\presentation\planner_page.dart", "r", encoding="utf-8") as f:
    content = f.read()

# Replace _WeekGrid.build method (lines 348-389)
old_week_grid_build = r"""  @override\r
  Widget build\(BuildContext context\) \{\r
    final days = List<DateTime>\.generate\(\r
      7,\r
      \(i\) => weekStart\.add\(Duration\(days: i\)\),\r
      growable: false,\r
    \);\r
\r
    final byDayId = <String, List<MealPlanEntry>>{};\r
    for \(final entry in weekData\.entries\) \{\r
      byDayId\[_dayId\(entry\.key\)\] = entry\.value;\r
    \}\r
\r
    return LayoutBuilder\(\r
      builder: \(context, constraints\) \{\r
        final minColumnWidth = constraints\.maxWidth >= 900 \? 200\.0 : 160\.0;\r
        final totalMinWidth = minColumnWidth \* 7;\r
        final totalWidth =\r
            constraints\.maxWidth >= totalMinWidth \? constraints\.maxWidth : totalMinWidth;\r
\r
        return SingleChildScrollView\(\r
          scrollDirection: Axis\.horizontal,\r
          child: SizedBox\(\r
            width: totalWidth,\r
            height: constraints\.maxHeight,\r
            child: Row\(\r
              crossAxisAlignment: CrossAxisAlignment\.stretch,\r
              children: \[\r
                for \(final day in days\)\r
                  Expanded\(\r
                    child: _DayColumn\(\r
                      date: day,\r
                      entries: byDayId\[_dayId\(day\)\] \?\? const <MealPlanEntry>\[\],\r
                      onTapCell: onTapCell,\r
                    \),\r
                  \),\r
              \],\r
            \),\r
          \),\r
        \);\r
      \},\r
    \);\r
  \}\r
}"""

new_week_grid_build = """  @override\r
  Widget build(BuildContext context) {\r
    final days = List<DateTime>.generate(\r
      7,\r
      (i) => weekStart.add(Duration(days: i)),\r
      growable: false,\r
    );\r
\r
    final byDayId = <String, List<MealPlanEntry>>{};\r
    for (final entry in weekData.entries) {\r
      byDayId[_dayId(entry.key)] = entry.value;\r
    }\r
\r
    return ListView.builder(\r
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),\r
      itemCount: days.length,\r
      itemBuilder: (context, index) {\r
        final day = days[index];\r
        final entries = byDayId[_dayId(day)] ?? const <MealPlanEntry>[];\r
        return _DaySection(\r
          date: day,\r
          entries: entries,\r
          onTapCell: onTapCell,\r
        );\r
      },\r
    );\r
  }\r
}"""

content = re.sub(old_week_grid_build, new_week_grid_build, content, flags=re.MULTILINE)

# Replace _DayColumn with _DaySection and _MealRow (lines 392-466)
old_day_column = r"""class _DayColumn extends StatelessWidget \{\r
  const _DayColumn\(\{\r
    required this\.date,\r
    required this\.entries,\r
    required this\.onTapCell,\r
  \}\);\r
\r
  final DateTime date;\r
  final List<MealPlanEntry> entries;\r
  final Future<void> Function\(\{\r
    required DateTime date,\r
    required MealType mealType,\r
    required List<MealPlanEntry> entries,\r
  \}\) onTapCell;\r
\r
  @override\r
  Widget build\(BuildContext context\) \{[\s\S]*?\r
  \}\r
\}\r
"""

new_day_section = """class _DaySection extends StatelessWidget {\r
  const _DaySection({\r
    required this.date,\r
    required this.entries,\r
    required this.onTapCell,\r
  });\r
\r
  final DateTime date;\r
  final List<MealPlanEntry> entries;\r
  final Future<void> Function({\r
    required DateTime date,\r
    required MealType mealType,\r
    required List<MealPlanEntry> entries,\r
  }) onTapCell;\r
\r
  @override\r
  Widget build(BuildContext context) {\r
    final theme = Theme.of(context);\r
    final now = DateTime.now();\r
    final isToday = now.year == date.year &&\r
        now.month == date.month &&\r
        now.day == date.day;\r
\r
    final grouped = <MealType, List<MealPlanEntry>>{\r
      for (final t in MealType.values) t: <MealPlanEntry>[],\r
    };\r
    for (final e in entries) {\r
      grouped[e.mealType]?.add(e);\r
    }\r
\r
    return Card(\r
      margin: const EdgeInsets.only(bottom: 12),\r
      clipBehavior: Clip.antiAlias,\r
      child: Column(\r
        crossAxisAlignment: CrossAxisAlignment.start,\r
        children: [\r
          Container(\r
            width: double.infinity,\r
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),\r
            decoration: BoxDecoration(\r
              color: isToday\r
                  ? theme.colorScheme.primary.withValues(alpha: 0.12)\r
                  : theme.colorScheme.surfaceContainerHighest,\r
            ),\r
            child: Row(\r
              children: [\r
                if (isToday) ...[\r
                  Container(\r
                    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),\r
                    decoration: BoxDecoration(\r
                      color: theme.colorScheme.primary,\r
                      borderRadius: BorderRadius.circular(12),\r
                    ),\r
                    child: Text(\r
                      'HOM NAY',\r
                      style: theme.textTheme.labelSmall?.copyWith(\r
                        color: theme.colorScheme.onPrimary,\r
                        fontWeight: FontWeight.bold,\r
                      ),\r
                    ),\r
                  ),\r
                  const SizedBox(width: 12),\r
                ],\r
                Text(\r
                  '${_weekdayLabel(date)}, ${_formatDayMonth(date)}',\r
                  style: theme.textTheme.titleMedium?.copyWith(\r
                    fontWeight: FontWeight.w600,\r
                  ),\r
                ),\r
              ],\r
            ),\r
          ),\r
          for (final mealType in MealType.values)\r
            _MealRow(\r
              date: date,\r
              mealType: mealType,\r
              entries: grouped[mealType] ?? const <MealPlanEntry>[],\r
              onTap: () => onTapCell(\r
                date: date,\r
                mealType: mealType,\r
                entries: grouped[mealType] ?? const <MealPlanEntry>[],\r
              ),\r
            ),\r
        ],\r
      ),\r
    );\r
  }\r
}\r
\r
class _MealRow extends StatelessWidget {\r
  const _MealRow({\r
    required this.date,\r
    required this.mealType,\r
    required this.entries,\r
    required this.onTap,\r
  });\r
\r
  final DateTime date;\r
  final MealType mealType;\r
  final List<MealPlanEntry> entries;\r
  final VoidCallback onTap;\r
\r
  @override\r
  Widget build(BuildContext context) {\r
    final theme = Theme.of(context);\r
    final title = _mealTypeLabel(mealType);\r
\r
    return InkWell(\r
      onTap: onTap,\r
      child: Container(\r
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),\r
        decoration: BoxDecoration(\r
          border: Border(\r
            top: BorderSide(color: theme.dividerColor, width: 0.5),\r
          ),\r
        ),\r
        child: Row(\r
          crossAxisAlignment: CrossAxisAlignment.start,\r
          children: [\r
            SizedBox(\r
              width: 70,\r
              child: Text(\r
                title,\r
                style: theme.textTheme.labelLarge?.copyWith(\r
                  fontWeight: FontWeight.w600,\r
                  color: theme.colorScheme.primary,\r
                ),\r
              ),\r
            ),\r
            const SizedBox(width: 16),\r
            Expanded(\r
              child: entries.isEmpty\r
                  ? Row(\r
                      children: [\r
                        Icon(\r
                          Icons.add_circle_outline,\r
                          size: 18,\r
                          color: theme.colorScheme.outline,\r
                        ),\r
                        const SizedBox(width: 8),\r
                        Text(\r
                          'Them mon',\r
                          style: theme.textTheme.bodyMedium?.copyWith(\r
                            color: theme.colorScheme.outline,\r
                          ),\r
                        ),\r
                      ],\r
                    )\r
                  : Column(\r
                      crossAxisAlignment: CrossAxisAlignment.start,\r
                      children: [\r
                        for (final entry in entries) ...[\r
                          Text(\r
                            _mealLabel(entry),\r
                            style: theme.textTheme.bodyMedium?.copyWith(\r
                              fontWeight: FontWeight.w500,\r
                            ),\r
                            maxLines: 2,\r
                            overflow: TextOverflow.ellipsis,\r
                          ),\r
                          Text(\r
                            'x${entry.servings}${entry.note?.isNotEmpty == true ? " \u00b7 ${entry.note}" : ""}',\r
                            style: theme.textTheme.bodySmall?.copyWith(\r
                              color: theme.colorScheme.onSurfaceVariant,\r
                            ),\r
                            maxLines: 1,\r
                            overflow: TextOverflow.ellipsis,\r
                          ),\r
                          if (entry != entries.last) const SizedBox(height: 8),\r
                        ],\r
                      ],\r
                    ),\r
            ),\r
            const SizedBox(width: 8),\r
            Icon(\r
              Icons.chevron_right,\r
              size: 20,\r
              color: theme.colorScheme.outline,\r
            ),\r
          ],\r
        ),\r
      ),\r
    );\r
  }\r
}\r
"""

# Find and replace _DayColumn class
match = re.search(r"class _DayColumn extends StatelessWidget \{.*?\n\}\n", content, re.DOTALL)
if match:
    content = content.replace(match.group(0), new_day_section)

# Write back
with open(r"g:\Final-Year\LTDD\VuaDauBepThuDuc\lib\features\planner\presentation\planner_page.dart", "w", encoding="utf-8") as f:
    f.write(content)

print("✅ Planner page updated successfully!")
