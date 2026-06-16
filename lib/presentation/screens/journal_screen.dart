import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../core/constants/app_colors.dart';
import '../../core/widgets/app_empty_view.dart';
import '../../core/widgets/app_error_view.dart';
import '../../core/widgets/app_loading.dart';
import '../../data/repositories/publication_repository.dart';
import '../providers/publication_provider.dart';
import 'publication_detail_screen.dart';

class JournalScreen extends StatelessWidget {
  const JournalScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final provider = context.watch<PublicationProvider>();

    return Scaffold(
      body: SafeArea(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            _buildHeader(context, provider),
            Expanded(child: _PublicationResults(provider: provider)),
          ],
        ),
      ),
    );
  }

  Widget _buildHeader(BuildContext context, PublicationProvider provider) {
    return Container(
      padding: const EdgeInsets.fromLTRB(20, 16, 20, 0),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Journals',
                      style:
                          Theme.of(context).textTheme.headlineSmall?.copyWith(
                                color: AppColors.textPrimary,
                                fontWeight: FontWeight.w800,
                              ),
                    ),
                    if (provider.hasSearched && provider.error == null)
                      Padding(
                        padding: const EdgeInsets.only(top: 2),
                        child: Text(
                          provider.totalAvailable > 0
                              ? '${provider.totalAvailable} publications · Page ${provider.currentPage}/${provider.totalPages}'
                              : '${provider.publications.length} publications loaded',
                          style:
                              Theme.of(context).textTheme.bodySmall?.copyWith(
                                    color: AppColors.textSecondary,
                                  ),
                        ),
                      ),
                  ],
                ),
              ),
              if (provider.hasSearched && provider.error == null)
                _SortChipControl(provider: provider),
            ],
          ),
          if (provider.hasSearched)
            Padding(
              padding: const EdgeInsets.only(top: 10),
              child: Container(
                padding: const EdgeInsets.symmetric(
                  horizontal: 12,
                  vertical: 8,
                ),
                decoration: BoxDecoration(
                  color: AppColors.primary.withValues(alpha: 0.08),
                  borderRadius: BorderRadius.circular(10),
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    const Icon(
                      Icons.search_rounded,
                      size: 14,
                      color: AppColors.primary,
                    ),
                    const SizedBox(width: 6),
                    Flexible(
                      child: Text(
                        '"${provider.query}"',
                        style: Theme.of(context).textTheme.labelMedium
                            ?.copyWith(color: AppColors.primary),
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                  ],
                ),
              ),
            ),
          const SizedBox(height: 12),
          const Divider(height: 1),
        ],
      ),
    );
  }
}

class _SortChipControl extends StatelessWidget {
  final PublicationProvider provider;

  const _SortChipControl({required this.provider});

  @override
  Widget build(BuildContext context) {
    final isDesc =
        provider.yearSort == PublicationYearSort.descending;

    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        const Icon(
          Icons.sort_rounded,
          size: 16,
          color: AppColors.textSecondary,
        ),
        const SizedBox(width: 4),
        _SortChip(
          label: 'Newest',
          selected: isDesc,
          onTap: provider.isLoading
              ? null
              : () => context
                    .read<PublicationProvider>()
                    .setYearSort(PublicationYearSort.descending),
        ),
        const SizedBox(width: 4),
        _SortChip(
          label: 'Oldest',
          selected: !isDesc,
          onTap: provider.isLoading
              ? null
              : () => context
                    .read<PublicationProvider>()
                    .setYearSort(PublicationYearSort.ascending),
        ),
      ],
    );
  }
}

class _SortChip extends StatelessWidget {
  final String label;
  final bool selected;
  final VoidCallback? onTap;

