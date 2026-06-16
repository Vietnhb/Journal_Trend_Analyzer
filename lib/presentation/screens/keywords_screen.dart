import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../core/widgets/app_empty_view.dart';
import '../../core/widgets/app_error_view.dart';
import '../../core/widgets/app_loading.dart';
import '../../data/repositories/publication_repository.dart';
import '../providers/publication_provider.dart';
import '../trends/widgets/trend_chart.dart';
import '../trends/widgets/year_ranking_list.dart';

class KeywordsScreen extends StatelessWidget {
  const KeywordsScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final provider = context.watch<PublicationProvider>();

    return Scaffold(
      appBar: AppBar(title: const Text('Keywords')),
      body: _KeywordsBody(provider: provider),
    );
  }
}

class _KeywordsBody extends StatelessWidget {
  final PublicationProvider provider;

  const _KeywordsBody({required this.provider});

  @override
  Widget build(BuildContext context) {
    if (!provider.hasSearched) {
      return const AppEmptyView(
        message: 'Search a topic from Home to view trends and rankings.',
        icon: Icons.query_stats,
      );
    }

    if (provider.isLoading && provider.analysisPublications.isEmpty) {
      return const AppLoading(message: 'Building topic analysis...');
    }

    final error = provider.error;
    if (error != null && provider.analysisPublications.isEmpty) {
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
          Wrap(
            spacing: 12,
            runSpacing: 12,
            children: [
              _MetricCard(
                title: 'Publications',
                value: provider.totalPublications.toString(),
                icon: Icons.article,
              ),
              _MetricCard(
                title: 'Top year',
                value: provider.mostActiveYear?.toString() ?? '-',
                icon: Icons.leaderboard,
              ),
              _MetricCard(
                title: 'Avg citations',
                value: provider.averageCitationCount?.toStringAsFixed(1) ?? '-',
                icon: Icons.trending_up,
              ),
            ],
          ),
          if (provider.isLoadingAnalytics) ...[
            const SizedBox(height: 12),
            const LinearProgressIndicator(),
            const SizedBox(height: 6),
            Text(
              'Loading full OpenAlex analytics...',
              style: Theme.of(context).textTheme.bodySmall,
            ),
          ] else if (provider.analyticsError != null) ...[
            const SizedBox(height: 12),
            Text(
              provider.analyticsError!.message,
              style: TextStyle(color: Theme.of(context).colorScheme.error),
            ),
          ],
          const SizedBox(height: 20),
          Text(
            'Publication Trend',
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
                          yearSort: PublicationYearSort.descending,
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
          const SizedBox(height: 20),
          _HorizontalBarSection(
            title: 'Top Influential Papers',
            items: provider.topPapers
                .map(
                  (paper) => _BarItem(
                    label: paper.title,
                    details:
                        '${paper.year ?? 'No year'} | ${paper.journalName}',
                    value: paper.citationCount,
                    valueLabel: '${paper.citationCount} citations',
                  ),
                )
                .toList(),
          ),
          _HorizontalBarSection(
            title: 'Top Journals',
            items: provider.topJournals
                .map(
                  (entry) => _BarItem(
                    label: entry.key,
                    value: entry.value,
                    valueLabel: '${entry.value} pubs',
                  ),
                )
                .toList(),
          ),
          _HorizontalBarSection(
            title: 'Top Authors',
            items: provider.topAuthors
                .map(
                  (entry) => _BarItem(
                    label: entry.key,
                    value: entry.value,
                    valueLabel: '${entry.value} pubs',
                  ),
                )
                .toList(),
          ),
        ],
      ),
    );
  }
}

class _MetricCard extends StatelessWidget {
  final String title;
  final String value;
  final IconData icon;

  const _MetricCard({
    required this.title,
    required this.value,
    required this.icon,
  });

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    return SizedBox(
      width: 170,
      child: DecoratedBox(
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(8),
          border: Border.all(color: colorScheme.outlineVariant),
        ),
        child: Padding(
          padding: const EdgeInsets.all(14),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Icon(icon, color: colorScheme.primary),
              const SizedBox(height: 12),
              FittedBox(
                fit: BoxFit.scaleDown,
                alignment: Alignment.centerLeft,
                child: Text(
                  value,
                  maxLines: 1,
                  style: Theme.of(context).textTheme.headlineSmall,
                ),
              ),
              const SizedBox(height: 4),
              Text(title, style: Theme.of(context).textTheme.labelMedium),
            ],
          ),
        ),
      ),
    );
  }
}

class _BarItem {
  final String label;
  final String? details;
  final int value;
  final String valueLabel;

  const _BarItem({
    required this.label,
    this.details,
    required this.value,
    required this.valueLabel,
  });
}

class _HorizontalBarSection extends StatelessWidget {
  final String title;
  final List<_BarItem> items;

  const _HorizontalBarSection({required this.title, required this.items});

  @override
  Widget build(BuildContext context) {
    if (items.isEmpty) {
      return const SizedBox.shrink();
    }

    final colorScheme = Theme.of(context).colorScheme;
    final maxValue = items
        .map((item) => item.value)
        .fold<int>(0, (max, value) => value > max ? value : max);

    return Padding(
      padding: const EdgeInsets.only(bottom: 16),
      child: DecoratedBox(
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(8),
          border: Border.all(color: colorScheme.outlineVariant),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 14, 16, 4),
              child: Text(
                title,
                style: Theme.of(context).textTheme.titleMedium,
              ),
            ),
            for (final item in items)
              Padding(
                padding: const EdgeInsets.fromLTRB(16, 8, 16, 14),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                item.label,
                                maxLines: 2,
                                overflow: TextOverflow.ellipsis,
                                style: const TextStyle(
                                  fontWeight: FontWeight.w700,
                                ),
                              ),
                              if (item.details != null)
                                Text(
                                  item.details!,
                                  maxLines: 1,
                                  overflow: TextOverflow.ellipsis,
                                  style: Theme.of(context).textTheme.bodySmall,
                                ),
                            ],
                          ),
                        ),
                        const SizedBox(width: 12),
                        Text(
                          item.valueLabel,
                          style: Theme.of(context).textTheme.labelMedium
                              ?.copyWith(color: colorScheme.primary),
                        ),
                      ],
                    ),
                    const SizedBox(height: 8),
                    ClipRRect(
                      borderRadius: BorderRadius.circular(4),
                      child: LinearProgressIndicator(
                        minHeight: 8,
                        value: maxValue == 0 ? 0 : item.value / maxValue,
                        backgroundColor: colorScheme.primary.withValues(
                          alpha: 0.12,
                        ),
                        valueColor: AlwaysStoppedAnimation<Color>(
                          colorScheme.primary,
                        ),
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
}
