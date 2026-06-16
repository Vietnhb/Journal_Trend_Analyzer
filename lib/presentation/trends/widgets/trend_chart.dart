import 'package:fl_chart/fl_chart.dart';
import 'package:flutter/material.dart';

import '../../../data/repositories/publication_repository.dart';

class TrendChart extends StatelessWidget {
  final Map<int, int> data;
  final PublicationYearSort yearSort;

  const TrendChart({super.key, required this.data, required this.yearSort});

  @override
  Widget build(BuildContext context) {
    if (data.isEmpty) {
      return const Center(child: Text('No data available'));
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
      if (entry.value > maxY) {
        maxY = entry.value.toDouble();
      }
    }

    final chartMaxY = maxY == 0 ? 10.0 : (maxY * 1.18).ceilToDouble();
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
            getTooltipColor: (group) => Colors.indigo.withValues(alpha: 0.8),
            getTooltipItem: (group, groupIndex, rod, rodIndex) {
              return BarTooltipItem(
                '${group.x.toInt()}\n',
                const TextStyle(
                  color: Colors.white,
                  fontWeight: FontWeight.bold,
                  fontSize: 14,
                ),
                children: <TextSpan>[
                  TextSpan(
                    text: '${rod.toY.toInt()} publications',
                    style: const TextStyle(
                      color: Colors.white,
                      fontSize: 12,
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
                final year = value.toInt();
                return Padding(
                  padding: const EdgeInsets.only(top: 8.0),
                  child: Text(
                    year.toString(),
                    style: const TextStyle(
                      color: Colors.grey,
                      fontWeight: FontWeight.bold,
                      fontSize: 12,
                    ),
                  ),
                );
              },
              reservedSize: 30,
            ),
          ),
          leftTitles: AxisTitles(
            sideTitles: SideTitles(
              showTitles: true,
              interval: horizontalInterval,
              getTitlesWidget: (value, meta) {
                if (value < 0) {
                  return const SizedBox.shrink();
                }
                return SizedBox(
                  width: 56,
                  child: Padding(
                    padding: const EdgeInsets.only(right: 8),
                    child: FittedBox(
                      fit: BoxFit.scaleDown,
                      alignment: Alignment.centerRight,
                      child: Text(
                        _formatCount(value),
                        style: const TextStyle(
                          color: Colors.grey,
                          fontSize: 11,
                        ),
                        maxLines: 1,
                        textAlign: TextAlign.right,
                      ),
                    ),
                  ),
                );
              },
              reservedSize: 62,
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
          getDrawingHorizontalLine: (value) {
            return FlLine(
              color: Colors.grey.withValues(alpha: 0.2),
              strokeWidth: 1,
            );
          },
        ),
        borderData: FlBorderData(show: false),
        barGroups: sortedEntries.map((entry) {
          return BarChartGroupData(
            x: entry.key,
            barRods: [
              BarChartRodData(
                toY: entry.value.toDouble(),
                gradient: const LinearGradient(
                  colors: [Colors.indigo, Colors.blueAccent],
                  begin: Alignment.bottomCenter,
                  end: Alignment.topCenter,
                ),
                width: 16,
                borderRadius: const BorderRadius.only(
                  topLeft: Radius.circular(4),
                  topRight: Radius.circular(4),
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
    if (count >= 1000000) {
      return '${_compactNumber(count / 1000000)}M';
    }
    if (count >= 1000) {
      return '${_compactNumber(count / 1000)}K';
    }
    return count.toString();
  }

  String _compactNumber(double value) {
    if (value >= 10 || value == value.roundToDouble()) {
      return value.toStringAsFixed(0);
    }
    return value.toStringAsFixed(1);
  }
}
