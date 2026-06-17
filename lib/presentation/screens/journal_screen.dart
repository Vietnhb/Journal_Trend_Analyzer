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
  final String? journalFilter;
  final String? authorFilter;

  const JournalScreen({super.key, this.journalFilter, this.authorFilter});

  @override
  Widget build(BuildContext context) {
    final provider = context.watch<PublicationProvider>();

    return Scaffold(
      body: SafeArea(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            _buildHeader(context, provider),
            Expanded(
              child: _PublicationResults(
                provider: provider,
                journalFilter: journalFilter,
                authorFilter: authorFilter,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildHeader(BuildContext context, PublicationProvider provider) {
    final colorScheme = Theme.of(context).colorScheme;

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
                      journalFilter != null
                          ? 'Journal: $journalFilter'
                          : authorFilter != null
                          ? 'Author: $authorFilter'
                          : 'Journals',
                      style: Theme.of(context).textTheme.headlineSmall
                          ?.copyWith(
                            color: colorScheme.onSurface,
                            fontWeight: FontWeight.w800,
                          ),
                    ),
                    if (provider.hasSearched && provider.error == null)
                      Padding(
                        padding: const EdgeInsets.only(top: 2),
                        child: Builder(
                          builder: (ctx) {
                            if (journalFilter != null || authorFilter != null) {
                              final all = provider.analysisPublications;
                              final filtered = all.where((p) {
                                if (journalFilter != null) {
                                  return p.journalName.toLowerCase().contains(
                                    journalFilter!.toLowerCase(),
                                  );
                                }
                                if (authorFilter != null) {
                                  return p.authors.any(
                                    (a) => a.toLowerCase().contains(
                                      authorFilter!.toLowerCase(),
                                    ),
                                  );
                                }
                                return true;
                              }).toList();
                              return Text(
                                '${filtered.length} publications',
                                style: Theme.of(context).textTheme.bodySmall
                                    ?.copyWith(
                                      color: colorScheme.onSurfaceVariant,
                                    ),
                              );
                            }
                            return Padding(
                              padding: const EdgeInsets.only(top: 2),
                              child: Text(
                                provider.totalAvailable > 0
                                    ? '${provider.totalAvailable} publications · Page ${provider.currentPage}/${provider.totalPages}'
                                    : '${provider.publications.length} publications loaded',
                                style: Theme.of(context).textTheme.bodySmall
                                    ?.copyWith(
                                      color: colorScheme.onSurfaceVariant,
                                    ),
                              ),
                            );
                          },
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
    final isDesc = provider.yearSort == PublicationYearSort.descending;
    final mutedColor = Theme.of(context).colorScheme.onSurfaceVariant;

    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Icon(Icons.sort_rounded, size: 16, color: mutedColor),
        const SizedBox(width: 4),
        _SortChip(
          label: 'Newest',
          selected: isDesc,
          onTap: provider.isLoading
              ? null
              : () => context.read<PublicationProvider>().setYearSort(
                  PublicationYearSort.descending,
                ),
        ),
        const SizedBox(width: 4),
        _SortChip(
          label: 'Oldest',
          selected: !isDesc,
          onTap: provider.isLoading
              ? null
              : () => context.read<PublicationProvider>().setYearSort(
                  PublicationYearSort.ascending,
                ),
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
    final colorScheme = Theme.of(context).colorScheme;

    return GestureDetector(
      onTap: onTap,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 180),
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
        decoration: BoxDecoration(
          color: selected
              ? AppColors.primary
              : colorScheme.surfaceContainerHighest,
          borderRadius: BorderRadius.circular(20),
          border: Border.all(
            color: selected ? AppColors.primary : colorScheme.outlineVariant,
          ),
        ),
        child: Text(
          label,
          style: TextStyle(
            fontSize: 12,
            fontWeight: FontWeight.w600,
            color: selected ? Colors.white : colorScheme.onSurfaceVariant,
          ),
        ),
      ),
    );
  }
}

class _PublicationResults extends StatelessWidget {
  final PublicationProvider provider;
  final String? journalFilter;
  final String? authorFilter;

  const _PublicationResults({
    required this.provider,
    this.journalFilter,
    this.authorFilter,
  });

  @override
  Widget build(BuildContext context) {
    if (!provider.hasSearched) {
      return const AppEmptyView(
        message:
            'Search by title, abstract, author, journal, or DOI\nfrom Home to browse publications.',
        icon: Icons.article_outlined,
      );
    }

    if (provider.isLoading) {
      return const AppLoading(message: 'Loading OpenAlex publications...');
    }

    final error = provider.error;
    if (error != null && provider.analysisPublications.isEmpty) {
      return AppErrorView(
        error: error,
        onRetry: provider.query.isEmpty
            ? null
            : () => context.read<PublicationProvider>().search(provider.query),
      );
    }

    final all = provider.analysisPublications;
    final results = (journalFilter != null)
        ? all
              .where(
                (p) => p.journalName.toLowerCase().contains(
                  journalFilter!.toLowerCase(),
                ),
              )
              .toList()
        : (authorFilter != null)
        ? all
              .where(
                (p) => p.authors.any(
                  (a) => a.toLowerCase().contains(authorFilter!.toLowerCase()),
                ),
              )
              .toList()
        : all;
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
                    builder: (_) => PublicationDetailScreen(publication: pub),
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

  const _PublicationCard({required this.publication, required this.onTap});

  @override
  Widget build(BuildContext context) {
    final year = publication.year;
    final citations = publication.citationCount as int;
    final colorScheme = Theme.of(context).colorScheme;

    return Container(
      margin: const EdgeInsets.only(bottom: 10),
      decoration: BoxDecoration(
        color: colorScheme.surface,
        borderRadius: BorderRadius.circular(14),
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
                  color: colorScheme.onSurface,
                  height: 1.4,
                ),
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
              ),
              const SizedBox(height: 8),
              Text(
                publication.journalName as String,
                style: Theme.of(context).textTheme.bodySmall?.copyWith(
                  color: colorScheme.onSurfaceVariant,
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
                        : colorScheme.onSurfaceVariant,
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
    final colorScheme = Theme.of(context).colorScheme;
    return Container(
      padding: const EdgeInsets.fromLTRB(10, 8, 10, 10),
      decoration: BoxDecoration(
        border: Border(top: BorderSide(color: colorScheme.outlineVariant)),
        color: colorScheme.surface,
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          _PagIconBtn(
            icon: Icons.first_page_rounded,
            tooltip: 'First page',
            enabled: provider.canGoPrevious,
            onPressed: () => provider.goToPage(1),
          ),
          _PagIconBtn(
            icon: Icons.chevron_left_rounded,
            tooltip: 'Previous page',
            enabled: provider.canGoPrevious,
            onPressed: () => provider.goToPage(provider.currentPage - 1),
          ),
          for (final page in pages)
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 1),
              child: page == null
                  ? const Padding(
                      padding: EdgeInsets.zero,
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
            onPressed: () => provider.goToPage(provider.currentPage + 1),
          ),
          _PagIconBtn(
            icon: Icons.last_page_rounded,
            tooltip: 'Last page',
            enabled: provider.canGoNext,
            onPressed: () => provider.goToPage(provider.totalPages),
          ),
        ],
      ),
    );
  }

  List<int?> _visiblePages(int currentPage, int totalPages) {
    if (totalPages <= 5) {
      return [for (var page = 1; page <= totalPages; page++) page];
    }

    final pages = <int?>[1];
    if (currentPage > 2) {
      pages.add(null);
    }
    for (var page = currentPage - 1; page <= currentPage + 1; page++) {
      if (page > 1 && page < totalPages) {
        pages.add(page);
      }
    }
    if (currentPage < totalPages - 1) {
      pages.add(null);
    }
    pages.add(totalPages);
    return pages;
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
    final colorScheme = Theme.of(context).colorScheme;

    return Tooltip(
      message: tooltip,
      child: InkWell(
        onTap: enabled ? onPressed : null,
        borderRadius: BorderRadius.circular(10),
        child: SizedBox(
          width: 30,
          height: 34,
          child: Icon(
            icon,
            size: 19,
            color: enabled ? AppColors.primary : colorScheme.onSurfaceVariant,
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
    final colorScheme = Theme.of(context).colorScheme;

    return InkWell(
      onTap: onPressed,
      borderRadius: BorderRadius.circular(10),
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 150),
        constraints: const BoxConstraints(minWidth: 32),
        height: 34,
        padding: const EdgeInsets.symmetric(horizontal: 7),
        decoration: BoxDecoration(
          color: selected ? AppColors.primary : Colors.transparent,
          borderRadius: BorderRadius.circular(10),
          border: Border.all(
            color: selected ? AppColors.primary : colorScheme.outlineVariant,
          ),
        ),
        alignment: Alignment.center,
        child: Text(
          page.toString(),
          style: TextStyle(
            fontSize: 13,
            fontWeight: FontWeight.w600,
            color: selected ? Colors.white : colorScheme.onSurfaceVariant,
          ),
        ),
      ),
    );
  }
}
