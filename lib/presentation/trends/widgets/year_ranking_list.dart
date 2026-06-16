import 'package:flutter/material.dart';

import '../../../core/constants/app_colors.dart';

class YearRankingList extends StatelessWidget {
  final List<MapEntry<int, int>> rankedYears;

  const YearRankingList({super.key, required this.rankedYears});

  @override
  Widget build(BuildContext context) {
    if (rankedYears.isEmpty) {
      return const Padding(
        padding: EdgeInsets.all(16),
        child: Center(child: Text('No ranking available')),
      );
    }

    return ListView.separated(
      shrinkWrap: true,
      physics: const NeverScrollableScrollPhysics(),
      itemCount: rankedYears.length,
      separatorBuilder: (context, index) =>
          const Divider(height: 1, indent: 16, endIndent: 16),
      itemBuilder: (context, index) {
        final entry = rankedYears[index];
        final rank = index + 1;

        Color medalColor;
        IconData? medalIcon;
        if (rank == 1) {
          medalColor = AppColors.gold;
          medalIcon = Icons.emoji_events_rounded;
        } else if (rank == 2) {
          medalColor = AppColors.silver;
          medalIcon = Icons.emoji_events_rounded;
        } else if (rank == 3) {
          medalColor = AppColors.bronze;
          medalIcon = Icons.emoji_events_rounded;
        } else {
          medalColor = AppColors.textHint;
          medalIcon = null;
        }

        return Padding(
          padding: const EdgeInsets.symmetric(
            horizontal: 16,
            vertical: 10,
          ),
          child: Row(
            children: [
              // Rank avatar
              Container(
                width: 38,
                height: 38,
                decoration: BoxDecoration(
                  color: medalColor.withValues(alpha: rank <= 3 ? 0.12 : 0.06),
                  borderRadius: BorderRadius.circular(10),
                ),
                alignment: Alignment.center,
                child: medalIcon != null
                    ? Icon(medalIcon, size: 18, color: medalColor)
                    : Text(
                        '#$rank',
                        style: TextStyle(
                          fontSize: 12,
                          fontWeight: FontWeight.w700,
                          color: AppColors.textSecondary,
                        ),
                      ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Year ${entry.key}',
                      style:
                          Theme.of(context).textTheme.bodyMedium?.copyWith(
                                fontWeight: FontWeight.w700,
                                color: AppColors.textPrimary,
                              ),
                    ),
                    Text(
                      rank == 1
                          ? 'Most active year'
                          : rank == 2
                              ? '2nd most active'
                              : rank == 3
                                  ? '3rd most active'
                                  : 'Rank #$rank',
                      style:
                          Theme.of(context).textTheme.labelSmall?.copyWith(
                                color: AppColors.textSecondary,
                              ),
                    ),
                  ],
                ),
              ),
              Container(
                padding: const EdgeInsets.symmetric(
                  horizontal: 10,
                  vertical: 5,
                ),
                decoration: BoxDecoration(
                  color: medalColor.withValues(
                    alpha: rank <= 3 ? 0.12 : 0.06,
                  ),
                  borderRadius: BorderRadius.circular(20),
                ),
                child: Text(
                  '${entry.value} pubs',
                  style: TextStyle(
                    fontSize: 12,
                    fontWeight: FontWeight.w700,
                    color: rank <= 3 ? medalColor : AppColors.textSecondary,
                  ),
                ),
              ),
            ],
          ),
        );
      },
    );
  }
}
