import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

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
      appBar: AppBar(title: const Text('Journal')),
      body: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Expanded(
                  child: Text(
                    provider.hasSearched
                        ? 'Publications for "${provider.query}"'
                        : 'Publications',
                    style: Theme.of(context).textTheme.titleMedium,
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
                const SizedBox(width: 12),
                _YearSortControl(provider: provider),
              ],
            ),
            const SizedBox(height: 8),
            if (provider.hasSearched && provider.error == null)
              Text(
                provider.totalAvailable > 0
                    ? 'Page ${provider.currentPage} of ${provider.totalPages} '
                          '(${provider.totalAvailable} publications)'
                    : '${provider.publications.length} publications loaded',
                style: Theme.of(context).textTheme.bodySmall,
              ),
            const SizedBox(height: 8),
            Expanded(child: _PublicationResults(provider: provider)),
          ],
        ),
      ),
    );
  }
}

class _YearSortControl extends StatelessWidget {
  final PublicationProvider provider;

  const _YearSortControl({required this.provider});

  @override
  Widget build(BuildContext context) {
    return DropdownButton<PublicationYearSort>(
      value: provider.yearSort,
      hint: const Text('Sort'),
      items: const [
        DropdownMenuItem(
          value: PublicationYearSort.descending,
          child: Text('Desc'),
        ),
        DropdownMenuItem(
          value: PublicationYearSort.ascending,
          child: Text('Asc'),
        ),
      ],
      onChanged: provider.isLoading
          ? null
          : (sort) {
              if (sort != null) {
                context.read<PublicationProvider>().setYearSort(sort);
              }
            },
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
        message: 'Search a topic from Home to browse publications.',
        icon: Icons.article,
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

    final results = provider.analysisPublications;
    if (results.isEmpty) {
      return const AppEmptyView(
        message: 'No publications found.',
        icon: Icons.search_off,
      );
    }

    return Column(
      children: [
        Expanded(
          child: ListView.builder(
            itemCount: results.length,
            itemBuilder: (context, index) {
              final publication = results[index];
              return Card(
                elevation: 1,
                margin: const EdgeInsets.only(bottom: 10),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(8),
                ),
                child: ListTile(
                  contentPadding: const EdgeInsets.symmetric(
                    horizontal: 16,
                    vertical: 8,
                  ),
                  title: Text(
                    publication.title,
                    style: const TextStyle(fontWeight: FontWeight.w700),
                  ),
                  subtitle: Padding(
                    padding: const EdgeInsets.only(top: 6),
                    child: Text(
                      '${publication.year ?? 'No year'} | '
                      '${publication.journalName}\n'
                      '${publication.citationCount} citations',
                    ),
                  ),
                  isThreeLine: true,
                  trailing: const Icon(Icons.chevron_right),
                  onTap: () {
                    Navigator.push(
                      context,
                      MaterialPageRoute(
                        builder: (context) =>
                            PublicationDetailScreen(publication: publication),
                      ),
                    );
                  },
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

class _PaginationBar extends StatelessWidget {
  final PublicationProvider provider;

  const _PaginationBar({required this.provider});

  @override
  Widget build(BuildContext context) {
    if (provider.totalAvailable <= provider.perPage) {
      return const SizedBox.shrink();
    }

    final pages = _visiblePages(provider.currentPage, provider.totalPages);
    return Padding(
      padding: const EdgeInsets.only(top: 8),
      child: SingleChildScrollView(
        scrollDirection: Axis.horizontal,
        child: Row(
          children: [
            IconButton(
              tooltip: 'Previous page',
              onPressed: provider.canGoPrevious
                  ? () => provider.goToPage(provider.currentPage - 1)
                  : null,
              icon: const Icon(Icons.chevron_left),
            ),
            for (final page in pages)
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 2),
                child: page == null
                    ? const Padding(
                        padding: EdgeInsets.symmetric(horizontal: 8),
                        child: Text('...'),
                      )
                    : _PageButton(
                        page: page,
                        selected: page == provider.currentPage,
                        onPressed: provider.isLoading
                            ? null
                            : () => provider.goToPage(page),
                      ),
              ),
            IconButton(
              tooltip: 'Next page',
              onPressed: provider.canGoNext
                  ? () => provider.goToPage(provider.currentPage + 1)
                  : null,
              icon: const Icon(Icons.chevron_right),
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
      if (page > 1 && page < totalPages) {
        pages.add(page);
      }
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
    if (selected) {
      return FilledButton(onPressed: onPressed, child: Text(page.toString()));
    }
    return TextButton(onPressed: onPressed, child: Text(page.toString()));
  }
}
