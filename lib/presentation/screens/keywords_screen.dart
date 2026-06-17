import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../core/constants/app_colors.dart';
import '../../core/widgets/app_empty_view.dart';
import '../../core/widgets/app_error_view.dart';
import '../../data/repositories/journal_repository.dart';
import '../providers/journal_provider.dart';
import '../trends/widgets/trend_chart.dart';
import '../trends/widgets/year_ranking_list.dart';

class KeywordsScreen extends StatelessWidget {
  const KeywordsScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final provider = context.watch<JournalProvider>();

    return Scaffold(
      body: SafeArea(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            _Header(provider: provider),
            Expanded(child: _SourceAnalyticsBody(provider: provider)),
          ],
        ),
      ),
    );
  }
}

class _Header extends StatelessWidget {
  final JournalProvider provider;

  const _Header({required this.provider});

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;

    return Container(
      padding: const EdgeInsets.fromLTRB(20, 16, 20, 12),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'Journal Source Analytics',
            style: Theme.of(context).textTheme.headlineSmall?.copyWith(
              color: colorScheme.onSurface,
              fontWeight: FontWeight.w800,
            ),
          ),
          const SizedBox(height: 2),
          Text(
            provider.selectedJournal == null
                ? 'Source metrics for selected journal'
                : 'Source metrics for ${provider.selectedJournal!.name}',
            style: Theme.of(context).textTheme.bodySmall?.copyWith(
              color: colorScheme.onSurfaceVariant,
            ),
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
          ),
          const SizedBox(height: 12),
          const Divider(height: 1),
        ],
      ),
    );
  }
}

class _SourceAnalyticsBody extends StatelessWidget {
  final JournalProvider provider;

  const _SourceAnalyticsBody({required this.provider});

  @override
  Widget build(BuildContext context) {
    if (!provider.hasSearched) {
      return const AppEmptyView(
        message: 'Search a topic from Home, then select a journal.',
        icon: Icons.query_stats_outlined,
      );
    }

    if (provider.selectedJournal == null) {
      return const AppEmptyView(
        message: 'Please select a journal to view journal source analytics.',
        icon: Icons.book_outlined,
      );
    }

    final error = provider.analyticsError;
    if (error != null) {
      return AppErrorView(error: error);
    }

    return RefreshIndicator(
      onRefresh: () => provider.selectJournal(provider.selectedJournal!),
      color: AppColors.primary,
      child: ListView(
        physics: const AlwaysScrollableScrollPhysics(),
        padding: const EdgeInsets.fromLTRB(16, 4, 16, 24),
        children: [
          _QueryBadge(
            query: provider.query,
            journalName: provider.selectedJournal!.name,
          ),
          const SizedBox(height: 16),
          _MetricRow(provider: provider),
          const SizedBox(height: 24),
          if (provider.sourceWorksByYear.isNotEmpty) ...[
            _SectionHeader(
              icon: Icons.bar_chart_rounded,
              title: 'Source Works Trend',
            ),
            const SizedBox(height: 12),
            _TrendChartCard(provider: provider),
            const SizedBox(height: 24),
            _SectionHeader(
              icon: Icons.leaderboard_rounded,
              title: 'Year Ranking',
            ),
            const SizedBox(height: 12),
            _YearRankingCard(provider: provider),
            const SizedBox(height: 24),
          ],
          _HorizontalBarSection(
            title: 'Source Topics',
            icon: Icons.topic_outlined,
            items: provider.journalTopics
                .map(
                  (topic) => _BarItem(
                    label: topic.name,
                    value: topic.worksCount,
                    valueLabel: '${topic.worksCount} works',
                  ),
                )
                .toList(),
          ),
        ],
      ),
    );
  }
}

class _QueryBadge extends StatelessWidget {
  final String query;
  final String journalName;

  const _QueryBadge({required this.query, required this.journalName});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
      decoration: BoxDecoration(
        color: AppColors.primary.withValues(alpha: 0.08),
        borderRadius: BorderRadius.circular(10),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _BadgeLine(icon: Icons.search_rounded, text: 'Topic: $query'),
          const SizedBox(height: 4),
          _BadgeLine(
            icon: Icons.book_outlined,
            text: 'Selected journal: $journalName',
          ),
        ],
      ),
    );
  }
}

