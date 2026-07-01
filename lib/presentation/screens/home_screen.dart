import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';

import '../../core/constants/app_colors.dart';
import '../../core/widgets/app_error_view.dart';
import '../../core/widgets/app_loading.dart';
import '../../core/widgets/app_markup_text.dart';
import '../../data/repositories/journal_repository.dart';
import '../providers/journal_provider.dart';
import '../trends/widgets/trend_chart.dart';
import 'analytics_entity_detail_screen.dart';
import 'publication_detail_screen.dart';

class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key});

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  final _searchController = TextEditingController();
  final _focusNode = FocusNode();
  final _scrollController = ScrollController();

  @override
  void dispose() {
    _searchController.dispose();
    _focusNode.dispose();
    _scrollController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final provider = context.watch<JournalProvider>();

    return AnnotatedRegion<SystemUiOverlayStyle>(
      value: SystemUiOverlayStyle.light.copyWith(
        statusBarColor: Colors.transparent,
      ),
      child: Scaffold(
        body: CustomScrollView(
          controller: _scrollController,
          slivers: [
            SliverToBoxAdapter(child: _buildHeader(context, provider)),
            SliverToBoxAdapter(
              child: Padding(
                padding: const EdgeInsets.fromLTRB(20, 20, 20, 28),
                child: _buildBody(context, provider),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildHeader(BuildContext context, JournalProvider provider) {
    final topInset = MediaQuery.paddingOf(context).top;
    final colorScheme = Theme.of(context).colorScheme;
    final inputSurface = colorScheme.surface;
    final inputText = colorScheme.onSurface;
    final inputHint = colorScheme.onSurfaceVariant;

    return Container(
      padding: EdgeInsets.fromLTRB(20, topInset + 18, 20, 28),
      decoration: const BoxDecoration(
        gradient: LinearGradient(
          colors: [AppColors.primary, AppColors.accent],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.vertical(bottom: Radius.circular(24)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                  color: Colors.white.withValues(alpha: 0.15),
                  borderRadius: BorderRadius.circular(10),
                ),
                child: const Icon(
                  Icons.auto_stories_rounded,
                  color: Colors.white,
                  size: 22,
                ),
              ),
              const SizedBox(width: 10),
              Text(
                'Journal Trend Analyzer',
                style: Theme.of(context).textTheme.titleMedium?.copyWith(
                  color: Colors.white.withValues(alpha: 0.9),
                  fontWeight: FontWeight.w500,
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),
          Text(
            'Research Topic Dashboard',
            style: Theme.of(context).textTheme.headlineMedium?.copyWith(
              color: Colors.white,
              fontWeight: FontWeight.w800,
              height: 1.2,
            ),
          ),
          const SizedBox(height: 6),
          Text(
            'Search publications by research topic',
            style: Theme.of(context).textTheme.bodyMedium?.copyWith(
              color: Colors.white.withValues(alpha: 0.82),
            ),
          ),
          const SizedBox(height: 18),
          Container(
            decoration: BoxDecoration(
              color: inputSurface,
              borderRadius: BorderRadius.circular(14),
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withValues(alpha: 0.14),
                  blurRadius: 16,
                  offset: const Offset(0, 4),
                ),
              ],
            ),
            child: TextField(
              key: const Key('topic_search_field'),
              controller: _searchController,
              focusNode: _focusNode,
              textInputAction: TextInputAction.search,
              style: TextStyle(
                color: inputText,
                fontWeight: FontWeight.w500,
                fontSize: 15,
              ),
              decoration: InputDecoration(
                hintText: 'Enter a topic, e.g. machine learning',
                hintStyle: TextStyle(
                  color: inputHint,
                  fontWeight: FontWeight.w400,
                  fontSize: 14,
                ),
                prefixIcon: const Icon(
                  Icons.search_rounded,
                  color: AppColors.primary,
                ),
                suffixIcon: _searchController.text.isNotEmpty
                    ? IconButton(
                        icon: const Icon(Icons.close_rounded, size: 20),
                        onPressed: () {
                          _searchController.clear();
                          context.read<JournalProvider>().clear();
                          setState(() {});
                        },
                      )
                    : null,
                filled: false,
                border: InputBorder.none,
                enabledBorder: InputBorder.none,
                focusedBorder: InputBorder.none,
                contentPadding: const EdgeInsets.symmetric(
                  horizontal: 16,
                  vertical: 14,
                ),
              ),
              onChanged: (_) => setState(() {}),
              onSubmitted: (_) => _search(context),
            ),
          ),
          const SizedBox(height: 12),
          SizedBox(
            width: double.infinity,
            child: FilledButton.icon(
              key: const Key('topic_search_button'),
              onPressed: provider.isLoading ? null : () => _search(context),
              style: FilledButton.styleFrom(
                backgroundColor: Colors.white,
                foregroundColor: AppColors.primary,
                padding: const EdgeInsets.symmetric(vertical: 14),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12),
                ),
              ),
              icon: provider.isLoading
                  ? const SizedBox(
                      width: 18,
                      height: 18,
                      child: CircularProgressIndicator(
                        strokeWidth: 2,
                        color: AppColors.primary,
                      ),
                    )
                  : const Icon(Icons.analytics_rounded, size: 20),
              label: Text(
                provider.isLoading ? 'Building dashboard...' : 'Search Topic',
                style: const TextStyle(
                  fontWeight: FontWeight.w700,
                  fontSize: 15,
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildBody(BuildContext context, JournalProvider provider) {
    if (provider.isLoading) {
      return const AppLoading(message: 'Building research dashboard...');
    }

    if (provider.error != null) {
      return AppErrorView(
        error: provider.error!,
        onRetry: provider.topicSearchQuery.isEmpty
            ? null
            : () => context.read<JournalProvider>().analyzeKeyword(
                provider.topicSearchQuery,
              ),
      );
    }

    if (provider.selectedKeyword.isEmpty) {
      return _buildRecentSearches(context, provider);
    }

    return _Dashboard(
      provider: provider,
      onPageSelected: _loadPage,
      onSortSelected: _setSort,
    );
  }

  Widget _buildRecentSearches(BuildContext context, JournalProvider provider) {
    final recentSearches = provider.recentSearches;
    final colorScheme = Theme.of(context).colorScheme;
    final mutedText = colorScheme.onSurfaceVariant;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _SectionHeader(icon: Icons.history_rounded, title: 'Recent Searches'),
        const SizedBox(height: 12),
        if (recentSearches.isEmpty)
          _MutedPanel(
            icon: Icons.manage_search_rounded,
            message: 'No recent searches yet. Search a topic to start.',
          )
        else
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: [
              for (final query in recentSearches)
                ActionChip(
                  label: Text(query),
                  avatar: const Icon(
                    Icons.history_rounded,
                    size: 16,
                    color: AppColors.primary,
                  ),
                  backgroundColor: colorScheme.surface,
                  side: BorderSide(color: colorScheme.outlineVariant),
                  labelStyle: TextStyle(
                    fontSize: 13,
                    fontWeight: FontWeight.w500,
                    color: colorScheme.onSurface,
                  ),
                  onPressed: provider.isLoading
                      ? null
                      : () => _runSuggestionSearch(context, query),
                ),
            ],
          ),
        if (recentSearches.isEmpty) ...[
          const SizedBox(height: 8),
          Text(
            'Your searched topics will appear here for quick access.',
            style: Theme.of(
              context,
            ).textTheme.bodySmall?.copyWith(color: mutedText),
          ),
        ],
      ],
    );
  }

  void _runSuggestionSearch(BuildContext context, String query) {
    _searchController.text = query;
    _focusNode.unfocus();
    context.read<JournalProvider>().analyzeKeyword(query);
  }

  void _search(BuildContext context) {
    _focusNode.unfocus();
    context.read<JournalProvider>().analyzeKeyword(_searchController.text);
  }

  Future<void> _loadPage(int page) async {
    await context.read<JournalProvider>().goToPage(page);
    await _scrollToDashboardTop();
  }

  Future<void> _setSort(PublicationListSort sort) async {
    await context.read<JournalProvider>().setPublicationSort(sort);
    await _scrollToDashboardTop();
  }

  Future<void> _scrollToDashboardTop() async {
    if (!mounted || !_scrollController.hasClients) return;
    await _scrollController.animateTo(
      0,
      duration: const Duration(milliseconds: 280),
      curve: Curves.easeOutCubic,
    );
  }
}

class _Dashboard extends StatelessWidget {
  final JournalProvider provider;
  final Future<void> Function(int page) onPageSelected;
  final Future<void> Function(PublicationListSort sort) onSortSelected;

  const _Dashboard({
    required this.provider,
    required this.onPageSelected,
    required this.onSortSelected,
  });

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _MetricRow(provider: provider),
        const SizedBox(height: 24),
        if (provider.sourceWorksByYear.isNotEmpty) ...[
          const _SectionHeader(
            icon: Icons.bar_chart_rounded,
            title: 'Publication Trend',
          ),
          const SizedBox(height: 12),
          _TrendChartCard(provider: provider),
          const SizedBox(height: 24),
        ],
        _Highlights(provider: provider),
        const SizedBox(height: 32),
        Row(
          children: [
            const Expanded(
              child: _SectionHeader(
                icon: Icons.article_outlined,
                title: 'Related Publications',
              ),
            ),
            const SizedBox(width: 12),
            _PublicationToolbar(
              provider: provider,
              onSortSelected: onSortSelected,
            ),
          ],
        ),
        const SizedBox(height: 12),
        _PublicationSection(provider: provider, onPageSelected: onPageSelected),
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
      height: 300,
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

class _Highlights extends StatelessWidget {
  final JournalProvider provider;

  const _Highlights({required this.provider});

  @override
  Widget build(BuildContext context) {
    final paper = provider.mostInfluentialPaper;
    final journal = provider.journals.firstOrNull;
    final author = provider.keywordAnalyticsTopAuthors.firstOrNull;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const _SectionHeader(
          icon: Icons.insights_rounded,
          title: 'Dashboard Highlights',
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
              label: 'Most Influential',
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

class _PublicationSection extends StatelessWidget {
  final JournalProvider provider;
  final Future<void> Function(int page) onPageSelected;

  const _PublicationSection({
    required this.provider,
    required this.onPageSelected,
  });

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        if (provider.isLoadingJournalPublications &&
            provider.journalPublications.isEmpty)
          const AppLoading(message: 'Loading publications...')
        else if (provider.journalPublicationError != null &&
            provider.journalPublications.isEmpty)
          AppErrorView(
            error: provider.journalPublicationError!,
            onRetry: () => provider.goToPage(provider.currentPage, force: true),
          )
        else
          _PublicationList(publications: provider.journalPublications),
        if (provider.totalPages > 1) ...[
          const SizedBox(height: 14),
          _Pagination(provider: provider, onPageSelected: onPageSelected),
        ],
      ],
    );
  }
}

class _PublicationToolbar extends StatelessWidget {
  final JournalProvider provider;
  final Future<void> Function(PublicationListSort sort) onSortSelected;

  const _PublicationToolbar({
    required this.provider,
    required this.onSortSelected,
  });

  @override
  Widget build(BuildContext context) {
    final sortLabel = switch (provider.publicationSort) {
      PublicationListSort.newest => 'Newest',
      PublicationListSort.oldest => 'Oldest',
      PublicationListSort.mostCited => 'Most cited',
    };

    return Row(
      mainAxisAlignment: MainAxisAlignment.end,
      children: [
        PopupMenuButton<PublicationListSort>(
          initialValue: provider.publicationSort,
          onSelected: onSortSelected,
          itemBuilder: (context) => const [
            PopupMenuItem(
              value: PublicationListSort.newest,
              child: Text('Newest'),
            ),
            PopupMenuItem(
              value: PublicationListSort.oldest,
              child: Text('Oldest'),
            ),
            PopupMenuItem(
              value: PublicationListSort.mostCited,
              child: Text('Most cited'),
            ),
          ],
          child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
            decoration: BoxDecoration(
              color: AppColors.primary.withValues(alpha: 0.08),
              borderRadius: BorderRadius.circular(18),
              border: Border.all(
                color: AppColors.primary.withValues(alpha: 0.16),
              ),
            ),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                const Icon(
                  Icons.sort_rounded,
                  size: 15,
                  color: AppColors.primary,
                ),
                const SizedBox(width: 5),
                Text(
                  sortLabel,
                  style: Theme.of(context).textTheme.labelMedium?.copyWith(
                    color: AppColors.primary,
                    fontWeight: FontWeight.w700,
                  ),
                ),
                const SizedBox(width: 2),
                const Icon(
                  Icons.arrow_drop_down_rounded,
                  size: 18,
                  color: AppColors.primary,
                ),
              ],
            ),
          ),
        ),
      ],
    );
  }
}

class _PublicationList extends StatelessWidget {
  final List<Publication> publications;

  const _PublicationList({required this.publications});

  @override
  Widget build(BuildContext context) {
    if (publications.isEmpty) {
      return const Text('No related publications found.');
    }
    final colorScheme = Theme.of(context).colorScheme;

    return Container(
      decoration: BoxDecoration(
        color: colorScheme.surface,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: colorScheme.outlineVariant),
      ),
      clipBehavior: Clip.antiAlias,
      child: Column(
        children: [
          for (var i = 0; i < publications.length; i++) ...[
            if (i > 0) const Divider(height: 1, indent: 16, endIndent: 16),
            _PublicationTile(publication: publications[i]),
          ],
        ],
      ),
    );
  }
}

class _PublicationTile extends StatelessWidget {
  final Publication publication;

  const _PublicationTile({required this.publication});

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    final date = publication.publicationDate ?? publication.year?.toString();

    return InkWell(
      key: const Key('publication_item'),
      onTap: () => Navigator.push(
        context,
        MaterialPageRoute(
          builder: (_) => PublicationDetailScreen(publication: publication),
        ),
      ),
      child: Padding(
        padding: const EdgeInsets.all(14),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Container(
              width: 36,
              height: 36,
              decoration: BoxDecoration(
                color: AppColors.primary.withValues(alpha: 0.10),
                borderRadius: BorderRadius.circular(9),
              ),
              child: const Icon(
                Icons.article_outlined,
                size: 18,
                color: AppColors.primary,
              ),
            ),
            const SizedBox(width: 10),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  AppMarkupText(
                    publication.titleMarkup ?? publication.title,
                    style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                      color: colorScheme.onSurface,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    [
                      ?date,
                      '${publication.citationCount} citations',
                      publication.journalName,
                    ].join(' - '),
                    style: Theme.of(context).textTheme.bodySmall?.copyWith(
                      color: colorScheme.onSurfaceVariant,
                    ),
                  ),
                ],
              ),
            ),
            Icon(
              Icons.chevron_right_rounded,
              color: colorScheme.onSurfaceVariant,
            ),
          ],
        ),
      ),
    );
  }
}

