import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:url_launcher/url_launcher.dart';

import '../../core/constants/app_colors.dart';
import '../../core/errors/app_errors.dart';
import '../../core/widgets/app_empty_view.dart';
import '../../core/widgets/app_error_view.dart';
import '../../core/widgets/app_loading.dart';
import '../../data/repositories/journal_repository.dart'
    show JournalProfile, JournalTopic, Publication;
import '../providers/bookmark_provider.dart';
import '../providers/firebase_provider.dart';
import '../providers/journal_screen_provider.dart';
import '../trends/widgets/donut_breakdown_chart.dart';
import '../trends/widgets/year_bar_chart.dart';
import '../widgets/analytics_ui.dart';
import 'publication_detail_screen.dart';

class JournalScreen extends StatefulWidget {
  const JournalScreen({super.key});

  @override
  State<JournalScreen> createState() => _JournalScreenState();
}

class _JournalScreenState extends State<JournalScreen> {
  final _searchController = TextEditingController();
  late final JournalSearchProvider _viewModel;

  String get _query => _viewModel.query;
  bool get _isSearching => _viewModel.isSearching;
  AppError? get _error => _viewModel.error;
  List<JournalProfile> get _results => _viewModel.results;

  @override
  void initState() {
    super.initState();
    _viewModel = JournalSearchProvider(
      resultLimit: context.read<FirebaseProvider>().maxJournals,
    );
    _viewModel.addListener(_onViewModelChanged);
  }

  void _onViewModelChanged() {
    if (mounted) setState(() {});
  }

  @override
  void dispose() {
    _viewModel
      ..removeListener(_onViewModelChanged)
      ..dispose();
    _searchController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    _viewModel.resultLimit = context.watch<FirebaseProvider>().maxJournals;
    return Scaffold(
      body: SafeArea(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            _Header(
              controller: _searchController,
              isSearching: _isSearching,
              onSearch: _search,
              onClear: _clear,
            ),
            Expanded(child: _buildBody()),
          ],
        ),
      ),
    );
  }

  Widget _buildBody() {
    if (_isSearching && _results.isEmpty) {
      return const AppLoading(message: 'Searching journals...');
    }

    if (_error != null && _results.isEmpty) {
      return AppErrorView(error: _error!, onRetry: () => _search(_query));
    }

    if (_query.isEmpty && _results.isEmpty) {
      return const AppEmptyView(
        message: 'Search a journal title, publisher, or ISSN.',
        icon: Icons.manage_search_rounded,
      );
    }

    return RefreshIndicator(
      color: AppColors.primary,
      onRefresh: () => _search(_query),
      child: ListView(
        physics: const AlwaysScrollableScrollPhysics(),
        padding: const EdgeInsets.fromLTRB(16, 4, 16, 24),
        children: [
          if (_results.isNotEmpty) ...[
            _SectionHeader(
              icon: Icons.library_books_rounded,
              title: 'Journal Search Results',
              subtitle: 'Tap a journal to view its analysis.',
            ),
            const SizedBox(height: 12),
            _JournalResultsList(journals: _results, onSelected: _selectJournal),
          ] else if (!_isSearching && _query.isNotEmpty)
            const AppEmptyView(
              message: 'No journals found for this search.',
              icon: Icons.library_books_outlined,
            ),
          if (_error != null && _results.isNotEmpty) ...[
            const SizedBox(height: 16),
            AppErrorView(error: _error!, onRetry: () => _search(_query)),
          ],
        ],
      ),
    );
  }

  Future<void> _search(String value) async {
    await _viewModel.search(value);
  }

  void _selectJournal(JournalProfile journal) {
    Navigator.of(context).push(
      MaterialPageRoute(
        builder: (_) => JournalDetailScreen(initialJournal: journal),
      ),
    );
  }

  void _clear() {
    _searchController.clear();
    _viewModel.clear();
  }
}

class JournalDetailScreen extends StatefulWidget {
  final JournalProfile initialJournal;

