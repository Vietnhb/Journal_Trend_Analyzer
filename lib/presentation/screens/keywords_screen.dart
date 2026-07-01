import 'dart:async';

import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../core/constants/app_colors.dart';
import '../../core/errors/app_errors.dart';
import '../../core/widgets/app_empty_view.dart';
import '../../core/widgets/app_error_view.dart';
import '../../core/widgets/app_loading.dart';
import '../../core/widgets/app_markup_text.dart';
import '../../data/repositories/journal_repository.dart';
import '../../data/services/firebase_service.dart';
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
            Expanded(child: _KeywordListBody(provider: provider)),
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
            'Keywords',
            style: Theme.of(context).textTheme.headlineSmall?.copyWith(
              color: colorScheme.onSurface,
              fontWeight: FontWeight.w800,
            ),
          ),
          const SizedBox(height: 2),
          Text(
            provider.selectedKeyword.isEmpty
                ? 'Search a research topic from Home first'
                : 'Keywords inside "${provider.selectedKeyword}"',
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

class _KeywordListBody extends StatelessWidget {
  final JournalProvider provider;

  const _KeywordListBody({required this.provider});

  @override
  Widget build(BuildContext context) {
    if (provider.selectedKeyword.isEmpty) {
      return const AppEmptyView(
        message: 'Search a research topic from Home first.',
        icon: Icons.key_outlined,
      );
    }

    if (provider.isLoadingTrendingKeywords &&
        provider.trendingKeywords.isEmpty) {
      return const AppLoading(message: 'Loading keywords...');
    }

    final error = provider.trendingKeywordError;
    if (error != null && provider.trendingKeywords.isEmpty) {
      return AppErrorView(
        error: error,
        onRetry: () => provider.loadTrendingKeywords(force: true),
      );
    }

    if (provider.trendingKeywords.isEmpty) {
      return const AppEmptyView(
        message: 'No keywords found inside the selected topic.',
        icon: Icons.key_outlined,
      );
    }

    return RefreshIndicator(
      onRefresh: () => provider.loadTrendingKeywords(force: true),
      color: AppColors.primary,
      child: ListView(
        physics: const AlwaysScrollableScrollPhysics(),
        padding: const EdgeInsets.fromLTRB(16, 4, 16, 24),
        children: [
          const _SectionHeader(
            icon: Icons.trending_up_rounded,
            title: 'Most Frequent & Trending Keywords',
          ),
          const SizedBox(height: 4),
          Text(
            'Most frequent keywords in recent publications for '
            '"${provider.selectedKeyword}".',
            style: Theme.of(context).textTheme.bodySmall?.copyWith(
              color: Theme.of(context).colorScheme.onSurfaceVariant,
            ),
          ),
          const SizedBox(height: 12),
          _KeywordRankingCard(
            keywords: provider.trendingKeywords,
            onSelected: (keyword) => _openKeywordDetail(
              context,
              keyword.name,
              provider.selectedKeyword,
              provider.filterFutureSourceYears,
            ),
          ),
        ],
      ),
    );
  }
}

class _KeywordRankingCard extends StatelessWidget {
  final List<RankedEntity> keywords;
  final ValueChanged<RankedEntity> onSelected;

  const _KeywordRankingCard({required this.keywords, required this.onSelected});

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    final maxCount = keywords.fold<int>(
      0,
      (max, keyword) => keyword.worksCount > max ? keyword.worksCount : max,
    );

    return Container(
      decoration: BoxDecoration(
        color: colorScheme.surface,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: colorScheme.outlineVariant),
      ),
      clipBehavior: Clip.antiAlias,
      child: Column(
        children: [
          for (var index = 0; index < keywords.length; index++) ...[
            if (index > 0) const Divider(height: 1, indent: 16, endIndent: 16),
            _KeywordRow(
              keyword: keywords[index],
              rank: index + 1,
              maxCount: maxCount,
              onTap: () => onSelected(keywords[index]),
            ),
          ],
        ],
      ),
    );
  }
}

class _KeywordRow extends StatelessWidget {
  final RankedEntity keyword;
  final int rank;
  final int maxCount;
  final VoidCallback onTap;

