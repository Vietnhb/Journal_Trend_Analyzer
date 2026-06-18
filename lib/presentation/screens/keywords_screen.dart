import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../core/constants/app_colors.dart';
import '../../core/widgets/app_empty_view.dart';
import '../../core/widgets/app_error_view.dart';
import '../../core/widgets/app_loading.dart';
import '../../core/widgets/app_markup_text.dart';
import '../../data/repositories/journal_repository.dart';
import '../providers/journal_provider.dart';
import '../trends/widgets/trend_chart.dart';
import '../trends/widgets/year_ranking_list.dart';
import 'analytics_entity_detail_screen.dart';
import 'publication_detail_screen.dart';

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
            Expanded(child: _TopicAnalyticsBody(provider: provider)),
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
            'Keyword Analytics',
            style: Theme.of(context).textTheme.headlineSmall?.copyWith(
              color: colorScheme.onSurface,
              fontWeight: FontWeight.w800,
            ),
          ),
          const SizedBox(height: 2),
          Text(
            provider.selectedKeyword.isEmpty
                ? 'Search a keyword from Home to view analytics'
                : '"${provider.selectedKeyword}" across all journals',
            style: Theme.of(context).textTheme.bodySmall?.copyWith(
              color: colorScheme.onSurfaceVariant,
            ),
          ),
          const SizedBox(height: 12),
          const Divider(height: 1),
        ],
      ),
    );
  }
}

class _TopicAnalyticsBody extends StatelessWidget {
  final JournalProvider provider;

  const _TopicAnalyticsBody({required this.provider});

  @override
  Widget build(BuildContext context) {
    if (provider.selectedKeyword.isEmpty) {
      return const AppEmptyView(
        message: 'Search a keyword from Home first.',
        icon: Icons.query_stats_outlined,
      );
    }

    if (provider.isLoadingAnalytics) {
      return const AppLoading(
        message: 'Loading analytics across all journals...',
      );
    }

    final error = provider.analyticsError;
    if (error != null) {
      return AppErrorView(
        error: error,
        onRetry: provider.refreshKeywordAnalytics,
      );
    }

    return RefreshIndicator(
      onRefresh: provider.refreshKeywordAnalytics,
      color: AppColors.primary,
      child: ListView(
        physics: const AlwaysScrollableScrollPhysics(),
        padding: const EdgeInsets.fromLTRB(16, 4, 16, 24),
        children: [
          _QueryBadge(keyword: provider.selectedKeyword),
          const SizedBox(height: 16),
          _MetricRow(provider: provider),
          const SizedBox(height: 24),
          _AnalyticsHighlights(provider: provider),
          const SizedBox(height: 24),
          if (provider.sourceWorksByYear.isNotEmpty) ...[
            _SectionHeader(
              icon: Icons.bar_chart_rounded,
              title: 'Publication Trend',
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
            title: 'Top Journals',
            icon: Icons.book_outlined,
            items: provider.journals
                .map(
                  (journal) => _BarItem(
                    label: journal.name,
                    value: journal.worksCount,
                    valueLabel: '${journal.worksCount} articles',
                    onTap: () => _openEntityAnalytics(
                      context,
                      provider,
                      AnalyticsEntityType.journal,
                      journal,
                    ),
                  ),
                )
                .toList(),
          ),
          _HorizontalBarSection(
            title: 'Top Influential Papers',
            icon: Icons.auto_stories_rounded,
            items: provider.topPapers
                .map(
                  (paper) => _BarItem(
                    label: paper.title,
                    markup: paper.titleMarkup,
                    details:
                        '${paper.year ?? 'No year'} · ${paper.citationCount} citations',
                    value: paper.citationCount,
                    valueLabel: '${paper.citationCount} cites',
                    onTap: () => Navigator.push(
                      context,
                      MaterialPageRoute(
                        builder: (_) =>
                            PublicationDetailScreen(publication: paper),
                      ),
                    ),
                  ),
                )
                .toList(),
          ),
          _HorizontalBarSection(
            title: 'Top Authors',
            icon: Icons.group_outlined,
            items: provider.topAuthors
                .map(
                  (author) => _BarItem(
                    label: author.name,
                    value: author.worksCount,
                    valueLabel: '${author.worksCount} articles',
                    onTap: () => _openEntityAnalytics(
                      context,
                      provider,
                      AnalyticsEntityType.author,
                      author,
                    ),
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
  final String keyword;

  const _QueryBadge({required this.keyword});

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
          _BadgeLine(icon: Icons.search_rounded, text: 'Keyword: $keyword'),
          const SizedBox(height: 4),
          const _BadgeLine(
            icon: Icons.library_books_outlined,
            text: 'Scope: all related journals',
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
          ),
        ),
      ],
    );
  }
}

class _MetricRow extends StatelessWidget {
  final JournalProvider provider;

  const _MetricRow({required this.provider});

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Expanded(
          child: _MetricCard(
            title: 'Total Publications',
            value: '${provider.totalWorks}',
            icon: Icons.article_rounded,
            color: AppColors.primary,
          ),
        ),
        const SizedBox(width: 8),
        Expanded(
          child: _MetricCard(
            title: 'Avg Citations',
            value: provider.avgCitationCount?.toString() ?? '-',
            icon: Icons.format_quote_rounded,
            color: AppColors.success,
          ),
        ),
        const SizedBox(width: 8),
        Expanded(
          child: _MetricCard(
            title: 'Most Active Year',
            value: provider.mostActiveYear?.toString() ?? '-',
            icon: Icons.leaderboard_rounded,
            color: AppColors.gold,
          ),
        ),
      ],
    );
  }
}

class _AnalyticsHighlights extends StatelessWidget {
  final JournalProvider provider;