  const JournalDetailScreen({super.key, required this.initialJournal});

  @override
  State<JournalDetailScreen> createState() => _JournalDetailScreenState();
}

class _JournalDetailScreenState extends State<JournalDetailScreen> {
  late final JournalDetailProvider _viewModel;
  bool get _isLoading => _viewModel.isLoading;
  AppError? get _error => _viewModel.error;
  JournalProfile get _profile => _viewModel.profile;
  List<Publication> get _relatedPublications => _viewModel.relatedPublications;

  @override
  void initState() {
    super.initState();
    _viewModel = JournalDetailProvider(widget.initialJournal)
      ..addListener(_onViewModelChanged);
    _loadProfile();
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
    return Scaffold(
      appBar: AppBar(
        title: Text(_profile.name),
        centerTitle: false,
        actions: [
          Consumer<BookmarkProvider>(
            builder: (context, bookmarks, _) {
              final isSaved = bookmarks.isJournalBookmarked(_profile.id);
              return IconButton(
                tooltip: isSaved ? 'Remove bookmark' : 'Bookmark journal',
                icon: Icon(
                  isSaved
                      ? Icons.bookmark_rounded
                      : Icons.bookmark_border_rounded,
                ),
                onPressed: _profile.id.isEmpty
                    ? null
                    : () => _toggleBookmark(context, bookmarks, isSaved),
              );
            },
          ),
        ],
      ),
      body: SafeArea(
        child: RefreshIndicator(
          color: AppColors.primary,
          onRefresh: _loadProfile,
          child: ListView(
            physics: const AlwaysScrollableScrollPhysics(),
            padding: const EdgeInsets.fromLTRB(16, 12, 16, 24),
            children: [
              if (_isLoading)
                const SizedBox(
                  height: 360,
                  child: AppLoading(message: 'Loading journal analysis...'),
                )
              else if (_error != null)
                AppErrorView(error: _error!, onRetry: _loadProfile)
              else
                _JournalAnalysis(
                  key: const Key('journal_analysis'),
                  profile: _profile,
                  averageCitations: _viewModel.averageCitations,
                  relatedPublications: _relatedPublications,
                ),
            ],
          ),
        ),
      ),
    );
  }

  Future<void> _loadProfile() async {
    await _viewModel.load();
    if (!mounted || _viewModel.error != null) return;
    await context.read<BookmarkProvider>().updateJournalSnapshot(_profile);
  }

  Future<void> _toggleBookmark(
    BuildContext context,
    BookmarkProvider bookmarks,
    bool wasSaved,
  ) async {
    await bookmarks.toggleJournal(_profile);
    if (!context.mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(
          wasSaved ? 'Journal bookmark removed.' : 'Journal saved.',
        ),
        duration: const Duration(seconds: 2),
      ),
    );
  }
}

class _Header extends StatelessWidget {
  final TextEditingController controller;
  final bool isSearching;
  final ValueChanged<String> onSearch;
  final VoidCallback onClear;

  const _Header({
    required this.controller,
    required this.isSearching,
    required this.onSearch,
    required this.onClear,
  });

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
            'Search journals and view source-level analysis.',
            style: Theme.of(context).textTheme.bodySmall?.copyWith(
              color: colorScheme.onSurfaceVariant,
            ),
          ),
          const SizedBox(height: 12),
          TextField(
            key: const Key('journal_search_field'),
            controller: controller,
            textInputAction: TextInputAction.search,
            enabled: !isSearching,
            onSubmitted: onSearch,
            decoration: InputDecoration(
              hintText: 'Search journal title, publisher, or ISSN',
              prefixIcon: const Icon(Icons.search_rounded),
              suffixIcon: controller.text.isEmpty
                  ? null
                  : IconButton(
                      tooltip: 'Clear',
                      icon: const Icon(Icons.close_rounded),
                      onPressed: onClear,
                    ),
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(12),
              ),
            ),
            onChanged: (_) => (context as Element).markNeedsBuild(),
          ),
          const SizedBox(height: 10),
          SizedBox(
            width: double.infinity,
            child: FilledButton.icon(
              key: const Key('journal_search_button'),
              onPressed: isSearching ? null : () => onSearch(controller.text),
              icon: const Icon(Icons.manage_search_rounded),
              label: const Text('Search Journals'),
            ),
          ),
          const SizedBox(height: 12),
          const Divider(height: 1),
        ],
      ),
    );
  }
}

