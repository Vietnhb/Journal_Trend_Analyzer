import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../core/constants/app_colors.dart';
import '../../core/widgets/app_empty_view.dart';
import '../../core/widgets/app_error_view.dart';
import '../../core/widgets/app_loading.dart';
import '../../data/repositories/publication_repository.dart';
import '../providers/publication_provider.dart';
import '../trends/widgets/trend_chart.dart';
import '../trends/widgets/year_ranking_list.dart';
import 'publication_detail_screen.dart';
import 'top_entity_detail_screen.dart';

class KeywordsScreen extends StatelessWidget {
  const KeywordsScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final provider = context.watch<PublicationProvider>();

    return Scaffold(
      body: SafeArea(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            _buildHeader(context),
            Expanded(child: _KeywordsBody(provider: provider)),
          ],
        ),
      ),
    );
  }

  Widget _buildHeader(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;

    return Container(
      padding: const EdgeInsets.fromLTRB(20, 16, 20, 12),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'Analytics',
            style: Theme.of(context).textTheme.headlineSmall?.copyWith(
              color: colorScheme.onSurface,
              fontWeight: FontWeight.w800,
            ),
          ),
          const SizedBox(height: 2),
          Text(
            'Publication trends & rankings',
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

class _KeywordsBody extends StatelessWidget {
  final PublicationProvider provider;

  const _KeywordsBody({required this.provider});

  @override
  Widget build(BuildContext context) {
    if (!provider.hasSearched) {
      return const AppEmptyView(
        message:
            'Search by title, abstract, author, journal, or DOI\nfrom Home to view trends and rankings.',
        icon: Icons.query_stats_outlined,
      );
    }

    if (provider.isLoading && provider.analysisPublications.isEmpty) {
      return const AppLoading(message: 'Building publication analysis...');
    }

    final error = provider.error;
    if (error != null && provider.analysisPublications.isEmpty) {
      return AppErrorView(error: error);
    }

    if (provider.publicationsByYear.isEmpty) {
      return const AppEmptyView(
        message: 'The loaded publications do not include publication years.',
        icon: Icons.event_busy_outlined,
      );
    }

    return RefreshIndicator(
      onRefresh: () => provider.search(provider.query),
      color: AppColors.primary,
      child: ListView(
        physics: const AlwaysScrollableScrollPhysics(),
        padding: const EdgeInsets.fromLTRB(16, 4, 16, 24),
        children: [
          // Query badge
          _QueryBadge(query: provider.query),
          const SizedBox(height: 16),

          // Metric cards row
          _MetricRow(provider: provider),

          // Analytics loading / error banner
          if (provider.isLoadingAnalytics) ...[
            const SizedBox(height: 12),
            _AnalyticsBanner(isLoading: true),
          ] else if (provider.analyticsError != null) ...[
            const SizedBox(height: 12),
            _AnalyticsBanner(
              isLoading: false,
              errorMessage: provider.analyticsError!.message,
            ),
          ],

          const SizedBox(height: 24),

          // Publication Trend chart
          _SectionHeader(
            icon: Icons.bar_chart_rounded,
            title: 'Publication Trend',
          ),
          const SizedBox(height: 12),
          _TrendChartCard(provider: provider),

          const SizedBox(height: 24),

          // Year Ranking
          _SectionHeader(
            icon: Icons.leaderboard_rounded,
            title: 'Year Ranking',
          ),
          const SizedBox(height: 12),
          _YearRankingCard(provider: provider),

          const SizedBox(height: 24),

          // Top Influential Papers
          _HorizontalBarSection(
            title: 'Top Influential Papers',
            icon: Icons.auto_stories_rounded,
            items: provider.topPapers
                .map(
                  (paper) => _BarItem(
                    label: paper.title,
                    details:
                        '${paper.year ?? 'No year'} · ${paper.journalName}',
                    value: paper.citationCount,
                    valueLabel: '${paper.citationCount} citations',
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

          // Top Journals
          _HorizontalBarSection(
            title: 'Top Journals',
            icon: Icons.book_outlined,
            items: provider.topJournals
                .map(
                  (entry) => _BarItem(
                    label: entry.name,
                    value: entry.worksCount,
                    valueLabel: '${entry.worksCount} pubs',
                    onTap: () => Navigator.push(
                      context,
                      MaterialPageRoute(
                        builder: (_) => TopEntityDetailScreen(
                          type: TopEntityType.journal,
                          entityId: entry.id,
                          name: entry.name,
                          worksCount: entry.worksCount,
                          topic: provider.query,
                        ),
                      ),
                    ),
                  ),
                )
                .toList(),
          ),

          // Top Authors
          _HorizontalBarSection(
            title: 'Top Authors',
            icon: Icons.group_outlined,
            items: provider.topAuthors
                .map(
                  (entry) => _BarItem(
                    label: entry.name,
                    value: entry.worksCount,
                    valueLabel: '${entry.worksCount} pubs',
                    onTap: () => Navigator.push(
                      context,
                      MaterialPageRoute(
                        builder: (_) => TopEntityDetailScreen(
                          type: TopEntityType.author,
                          entityId: entry.id,
                          name: entry.name,
                          worksCount: entry.worksCount,
                          topic: provider.query,
                        ),
                      ),
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

// ──────────────────────────────────────────────────────────────
// Small helper widgets
// ──────────────────────────────────────────────────────────────

class _QueryBadge extends StatelessWidget {
  final String query;
  const _QueryBadge({required this.query});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
      decoration: BoxDecoration(
        color: AppColors.primary.withValues(alpha: 0.08),
        borderRadius: BorderRadius.circular(10),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          const Icon(Icons.search_rounded, size: 14, color: AppColors.primary),
          const SizedBox(width: 6),
          Flexible(
            child: Text(
              '"$query"',
              style: Theme.of(context).textTheme.labelMedium?.copyWith(
                color: AppColors.primary,
                fontWeight: FontWeight.w600,
              ),
              overflow: TextOverflow.ellipsis,
            ),
          ),
        ],
      ),
    );
  }
}

class _MetricRow extends StatelessWidget {
  final PublicationProvider provider;
  const _MetricRow({required this.provider});

  String _formatCitations(int count) {
    if (count >= 1000000) return '${(count / 1000000).toStringAsFixed(1)}M';
    if (count >= 1000) return '${(count / 1000).toStringAsFixed(1)}K';
    return count.toString();
  }

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Expanded(
          child: _MetricCard(
            title: 'Publications',
            value: provider.totalPublications.toString(),
            icon: Icons.article_rounded,
            color: AppColors.primary,
          ),
        ),
        const SizedBox(width: 8),
        Expanded(
          child: _MetricCard(
            title: 'Top Year',
            value: provider.mostActiveYear?.toString() ?? '—',
            icon: Icons.leaderboard_rounded,
            color: AppColors.gold,
          ),
        ),
        const SizedBox(width: 8),
        Expanded(
          child: _MetricCard(
            title: 'Avg Citations',
            subtitle: 'Across topic',
            value: provider.avgCitationCount != null
                ? _formatCitations(provider.avgCitationCount!)
                : '—',
            icon: Icons.trending_up_rounded,
            color: AppColors.success,
          ),
        ),
      ],
    );
  }
}

class _MetricCard extends StatelessWidget {
  final String title;
  final String? subtitle;
  final String value;
  final IconData icon;
  final Color color;

  const _MetricCard({
    required this.title,
    this.subtitle,
    required this.value,
    required this.icon,
    required this.color,
  });

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;

    return Container(
      constraints: const BoxConstraints(minHeight: 106),
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 12),
      decoration: BoxDecoration(
        color: colorScheme.surface,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: colorScheme.outlineVariant),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(
              alpha: Theme.of(context).brightness == Brightness.dark
                  ? 0.18
                  : 0.03,
            ),
            blurRadius: 6,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                width: 26,
                height: 26,
                decoration: BoxDecoration(
                  color: color.withValues(alpha: 0.12),
                  borderRadius: BorderRadius.circular(8),
                ),
                alignment: Alignment.center,
                child: Icon(icon, color: color, size: 15),
              ),
              const Spacer(),
            ],
          ),
          const SizedBox(height: 8),
          SizedBox(
            height: 26,
            child: FittedBox(
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
          ),
          const SizedBox(height: 4),
          SizedBox(
            height: 30,
            child: FittedBox(
              fit: BoxFit.scaleDown,
              alignment: Alignment.centerLeft,
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    title,
                    maxLines: 1,
                    style: Theme.of(context).textTheme.labelSmall?.copyWith(
                      color: colorScheme.onSurfaceVariant,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                  if (subtitle != null)
                    Text(
                      subtitle!,
                      maxLines: 1,
                      style: Theme.of(context).textTheme.labelSmall?.copyWith(
                        color: colorScheme.onSurfaceVariant.withValues(
                          alpha: 0.72,
                        ),
                        fontSize: 10,
                      ),
                    ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _AnalyticsBanner extends StatelessWidget {
  final bool isLoading;
  final String? errorMessage;

  const _AnalyticsBanner({required this.isLoading, this.errorMessage});

  @override
  Widget build(BuildContext context) {
    if (isLoading) {
      return Container(
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
        decoration: BoxDecoration(
          color: AppColors.info.withValues(alpha: 0.08),
          borderRadius: BorderRadius.circular(10),
          border: Border.all(color: AppColors.info.withValues(alpha: 0.2)),
        ),
        child: Row(
          children: [
            SizedBox(
              width: 14,
              height: 14,
              child: CircularProgressIndicator(
                strokeWidth: 2,
                color: AppColors.info,
              ),
            ),
            const SizedBox(width: 10),
            Expanded(
              child: Text(
                'Loading full OpenAlex analytics...',
                style: Theme.of(
                  context,
                ).textTheme.bodySmall?.copyWith(color: AppColors.info),
              ),
            ),
          ],
        ),
      );
    }
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
      decoration: BoxDecoration(
        color: AppColors.danger.withValues(alpha: 0.08),
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: AppColors.danger.withValues(alpha: 0.2)),
      ),
      child: Row(
        children: [
          const Icon(
            Icons.error_outline_rounded,
            size: 16,
            color: AppColors.danger,
          ),
          const SizedBox(width: 8),
          Expanded(
            child: Text(
              errorMessage ?? 'Analytics unavailable.',
              style: Theme.of(
                context,
              ).textTheme.bodySmall?.copyWith(color: AppColors.danger),
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
  final PublicationProvider provider;
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
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(
              alpha: Theme.of(context).brightness == Brightness.dark
                  ? 0.18
                  : 0.04,
            ),
            blurRadius: 8,
            offset: const Offset(0, 2),
          ),
        ],
      ),
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
    );
  }
}

class _YearRankingCard extends StatelessWidget {
  final PublicationProvider provider;
  const _YearRankingCard({required this.provider});

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;

    return Container(
      decoration: BoxDecoration(
        color: colorScheme.surface,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: colorScheme.outlineVariant),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(
              alpha: Theme.of(context).brightness == Brightness.dark
                  ? 0.18
                  : 0.04,
            ),
            blurRadius: 8,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      clipBehavior: Clip.antiAlias,
      child: YearRankingList(rankedYears: provider.yearsByPublicationCount),
    );
  }
}

// ──────────────────────────────────────────────────────────────
// Horizontal bar section
// ──────────────────────────────────────────────────────────────

class _BarItem {
  final String label;
  final String? details;
  final int value;
  final String valueLabel;
  final VoidCallback? onTap;

  const _BarItem({
    required this.label,
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
        .map((e) => e.value)
        .fold<int>(0, (max, v) => v > max ? v : max);

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
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withValues(
                    alpha: Theme.of(context).brightness == Brightness.dark
                        ? 0.18
                        : 0.04,
                  ),
                  blurRadius: 8,
                  offset: const Offset(0, 2),
                ),
              ],
            ),
            child: Column(
              children: [
                for (int i = 0; i < items.length; i++) ...[
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
    final ratio = maxValue == 0 ? 0.0 : item.value / maxValue;
    final colorScheme = Theme.of(context).colorScheme;

    Widget content = Padding(
      padding: const EdgeInsets.fromLTRB(16, 12, 16, 12),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Rank badge
              Container(
                width: 24,
                height: 24,
                alignment: Alignment.center,
                decoration: BoxDecoration(
                  color: rank == 1
                      ? AppColors.gold.withValues(alpha: 0.15)
                      : colorScheme.surfaceContainerHighest,
                  borderRadius: BorderRadius.circular(6),
                ),
                child: Text(
                  '$rank',
                  style: TextStyle(
                    fontSize: 11,
                    fontWeight: FontWeight.w700,
                    color: rank == 1
                        ? AppColors.gold
                        : colorScheme.onSurfaceVariant,
                  ),
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      item.label,
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                      style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                        fontWeight: FontWeight.w600,
                        color: colorScheme.onSurface,
                      ),
                    ),
                    if (item.details != null)
                      Text(
                        item.details!,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: Theme.of(context).textTheme.bodySmall?.copyWith(
                          color: colorScheme.onSurfaceVariant,
                        ),
                      ),
                  ],
                ),
              ),
              const SizedBox(width: 8),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                decoration: BoxDecoration(
                  color: AppColors.primary.withValues(alpha: 0.1),
                  borderRadius: BorderRadius.circular(20),
                ),
                child: Text(
                  item.valueLabel,
                  style: Theme.of(context).textTheme.labelSmall?.copyWith(
                    color: AppColors.primary,
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ),
              if (item.onTap != null) ...[
                const SizedBox(width: 4),
                const Icon(
                  Icons.arrow_forward_ios_rounded,
                  size: 11,
                  color: AppColors.textHint,
                ),
              ],
            ],
          ),
          const SizedBox(height: 8),
          ClipRRect(
            borderRadius: BorderRadius.circular(6),
            child: LinearProgressIndicator(
              minHeight: 6,
              value: ratio,
              backgroundColor: AppColors.primary.withValues(alpha: 0.08),
              valueColor: AlwaysStoppedAnimation<Color>(
                rank == 1 ? AppColors.gold : AppColors.primary,
              ),
            ),
          ),
        ],
      ),
    );

    if (item.onTap != null) {
      return InkWell(onTap: item.onTap, child: content);
    }
    return content;
  }
}
