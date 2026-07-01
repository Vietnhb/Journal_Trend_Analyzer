import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../core/constants/app_colors.dart';
import '../../core/widgets/app_empty_view.dart';
import '../../core/widgets/app_error_view.dart';
import '../../core/widgets/app_loading.dart';
import '../../data/repositories/journal_repository.dart';
import '../providers/journal_provider.dart';
import 'analytics_entity_detail_screen.dart';

class JournalScreen extends StatelessWidget {
  const JournalScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final provider = context.watch<JournalProvider>();

    return Scaffold(
      body: SafeArea(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            _Header(provider: provider),
            Expanded(child: _JournalAnalysisBody(provider: provider)),
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

    return Padding(
      padding: const EdgeInsets.fromLTRB(20, 16, 20, 12),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'Journals',
            style: Theme.of(context).textTheme.headlineSmall?.copyWith(
              color: colorScheme.onSurface,
              fontWeight: FontWeight.w800,
            ),
          ),
          const SizedBox(height: 2),
          Text(
            provider.selectedKeyword.isEmpty
                ? 'Search a topic from Home first'
                : 'Journal-level analysis for "${provider.selectedKeyword}"',
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

class _JournalAnalysisBody extends StatelessWidget {
  final JournalProvider provider;

  const _JournalAnalysisBody({required this.provider});

  @override
  Widget build(BuildContext context) {
    if (provider.selectedKeyword.isEmpty) {
      return const AppEmptyView(
        message: 'Search a topic from Home first.',
        icon: Icons.book_outlined,
      );
    }

    if (provider.isLoadingAnalytics && provider.journals.isEmpty) {
      return const AppLoading(message: 'Loading journal analysis...');
    }

    final error = provider.analyticsError ?? provider.error;
    if (error != null && provider.journals.isEmpty) {
      return AppErrorView(
        error: error,
        onRetry: provider.refreshKeywordAnalytics,
      );
    }

    if (provider.journals.isEmpty) {
      return const AppEmptyView(
        message: 'No journals found for this topic.',
        icon: Icons.book_outlined,
      );
    }

    return RefreshIndicator(
      onRefresh: provider.refreshKeywordAnalytics,
      color: AppColors.primary,
      child: ListView(
        physics: const AlwaysScrollableScrollPhysics(),
        padding: const EdgeInsets.fromLTRB(16, 4, 16, 24),
        children: [
          _JournalMetricRow(provider: provider),
          const SizedBox(height: 24),
          const _SectionHeader(
            icon: Icons.stacked_bar_chart_rounded,
            title: 'Journal Contribution Chart',
          ),
          const SizedBox(height: 12),
          _JournalContributionCard(
            journals: provider.journals.take(10).toList(),
            onJournalSelected: (journal) =>
                _openJournalDetail(context, provider, journal),
          ),
        ],
      ),
    );
  }
}

class _JournalMetricRow extends StatelessWidget {
  final JournalProvider provider;

  const _JournalMetricRow({required this.provider});

  @override
  Widget build(BuildContext context) {
    final journals = provider.journals;
    final topJournal = journals.firstOrNull;
    final countedPublications = journals.fold<int>(
      0,
      (total, journal) => total + journal.worksCount,
    );

    return Row(
      children: [
        Expanded(
          child: _MetricCard(
            label: 'Ranked Journals',
            value: '${journals.length}',
            icon: Icons.book_rounded,
            color: AppColors.primary,
          ),
        ),
        const SizedBox(width: 8),
        Expanded(
          child: _MetricCard(
            label: 'Top Journal',
            value: topJournal?.name ?? '-',
            icon: Icons.workspace_premium_rounded,
            color: AppColors.gold,
          ),
        ),
        const SizedBox(width: 8),
        Expanded(
          child: _MetricCard(
            label: 'Articles in Top 10',
            value: '$countedPublications',
            icon: Icons.article_rounded,
            color: AppColors.success,
          ),
        ),
      ],
    );
  }
}

class _JournalContributionCard extends StatelessWidget {
  final List<RankedEntity> journals;
  final ValueChanged<RankedEntity> onJournalSelected;

  const _JournalContributionCard({
    required this.journals,
    required this.onJournalSelected,
  });

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    final maxCount = journals.fold<int>(
      0,
      (max, journal) => journal.worksCount > max ? journal.worksCount : max,
    );

    return Container(
      padding: const EdgeInsets.fromLTRB(14, 14, 14, 6),
      decoration: BoxDecoration(
        color: colorScheme.surface,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: colorScheme.outlineVariant),
      ),
      child: Column(
        children: [
          for (var index = 0; index < journals.length; index++)
            _JournalContributionRow(
              journal: journals[index],
              rank: index + 1,
              ratio: maxCount == 0 ? 0 : journals[index].worksCount / maxCount,
              onTap: () => onJournalSelected(journals[index]),
            ),
        ],
      ),
    );
  }
}

class _JournalContributionRow extends StatelessWidget {
  final RankedEntity journal;
  final int rank;
  final double ratio;
  final VoidCallback onTap;

  const _JournalContributionRow({
    required this.journal,
    required this.rank,
    required this.ratio,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;

    return InkWell(
      key: Key('journal_item_$rank'),
      onTap: onTap,
      borderRadius: BorderRadius.circular(10),
      child: Padding(
        padding: const EdgeInsets.only(bottom: 12),
        child: Column(
          children: [
            Row(
              children: [
                SizedBox(
                  width: 28,
                  child: Text(
                    '$rank',
                    style: TextStyle(
                      color: colorScheme.onSurfaceVariant,
                      fontWeight: FontWeight.w800,
                    ),
                  ),
                ),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        journal.name,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                          color: colorScheme.onSurface,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                      Text(
                        'View citation statistics',
                        style: Theme.of(context).textTheme.labelSmall?.copyWith(
                          color: colorScheme.onSurfaceVariant,
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(width: 8),
                Text(
                  '${journal.worksCount} articles',
                  style: Theme.of(context).textTheme.labelSmall?.copyWith(
                    color: AppColors.primary,
                    fontWeight: FontWeight.w800,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 8),
            ClipRRect(
              borderRadius: BorderRadius.circular(6),
              child: LinearProgressIndicator(
                minHeight: 7,
                value: ratio.clamp(0.0, 1.0),
                backgroundColor: AppColors.primary.withValues(alpha: 0.08),
                valueColor: const AlwaysStoppedAnimation<Color>(
                  AppColors.primary,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _MetricCard extends StatelessWidget {
  final String label;
  final String value;
  final IconData icon;
  final Color color;

  const _MetricCard({
    required this.label,
    required this.value,
    required this.icon,
    required this.color,
  });

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;

    return SizedBox(
      height: 102,
      child: Container(
        padding: const EdgeInsets.all(11),
        decoration: BoxDecoration(
          color: colorScheme.surface,
          borderRadius: BorderRadius.circular(14),
          border: Border.all(color: colorScheme.outlineVariant),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Icon(icon, size: 18, color: color),
            const SizedBox(height: 8),
            SizedBox(
              height: 20,
              width: double.infinity,
              child: FittedBox(
                fit: BoxFit.scaleDown,
                alignment: Alignment.centerLeft,
                child: Text(
                  value,
                  maxLines: 1,
                  style: Theme.of(context).textTheme.titleMedium?.copyWith(
                    color: colorScheme.onSurface,
                    fontWeight: FontWeight.w800,
                  ),
                ),
              ),
            ),
            const SizedBox(height: 4),
            Text(
              label,
              style: Theme.of(context).textTheme.labelSmall?.copyWith(
                color: colorScheme.onSurfaceVariant,
                fontWeight: FontWeight.w700,
              ),
            ),
          ],
        ),
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
        Expanded(
          child: Text(
            title,
            style: Theme.of(
              context,
            ).textTheme.titleMedium?.copyWith(color: colorScheme.onSurface),
          ),
        ),
      ],
    );
  }
}

void _openJournalDetail(
  BuildContext context,
  JournalProvider provider,
  RankedEntity journal,
) {
  Navigator.push(
    context,
    MaterialPageRoute(
      builder: (_) => AnalyticsEntityDetailScreen(
        type: AnalyticsEntityType.journal,
        entity: journal,
        keyword: provider.selectedKeyword,
        excludeFuturePublications: provider.filterFutureSourceYears,
      ),
    ),
  );
}