class _BadgeLine extends StatelessWidget {
  final IconData icon;
  final String text;

  const _BadgeLine({required this.icon, required this.text});

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Icon(icon, size: 14, color: AppColors.primary),
        const SizedBox(width: 6),
        Flexible(
          child: Text(
            text,
            style: Theme.of(context).textTheme.labelMedium?.copyWith(
              color: AppColors.primary,
              fontWeight: FontWeight.w600,
            ),
            overflow: TextOverflow.ellipsis,
          ),
        ),
      ],
    );
  }
}

class _MetricRow extends StatelessWidget {
  final JournalProvider provider;

  const _MetricRow({required this.provider});

  String _compact(num count) {
    if (count >= 1000000) return '${(count / 1000000).toStringAsFixed(1)}M';
    if (count >= 1000) return '${(count / 1000).toStringAsFixed(1)}K';
    return count.toString();
  }

  @override
  Widget build(BuildContext context) {
    final journal = provider.selectedJournal!;

    return Column(
      children: [
        Row(
          children: [
            Expanded(
              child: _MetricCard(
                title: 'Works',
                value: _compact(journal.worksCount),
                icon: Icons.article_rounded,
                color: AppColors.primary,
              ),
            ),
            const SizedBox(width: 8),
            Expanded(
              child: _MetricCard(
                title: 'Citations',
                value: _compact(journal.citedByCount),
                icon: Icons.format_quote_rounded,
                color: AppColors.success,
              ),
            ),
            const SizedBox(width: 8),
            Expanded(
              child: _MetricCard(
                title: 'Top Year',
                value: provider.mostActiveYear?.toString() ?? '-',
                icon: Icons.leaderboard_rounded,
                color: AppColors.gold,
              ),
            ),
          ],
        ),
        const SizedBox(height: 8),
        Row(
          children: [
            Expanded(
              child: _MetricCard(
                title: 'H-index',
                value: journal.hIndex?.toString() ?? '-',
                icon: Icons.insights_rounded,
                color: AppColors.info,
              ),
            ),
            const SizedBox(width: 8),
            Expanded(
              child: _MetricCard(
                title: 'i10-index',
                value: journal.i10Index?.toString() ?? '-',
                icon: Icons.stacked_bar_chart_rounded,
                color: AppColors.accent,
              ),
            ),
            const SizedBox(width: 8),
            Expanded(
              child: _MetricCard(
                title: '2yr Mean',
                value: journal.twoYearMeanCitedness?.toStringAsFixed(2) ?? '-',
                icon: Icons.trending_up_rounded,
                color: AppColors.success,
              ),
            ),
          ],
        ),
      ],
    );
  }
}

class _MetricCard extends StatelessWidget {
  final String title;
  final String value;
  final IconData icon;
  final Color color;

  const _MetricCard({
    required this.title,
    required this.value,
    required this.icon,
    required this.color,
  });

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;

    return Container(
      constraints: const BoxConstraints(minHeight: 94),
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 12),
      decoration: BoxDecoration(
        color: colorScheme.surface,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: colorScheme.outlineVariant),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(icon, color: color, size: 18),
          const SizedBox(height: 8),
          FittedBox(
            fit: BoxFit.scaleDown,
            alignment: Alignment.centerLeft,
            child: Text(
              value,
              style: Theme.of(context).textTheme.titleLarge?.copyWith(
                color: colorScheme.onSurface,
                fontWeight: FontWeight.w800,
              ),
            ),
          ),
          const SizedBox(height: 4),
          Text(
            title,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: Theme.of(context).textTheme.labelSmall?.copyWith(
              color: colorScheme.onSurfaceVariant,
              fontWeight: FontWeight.w700,
            ),
          ),
        ],
      ),
    );
  }
}

class _SectionHeader extends StatelessWidget {
  final IconData icon;
  final String title;

  const _SectionHeader({required this.icon, required this.title});

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;

    return Row(
      children: [
        Container(
          padding: const EdgeInsets.all(6),
          decoration: BoxDecoration(
            color: AppColors.primary.withValues(alpha: 0.10),
            borderRadius: BorderRadius.circular(8),
          ),
          child: Icon(icon, size: 16, color: AppColors.primary),
        ),
        const SizedBox(width: 10),
        Text(
          title,
          style: Theme.of(
            context,
          ).textTheme.titleMedium?.copyWith(color: colorScheme.onSurface),
        ),
      ],
    );
  }
}

