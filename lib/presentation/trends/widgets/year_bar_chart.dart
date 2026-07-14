import 'dart:math' as math;

import 'package:fl_chart/fl_chart.dart';
import 'package:flutter/material.dart';

import 'chart_empty_state.dart';
import 'chart_formatters.dart';

/// A discrete bar chart for comparing independent yearly totals.
class YearBarChart extends StatelessWidget {
  final Map<int, int> data;
  final bool ascending;
  final Color? color;
  final String valueLabel;

  const YearBarChart({
    super.key,
    required this.data,
    this.ascending = true,
    this.color,
    this.valueLabel = 'publications',
  });

  @override
  Widget build(BuildContext context) {
    if (data.isEmpty) {
      return const ChartEmptyState(message: 'No yearly data available');
    }

    final entries = data.entries.toList()
      ..sort(
        (first, second) => ascending
            ? first.key.compareTo(second.key)
            : second.key.compareTo(first.key),
      );
    final maximum = entries.fold<double>(
      0,
      (current, entry) => math.max(current, entry.value.toDouble()),
    );
    final interval = chartIntervalFor(maximum);
    final chartMaximum = chartMaximumFor(maximum, interval);
    final barColor = color ?? Theme.of(context).colorScheme.primary;

    return Semantics(
      label: 'Bar chart comparing ${entries.length} yearly values',
      child: LayoutBuilder(
        builder: (context, constraints) {
          final plotWidth = math.max(1, constraints.maxWidth - 54);
          final labelCapacity = math.max(1, (plotWidth / 46).floor());
          final labelStep = math.max(
            1,
            (entries.length / labelCapacity).ceil(),
          );
          final rodWidth = (plotWidth / math.max(entries.length, 1) * 0.46)
              .clamp(8.0, 22.0);

          return BarChart(
            BarChartData(
              minY: 0,
              maxY: chartMaximum,
              alignment: BarChartAlignment.spaceAround,
              barTouchData: BarTouchData(
                enabled: true,
                touchTooltipData: BarTouchTooltipData(
                  fitInsideHorizontally: true,
                  fitInsideVertically: true,
                  tooltipBorderRadius: BorderRadius.circular(12),
                  tooltipPadding: const EdgeInsets.symmetric(
                    horizontal: 12,
                    vertical: 9,
                  ),
                  tooltipMargin: 8,
                  getTooltipColor: (group) =>
                      Theme.of(context).colorScheme.inverseSurface,
                  getTooltipItem: (group, groupIndex, rod, rodIndex) {
                    final entry = entries[group.x.clamp(0, entries.length - 1)];
                    final colorScheme = Theme.of(context).colorScheme;
                    return BarTooltipItem(
                      '${entry.key}\n',
                      TextStyle(
                        color: colorScheme.onInverseSurface.withValues(
                          alpha: 0.75,
                        ),
                        fontSize: 11,
                        fontWeight: FontWeight.w600,
                        height: 1.35,
                      ),
                      children: [
                        TextSpan(
                          text:
                              '${formatExactChartValue(entry.value)} $valueLabel',
                          style: TextStyle(
                            color: colorScheme.onInverseSurface,
                            fontSize: 12,
                            fontWeight: FontWeight.w800,
                          ),
                        ),
                      ],
                    );
                  },
                ),
              ),
              titlesData: _titlesData(
                context,
                entries: entries,
                interval: interval,
                labelStep: labelStep,
              ),
              gridData: FlGridData(
                show: true,
                drawVerticalLine: false,
                horizontalInterval: interval,
                getDrawingHorizontalLine: (value) => FlLine(
                  color: Theme.of(
                    context,
                  ).colorScheme.outlineVariant.withValues(alpha: 0.6),
                  strokeWidth: 1,
                  dashArray: [5, 5],
                ),
              ),
              borderData: FlBorderData(show: false),
              barGroups: [
                for (var index = 0; index < entries.length; index++)
                  BarChartGroupData(
                    x: index,
                    barRods: [
                      BarChartRodData(
                        toY: math.max(0, entries[index].value).toDouble(),
                        width: rodWidth,
                        gradient: LinearGradient(
                          begin: Alignment.bottomCenter,
                          end: Alignment.topCenter,
                          colors: [barColor.withValues(alpha: 0.72), barColor],
                        ),
                        borderRadius: const BorderRadius.vertical(
                          top: Radius.circular(6),
                        ),
                        backDrawRodData: BackgroundBarChartRodData(
                          show: true,
                          toY: chartMaximum,
                          color: barColor.withValues(alpha: 0.055),
                        ),
                      ),
                    ],
                  ),
              ],
            ),
            duration: const Duration(milliseconds: 400),
            curve: Curves.easeOutCubic,
          );
        },
      ),
    );
  }

  FlTitlesData _titlesData(
    BuildContext context, {
    required List<MapEntry<int, int>> entries,
    required double interval,
    required int labelStep,
  }) {
    final colorScheme = Theme.of(context).colorScheme;
    final axisStyle = Theme.of(context).textTheme.labelSmall?.copyWith(
      color: colorScheme.onSurfaceVariant,
      fontSize: 10.5,
      fontWeight: FontWeight.w600,
    );

    return FlTitlesData(
      topTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
      rightTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
      bottomTitles: AxisTitles(
        sideTitles: SideTitles(
          showTitles: true,
          reservedSize: 30,
          interval: 1,
          getTitlesWidget: (value, meta) {
            final index = value.round();
            final isEdge = index == 0 || index == entries.length - 1;
            if ((value - index).abs() > 0.01 ||
                index < 0 ||
                index >= entries.length ||
                (!isEdge && index % labelStep != 0)) {
              return const SizedBox.shrink();
            }
            return SideTitleWidget(
              meta: meta,
              space: 8,
              child: Text('${entries[index].key}', style: axisStyle),
            );
          },
        ),
      ),
      leftTitles: AxisTitles(
        sideTitles: SideTitles(
          showTitles: true,
          reservedSize: 46,
          interval: interval,
          getTitlesWidget: (value, meta) {
            if (value < 0 || value > meta.max) {
              return const SizedBox.shrink();
            }
            return SideTitleWidget(
              meta: meta,
              space: 7,
              child: Text(formatCompactChartValue(value), style: axisStyle),
            );
          },
        ),
      ),
    );
  }
}