  const _AnalyticsHighlights({required this.provider});

  @override
  Widget build(BuildContext context) {
    final paper = provider.mostInfluentialPaper;
    final journal = provider.journals.firstOrNull;
    final author = provider.topAuthors.firstOrNull;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const _SectionHeader(
          icon: Icons.insights_rounded,
          title: 'Analytics Highlights',
        ),
        const SizedBox(height: 12),
        _HighlightCard(
          children: [
            _HighlightRow(
              icon: Icons.book_outlined,
              label: 'Top Journal',
              value: provider.topJournal ?? '-',
              onTap: journal == null
                  ? null
                  : () => _openEntityAnalytics(
                      context,
                      provider,
                      AnalyticsEntityType.journal,
                      journal,
                    ),
            ),
            const Divider(height: 1),
            _HighlightRow(
              icon: Icons.person_outline_rounded,
              label: 'Top Author',
              value: provider.topAuthor ?? '-',
              onTap: author == null
                  ? null
                  : () => _openEntityAnalytics(
                      context,
                      provider,
                      AnalyticsEntityType.author,
                      author,
                    ),
            ),
            const Divider(height: 1),
            _HighlightRow(
              icon: Icons.auto_stories_outlined,
              label: 'Most Influential Paper',
              value: paper?.title ?? '-',
              markup: paper?.titleMarkup,
              onTap: paper == null
                  ? null
                  : () => Navigator.push(
                      context,
                      MaterialPageRoute(
                        builder: (_) =>
                            PublicationDetailScreen(publication: paper),
                      ),
                    ),
            ),
          ],
        ),
      ],
    );
  }
}

void _openEntityAnalytics(
  BuildContext context,
  JournalProvider provider,
  AnalyticsEntityType type,
  RankedEntity entity,
) {
  Navigator.push(
    context,
    MaterialPageRoute(
      builder: (_) => AnalyticsEntityDetailScreen(
        type: type,
        entity: entity,
        keyword: provider.selectedKeyword,
        excludeFuturePublications: provider.filterFutureSourceYears,
      ),
    ),
  );
}

class _HighlightCard extends StatelessWidget {
  final List<Widget> children;

  const _HighlightCard({required this.children});

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
      child: Column(children: children),
    );
  }
}

class _HighlightRow extends StatelessWidget {
  final IconData icon;
  final String label;
  final String value;
  final String? markup;
  final VoidCallback? onTap;

  const _HighlightRow({
    required this.icon,
    required this.label,
    required this.value,
    this.markup,
    this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    final content = Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 13),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(icon, size: 18, color: AppColors.primary),
          const SizedBox(width: 10),
          SizedBox(
            width: 112,
            child: Text(
              label,
              style: Theme.of(context).textTheme.bodySmall?.copyWith(
                color: colorScheme.onSurfaceVariant,
                fontWeight: FontWeight.w600,
              ),
            ),
          ),
          const SizedBox(width: 8),
          Expanded(
            child: AppMarkupText(
              markup ?? value,
              style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                color: colorScheme.onSurface,
                fontWeight: FontWeight.w700,
              ),
            ),
          ),
          if (onTap != null)
            Icon(
              Icons.chevron_right_rounded,
              color: colorScheme.onSurfaceVariant,
            ),
        ],
      ),
    );

    return onTap == null ? content : InkWell(onTap: onTap, child: content);
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
  final String? markup;
  final String? details;
  final int value;
  final String valueLabel;
  final VoidCallback? onTap;

  const _BarItem({
    required this.label,
    this.markup,
    this.details,
    required this.value,
    required this.valueLabel,
    this.onTap,
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

    final content = Padding(
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
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    AppMarkupText(
                      item.markup ?? item.label,
                      style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                        fontWeight: FontWeight.w600,
                        color: colorScheme.onSurface,
                      ),
                    ),
                    if (item.details != null)
                      Text(
                        item.details!,
                        style: Theme.of(context).textTheme.bodySmall?.copyWith(
                          color: colorScheme.onSurfaceVariant,
                        ),
                      ),
                  ],
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
    if (item.onTap == null) return content;
    return InkWell(onTap: item.onTap, child: content);
  }
}