  const _KeywordRow({
    required this.keyword,
    required this.rank,
    required this.maxCount,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    final ratio = maxCount == 0 ? 0.0 : keyword.worksCount / maxCount;

    return InkWell(
      key: Key('keyword_item_$rank'),
      onTap: onTap,
      child: Padding(
        padding: const EdgeInsets.fromLTRB(14, 12, 14, 12),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Container(
              width: 28,
              height: 28,
              alignment: Alignment.center,
              decoration: BoxDecoration(
                color: AppColors.primary.withValues(alpha: 0.10),
                borderRadius: BorderRadius.circular(8),
              ),
              child: Text(
                '$rank',
                style: Theme.of(context).textTheme.labelMedium?.copyWith(
                  color: AppColors.primary,
                  fontWeight: FontWeight.w800,
                ),
              ),
            ),
            const SizedBox(width: 10),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    keyword.name,
                    style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                      color: colorScheme.onSurface,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                  const SizedBox(height: 5),
                  ClipRRect(
                    borderRadius: BorderRadius.circular(5),
                    child: LinearProgressIndicator(
                      minHeight: 5,
                      value: ratio,
                      backgroundColor: AppColors.primary.withValues(
                        alpha: 0.08,
                      ),
                      valueColor: const AlwaysStoppedAnimation<Color>(
                        AppColors.primary,
                      ),
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(width: 10),
            Text(
              '${_compactCount(keyword.worksCount)} pubs',
              style: Theme.of(context).textTheme.labelSmall?.copyWith(
                color: AppColors.primary,
                fontWeight: FontWeight.w700,
              ),
            ),
            Icon(
              Icons.chevron_right_rounded,
              size: 20,
              color: colorScheme.onSurfaceVariant,
            ),
          ],
        ),
      ),
    );
  }
}

class KeywordDetailScreen extends StatefulWidget {
  final String keyword;
  final String parentTopic;
  final bool excludeFuturePublications;

  const KeywordDetailScreen({
    super.key,
    required this.keyword,
    required this.parentTopic,
    required this.excludeFuturePublications,
  });

  @override
  State<KeywordDetailScreen> createState() => _KeywordDetailScreenState();
}

class _KeywordDetailScreenState extends State<KeywordDetailScreen> {
  final JournalRepository _repository = JournalRepository();

  bool _isLoading = true;
  AppError? _error;
  List<RankedEntity> _journals = const [];
  List<Publication> _publications = const [];
  List<RankedEntity> _authors = const [];
  Map<int, int> _publicationsByYear = const {};

  @override
  void initState() {
    super.initState();
    unawaited(
      FirebaseService.instance.logEvent(
        'view_keyword',
        parameters: {'keyword': widget.keyword},
      ),
    );
    _load();
  }

  @override
  void dispose() {
    _repository.dispose();
    super.dispose();
  }

