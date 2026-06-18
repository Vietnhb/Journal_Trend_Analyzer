import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../core/constants/app_colors.dart';
import '../../core/widgets/app_empty_view.dart';
import '../../core/widgets/app_error_view.dart';
import '../../core/widgets/app_loading.dart';
import '../../core/widgets/app_markup_text.dart';
import '../../data/repositories/journal_repository.dart';
import '../providers/journal_provider.dart';
import 'publication_detail_screen.dart';

class JournalScreen extends StatefulWidget {
  final String? journalFilter;
  final String? authorFilter;

  const JournalScreen({super.key, this.journalFilter, this.authorFilter});

  @override
  State<JournalScreen> createState() => _JournalScreenState();
}

class _JournalScreenState extends State<JournalScreen> {
  final _scrollController = ScrollController();
  String? _lastKeyword;

  @override
  void dispose() {
    _scrollController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final provider = context.watch<JournalProvider>();
    if (_lastKeyword != provider.selectedKeyword) {
      _lastKeyword = provider.selectedKeyword;
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (_scrollController.hasClients) {
          _scrollController.jumpTo(0);
        }
      });
    }

    return Scaffold(
      body: SafeArea(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            _Header(provider: provider),
            Expanded(
              child: _JournalContent(
                provider: provider,
                scrollController: _scrollController,
                onPageSelected: _loadPage,
                onSortSelected: _setSort,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Future<void> _loadPage(int page) async {
    await context.read<JournalProvider>().goToPage(page);
    await _scrollToTop();
  }

  Future<void> _setSort(PublicationListSort sort) async {
    await context.read<JournalProvider>().setPublicationSort(sort);
    await _scrollToTop();
  }

  Future<void> _scrollToTop() async {
    if (!mounted || !_scrollController.hasClients) return;
    await _scrollController.animateTo(
      0,
      duration: const Duration(milliseconds: 280),
      curve: Curves.easeOutCubic,
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
            'Publications',
            style: Theme.of(context).textTheme.headlineSmall?.copyWith(
              color: colorScheme.onSurface,
              fontWeight: FontWeight.w800,
            ),
          ),
          const SizedBox(height: 2),
          Text(
            provider.selectedKeyword.isEmpty
                ? 'Search a keyword from Home first'
                : provider.selectedKeyword,
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

class _JournalContent extends StatelessWidget {
  final JournalProvider provider;
  final ScrollController scrollController;
  final Future<void> Function(int page) onPageSelected;
  final Future<void> Function(PublicationListSort sort) onSortSelected;

  const _JournalContent({
    required this.provider,
    required this.scrollController,
    required this.onPageSelected,
    required this.onSortSelected,
  });

  @override
  Widget build(BuildContext context) {
    if (provider.selectedKeyword.isEmpty) {
      return const AppEmptyView(
        message: 'Search a keyword from Home first.',
        icon: Icons.library_books_outlined,
      );
    }

    if (provider.isLoading && provider.journalPublications.isEmpty) {
      return const AppLoading(message: 'Loading publications...');
    }

    final error = provider.error;
    if (error != null && provider.journalPublications.isEmpty) {
      return AppErrorView(
        error: error,
        onRetry: () => provider.analyzeKeyword(provider.selectedKeyword),
      );
    }

    return RefreshIndicator(
      onRefresh: () => provider.analyzeKeyword(provider.selectedKeyword),
      color: AppColors.primary,
      child: ListView(
        controller: scrollController,
        physics: const AlwaysScrollableScrollPhysics(),
        padding: const EdgeInsets.fromLTRB(16, 4, 16, 24),
        children: [
          _PublicationToolbar(
            provider: provider,
            onSortSelected: onSortSelected,
          ),
          const SizedBox(height: 10),
          if (provider.isLoadingJournalPublications &&
              provider.journalPublications.isEmpty)
            const AppLoading(message: 'Loading publications...')
          else if (provider.journalPublicationError != null &&
              provider.journalPublications.isEmpty)
            AppErrorView(
              error: provider.journalPublicationError!,
              onRetry: () =>
                  provider.goToPage(provider.currentPage, force: true),
            )
          else
            _PublicationList(publications: provider.journalPublications),
          if (provider.totalPages > 1) ...[
            const SizedBox(height: 14),
            _Pagination(provider: provider, onPageSelected: onPageSelected),
          ],
        ],
      ),
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
    final colorScheme = Theme.of(context).colorScheme;
    final sortLabel = switch (provider.publicationSort) {
      PublicationListSort.newest => 'Newest',
      PublicationListSort.oldest => 'Oldest',
      PublicationListSort.mostCited => 'Most cited',
    };

    return Row(
      children: [
        const Icon(Icons.article_outlined, size: 17, color: AppColors.primary),
        const SizedBox(width: 6),
        Expanded(
          child: Text(
            '${provider.journalTotalAvailable} publications',
            style: Theme.of(context).textTheme.labelLarge?.copyWith(
              color: colorScheme.onSurface,
              fontWeight: FontWeight.w700,
            ),
          ),
        ),
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
                    ].join(' · '),
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
                    child: Text('…'),
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
