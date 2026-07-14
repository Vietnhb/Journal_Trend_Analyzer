import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../core/constants/app_colors.dart';
import '../../core/errors/app_errors.dart';
import '../../core/widgets/app_empty_view.dart';
import '../../core/widgets/app_error_view.dart';
import '../../core/widgets/app_loading.dart';
import '../../core/widgets/app_markup_text.dart';
import '../../data/repositories/journal_repository.dart'
    show Publication, PublicationYearSort, RankedEntity;
import '../providers/entity_analytics_provider.dart';
import '../providers/firebase_provider.dart';
import '../providers/journal_provider.dart';
import '../providers/keyword_screen_provider.dart';
import '../trends/widgets/trend_chart.dart';
import '../trends/widgets/year_heatmap.dart';
import '../widgets/analytics_ui.dart';
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

    return Padding(
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
                ? 'Explore frequent and trending research keywords.'
                : 'Research topic: ${provider.selectedKeyword}',
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
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
    return RefreshIndicator(
      onRefresh: () async {
        if (provider.selectedKeyword.isNotEmpty) {
          await provider.loadTrendingKeywords(force: true);
        }
      },
      color: AppColors.primary,
      child: ListView(
        physics: const AlwaysScrollableScrollPhysics(),
        padding: const EdgeInsets.fromLTRB(16, 20, 16, 28),
        children: [
          const _MonthlyKeywordTrendsWidget(),
          const SizedBox(height: 28),
          if (provider.selectedKeyword.isEmpty)
            const AppEmptyView(
              message: 'Search a research topic from Home first.',
              icon: Icons.key_outlined,
            )
          else if (provider.isLoadingTrendingKeywords &&
              provider.trendingKeywords.isEmpty)
            const SizedBox(
              height: 220,
              child: AppLoading(message: 'Loading keywords...'),
            )
          else if (provider.trendingKeywordError != null &&
              provider.trendingKeywords.isEmpty)
            AppErrorView(
              error: provider.trendingKeywordError!,
              onRetry: () => provider.loadTrendingKeywords(force: true),
            )
          else if (provider.trendingKeywords.isEmpty)
            const AppEmptyView(
              message: 'No keywords found inside the selected topic.',
              icon: Icons.key_outlined,
            )
          else ...[
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
              keyPrefix: 'topic_keyword_item',
              onSelected: (keyword) => _openKeywordDetail(
                context,
                keyword.name,
                provider.selectedKeyword,
                provider.filterFutureSourceYears,
              ),
            ),
          ],
        ],
      ),
    );
  }
}

class _MonthlyKeywordTrendsWidget extends StatefulWidget {
  const _MonthlyKeywordTrendsWidget();

  @override
  State<_MonthlyKeywordTrendsWidget> createState() =>
      _MonthlyKeywordTrendsWidgetState();
}

class _MonthlyKeywordTrendsWidgetState
    extends State<_MonthlyKeywordTrendsWidget> {
  late final MonthlyKeywordsProvider _viewModel;
  bool get _isLoading => _viewModel.isLoading;
  AppError? get _error => _viewModel.error;
  List<RankedEntity> get _keywords => _viewModel.keywords;

  @override
  void initState() {
    super.initState();
    _viewModel = MonthlyKeywordsProvider(
      resultLimit: context.read<FirebaseProvider>().maxKeywords,
    );
    _viewModel.addListener(_onViewModelChanged);
    _load();
  }

  void _onViewModelChanged() {
    if (mounted) setState(() {});
  }

  @override
  void dispose() {
    _viewModel
      ..removeListener(_onViewModelChanged)
      ..dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    _viewModel.resultLimit = context.watch<FirebaseProvider>().maxKeywords;
    final colorScheme = Theme.of(context).colorScheme;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            const Expanded(
              child: _SectionHeader(
                icon: Icons.calendar_month_rounded,
                title: 'Top 10 Keywords This Month',
              ),
            ),
            IconButton(
              tooltip: 'Refresh',
              onPressed: _isLoading ? null : _load,
              icon: const Icon(Icons.refresh_rounded),
            ),
          ],
        ),
        const SizedBox(height: 4),
        Text(
          'Most researched keywords across OpenAlex publications in the last 30 days.',
          style: Theme.of(
            context,
          ).textTheme.bodySmall?.copyWith(color: colorScheme.onSurfaceVariant),
        ),
        const SizedBox(height: 12),
        if (_isLoading)
          const SizedBox(
            height: 180,
            child: AppLoading(message: 'Loading monthly keywords...'),
          )
        else if (_error != null)
          AppErrorView(error: _error!, onRetry: _load)
        else if (_keywords.isEmpty)
          const AppEmptyView(
            message: 'No monthly keyword data available.',
            icon: Icons.calendar_month_outlined,
          )
        else
          _KeywordRankingCard(
            keywords: _keywords,
            keyPrefix: 'monthly_keyword_item',
            onSelected: (keyword) =>
                _openKeywordDetail(context, keyword.name, 'Last 30 days', true),
          ),
      ],
    );
  }

  Future<void> _load() async {
    await _viewModel.load();
  }
}

class _KeywordRankingCard extends StatelessWidget {
  final List<RankedEntity> keywords;
  final ValueChanged<RankedEntity> onSelected;
  final String keyPrefix;

