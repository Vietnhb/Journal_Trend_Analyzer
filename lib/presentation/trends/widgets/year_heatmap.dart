import 'dart:math' as math;

import 'package:flutter/material.dart';

import 'chart_empty_state.dart';
import 'chart_formatters.dart';

/// A responsive density grid for scanning activity across many years.
class YearHeatmap extends StatelessWidget {
  final Map<int, int> data;
  final bool ascending;
  final Color? color;
  final String valueLabel;
  final double minimumCellWidth;

  const YearHeatmap({
    super.key,
    required this.data,
    this.ascending = true,
    this.color,
    this.valueLabel = 'publications',
    this.minimumCellWidth = 76,
  });

  @override
  Widget build(BuildContext context) {
    if (data.isEmpty) {
      return const ChartEmptyState(message: 'No density data available');
    }

    final entries = data.entries.toList()
      ..sort(
        (first, second) => ascending
            ? first.key.compareTo(second.key)
            : second.key.compareTo(first.key),
      );
    final maximum = entries.fold<int>(
      0,
      (current, entry) => math.max(current, entry.value),
    );
    final baseColor = color ?? Theme.of(context).colorScheme.primary;

    return Semantics(
      label: 'Year heatmap with ${entries.length} values',
      child: LayoutBuilder(
        builder: (context, constraints) {
          final availableWidth = constraints.maxWidth.isFinite
              ? constraints.maxWidth
              : minimumCellWidth;
          final columns = math.max(
            1,
            math.min(
              entries.length,
              (availableWidth / minimumCellWidth).floor(),
            ),
          );

          return GridView.builder(
            shrinkWrap: true,
            physics: const NeverScrollableScrollPhysics(),
            padding: EdgeInsets.zero,
            itemCount: entries.length,
            gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
              crossAxisCount: columns,
              crossAxisSpacing: 8,
              mainAxisSpacing: 8,
              mainAxisExtent: 72,
            ),
            itemBuilder: (context, index) {
              final entry = entries[index];
              final intensity = maximum <= 0
                  ? 0.0
                  : (entry.value / maximum).clamp(0.0, 1.0);
              return _HeatmapCell(
                year: entry.key,
                value: entry.value,
                valueLabel: valueLabel,
                color: baseColor,
                intensity: intensity,
              );
            },
          );
        },
      ),
    );
  }
}

class _HeatmapCell extends StatelessWidget {
  final int year;
  final int value;
  final String valueLabel;
  final Color color;
  final double intensity;

  const _HeatmapCell({
    required this.year,
    required this.value,
    required this.valueLabel,
    required this.color,
    required this.intensity,
  });

  @override
  Widget build(BuildContext context) {
    final backgroundColor = Color.lerp(
      Theme.of(context).colorScheme.surfaceContainerLow,
      color,
      0.14 + intensity * 0.76,
    )!;
    final foregroundColor =
        ThemeData.estimateBrightnessForColor(backgroundColor) == Brightness.dark
        ? Colors.white
        : Theme.of(context).colorScheme.onSurface;

    return Tooltip(
      message: '$year: ${formatExactChartValue(value)} $valueLabel',
      child: Semantics(
        label: '$year, $value $valueLabel',
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 300),
          curve: Curves.easeOutCubic,
          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 7),
          decoration: BoxDecoration(
            color: backgroundColor,
            borderRadius: BorderRadius.circular(12),
            border: Border.all(color: color.withValues(alpha: 0.16)),
          ),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            mainAxisSize: MainAxisSize.min,
            children: [
              FittedBox(
                fit: BoxFit.scaleDown,
                child: Text(
                  '$year',
                  style: Theme.of(context).textTheme.labelMedium?.copyWith(
                    color: foregroundColor.withValues(alpha: 0.82),
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ),
              const SizedBox(height: 3),
              FittedBox(
                fit: BoxFit.scaleDown,
                child: Text(
                  formatCompactChartValue(value),
                  style: Theme.of(context).textTheme.titleSmall?.copyWith(
                    color: foregroundColor,
                    fontWeight: FontWeight.w800,
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