class _Pagination extends StatelessWidget {
  final JournalProvider provider;
  final Future<void> Function(int page) onPageSelected;

  const _Pagination({required this.provider, required this.onPageSelected});

  @override
  Widget build(BuildContext context) {
    final pageItems = _pageItems(provider.currentPage, provider.totalPages);

    return Column(
      children: [
        SingleChildScrollView(
          scrollDirection: Axis.horizontal,
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              _PageButton(
                icon: Icons.first_page_rounded,
                onTap: provider.currentPage > 1
                    ? () => onPageSelected(1)
                    : null,
              ),
              const SizedBox(width: 5),
              _PageButton(
                icon: Icons.chevron_left_rounded,
                onTap: provider.canGoPrevious
                    ? () => onPageSelected(provider.currentPage - 1)
                    : null,
              ),
              const SizedBox(width: 5),
              for (var i = 0; i < pageItems.length; i++) ...[
                if (i > 0) const SizedBox(width: 5),
                if (pageItems[i] == null)
                  const Padding(
                    padding: EdgeInsets.symmetric(horizontal: 2),
                    child: Text('...'),
                  )
                else
                  _PageButton(
                    label: '${pageItems[i]}',
                    selected: pageItems[i] == provider.currentPage,
                    loading: pageItems[i] == provider.loadingPage,
                    onTap: pageItems[i] == provider.currentPage
                        ? null
                        : () => onPageSelected(pageItems[i]!),
                  ),
              ],
              const SizedBox(width: 5),
              _PageButton(
                icon: Icons.chevron_right_rounded,
                onTap: provider.canGoNext
                    ? () => onPageSelected(provider.currentPage + 1)
                    : null,
              ),
              const SizedBox(width: 5),
              _PageButton(
                icon: Icons.last_page_rounded,
                onTap: provider.currentPage < provider.totalPages
                    ? () => onPageSelected(provider.totalPages)
                    : null,
              ),
            ],
          ),
        ),
        if (provider.journalPublicationError != null) ...[
          const SizedBox(height: 8),
          Text(
            provider.journalPublicationError!.message,
            style: TextStyle(color: Theme.of(context).colorScheme.error),
          ),
        ],
      ],
    );
  }

  List<int?> _pageItems(int current, int last) {
    if (last <= 7) {
      return [for (var page = 1; page <= last; page++) page];
    }

    final pages = <int>{1, last};
    for (var page = current - 1; page <= current + 1; page++) {
      final isReachable =
          page <= provider.directPageLimit ||
          last - page + 1 <= provider.directPageLimit;
      if (page > 1 && page < last && isReachable) pages.add(page);
    }
    final sorted = pages.toList()..sort();
    final result = <int?>[];
    for (var i = 0; i < sorted.length; i++) {
      if (i > 0 && sorted[i] - sorted[i - 1] > 1) result.add(null);
      result.add(sorted[i]);
    }
    return result;
  }
}