class _TrendChartCard extends StatelessWidget {
  final JournalProvider provider;

  const _TrendChartCard({required this.provider});

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;

    return Container(
      height: 330,
      padding: const EdgeInsets.fromLTRB(12, 16, 12, 8),
      decoration: BoxDecoration(
        color: colorScheme.surface,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: colorScheme.outlineVariant),
      ),
      child: LayoutBuilder(
        builder: (context, constraints) {
          final minWidth = provider.sourceWorksByYear.length * 44.0;
          final chartWidth = minWidth > constraints.maxWidth
              ? minWidth
              : constraints.maxWidth;
          return SingleChildScrollView(
            scrollDirection: Axis.horizontal,
            child: SizedBox(
              width: chartWidth,
              child: TrendChart(
                data: provider.sourceWorksByYear,
                yearSort: PublicationYearSort.descending,
              ),
            ),
          );
        },
      ),
    );
  }
}

class _YearRankingCard extends StatelessWidget {
  final JournalProvider provider;

  const _YearRankingCard({required this.provider});

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;

    return Container(
      decoration: BoxDecoration(
        color: colorScheme.surface,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: colorScheme.outlineVariant),
      ),
      clipBehavior: Clip.antiAlias,
      child: YearRankingList(rankedYears: provider.yearsByWorkCount),
    );
  }
}

class _BarItem {
  final String label;
  final int value;
  final String valueLabel;

  const _BarItem({
    required this.label,
    required this.value,
    required this.valueLabel,
  });
}

class _HorizontalBarSection extends StatelessWidget {
  final String title;
  final IconData icon;
  final List<_BarItem> items;

  const _HorizontalBarSection({
    required this.title,
    required this.icon,
    required this.items,
  });

  @override
  Widget build(BuildContext context) {
    if (items.isEmpty) return const SizedBox.shrink();
    final colorScheme = Theme.of(context).colorScheme;
    final maxValue = items
        .map((item) => item.value)
        .fold<int>(0, (max, value) => value > max ? value : max);

    return Padding(
      padding: const EdgeInsets.only(bottom: 20),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _SectionHeader(icon: icon, title: title),
          const SizedBox(height: 12),
          Container(
            decoration: BoxDecoration(
              color: colorScheme.surface,
              borderRadius: BorderRadius.circular(16),
              border: Border.all(color: colorScheme.outlineVariant),
            ),
            child: Column(
              children: [
                for (var i = 0; i < items.length; i++) ...[
                  if (i > 0)
                    const Divider(height: 1, indent: 16, endIndent: 16),
                  _BarRow(item: items[i], rank: i + 1, maxValue: maxValue),
                ],
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _BarRow extends StatelessWidget {
  final _BarItem item;
  final int rank;
  final int maxValue;

  const _BarRow({
    required this.item,
    required this.rank,
    required this.maxValue,
  });

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    final ratio = maxValue == 0 ? 0.0 : item.value / maxValue;

    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 12, 16, 12),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              SizedBox(
                width: 26,
                child: Text(
                  '$rank',
                  style: TextStyle(
                    fontWeight: FontWeight.w700,
                    color: colorScheme.onSurfaceVariant,
                  ),
                ),
              ),
              Expanded(
                child: Text(
                  item.label,
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                  style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                    fontWeight: FontWeight.w600,
                    color: colorScheme.onSurface,
                  ),
                ),
              ),
              const SizedBox(width: 8),
              Text(
                item.valueLabel,
                style: Theme.of(context).textTheme.labelSmall?.copyWith(
                  color: AppColors.primary,
                  fontWeight: FontWeight.w700,
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),
          ClipRRect(
            borderRadius: BorderRadius.circular(6),
            child: LinearProgressIndicator(
              minHeight: 6,
              value: ratio,
              backgroundColor: AppColors.primary.withValues(alpha: 0.08),
              valueColor: const AlwaysStoppedAnimation<Color>(
                AppColors.primary,
              ),
            ),
          ),
        ],
      ),
    );
  }
}