  Future<void> _load() async {
    setState(() {
      _isLoading = true;
      _error = null;
    });

    try {
      final journalsFuture = _repository.getTopJournalsByKeyword(
        widget.keyword,
        excludeFuturePublications: widget.excludeFuturePublications,
      );
      final publicationsFuture = _repository.getTopPapersByKeyword(
        widget.keyword,
        excludeFuturePublications: widget.excludeFuturePublications,
      );
      final authorsFuture = _repository.getTopAuthorsByKeyword(
        widget.keyword,
        excludeFuturePublications: widget.excludeFuturePublications,
      );
      final publicationTrendFuture = _repository.getPublicationTrendByKeyword(
        widget.keyword,
        excludeFuturePublications: widget.excludeFuturePublications,
      );

      late List<RankedEntity> journals;
      late List<Publication> publications;
      late List<RankedEntity> authors;
      late Map<int, int> publicationsByYear;
      await Future.wait<void>([
        journalsFuture.then((value) => journals = value),
        publicationsFuture.then((value) => publications = value),
        authorsFuture.then((value) => authors = value),
        publicationTrendFuture.then((value) => publicationsByYear = value),
      ]);

      if (!mounted) return;
      setState(() {
        _journals = journals;
        _publications = publications;
        _authors = authors;
        _publicationsByYear = publicationsByYear;
      });
    } on AppError catch (error) {
      if (mounted) setState(() => _error = error);
    } catch (error) {
      if (mounted) {
        setState(() {
          _error = AppError(
            'Could not load keyword analysis.',
            details: error.toString(),
          );
        });
      }
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Keyword Detail')),
      body: _isLoading
          ? const AppLoading(message: 'Loading keyword analysis...')
          : _error != null
          ? AppErrorView(error: _error!, onRetry: _load)
          : RefreshIndicator(
              onRefresh: _load,
              color: AppColors.primary,
              child: ListView(
                physics: const AlwaysScrollableScrollPhysics(),
                padding: const EdgeInsets.fromLTRB(16, 12, 16, 24),
                children: [
                  Text(
                    widget.keyword,
                    style: Theme.of(context).textTheme.titleLarge?.copyWith(
                      fontWeight: FontWeight.w800,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    'Analysis within "${widget.parentTopic}"',
                    style: Theme.of(context).textTheme.bodySmall?.copyWith(
                      color: Theme.of(context).colorScheme.onSurfaceVariant,
                    ),
                  ),
                  const SizedBox(height: 20),
                  if (_publicationsByYear.isNotEmpty) ...[
                    const _SectionHeader(
                      icon: Icons.bar_chart_rounded,
                      title: 'Publication Trend',
                    ),
                    const SizedBox(height: 12),
                    _TrendChartCard(data: _publicationsByYear),
                    const SizedBox(height: 24),
                    const _SectionHeader(
                      icon: Icons.leaderboard_rounded,
                      title: 'Year Ranking',
                    ),
                    const SizedBox(height: 12),
                    _YearRankingCard(data: _publicationsByYear),
                    const SizedBox(height: 24),
                  ],
                  _HorizontalBarSection(
                    title: 'Related Journals',
                    icon: Icons.book_outlined,
                    items: _journals
                        .map(
                          (journal) => _BarItem(
                            label: journal.name,
                            value: journal.worksCount,
                            valueLabel: '${journal.worksCount} articles',
                            onTap: () => _openEntityAnalytics(
                              context,
                              widget.keyword,
                              widget.excludeFuturePublications,
                              AnalyticsEntityType.journal,
                              journal,
                            ),
                          ),
                        )
                        .toList(),
                  ),
                  _HorizontalBarSection(
                    title: 'Related Publications',
                    icon: Icons.auto_stories_outlined,
                    items: _publications
                        .map(
                          (paper) => _BarItem(
                            label: paper.title,
                            markup: paper.titleMarkup,
                            details:
                                '${paper.year ?? 'No year'} - ${paper.journalName}',
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
                    items: _authors
                        .map(
                          (author) => _BarItem(
                            label: author.name,
                            value: author.worksCount,
                            valueLabel: '${author.worksCount} articles',
                            onTap: () => _openEntityAnalytics(
                              context,
                              widget.keyword,
                              widget.excludeFuturePublications,
                              AnalyticsEntityType.author,
                              author,
                            ),
                          ),
                        )
                        .toList(),
                  ),
                ],
              ),
            ),
    );
  }
}

void _openKeywordDetail(
  BuildContext context,
  String keyword,
  String parentTopic,
  bool excludeFuturePublications,
) {
  Navigator.push(
    context,
    MaterialPageRoute(
      builder: (_) => KeywordDetailScreen(
        keyword: keyword,
        parentTopic: parentTopic,
        excludeFuturePublications: excludeFuturePublications,
      ),
    ),
  );
}

void _openEntityAnalytics(
  BuildContext context,
  String keyword,
  bool excludeFuturePublications,
  AnalyticsEntityType type,
  RankedEntity entity,
) {
  Navigator.push(
    context,
    MaterialPageRoute(
      builder: (_) => AnalyticsEntityDetailScreen(
        type: type,
        entity: entity,
        keyword: keyword,
        excludeFuturePublications: excludeFuturePublications,
      ),
    ),
  );
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

String _compactCount(int value) {
  if (value >= 1000000) {
    return '${(value / 1000000).toStringAsFixed(1)}M';
  }
  if (value >= 1000) {
    return '${(value / 1000).toStringAsFixed(1)}K';
  }
  return '$value';
}

class _TrendChartCard extends StatelessWidget {
  final Map<int, int> data;

  const _TrendChartCard({required this.data});

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
          final minWidth = data.length * 44.0;
          final chartWidth = minWidth > constraints.maxWidth
              ? minWidth
              : constraints.maxWidth;
          return SingleChildScrollView(
            scrollDirection: Axis.horizontal,
            child: SizedBox(
              width: chartWidth,
              child: TrendChart(
                data: data,
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
  final Map<int, int> data;

  const _YearRankingCard({required this.data});

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
      child: YearRankingList(rankedYears: _rankedYears(data)),
    );
  }

  List<MapEntry<int, int>> _rankedYears(Map<int, int> values) {
    final entries = values.entries.toList()
      ..sort((a, b) {
        final countCompare = b.value.compareTo(a.value);
        return countCompare != 0 ? countCompare : b.key.compareTo(a.key);
      });
    return entries.take(10).toList();
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