class _PageButton extends StatelessWidget {
  final String? label;
  final IconData? icon;
  final bool selected;
  final bool loading;
  final VoidCallback? onTap;

  const _PageButton({
    this.label,
    this.icon,
    this.selected = false,
    this.loading = false,
    this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;

    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(8),
      child: Container(
        constraints: const BoxConstraints(minWidth: 34, minHeight: 34),
        padding: const EdgeInsets.symmetric(horizontal: 8),
        alignment: Alignment.center,
        decoration: BoxDecoration(
          color: selected
              ? AppColors.primary
              : colorScheme.surfaceContainerHighest,
          borderRadius: BorderRadius.circular(8),
          border: Border.all(
            color: selected ? AppColors.primary : colorScheme.outlineVariant,
          ),
        ),
        child: loading
            ? SizedBox(
                width: 14,
                height: 14,
                child: CircularProgressIndicator(
                  strokeWidth: 2,
                  color: selected ? Colors.white : AppColors.primary,
                ),
              )
            : icon != null
            ? Icon(
                icon,
                size: 18,
                color: onTap == null
                    ? colorScheme.onSurfaceVariant.withValues(alpha: 0.4)
                    : colorScheme.onSurface,
              )
            : Text(
                label!,
                style: Theme.of(context).textTheme.labelMedium?.copyWith(
                  color: selected ? Colors.white : colorScheme.onSurface,
                  fontWeight: FontWeight.w700,
                ),
              ),
      ),
    );
  }
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
            width: 102,
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
      constraints: const BoxConstraints(minHeight: 96),
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

class _MutedPanel extends StatelessWidget {
  final IconData icon;
  final String message;

  const _MutedPanel({required this.icon, required this.message});

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    final mutedText = colorScheme.onSurfaceVariant;

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: colorScheme.surfaceContainerHighest,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: colorScheme.outlineVariant),
      ),
      child: Column(
        children: [
          Icon(icon, size: 34, color: mutedText),
          const SizedBox(height: 8),
          Text(
            message,
            textAlign: TextAlign.center,
            style: Theme.of(
              context,
            ).textTheme.bodyMedium?.copyWith(color: mutedText),
          ),
        ],
      ),
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
