import 'package:flutter/material.dart';

class YearRankingList extends StatelessWidget {
  final List<MapEntry<int, int>> rankedYears;

  const YearRankingList({super.key, required this.rankedYears});

  @override
  Widget build(BuildContext context) {
    if (rankedYears.isEmpty) {
      return const Center(child: Text('No ranking available'));
    }

    return ListView.separated(
      shrinkWrap: true,
      physics: const NeverScrollableScrollPhysics(),
      itemCount: rankedYears.length,
      separatorBuilder: (context, index) => const Divider(height: 1),
      itemBuilder: (context, index) {
        final entry = rankedYears[index];
        final rank = index + 1;

        // Style top 3 ranks differently
        Color? avatarColor;
        if (rank == 1) {
          avatarColor = Colors.amber;
        } else if (rank == 2) {
          avatarColor = Colors.grey[400];
        } else if (rank == 3) {
          avatarColor = Colors.brown[300];
        } else {
          avatarColor = Colors.indigo[100];
        }

        return ListTile(
          leading: CircleAvatar(
            backgroundColor: avatarColor,
            foregroundColor: rank <= 3 ? Colors.white : Colors.indigo[900],
            child: Text(
              '#$rank',
              style: TextStyle(
                fontWeight: rank <= 3 ? FontWeight.bold : FontWeight.normal,
                fontSize: 14,
              ),
            ),
          ),
          title: Text(
            'Year ${entry.key}',
            style: const TextStyle(fontWeight: FontWeight.w600),
          ),
          trailing: Container(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
            decoration: BoxDecoration(
              color: Colors.indigo.withValues(alpha: 0.1),
              borderRadius: BorderRadius.circular(16),
            ),
            child: Text(
              '${entry.value} pubs',
              style: const TextStyle(
                color: Colors.indigo,
                fontWeight: FontWeight.bold,
              ),
            ),
          ),
        );
      },
    );
  }
}
