import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../core/constants/app_colors.dart';
import '../../core/widgets/app_empty_view.dart';
import '../../data/models/bookmark.dart';
import '../providers/bookmark_provider.dart';
import 'journal_screen.dart';
import 'publication_detail_screen.dart';

class BookmarksScreen extends StatelessWidget {
  const BookmarksScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final bookmarks = context.watch<BookmarkProvider>();

    return DefaultTabController(
      length: 2,
      child: Scaffold(
        appBar: AppBar(
          title: const Text('Bookmarks'),
          bottom: TabBar(
            tabs: [
              Tab(text: 'Journals (${bookmarks.journals.length})'),
              Tab(text: 'Publications (${bookmarks.publications.length})'),
            ],
          ),
        ),
        body: bookmarks.isLoading
            ? const Center(child: CircularProgressIndicator())
            : TabBarView(
                children: [
                  _JournalBookmarksTab(items: bookmarks.journals),
                  _PublicationBookmarksTab(items: bookmarks.publications),
                ],
              ),
      ),
    );
  }
}

class _JournalBookmarksTab extends StatelessWidget {
  final List<JournalBookmark> items;

  const _JournalBookmarksTab({required this.items});

  @override
  Widget build(BuildContext context) {
    if (items.isEmpty) {
      return const AppEmptyView(
        message: 'Bookmarked journals will appear here.',
        icon: Icons.bookmark_border_rounded,
      );
    }

    return ListView.separated(
      padding: const EdgeInsets.fromLTRB(16, 16, 16, 24),
      itemCount: items.length,
      separatorBuilder: (_, _) => const SizedBox(height: 10),
      itemBuilder: (context, index) {
        final item = items[index];
        return _BookmarkCard(
          icon: Icons.menu_book_outlined,
          title: item.name,
          subtitle: [
            if (item.publisher != null) item.publisher!,
            if (item.countryCode != null) item.countryCode!,
            if (item.issnL != null) 'ISSN ${item.issnL}',
          ].join(' | '),
          metric: '${_compactCount(item.worksCount)} works',
          onTap: () => Navigator.push(
            context,
            MaterialPageRoute(
              builder: (_) =>
                  JournalDetailScreen(initialJournal: item.toInitialProfile()),
            ),
          ),
          onRemove: () =>
              context.read<BookmarkProvider>().removeJournal(item.id),
        );
      },
    );
  }
}

class _PublicationBookmarksTab extends StatelessWidget {
  final List<PublicationBookmark> items;

  const _PublicationBookmarksTab({required this.items});

  @override
  Widget build(BuildContext context) {
    if (items.isEmpty) {
      return const AppEmptyView(
        message: 'Bookmarked publications will appear here.',
        icon: Icons.bookmark_border_rounded,
      );
    }

    return ListView.separated(
      padding: const EdgeInsets.fromLTRB(16, 16, 16, 24),
      itemCount: items.length,
      separatorBuilder: (_, _) => const SizedBox(height: 10),
      itemBuilder: (context, index) {
        final item = items[index];
        final publication = item.publication;
        return _BookmarkCard(
          icon: Icons.article_outlined,
          title: publication.title,
          subtitle: [
            publication.journalName,
            if (publication.year != null) '${publication.year}',
          ].join(' | '),
          metric: '${_compactCount(publication.citationCount)} cites',
          onTap: () => Navigator.push(
            context,
            MaterialPageRoute(
              builder: (_) => PublicationDetailScreen(publication: publication),
            ),
          ),
          onRemove: () => context.read<BookmarkProvider>().removePublication(
            publication.id,
          ),
        );
      },
    );
  }
}

class _BookmarkCard extends StatelessWidget {
  final IconData icon;
  final String title;
  final String subtitle;
  final String metric;
  final VoidCallback onTap;
  final VoidCallback onRemove;

  const _BookmarkCard({
    required this.icon,
    required this.title,
    required this.subtitle,
    required this.metric,
    required this.onTap,
    required this.onRemove,
  });

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;

    return Material(
      color: colorScheme.surface,
      borderRadius: BorderRadius.circular(12),
      clipBehavior: Clip.antiAlias,
      child: InkWell(
        onTap: onTap,
        child: Container(
          padding: const EdgeInsets.fromLTRB(14, 12, 8, 12),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(12),
            border: Border.all(color: colorScheme.outlineVariant),
          ),
          child: Row(
            children: [
              Container(
                width: 38,
                height: 38,
                alignment: Alignment.center,
                decoration: BoxDecoration(
                  color: AppColors.primary.withValues(alpha: 0.10),
                  borderRadius: BorderRadius.circular(10),
                ),
                child: Icon(icon, color: AppColors.primary, size: 20),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      title,
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                      style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                        color: colorScheme.onSurface,
                        fontWeight: FontWeight.w800,
                      ),
                    ),
                    if (subtitle.isNotEmpty) ...[
                      const SizedBox(height: 3),
                      Text(
                        subtitle,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: Theme.of(context).textTheme.labelSmall?.copyWith(
                          color: colorScheme.onSurfaceVariant,
                        ),
                      ),
                    ],
                    const SizedBox(height: 6),
                    Text(
                      metric,
                      style: Theme.of(context).textTheme.labelSmall?.copyWith(
                        color: AppColors.primary,
                        fontWeight: FontWeight.w800,
                      ),
                    ),
                  ],
                ),
              ),
              IconButton(
                tooltip: 'Remove bookmark',
                onPressed: onRemove,
                icon: const Icon(Icons.bookmark_remove_outlined),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

String _compactCount(int value) {
  if (value >= 1000000) return '${(value / 1000000).toStringAsFixed(1)}M';
  if (value >= 1000) return '${(value / 1000).toStringAsFixed(1)}K';
  return '$value';
}
