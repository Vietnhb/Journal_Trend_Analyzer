import 'dart:math' as math;

import 'package:flutter/material.dart';

import '../../../core/constants/app_colors.dart';
import 'chart_empty_state.dart';
import 'chart_formatters.dart';

/// A compact leaderboard that intentionally differs from time-series charts.
///
/// The progress rail compares every year with the leading year while the exact
/// count remains visible in a tooltip on narrow layouts.
class YearRankingList extends StatelessWidget {
  final List<MapEntry<int, int>> rankedYears;
  final String valueLabel;

  const YearRankingList({
    super.key,
    required this.rankedYears,
    this.valueLabel = 'publications',
  });

  @override
  Widget build(BuildContext context) {
    if (rankedYears.isEmpty) {
      return const Padding(
        padding: EdgeInsets.symmetric(vertical: 12),
        child: ChartEmptyState(message: 'No yearly ranking available'),
      );
    }

    final highestValue = rankedYears.fold<int>(
      0,
      (highest, entry) => math.max(highest, entry.value),
    );

    return Semantics(
      label: 'Year ranking with ${rankedYears.length} entries',
      child: ListView.separated(
        shrinkWrap: true,
        physics: const NeverScrollableScrollPhysics(),
        padding: const EdgeInsets.symmetric(vertical: 6),
        itemCount: rankedYears.length,
        separatorBuilder: (context, index) => const SizedBox(height: 2),
        itemBuilder: (context, index) {
          final entry = rankedYears[index];
          return _RankingRow(
            rank: index + 1,
            year: entry.key,
            value: entry.value,
            highestValue: highestValue,
            valueLabel: valueLabel,
          );
        },
      ),
    );
  }
}

class _RankingRow extends StatelessWidget {
  final int rank;
  final int year;
  final int value;
  final int highestValue;
  final String valueLabel;

  const _RankingRow({
    required this.rank,
    required this.year,
    required this.value,
    required this.highestValue,
    required this.valueLabel,
  });

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    final accentColor = _rankColor(rank, colorScheme);
    final fraction = highestValue <= 0
        ? 0.0
        : (value / highestValue).clamp(0.0, 1.0);

    return Semantics(
      label: 'Rank $rank, year $year, $value $valueLabel',
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 9),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.center,
          children: [
            _RankMarker(rank: rank, color: accentColor),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Expanded(
                        child: Text(
                          '$year',
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: Theme.of(context).textTheme.bodyMedium
                              ?.copyWith(
                                color: colorScheme.onSurface,
                                fontWeight: FontWeight.w700,
                              ),
                        ),
                      ),
                      const SizedBox(width: 8),
                      Tooltip(
                        message: '${formatExactChartValue(value)} $valueLabel',
                        child: Text(
                          formatCompactChartValue(value),
                          maxLines: 1,
                          style: Theme.of(context).textTheme.labelMedium
                              ?.copyWith(
                                color: accentColor,
                                fontWeight: FontWeight.w800,
                                fontFeatures: const [
                                  FontFeature.tabularFigures(),
                                ],
                              ),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 7),
                  ClipRRect(
                    borderRadius: BorderRadius.circular(99),
                    child: SizedBox(
                      height: 7,
                      child: Stack(
                        fit: StackFit.expand,
                        children: [
                          ColoredBox(
                            color: colorScheme.surfaceContainerHighest
                                .withValues(alpha: 0.75),
                          ),
                          Align(
                            alignment: Alignment.centerLeft,
                            child: TweenAnimationBuilder<double>(
                              tween: Tween(begin: 0, end: fraction),
                              duration: const Duration(milliseconds: 450),
                              curve: Curves.easeOutCubic,
                              builder: (context, animatedFraction, child) {
                                return FractionallySizedBox(
                                  widthFactor: animatedFraction,
                                  child: DecoratedBox(
                                    decoration: BoxDecoration(
                                      gradient: LinearGradient(
                                        colors: [
                                          accentColor,
                                          accentColor.withValues(alpha: 0.62),
                                        ],
                                      ),
                                    ),
                                  ),
                                );
                              },
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                  const SizedBox(height: 5),
                  Text(
                    rank == 1
                        ? 'Highest activity'
                        : '${(fraction * 100).round()}% of the leading year',
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: Theme.of(context).textTheme.labelSmall?.copyWith(
                      color: colorScheme.onSurfaceVariant,
                      fontSize: 10.5,
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Color _rankColor(int rank, ColorScheme colorScheme) {
    return switch (rank) {
      1 => AppColors.gold,
      2 => AppColors.silver,
      3 => AppColors.bronze,
      _ => colorScheme.primary,
    };
  }
}

class _RankMarker extends StatelessWidget {
  final int rank;
  final Color color;

  const _RankMarker({required this.rank, required this.color});

  @override
  Widget build(BuildContext context) {
    final isPodium = rank <= 3;
    return Container(
      width: 38,
      height: 38,
      decoration: BoxDecoration(
        color: color.withValues(alpha: isPodium ? 0.14 : 0.09),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: color.withValues(alpha: 0.2)),
      ),
      alignment: Alignment.center,
      child: isPodium
          ? Icon(Icons.emoji_events_rounded, size: 18, color: color)
          : Text(
              '$rank',
              style: Theme.of(context).textTheme.labelMedium?.copyWith(
                color: color,
                fontWeight: FontWeight.w800,
                fontFeatures: const [FontFeature.tabularFigures()],
              ),
            ),
    );
  }
}
