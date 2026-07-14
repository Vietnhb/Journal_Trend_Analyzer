import 'dart:math' as math;

import 'package:fl_chart/fl_chart.dart';
import 'package:flutter/material.dart';

import '../../../data/repositories/journal_repository.dart';
import 'chart_empty_state.dart';
import 'chart_formatters.dart';

/// A responsive line chart for chronological publication counts.
///
/// Years are mapped to evenly spaced x-axis positions so missing years never
/// distort the visual spacing. The original year and exact value remain
/// available through the touch tooltip.
class TrendChart extends StatelessWidget {
  final Map<int, int> data;
  final PublicationYearSort yearSort;
  final String valueLabel;
  final Color? color;
  final bool showArea;

  const TrendChart({
    super.key,
    required this.data,
    required this.yearSort,
    this.valueLabel = 'publications',
    this.color,
    this.showArea = true,
  });

  @override
  Widget build(BuildContext context) {
    if (data.isEmpty) {
      return const ChartEmptyState(message: 'No trend data available');
    }

    final entries = data.entries.toList()
      ..sort((first, second) {
        return switch (yearSort) {
          PublicationYearSort.descending => second.key.compareTo(first.key),
          PublicationYearSort.ascending => first.key.compareTo(second.key),
        };
      });

    final maximum = entries.fold<double>(
      0,
      (current, entry) => math.max(current, entry.value.toDouble()),
    );
    final interval = chartIntervalFor(maximum);
    final chartMaximum = chartMaximumFor(maximum, interval);
    final lineColor = color ?? Theme.of(context).colorScheme.primary;

    return Semantics(
      label: _semanticDescription(entries),
      child: LayoutBuilder(
        builder: (context, constraints) {
          final plotWidth = math.max(1, constraints.maxWidth - 58);
          final labelCapacity = math.max(1, (plotWidth / 46).floor());
          final labelStep = math.max(
            1,
            (entries.length / labelCapacity).ceil(),
          );

          return LineChart(
            LineChartData(
              minX: entries.length == 1 ? -0.5 : 0,
              maxX: entries.length == 1 ? 0.5 : (entries.length - 1).toDouble(),
              minY: 0,
              maxY: chartMaximum,
              clipData: const FlClipData(
                top: false,
                right: false,
                bottom: true,
                left: true,
              ),
              lineTouchData: _touchData(
                context,
                entries: entries,
                lineColor: lineColor,
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
                  ).colorScheme.outlineVariant.withValues(alpha: 0.65),
                  strokeWidth: 1,
                  dashArray: [5, 5],
                ),
              ),
              borderData: FlBorderData(show: false),
              lineBarsData: [
                LineChartBarData(
                  spots: [
                    for (var index = 0; index < entries.length; index++)
                      FlSpot(
                        index.toDouble(),
                        math.max(0, entries[index].value).toDouble(),
                      ),
                  ],
                  isCurved: entries.length > 2,
                  curveSmoothness: 0.24,
                  preventCurveOverShooting: true,
                  color: lineColor,
                  barWidth: 3,
                  isStrokeCapRound: true,
                  isStrokeJoinRound: true,
                  shadow: Shadow(
                    color: lineColor.withValues(alpha: 0.16),
                    blurRadius: 8,
                    offset: const Offset(0, 3),
                  ),
                  dotData: FlDotData(
                    show: true,
                    checkToShowDot: (spot, barData) {
                      if (entries.length <= 8) return true;
                      return spot.x == 0 || spot.x == entries.length - 1;
                    },
                    getDotPainter: (spot, percent, barData, index) {
                      return FlDotCirclePainter(
                        radius: 3.5,
                        color: Theme.of(context).colorScheme.surface,
                        strokeWidth: 2.2,
                        strokeColor: lineColor,
                      );
                    },
                  ),
                  belowBarData: BarAreaData(
                    show: showArea,
                    gradient: LinearGradient(
                      begin: Alignment.topCenter,
                      end: Alignment.bottomCenter,
                      colors: [
                        lineColor.withValues(alpha: 0.24),
                        lineColor.withValues(alpha: 0.015),
                      ],
                    ),
                  ),
                ),
              ],
            ),
            duration: const Duration(milliseconds: 450),
            curve: Curves.easeOutCubic,
          );
        },
      ),
    );
  }

  LineTouchData _touchData(
    BuildContext context, {
    required List<MapEntry<int, int>> entries,
    required Color lineColor,
  }) {
    final colorScheme = Theme.of(context).colorScheme;

    return LineTouchData(
      enabled: true,
      touchSpotThreshold: 24,
      getTouchedSpotIndicator: (barData, spotIndexes) {
        return spotIndexes
            .map(
              (index) => TouchedSpotIndicatorData(
                FlLine(
                  color: lineColor.withValues(alpha: 0.42),
                  strokeWidth: 1.5,
                  dashArray: [4, 3],
                ),
                FlDotData(
                  getDotPainter: (spot, percent, barData, index) {
                    return FlDotCirclePainter(
                      radius: 5,
                      color: colorScheme.surface,
                      strokeWidth: 3,
                      strokeColor: lineColor,
                    );
                  },
                ),
              ),
            )
            .toList();
      },
      touchTooltipData: LineTouchTooltipData(
        fitInsideHorizontally: true,
        fitInsideVertically: true,
        tooltipBorderRadius: BorderRadius.circular(12),
        tooltipPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 9),
        tooltipMargin: 10,
        maxContentWidth: 180,
        getTooltipColor: (spot) => colorScheme.inverseSurface,
        getTooltipItems: (touchedSpots) {
          return touchedSpots.map((touchedSpot) {
            final index = touchedSpot.x.round().clamp(0, entries.length - 1);
            final entry = entries[index];
            return LineTooltipItem(
              '${entry.key}\n',
              TextStyle(
                color: colorScheme.onInverseSurface.withValues(alpha: 0.75),
                fontSize: 11,
                fontWeight: FontWeight.w600,
                height: 1.35,
              ),
              children: [
                TextSpan(
                  text: '${formatExactChartValue(entry.value)} $valueLabel',
                  style: TextStyle(
                    color: colorScheme.onInverseSurface,
                    fontSize: 12,
                    fontWeight: FontWeight.w800,
                  ),
                ),
              ],
            );
          }).toList();
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
            final isWholePosition = (value - index).abs() < 0.01;
            final isEdge = index == 0 || index == entries.length - 1;
            if (!isWholePosition ||
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
          reservedSize: 48,
          interval: interval,
          getTitlesWidget: (value, meta) {
            if (value < 0 || value > meta.max) {
              return const SizedBox.shrink();
            }
            return SideTitleWidget(
              meta: meta,
              space: 8,
              child: Text(
                formatCompactChartValue(value),
                maxLines: 1,
                style: axisStyle,
              ),
            );
          },
        ),
      ),
    );
  }

  String _semanticDescription(List<MapEntry<int, int>> entries) {
    final peak = entries.reduce(
      (first, second) => first.value >= second.value ? first : second,
    );
    return 'Trend chart with ${entries.length} years. '
        'Highest value ${formatExactChartValue(peak.value)} in ${peak.key}.';
  }
}