class _JournalResultsList extends StatelessWidget {
  final List<JournalProfile> journals;
  final ValueChanged<JournalProfile> onSelected;

  const _JournalResultsList({required this.journals, required this.onSelected});

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;

    return Container(
      decoration: BoxDecoration(
        color: colorScheme.surface,
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: colorScheme.outlineVariant),
      ),
      child: Column(
        children: [
          for (var index = 0; index < journals.length; index++)
            _JournalResultTile(
              key: Key('journal_item_${index + 1}'),
              journal: journals[index],
              rank: index + 1,
              showDivider: index < journals.length - 1,
              onTap: () => onSelected(journals[index]),
            ),
        ],
      ),
    );
  }
}

class _JournalResultTile extends StatelessWidget {
  final JournalProfile journal;
  final int rank;
  final bool showDivider;
  final VoidCallback onTap;

  const _JournalResultTile({
    super.key,
    required this.journal,
    required this.rank,
    required this.showDivider,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;

    return InkWell(
      onTap: onTap,
      child: DecoratedBox(
        decoration: BoxDecoration(
          border: showDivider
              ? Border(bottom: BorderSide(color: colorScheme.outlineVariant))
              : null,
        ),
        child: Padding(
          padding: const EdgeInsets.all(12),
          child: Row(
            children: [
              SizedBox(
                width: 30,
                child: Text(
                  '$rank',
                  style: Theme.of(context).textTheme.titleSmall?.copyWith(
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
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                      style: Theme.of(context).textTheme.titleSmall?.copyWith(
                        color: colorScheme.onSurface,
                        fontWeight: FontWeight.w800,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      [
                        if (journal.publisher != null) journal.publisher!,
                        if (journal.countryCode != null) journal.countryCode!,
                        if (journal.issnL != null) 'ISSN ${journal.issnL}',
                      ].join(' | '),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: Theme.of(context).textTheme.labelSmall?.copyWith(
                        color: colorScheme.onSurfaceVariant,
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 8),
              Column(
                crossAxisAlignment: CrossAxisAlignment.end,
                children: [
                  Text(
                    _formatCount(journal.worksCount),
                    style: Theme.of(context).textTheme.labelLarge?.copyWith(
                      color: AppColors.primary,
                      fontWeight: FontWeight.w900,
                    ),
                  ),
                  Text(
                    'works',
                    style: Theme.of(context).textTheme.labelSmall?.copyWith(
                      color: colorScheme.onSurfaceVariant,
                    ),
                  ),
                ],
              ),
              const SizedBox(width: 6),
              Icon(
                Icons.chevron_right_rounded,
                color: colorScheme.onSurfaceVariant,
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _JournalAnalysis extends StatelessWidget {
  final JournalProfile profile;
  final double? averageCitations;
  final List<Publication> relatedPublications;

  const _JournalAnalysis({
    super.key,
    required this.profile,
    required this.averageCitations,
    required this.relatedPublications,
  });

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    final recentTrend = _recentYears(profile.worksByYear, 12);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _SectionHeader(
          icon: Icons.analytics_rounded,
          title: profile.name,
          subtitle: 'Journal profile and performance indicators.',
        ),
        const SizedBox(height: 12),
        Container(
          width: double.infinity,
          padding: const EdgeInsets.all(14),
          decoration: BoxDecoration(
            color: colorScheme.surface,
            borderRadius: BorderRadius.circular(8),
            border: Border.all(color: colorScheme.outlineVariant),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Wrap(
                spacing: 8,
                runSpacing: 8,
                children: [
                  _Badge(text: profile.type.toUpperCase()),
                  _Badge(
                    text: profile.isOpenAccess ? 'Open access' : 'Hybrid/paid',
                  ),
                  if (profile.isInDoaj) const _Badge(text: 'DOAJ'),
                  if (profile.firstPublicationYear != null)
                    _Badge(text: 'Since ${profile.firstPublicationYear}'),
                ],
              ),
              const SizedBox(height: 14),
              _InfoGrid(profile: profile),
            ],
          ),
        ),
        const SizedBox(height: 14),
        _MetricGrid(profile: profile, averageCitations: averageCitations),
        if (profile.worksCount > 0) ...[
          const SizedBox(height: 20),
          const _SectionHeader(
            icon: Icons.donut_large_rounded,
            title: 'Access Distribution',
            subtitle: 'Open-access and restricted works in this journal.',
          ),
          const SizedBox(height: 12),
          SizedBox(
            height: 240,
            child: AnalyticsSurfaceCard(
              child: DonutBreakdownChart(
                data: {
                  'Open access': profile.oaWorksCount,
                  'Restricted': math.max(
                    0,
                    profile.worksCount - profile.oaWorksCount,
                  ),
                },
                centerLabel: 'Works',
              ),
            ),
          ),
        ],
        const SizedBox(height: 20),
        _SectionHeader(
          icon: Icons.show_chart_rounded,
          title: 'Publication Trend',
          subtitle: 'Recent yearly output from OpenAlex, newest year first.',
        ),
        const SizedBox(height: 12),
        Container(
          height: 260,
          padding: const EdgeInsets.fromLTRB(8, 14, 8, 8),
          decoration: BoxDecoration(
            color: colorScheme.surface,
            borderRadius: BorderRadius.circular(8),
            border: Border.all(color: colorScheme.outlineVariant),
          ),
          child: LayoutBuilder(
            builder: (context, constraints) {
              final chartWidth = math.max(
                constraints.maxWidth,
                recentTrend.length * 48.0,
              );
              return SingleChildScrollView(
                scrollDirection: Axis.horizontal,
                child: SizedBox(
                  width: chartWidth,
                  child: YearBarChart(data: recentTrend, ascending: false),
                ),
              );
            },
          ),
        ),
        const SizedBox(height: 20),
        _SectionHeader(
          icon: Icons.category_rounded,
          title: 'Subject Areas',
          subtitle: 'Top topics and categories associated with this journal.',
        ),
        const SizedBox(height: 12),
        _TopicList(topics: profile.topics),
        const SizedBox(height: 20),
        const _SectionHeader(
          icon: Icons.auto_stories_outlined,
          title: 'Related Publications',
          subtitle: 'Highly cited publications from this journal.',
        ),
        const SizedBox(height: 12),
        _RelatedPublications(publications: relatedPublications),
      ],
    );
  }

  Map<int, int> _recentYears(Map<int, int> values, int limit) {
    final entries = values.entries.toList()
      ..sort((a, b) => b.key.compareTo(a.key));
    return Map<int, int>.fromEntries(entries.take(limit).toList().reversed);
  }
}

class _InfoGrid extends StatelessWidget {
  final JournalProfile profile;

  const _InfoGrid({required this.profile});

  @override
  Widget build(BuildContext context) {
    return Wrap(
      spacing: 10,
      runSpacing: 10,
      children: [
        _InfoCell(label: 'Publisher', value: profile.publisher ?? '-'),
        _InfoCell(label: 'Country', value: profile.countryCode ?? '-'),
        _InfoCell(label: 'ISSN-L', value: profile.issnL ?? '-'),
        _InfoCell(
          label: 'ISSN',
          value: profile.issn.isEmpty ? '-' : profile.issn.join(', '),
        ),
        _InfoCell(
          label: 'Years',
          value:
              '${profile.firstPublicationYear ?? '-'} - ${profile.lastPublicationYear ?? '-'}',
        ),
        _InfoCell(
          label: 'Homepage',
          value: profile.homepageUrl ?? '-',
          url: profile.homepageUrl,
        ),
      ],
    );
  }
}

class _InfoCell extends StatelessWidget {
  final String label;
  final String value;
  final String? url;

  const _InfoCell({required this.label, required this.value, this.url});

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    final targetUri = url == null ? null : Uri.tryParse(url!);
    final canOpen = targetUri != null && targetUri.hasScheme;

    return SizedBox(
      width: MediaQuery.sizeOf(context).width >= 700 ? 210 : double.infinity,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            label,
            style: Theme.of(context).textTheme.labelSmall?.copyWith(
              color: colorScheme.onSurfaceVariant,
              fontWeight: FontWeight.w700,
            ),
          ),
          const SizedBox(height: 2),
          InkWell(
            onTap: canOpen ? () => _openUrl(context, targetUri) : null,
            borderRadius: BorderRadius.circular(4),
            child: Padding(
              padding: const EdgeInsets.symmetric(vertical: 2),
              child: Text(
                value,
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
                style: Theme.of(context).textTheme.bodySmall?.copyWith(
                  color: canOpen ? AppColors.primary : colorScheme.onSurface,
                  fontWeight: FontWeight.w600,
                  decoration: canOpen ? TextDecoration.underline : null,
                  decorationColor: AppColors.primary,
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

Future<void> _openUrl(BuildContext context, Uri uri) async {
  final opened = await launchUrl(uri, mode: LaunchMode.externalApplication);
  if (!opened && context.mounted) {
    ScaffoldMessenger.of(
      context,
    ).showSnackBar(const SnackBar(content: Text('Could not open homepage.')));
  }
}

class _MetricGrid extends StatelessWidget {
  final JournalProfile profile;
  final double? averageCitations;

  const _MetricGrid({required this.profile, required this.averageCitations});

  @override
  Widget build(BuildContext context) {
    return ResponsiveMetricGrid(
      minItemWidth: 145,
      children: [
        AnalyticsMetricCard(
          label: 'Total works',
          value: _formatCount(profile.worksCount),
          icon: Icons.article_rounded,
          color: AppColors.primary,
        ),
        AnalyticsMetricCard(
          label: 'Citations',
          value: _formatCount(profile.citedByCount),
          icon: Icons.format_quote_rounded,
          color: AppColors.success,
        ),
        AnalyticsMetricCard(
          label: 'Avg. citations / work',
          value: averageCitations?.toStringAsFixed(2) ?? '-',
          icon: Icons.calculate_outlined,
          color: AppColors.info,
        ),
        AnalyticsMetricCard(
          label: 'H-index',
          value: profile.hIndex?.toString() ?? '-',
          icon: Icons.workspace_premium_rounded,
          color: AppColors.gold,
        ),
        AnalyticsMetricCard(
          label: '2yr mean citedness',
          value: profile.twoYearMeanCitedness == null
              ? '-'
              : profile.twoYearMeanCitedness!.toStringAsFixed(2),
          icon: Icons.trending_up_rounded,
          color: AppColors.info,
        ),
        AnalyticsMetricCard(
          label: 'i10-index',
          value: profile.i10Index?.toString() ?? '-',
          icon: Icons.filter_9_plus_rounded,
          color: AppColors.accent,
        ),
        AnalyticsMetricCard(
          label: 'Open access',
          value: '${profile.openAccessPercent.toStringAsFixed(0)}%',
          icon: Icons.lock_open_rounded,
          color: AppColors.success,
        ),
      ],
    );
  }
}

class _RelatedPublications extends StatelessWidget {
  final List<Publication> publications;

  const _RelatedPublications({required this.publications});

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    if (publications.isEmpty) {
      return const AppEmptyView(
        message: 'No related publications available.',
        icon: Icons.article_outlined,
      );
    }

    return Container(
      decoration: BoxDecoration(
        color: colorScheme.surface,
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: colorScheme.outlineVariant),
      ),
      clipBehavior: Clip.antiAlias,
      child: Column(
        children: [
          for (var index = 0; index < publications.length; index++)
            ListTile(
              key: Key('journal_related_publication_${index + 1}'),
              title: Text(
                publications[index].title,
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
                style: const TextStyle(fontWeight: FontWeight.w700),
              ),
              subtitle: Text(
                [
                  if (publications[index].year != null)
                    '${publications[index].year}',
                  '${_formatCount(publications[index].citationCount)} citations',
                ].join(' • '),
              ),
              trailing: const Icon(Icons.chevron_right_rounded),
              onTap: () => Navigator.push(
                context,
                MaterialPageRoute(
                  builder: (_) =>
                      PublicationDetailScreen(publication: publications[index]),
                ),
              ),
            ),
        ],
      ),
    );
  }
}

class _TopicList extends StatelessWidget {
  final List<JournalTopic> topics;

  const _TopicList({required this.topics});

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;

    if (topics.isEmpty) {
      return const AppEmptyView(
        message: 'No topic data available for this journal.',
        icon: Icons.category_outlined,
      );
    }

    return Container(
      decoration: BoxDecoration(
        color: colorScheme.surface,
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: colorScheme.outlineVariant),
      ),
      child: Column(
        children: [
          for (var index = 0; index < topics.length; index++)
            _TopicTile(
              topic: topics[index],
              showDivider: index < topics.length - 1,
            ),
        ],
      ),
    );
  }
}

class _TopicTile extends StatelessWidget {
  final JournalTopic topic;
  final bool showDivider;

  const _TopicTile({required this.topic, required this.showDivider});

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    final meta = [
      if (topic.subfield != null) topic.subfield!,
      if (topic.field != null) topic.field!,
      if (topic.domain != null) topic.domain!,
    ].join(' | ');

    return DecoratedBox(
      decoration: BoxDecoration(
        border: showDivider
            ? Border(bottom: BorderSide(color: colorScheme.outlineVariant))
            : null,
      ),
      child: Padding(
        padding: const EdgeInsets.all(12),
        child: Row(
          children: [
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    topic.name,
                    style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                      color: colorScheme.onSurface,
                      fontWeight: FontWeight.w800,
                    ),
                  ),
                  if (meta.isNotEmpty) ...[
                    const SizedBox(height: 3),
                    Text(
                      meta,
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                      style: Theme.of(context).textTheme.labelSmall?.copyWith(
                        color: colorScheme.onSurfaceVariant,
                      ),
                    ),
                  ],
                ],
              ),
            ),
            const SizedBox(width: 8),
            Text(
              _formatCount(topic.count),
              style: Theme.of(context).textTheme.labelLarge?.copyWith(
                color: AppColors.primary,
                fontWeight: FontWeight.w900,
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
  final String subtitle;

  const _SectionHeader({
    required this.icon,
    required this.title,
    required this.subtitle,
  });

  @override
  Widget build(BuildContext context) {
    return AnalyticsSectionHeader(icon: icon, title: title, subtitle: subtitle);
  }
}

class _Badge extends StatelessWidget {
  final String text;

  const _Badge({required this.text});

  @override
  Widget build(BuildContext context) {
    return DecoratedBox(
      decoration: BoxDecoration(
        color: AppColors.primary.withValues(alpha: 0.10),
        borderRadius: BorderRadius.circular(8),
      ),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 5),
        child: Text(
          text,
          style: Theme.of(context).textTheme.labelSmall?.copyWith(
            color: AppColors.primary,
            fontWeight: FontWeight.w800,
          ),
        ),
      ),
    );
  }
}

String _formatCount(int count) {
  if (count >= 1000000) return '${_compact(count / 1000000)}M';
  if (count >= 1000) return '${_compact(count / 1000)}K';
  return count.toString();
}

String _compact(double value) {
  if (value >= 10 || value == value.roundToDouble()) {
    return value.toStringAsFixed(0);
  }
  return value.toStringAsFixed(1);
}
