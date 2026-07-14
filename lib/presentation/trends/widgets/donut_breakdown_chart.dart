import 'dart:math' as math;

import 'package:fl_chart/fl_chart.dart';
import 'package:flutter/material.dart';

import 'chart_empty_state.dart';
import 'chart_formatters.dart';

/// A responsive donut and legend for proportional category data.
class DonutBreakdownChart extends StatefulWidget {
  final Map<String, num> data;
  final String centerLabel;
  final List<Color>? colors;
  final bool showLegend;

  const DonutBreakdownChart({
    super.key,
    required this.data,
    this.centerLabel = 'Total',
    this.colors,
    this.showLegend = true,
  });

  @override
  State<DonutBreakdownChart> createState() => _DonutBreakdownChartState();
}

class _DonutBreakdownChartState extends State<DonutBreakdownChart> {
  int _touchedIndex = -1;

  @override
  Widget build(BuildContext context) {
    final entries = widget.data.entries
        .where((entry) => entry.value.isFinite && entry.value > 0)
        .toList();
    if (entries.isEmpty) {
      return const ChartEmptyState(message: 'No breakdown data available');
    }

    final total = entries.fold<double>(
      0,
      (sum, entry) => sum + entry.value.toDouble(),
    );
    final colors = _chartColors(context, entries.length);
    final selectedIndex = _touchedIndex >= 0 && _touchedIndex < entries.length
        ? _touchedIndex
        : -1;

    return Semantics(
      label: 'Donut chart with ${entries.length} categories',
      child: LayoutBuilder(
        builder: (context, constraints) {
          final isWide = constraints.maxWidth >= 420;
          final chart = _Donut(
            entries: entries,
            total: total,
            colors: colors,
            selectedIndex: selectedIndex,
            centerLabel: widget.centerLabel,
            onTouched: (index) {
              if (_touchedIndex == index) return;
              setState(() => _touchedIndex = index);
            },
          );

          if (!widget.showLegend) return chart;

          final legend = _Legend(
            entries: entries,
            total: total,
            colors: colors,
            selectedIndex: selectedIndex,
            onSelected: (index) {
              setState(() => _touchedIndex = index);
            },
          );

          if (isWide) {
            return Row(
              crossAxisAlignment: CrossAxisAlignment.center,
              children: [
                SizedBox(width: 180, height: 180, child: chart),
                const SizedBox(width: 20),
                Expanded(child: legend),
              ],
            );
          }

          final availableHeight = constraints.maxHeight.isFinite
              ? constraints.maxHeight
              : 220.0;
          final chartSize = (availableHeight - 52).clamp(120.0, 168.0);
          final verticalGap = availableHeight < 220 ? 8.0 : 14.0;

          return Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              SizedBox(width: chartSize, height: chartSize, child: chart),
              SizedBox(height: verticalGap),
              legend,
            ],
          );
        },
      ),
    );
  }

  List<Color> _chartColors(BuildContext context, int length) {
    final suppliedColors = widget.colors;
    if (suppliedColors != null && suppliedColors.isNotEmpty) {
      return [
        for (var index = 0; index < length; index++)
          suppliedColors[index % suppliedColors.length],
      ];
    }

    final base = HSLColor.fromColor(Theme.of(context).colorScheme.primary);
    return [
      for (var index = 0; index < length; index++)
        base
            .withHue((base.hue + (360 / math.max(length, 3)) * index) % 360)
            .withSaturation((base.saturation * 0.9).clamp(0.45, 0.82))
            .withLightness((0.49 + (index.isOdd ? 0.08 : 0)).clamp(0.36, 0.65))
            .toColor(),
    ];
  }
}

class _Donut extends StatelessWidget {
  final List<MapEntry<String, num>> entries;
  final double total;
  final List<Color> colors;
  final int selectedIndex;
  final String centerLabel;
  final ValueChanged<int> onTouched;

  const _Donut({
    required this.entries,
    required this.total,
    required this.colors,
    required this.selectedIndex,
    required this.centerLabel,
    required this.onTouched,
  });

