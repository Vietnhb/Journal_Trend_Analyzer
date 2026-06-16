import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../../core/widgets/app_empty_view.dart';
import '../../../core/widgets/app_error_view.dart';
import '../../../core/widgets/app_loading.dart';
import '../../providers/publication_provider.dart';
import '../widgets/trend_chart.dart';
import '../widgets/year_ranking_list.dart';

class TrendAnalysisScreen extends StatelessWidget {
  const TrendAnalysisScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final provider = context.watch<PublicationProvider>();

    return Scaffold(
      appBar: AppBar(title: const Text('Trend Analysis')),
      body: _TrendBody(provider: provider),
    );
  }
}

class _TrendBody extends StatelessWidget {
  final PublicationProvider provider;

  const _TrendBody({required this.provider});

  @override
  Widget build(BuildContext context) {
    if (!provider.hasSearched) {
      return const AppEmptyView(
        message: 'Search a topic first, then trends will appear here.',
        icon: Icons.query_stats,
      );
    }

    if (provider.isLoading) {
      return const AppLoading(message: 'Building trend analysis...');
    }

    final error = provider.error;
    if (error != null) {
      return AppErrorView(error: error);
    }

    if (provider.publicationsByYear.isEmpty) {
      return const AppEmptyView(
        message: 'The loaded publications do not include publication years.',
        icon: Icons.event_busy,
      );
    }

    return RefreshIndicator(
      onRefresh: () => provider.search(provider.query),
      child: ListView(
        physics: const AlwaysScrollableScrollPhysics(),
        padding: const EdgeInsets.all(16),
        children: [
          Row(
            children: [
              Expanded(
                child: _SummaryTile(
                  label: 'Publications',
                  value: provider.totalPublications.toString(),
                  icon: Icons.article,
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: _SummaryTile(
                  label: 'Top year',
                  value: provider.mostActiveYear?.toString() ?? '-',
                  icon: Icons.leaderboard,
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),
          Text(
            'Publications by Year',
            style: Theme.of(context).textTheme.titleLarge,
          ),
          const SizedBox(height: 12),
          SizedBox(
            height: 320,
            child: DecoratedBox(
              decoration: BoxDecoration(
                color: Theme.of(context).colorScheme.surface,
                borderRadius: BorderRadius.circular(8),
                border: Border.all(
                  color: Theme.of(context).dividerColor.withValues(alpha: 0.4),
                ),
              ),
              child: Padding(
                padding: const EdgeInsets.all(12),
                child: LayoutBuilder(
                  builder: (context, constraints) {
                    final minWidth = provider.publicationsByYear.length * 44.0;
                    final chartWidth = minWidth > constraints.maxWidth
                        ? minWidth
                        : constraints.maxWidth;
                    return SingleChildScrollView(
                      scrollDirection: Axis.horizontal,
                      child: SizedBox(
                        width: chartWidth,
                        child: TrendChart(
                          data: provider.publicationsByYear,
                          yearSort: provider.yearSort,
                        ),
                      ),
                    );
                  },
                ),
              ),
            ),
          ),
          const SizedBox(height: 20),
          Text('Year Ranking', style: Theme.of(context).textTheme.titleLarge),
          const SizedBox(height: 12),
          YearRankingList(rankedYears: provider.yearsByPublicationCount),
        ],
      ),
    );
  }
}

class _SummaryTile extends StatelessWidget {
  final String label;
  final String value;
  final IconData icon;

  const _SummaryTile({
    required this.label,
    required this.value,
    required this.icon,
  });

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    return DecoratedBox(
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: colorScheme.outlineVariant),
      ),
      child: Padding(
        padding: const EdgeInsets.all(14),
        child: Row(
          children: [
            Icon(icon, color: colorScheme.primary),
            const SizedBox(width: 10),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(label, style: Theme.of(context).textTheme.labelMedium),
                  Text(value, style: Theme.of(context).textTheme.titleLarge),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}