  const _SortChip({
    required this.label,
    required this.selected,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 180),
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
        decoration: BoxDecoration(
          color: selected
              ? AppColors.primary
              : AppColors.surfaceVariant,
          borderRadius: BorderRadius.circular(20),
          border: Border.all(
            color: selected ? AppColors.primary : AppColors.borderLight,
          ),
        ),
        child: Text(
          label,
          style: TextStyle(
            fontSize: 12,
            fontWeight: FontWeight.w600,
            color: selected ? Colors.white : AppColors.textSecondary,
          ),
        ),
      ),
    );
  }
}

class _PublicationResults extends StatelessWidget {
  final PublicationProvider provider;

  const _PublicationResults({required this.provider});

  @override
  Widget build(BuildContext context) {
    if (!provider.hasSearched) {
      return const AppEmptyView(
        message:
            'Search a research topic from Home\nto browse publications.',
        icon: Icons.article_outlined,
      );
    }

    if (provider.isLoading) {
      return const AppLoading(
        message: 'Loading OpenAlex publications...',
      );
    }

    final error = provider.error;
    if (error != null && provider.analysisPublications.isEmpty) {
      return AppErrorView(
        error: error,
        onRetry: provider.query.isEmpty
            ? null
            : () =>
                context.read<PublicationProvider>().search(provider.query),
      );
    }

    final results = provider.analysisPublications;
    if (results.isEmpty) {
      return const AppEmptyView(
        message: 'No publications found.',
        icon: Icons.search_off_rounded,
      );
    }

    return Column(
      children: [
        Expanded(
          child: ListView.builder(
            padding: const EdgeInsets.fromLTRB(16, 12, 16, 8),
            itemCount: results.length,
            itemBuilder: (context, index) {
              final pub = results[index];
              return _PublicationCard(
                publication: pub,
                onTap: () => Navigator.push(
                  context,
                  MaterialPageRoute(
                    builder: (_) =>
                        PublicationDetailScreen(publication: pub),
                  ),
                ),
              );
            },
          ),
        ),
        _PaginationBar(provider: provider),
      ],
    );
  }
}

class _PublicationCard extends StatelessWidget {
  final dynamic publication;
  final VoidCallback onTap;

  const _PublicationCard({
    required this.publication,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final year = publication.year;
    final citations = publication.citationCount as int;

    return Container(
      margin: const EdgeInsets.only(bottom: 10),
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: AppColors.borderLight),
        boxShadow: [
          BoxShadow(
            color: AppColors.textPrimary.withValues(alpha: 0.04),
            blurRadius: 8,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(14),
        child: Padding(
          padding: const EdgeInsets.all(14),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                publication.title as String,
                style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                      fontWeight: FontWeight.w700,
                      color: AppColors.textPrimary,
                      height: 1.4,
                    ),
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
              ),
              const SizedBox(height: 8),
              Text(
                publication.journalName as String,
                style: Theme.of(context).textTheme.bodySmall?.copyWith(
                      color: AppColors.textSecondary,
                    ),
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
              ),
              const SizedBox(height: 10),
              Row(
                children: [
                  if (year != null)
                    _MetaBadge(
                      icon: Icons.calendar_today_outlined,
                      label: year.toString(),
                      color: AppColors.info,
                    ),
                  if (year != null) const SizedBox(width: 6),
                  _MetaBadge(
                    icon: Icons.format_quote_rounded,
                    label: '$citations citations',
                    color: citations > 50
                        ? AppColors.success
                        : AppColors.textSecondary,
                  ),
                  const Spacer(),
                  const Icon(
                    Icons.arrow_forward_ios_rounded,
                    size: 13,
                    color: AppColors.textHint,
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _MetaBadge extends StatelessWidget {
  final IconData icon;
  final String label;
  final Color color;

  const _MetaBadge({
    required this.icon,
    required this.label,
    required this.color,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.1),
        borderRadius: BorderRadius.circular(6),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 11, color: color),
          const SizedBox(width: 4),
          Text(
            label,
            style: TextStyle(
              fontSize: 11,
              fontWeight: FontWeight.w600,
              color: color,
            ),
          ),
        ],
      ),
    );
  }
}

class _PaginationBar extends StatelessWidget {
  final PublicationProvider provider;

  const _PaginationBar({required this.provider});

  @override
  Widget build(BuildContext context) {
    if (provider.totalAvailable <= provider.perPage) {
      return const SizedBox.shrink();
    }

    final pages = _visiblePages(provider.currentPage, provider.totalPages);
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
      decoration: const BoxDecoration(
        border: Border(top: BorderSide(color: AppColors.borderLight)),
        color: AppColors.surface,
      ),
      child: SingleChildScrollView(
        scrollDirection: Axis.horizontal,
        child: Row(
          children: [
            _PagIconBtn(
              icon: Icons.chevron_left_rounded,
              tooltip: 'Previous page',
              enabled: provider.canGoPrevious,
              onPressed: () =>
                  provider.goToPage(provider.currentPage - 1),
            ),
            for (final page in pages)
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 2),
                child: page == null
                    ? const Padding(
                        padding: EdgeInsets.symmetric(horizontal: 6),
                        child: Text(
                          '···',
                          style: TextStyle(color: AppColors.textHint),
                        ),
                      )
                    : _PageButton(
                        page: page,
                        selected: page == provider.currentPage,
                        onPressed: provider.isLoading
                            ? null
                            : () => provider.goToPage(page),
                      ),
              ),
            _PagIconBtn(
              icon: Icons.chevron_right_rounded,
              tooltip: 'Next page',
              enabled: provider.canGoNext,
              onPressed: () =>
                  provider.goToPage(provider.currentPage + 1),
            ),
          ],
        ),
      ),
    );
  }