  @override
  Widget build(BuildContext context) {
    final selectedEntry = selectedIndex >= 0 ? entries[selectedIndex] : null;
    final centerValue = selectedEntry?.value ?? total;
    final centerCaption = selectedEntry?.key ?? centerLabel;

    return Stack(
      alignment: Alignment.center,
      children: [
        PieChart(
          PieChartData(
            startDegreeOffset: -90,
            sectionsSpace: 3,
            centerSpaceRadius: 48,
            borderData: FlBorderData(show: false),
            pieTouchData: PieTouchData(
              touchCallback: (event, response) {
                if (!event.isInterestedForInteractions ||
                    response?.touchedSection == null) {
                  onTouched(-1);
                  return;
                }
                onTouched(response!.touchedSection!.touchedSectionIndex);
              },
            ),
            sections: [
              for (var index = 0; index < entries.length; index++)
                PieChartSectionData(
                  value: entries[index].value.toDouble(),
                  color: colors[index],
                  radius: index == selectedIndex ? 25 : 20,
                  showTitle: false,
                  borderSide: BorderSide(
                    color: Theme.of(context).colorScheme.surface,
                    width: 1.5,
                  ),
                  cornerRadius: 4,
                ),
            ],
          ),
          duration: const Duration(milliseconds: 350),
          curve: Curves.easeOutCubic,
        ),
        IgnorePointer(
          child: Padding(
            padding: const EdgeInsets.all(38),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                FittedBox(
                  fit: BoxFit.scaleDown,
                  child: Text(
                    formatCompactChartValue(centerValue),
                    style: Theme.of(context).textTheme.titleMedium?.copyWith(
                      fontWeight: FontWeight.w800,
                      color: Theme.of(context).colorScheme.onSurface,
                    ),
                  ),
                ),
                Text(
                  centerCaption,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  textAlign: TextAlign.center,
                  style: Theme.of(context).textTheme.labelSmall?.copyWith(
                    color: Theme.of(context).colorScheme.onSurfaceVariant,
                    fontSize: 9.5,
                  ),
                ),
              ],
            ),
          ),
        ),
      ],
    );
  }
}

class _Legend extends StatelessWidget {
  final List<MapEntry<String, num>> entries;
  final double total;
  final List<Color> colors;
  final int selectedIndex;
  final ValueChanged<int> onSelected;

  const _Legend({
    required this.entries,
    required this.total,
    required this.colors,
    required this.selectedIndex,
    required this.onSelected,
  });

  @override
  Widget build(BuildContext context) {
    return Wrap(
      spacing: 8,
      runSpacing: 8,
      children: [
        for (var index = 0; index < entries.length; index++)
          _LegendItem(
            label: entries[index].key,
            percentage: entries[index].value / total,
            color: colors[index],
            isSelected: selectedIndex == index,
            onTap: () => onSelected(selectedIndex == index ? -1 : index),
          ),
      ],
    );
  }
}

class _LegendItem extends StatelessWidget {
  final String label;
  final double percentage;
  final Color color;
  final bool isSelected;
  final VoidCallback onTap;

  const _LegendItem({
    required this.label,
    required this.percentage,
    required this.color,
    required this.isSelected,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return Tooltip(
      message: '$label: ${(percentage * 100).toStringAsFixed(1)}%',
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(10),
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 180),
          constraints: const BoxConstraints(maxWidth: 190),
          padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 7),
          decoration: BoxDecoration(
            color: isSelected
                ? color.withValues(alpha: 0.12)
                : Theme.of(context).colorScheme.surfaceContainerLow,
            borderRadius: BorderRadius.circular(10),
            border: Border.all(
              color: isSelected
                  ? color.withValues(alpha: 0.45)
                  : Theme.of(context).colorScheme.outlineVariant,
            ),
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Container(
                width: 9,
                height: 9,
                decoration: BoxDecoration(
                  color: color,
                  borderRadius: BorderRadius.circular(3),
                ),
              ),
              const SizedBox(width: 7),
              Flexible(
                child: Text(
                  label,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: Theme.of(context).textTheme.labelSmall?.copyWith(
                    color: Theme.of(context).colorScheme.onSurface,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ),
              const SizedBox(width: 6),
              Text(
                '${(percentage * 100).round()}%',
                style: Theme.of(context).textTheme.labelSmall?.copyWith(
                  color: color,
                  fontWeight: FontWeight.w800,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