  const _KeywordRankingCard({
    required this.keywords,
    required this.onSelected,
    required this.keyPrefix,
  });

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
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: colorScheme.outlineVariant),
        boxShadow: [
          BoxShadow(
            color: colorScheme.shadow.withValues(alpha: 0.05),
            blurRadius: 18,
            offset: const Offset(0, 6),
          ),
        ],
      ),
      clipBehavior: Clip.antiAlias,
      child: Column(
        children: [
          for (var index = 0; index < keywords.length; index++) ...[
            if (index > 0) const Divider(height: 1, indent: 16, endIndent: 16),
            _KeywordRow(
              keyword: keywords[index],
              rank: index + 1,
              itemKey: Key('${keyPrefix}_${index + 1}'),
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
  final Key itemKey;

  const _KeywordRow({
    required this.keyword,
    required this.rank,
    required this.maxCount,
    required this.onTap,
    required this.itemKey,
  });

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    final ratio = maxCount == 0 ? 0.0 : keyword.worksCount / maxCount;
    final rankColor = switch (rank) {
      1 => AppColors.gold,
      2 => AppColors.silver,
      3 => AppColors.bronze,
      _ => AppColors.primary,
    };

    return InkWell(
      key: itemKey,
      onTap: onTap,
      child: Padding(
        padding: const EdgeInsets.fromLTRB(14, 14, 10, 14),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Container(
              width: 34,
              height: 34,
              alignment: Alignment.center,
              decoration: BoxDecoration(
                color: rankColor.withValues(alpha: 0.13),
                borderRadius: BorderRadius.circular(10),
              ),
              child: Text(
                '$rank',
                style: Theme.of(context).textTheme.labelMedium?.copyWith(
                  color: rankColor,
                  fontWeight: FontWeight.w800,
                ),
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    keyword.name,
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                    style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                      color: colorScheme.onSurface,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                  const SizedBox(height: 8),
                  ClipRRect(
                    borderRadius: BorderRadius.circular(5),
                    child: LinearProgressIndicator(
                      minHeight: 6,
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
            const SizedBox(width: 12),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 6),
              decoration: BoxDecoration(
                color: AppColors.primary.withValues(alpha: 0.08),
                borderRadius: BorderRadius.circular(999),
              ),
              child: Text(
                _compactCount(keyword.worksCount),
                style: Theme.of(context).textTheme.labelSmall?.copyWith(
                  color: AppColors.primary,
                  fontWeight: FontWeight.w800,
                ),
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
  late final KeywordDetailProvider _viewModel;
  bool get _isLoading => _viewModel.isLoading;
  AppError? get _error => _viewModel.error;
  List<RankedEntity> get _journals => _viewModel.journals;
  List<Publication> get _publications => _viewModel.publications;
  List<RankedEntity> get _authors => _viewModel.authors;
  Map<int, int> get _publicationsByYear => _viewModel.publicationsByYear;

  @override
  void initState() {
    super.initState();
    _viewModel = KeywordDetailProvider(
      keyword: widget.keyword,
      excludeFuturePublications: widget.excludeFuturePublications,
      maxJournals: context.read<FirebaseProvider>().maxJournals,
    )..addListener(_onViewModelChanged);
    _load();
  }

  void _onViewModelChanged() {
    if (mounted) setState(() {});
  }

  @override
  void dispose() {
    _viewModel
      ..removeListener(_onViewModelChanged)
      ..dispose();
    super.dispose();
  }

  Future<void> _load() async {
    await _viewModel.load();
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
                key: const Key('keyword_detail_scroll'),
                cacheExtent: 20000,
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
                  const _SectionHeader(
                    icon: Icons.bar_chart_rounded,
                    title: 'Publication Trend',
                  ),
                  const SizedBox(height: 12),
                  _TrendChartCard(data: _publicationsByYear),
                  const SizedBox(height: 24),
                  if (_publicationsByYear.isNotEmpty) ...[
                    const _SectionHeader(
                      icon: Icons.leaderboard_rounded,
                      title: 'Activity Heatmap',
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
                    key: const Key('keyword_top_authors'),
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
    return AnalyticsSectionHeader(icon: icon, title: title);
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
    return SizedBox(
      height: 330,
      child: AnalyticsSurfaceCard(
        padding: const EdgeInsets.fromLTRB(12, 16, 12, 8),
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
      ),
    );
  }
}

class _YearRankingCard extends StatelessWidget {
  final Map<int, int> data;

  const _YearRankingCard({required this.data});

  @override
  Widget build(BuildContext context) {
    final recent = Map<int, int>.fromEntries(
      (data.entries.toList()..sort((a, b) => b.key.compareTo(a.key))).take(12),
    );
    return AnalyticsSurfaceCard(
      child: YearHeatmap(
        data: recent,
        ascending: false,
        valueLabel: 'publications',
      ),
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
    super.key,
    required this.title,
    required this.icon,
    required this.items,
  });

  @override
  Widget build(BuildContext context) {
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
          if (items.isEmpty)
            AppEmptyView(
              message: 'No ${title.toLowerCase()} available.',
              icon: icon,
            )
          else
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
