import 'package:fl_chart/fl_chart.dart';
import 'package:flutter/material.dart';

import '../../../core/constants/app_colors.dart';
import '../../../data/repositories/publication_repository.dart';

class TrendChart extends StatelessWidget {
  final Map<int, int> data;
  final PublicationYearSort yearSort;

  const TrendChart({super.key, required this.data, required this.yearSort});

  @override
  Widget build(BuildContext context) {
    if (data.isEmpty) {
      return const Center(
        child: Text(
          'No data available',
          style: TextStyle(color: AppColors.textSecondary),
        ),
      );
    }

    final sortedEntries = data.entries.toList()
      ..sort((a, b) {
        return switch (yearSort) {
          PublicationYearSort.descending => b.key.compareTo(a.key),
          PublicationYearSort.ascending => a.key.compareTo(b.key),
        };
      });

    double maxY = 0;
    for (final entry in sortedEntries) {
      if (entry.value > maxY) maxY = entry.value.toDouble();
    }

    final chartMaxY = maxY == 0 ? 10.0 : (maxY * 1.38).ceilToDouble();
    final horizontalInterval = chartMaxY > 10
        ? (chartMaxY / 4).ceilToDouble()
        : 1.0;

    return BarChart(
      BarChartData(
        alignment: BarChartAlignment.spaceAround,
        maxY: chartMaxY,
        barTouchData: BarTouchData(
          enabled: true,
          touchTooltipData: BarTouchTooltipData(
            fitInsideHorizontally: true,
            fitInsideVertically: true,
            tooltipPadding: const EdgeInsets.symmetric(
              horizontal: 8,
              vertical: 6,
            ),
            tooltipMargin: 6,
            getTooltipColor: (group) =>
                AppColors.primary.withValues(alpha: 0.92),
            getTooltipItem: (group, groupIndex, rod, rodIndex) {
              return BarTooltipItem(
                '${group.x.toInt()}  ',
                const TextStyle(
                  color: Colors.white,
                  fontWeight: FontWeight.w700,
                  fontSize: 11,
                ),
                children: <TextSpan>[
                  TextSpan(
                    text: _formatCount(rod.toY),
                    style: const TextStyle(
                      color: Colors.white,
                      fontSize: 11,
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                ],
              );
            },
          ),
        ),
        titlesData: FlTitlesData(
          show: true,
          bottomTitles: AxisTitles(
            sideTitles: SideTitles(
              showTitles: true,
              getTitlesWidget: (value, meta) {
                return Padding(
                  padding: const EdgeInsets.only(top: 6),
                  child: Text(
                    value.toInt().toString(),
                    style: const TextStyle(
                      color: AppColors.textSecondary,
                      fontWeight: FontWeight.w600,
                      fontSize: 11,
                    ),
                  ),
                );
              },
              reservedSize: 28,
            ),
          ),
          leftTitles: AxisTitles(
            sideTitles: SideTitles(
              showTitles: true,
              interval: horizontalInterval,
              getTitlesWidget: (value, meta) {
                if (value < 0) return const SizedBox.shrink();
                return SizedBox(
                  width: 52,
                  child: Padding(
                    padding: const EdgeInsets.only(right: 6),
                    child: FittedBox(
                      fit: BoxFit.scaleDown,
                      alignment: Alignment.centerRight,
                      child: Text(
                        _formatCount(value),
                        style: const TextStyle(
                          color: AppColors.textSecondary,
                          fontSize: 11,
                        ),
                        maxLines: 1,
                        textAlign: TextAlign.right,
                      ),
                    ),
                  ),
                );
              },
              reservedSize: 56,
            ),
          ),
          topTitles: const AxisTitles(
            sideTitles: SideTitles(showTitles: false),
          ),
          rightTitles: const AxisTitles(
            sideTitles: SideTitles(showTitles: false),
          ),
        ),
        gridData: FlGridData(
          show: true,
          drawVerticalLine: false,
          horizontalInterval: horizontalInterval,
          getDrawingHorizontalLine: (value) => FlLine(
            color: AppColors.borderLight.withValues(alpha: 0.8),
            strokeWidth: 1,
            dashArray: [4, 4],
          ),
        ),
        borderData: FlBorderData(show: false),
        barGroups: sortedEntries.map((entry) {
          return BarChartGroupData(
            x: entry.key,
            barRods: [
              BarChartRodData(
                toY: entry.value.toDouble(),
                gradient: const LinearGradient(
                  colors: [AppColors.primary, AppColors.primaryLight],
                  begin: Alignment.bottomCenter,
                  end: Alignment.topCenter,
                ),
                width: 14,
                borderRadius: const BorderRadius.only(
                  topLeft: Radius.circular(5),
                  topRight: Radius.circular(5),
                ),
                backDrawRodData: BackgroundBarChartRodData(
                  show: true,
                  toY: chartMaxY,
                  color: AppColors.primary.withValues(alpha: 0.04),
                ),
              ),
            ],
          );
        }).toList(),
      ),
    );
  }

  String _formatCount(double value) {
    final count = value.round();
    if (count >= 1000000) return '${_compact(count / 1000000)}M';
    if (count >= 1000) return '${_compact(count / 1000)}K';
    return count.toString();
  }

  String _compact(double value) {
    if (value >= 10 || value == value.roundToDouble()) {
      return value.toStringAsFixed(0);
    }
    return value.toStringAsFixed(1);
  }
}