  List<int?> _visiblePages(int currentPage, int totalPages) {
    if (totalPages <= 7) {
      return [for (var page = 1; page <= totalPages; page++) page];
    }
    final pages = <int?>{1, totalPages};
    for (var page = currentPage - 1; page <= currentPage + 1; page++) {
      if (page > 1 && page < totalPages) pages.add(page);
    }
    final sorted = pages.toList()..sort((a, b) => a!.compareTo(b!));
    final visible = <int?>[];
    for (final page in sorted) {
      if (visible.isNotEmpty && page! - visible.last! > 1) {
        visible.add(null);
      }
      visible.add(page);
    }
    return visible;
  }
}

class _PagIconBtn extends StatelessWidget {
  final IconData icon;
  final String tooltip;
  final bool enabled;
  final VoidCallback onPressed;

  const _PagIconBtn({
    required this.icon,
    required this.tooltip,
    required this.enabled,
    required this.onPressed,
  });

  @override
  Widget build(BuildContext context) {
    return Tooltip(
      message: tooltip,
      child: InkWell(
        onTap: enabled ? onPressed : null,
        borderRadius: BorderRadius.circular(8),
        child: Container(
          padding: const EdgeInsets.all(6),
          child: Icon(
            icon,
            size: 20,
            color: enabled ? AppColors.primary : AppColors.textHint,
          ),
        ),
      ),
    );
  }
}

class _PageButton extends StatelessWidget {
  final int page;
  final bool selected;
  final VoidCallback? onPressed;

  const _PageButton({
    required this.page,
    required this.selected,
    required this.onPressed,
  });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onPressed,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 150),
        constraints: const BoxConstraints(minWidth: 34),
        height: 34,
        padding: const EdgeInsets.symmetric(horizontal: 8),
        decoration: BoxDecoration(
          color: selected ? AppColors.primary : Colors.transparent,
          borderRadius: BorderRadius.circular(8),
          border: Border.all(
            color: selected ? AppColors.primary : AppColors.borderLight,
          ),
        ),
        alignment: Alignment.center,
        child: Text(
          page.toString(),
          style: TextStyle(
            fontSize: 13,
            fontWeight: FontWeight.w600,
            color: selected ? Colors.white : AppColors.textSecondary,
          ),
        ),
      ),
    );
  }
}
