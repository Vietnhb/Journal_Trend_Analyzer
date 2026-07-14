import 'dart:math' as math;

import 'package:fl_chart/fl_chart.dart';
import 'package:flutter/material.dart';

import 'chart_formatters.dart';

/// A small, axis-free trend line intended for summary and metric cards.
class MiniSparkline extends StatelessWidget {
  final List<num> values;
  final double height;
  final Color? color;
  final bool showArea;
  final String valueLabel;

  const MiniSparkline({
    super.key,
    required this.values,
    this.height = 48,
    this.color,
    this.showArea = true,
    this.valueLabel = 'value',
  });

  @override
  Widget build(BuildContext context) {
    if (values.isEmpty) {
      return SizedBox(
        height: height,
        child: Semantics(
          label: 'No sparkline data available',
          child: Center(
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(
                  Icons.show_chart_rounded,
                  size: 16,
                  color: Theme.of(context).colorScheme.onSurfaceVariant,
                ),
                const SizedBox(width: 5),
                Text(
                  'No data',
                  style: Theme.of(context).textTheme.labelSmall?.copyWith(
                    color: Theme.of(context).colorScheme.onSurfaceVariant,
                  ),
                ),
              ],
            ),
          ),
        ),
      );
    }

    final lineColor = color ?? Theme.of(context).colorScheme.primary;
    final minimum = values.fold<double>(
      double.infinity,
      (current, value) => math.min(current, value.toDouble()),
    );
    final maximum = values.fold<double>(
      double.negativeInfinity,
      (current, value) => math.max(current, value.toDouble()),
    );
    final range = maximum - minimum;
    final padding = range == 0 ? math.max(maximum.abs() * 0.1, 1) : range * 0.2;

    return SizedBox(
      height: height,
      child: Semantics(
        label: 'Sparkline with ${values.length} values',
        child: LineChart(
          LineChartData(
            minX: values.length == 1 ? -0.5 : 0,
            maxX: values.length == 1 ? 0.5 : (values.length - 1).toDouble(),
            minY: minimum - padding,
            maxY: maximum + padding,
            titlesData: const FlTitlesData(show: false),
            gridData: const FlGridData(show: false),
            borderData: FlBorderData(show: false),
            lineTouchData: LineTouchData(
              enabled: true,
              touchSpotThreshold: 20,
              touchTooltipData: LineTouchTooltipData(
                fitInsideHorizontally: true,
                fitInsideVertically: true,
                tooltipBorderRadius: BorderRadius.circular(9),
                tooltipPadding: const EdgeInsets.symmetric(
                  horizontal: 9,
                  vertical: 6,
                ),
                tooltipMargin: 6,
                getTooltipColor: (spot) =>
                    Theme.of(context).colorScheme.inverseSurface,
                getTooltipItems: (spots) => spots.map((spot) {
                  return LineTooltipItem(
                    '${formatExactChartValue(spot.y)} $valueLabel',
                    TextStyle(
                      color: Theme.of(context).colorScheme.onInverseSurface,
                      fontSize: 10.5,
                      fontWeight: FontWeight.w700,
                    ),
                  );
                }).toList(),
              ),
            ),
            lineBarsData: [
              LineChartBarData(
                spots: [
                  for (var index = 0; index < values.length; index++)
                    FlSpot(index.toDouble(), values[index].toDouble()),
                ],
                isCurved: values.length > 2,
                curveSmoothness: 0.25,
                preventCurveOverShooting: true,
                color: lineColor,
                barWidth: 2.5,
                isStrokeCapRound: true,
                dotData: FlDotData(
                  show: true,
                  checkToShowDot: (spot, barData) =>
                      spot.x == values.length - 1,
                  getDotPainter: (spot, percent, barData, index) =>
                      FlDotCirclePainter(
                        radius: 3,
                        color: Theme.of(context).colorScheme.surface,
                        strokeWidth: 2,
                        strokeColor: lineColor,
                      ),
                ),
                belowBarData: BarAreaData(
                  show: showArea,
                  gradient: LinearGradient(
                    begin: Alignment.topCenter,
                    end: Alignment.bottomCenter,
                    colors: [
                      lineColor.withValues(alpha: 0.2),
                      lineColor.withValues(alpha: 0.01),
                    ],
                  ),
                ),
              ),
            ],
          ),
          duration: const Duration(milliseconds: 350),
          curve: Curves.easeOutCubic,
        ),
      ),
    );
  }
}
