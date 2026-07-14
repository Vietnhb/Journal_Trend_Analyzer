import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../core/constants/app_colors.dart';
import '../../core/widgets/app_empty_view.dart';
import '../../core/widgets/app_loading.dart';
import '../../data/models/bookmark.dart';
import '../providers/bookmark_provider.dart';
import 'journal_screen.dart';
import 'publication_detail_screen.dart';

class BookmarksScreen extends StatelessWidget {
  const BookmarksScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final bookmarks = context.watch<BookmarkProvider>();
    final colorScheme = Theme.of(context).colorScheme;

    return DefaultTabController(
      length: 2,
      child: Scaffold(
        backgroundColor: colorScheme.surfaceContainerLowest,
        appBar: AppBar(
          toolbarHeight: 68,
          title: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisSize: MainAxisSize.min,
            children: [
              const Text('Bookmarks'),
              Text(
                '${bookmarks.totalCount} saved items',
                style: Theme.of(context).textTheme.labelSmall?.copyWith(
                  color: colorScheme.onSurfaceVariant,
                  fontWeight: FontWeight.w500,
                ),
              ),
            ],
          ),
          bottom: PreferredSize(
            preferredSize: const Size.fromHeight(62),
            child: Padding(
              padding: const EdgeInsets.fromLTRB(16, 4, 16, 12),
              child: ConstrainedBox(
                constraints: const BoxConstraints(maxWidth: 760),
                child: Container(
                  height: 46,
                  padding: const EdgeInsets.all(4),
                  decoration: BoxDecoration(
                    color: colorScheme.surfaceContainerHighest,
                    borderRadius: BorderRadius.circular(14),
                  ),
                  child: TabBar(
                    dividerColor: Colors.transparent,
                    indicatorSize: TabBarIndicatorSize.tab,
                    indicator: BoxDecoration(
                      color: colorScheme.surface,
                      borderRadius: BorderRadius.circular(10),
                      boxShadow: [
                        BoxShadow(
                          color: colorScheme.shadow.withValues(alpha: 0.08),
                          blurRadius: 8,
                          offset: const Offset(0, 2),
                        ),
                      ],
                    ),
                    labelColor: colorScheme.onSurface,
                    unselectedLabelColor: colorScheme.onSurfaceVariant,
                    labelStyle: Theme.of(context).textTheme.labelMedium
                        ?.copyWith(fontWeight: FontWeight.w800),
                    tabs: [
                      _BookmarkTab(
                        icon: Icons.menu_book_outlined,
                        label: 'Journals',
                        count: bookmarks.journals.length,
                      ),
                      _BookmarkTab(
                        icon: Icons.article_outlined,
                        label: 'Publications',
                        count: bookmarks.publications.length,
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ),
        ),
        body: bookmarks.isLoading
            ? const AppLoading(message: 'Loading bookmarks...')
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

class _BookmarkTab extends StatelessWidget {
  final IconData icon;
  final String label;
  final int count;

  const _BookmarkTab({
    required this.icon,
    required this.label,
    required this.count,
  });

  @override
  Widget build(BuildContext context) {
    return Tab(
      child: Row(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(icon, size: 17),
          const SizedBox(width: 6),
          Flexible(
            child: Text(label, maxLines: 1, overflow: TextOverflow.ellipsis),
          ),
          const SizedBox(width: 6),
          _CountBadge(count: count),
        ],
      ),
    );
  }
}

class _CountBadge extends StatelessWidget {
  final int count;

  const _CountBadge({required this.count});

  @override
  Widget build(BuildContext context) {
    return Container(
      constraints: const BoxConstraints(minWidth: 22),
      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
      decoration: BoxDecoration(
        color: AppColors.primary.withValues(alpha: 0.10),
        borderRadius: BorderRadius.circular(999),
      ),
      child: Text(
        '$count',
        textAlign: TextAlign.center,
        style: Theme.of(context).textTheme.labelSmall?.copyWith(
          color: AppColors.primary,
          fontWeight: FontWeight.w800,
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

    return _BookmarkList(
      count: items.length,
      typeLabel: 'journal',
      children: [
        for (final item in items)
          _BookmarkCard(
            icon: Icons.menu_book_outlined,
            type: 'Journal',
            title: item.name,
            subtitle: [
              if (item.publisher != null) item.publisher!,
              if (item.countryCode != null) item.countryCode!,
              if (item.issnL != null) 'ISSN ${item.issnL}',
            ].join(' • '),
            metric: '${_compactCount(item.worksCount)} works',
            onTap: () => Navigator.push(
              context,
              MaterialPageRoute(
                builder: (_) => JournalDetailScreen(
                  initialJournal: item.toInitialProfile(),
                ),
              ),
            ),
            onRemove: () =>
                context.read<BookmarkProvider>().removeJournal(item.id),
          ),
      ],
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

    return _BookmarkList(
      count: items.length,
      typeLabel: 'publication',
      children: [
        for (final item in items)
          _BookmarkCard(
            icon: Icons.article_outlined,
            type: 'Publication',
            title: item.publication.title,
            subtitle: [
              item.publication.journalName,
              if (item.publication.year != null) '${item.publication.year}',
            ].join(' • '),
            metric: '${_compactCount(item.publication.citationCount)} cites',
            onTap: () => Navigator.push(
              context,
              MaterialPageRoute(
                builder: (_) =>
                    PublicationDetailScreen(publication: item.publication),
              ),
            ),
            onRemove: () => context.read<BookmarkProvider>().removePublication(
              item.publication.id,
            ),
          ),
      ],
    );
  }
}

class _BookmarkList extends StatelessWidget {
  final int count;
  final String typeLabel;
  final List<Widget> children;

  const _BookmarkList({
    required this.count,
    required this.typeLabel,
    required this.children,
  });

  @override
  Widget build(BuildContext context) {
    return Center(
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 760),
        child: ListView.separated(
          padding: const EdgeInsets.fromLTRB(16, 18, 16, 28),
          itemCount: children.length + 1,
          separatorBuilder: (_, index) =>
              SizedBox(height: index == 0 ? 14 : 10),
          itemBuilder: (context, index) {
            if (index == 0) {
              return _CollectionSummary(count: count, typeLabel: typeLabel);
            }
            return children[index - 1];
          },
        ),
      ),
    );
  }
}

class _CollectionSummary extends StatelessWidget {
  final int count;
  final String typeLabel;

  const _CollectionSummary({required this.count, required this.typeLabel});

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    final plural = count == 1 ? typeLabel : '${typeLabel}s';
    return Row(
      children: [
        Container(
          padding: const EdgeInsets.all(8),
          decoration: BoxDecoration(
            color: AppColors.primary.withValues(alpha: 0.10),
            borderRadius: BorderRadius.circular(10),
          ),
          child: const Icon(
            Icons.collections_bookmark_outlined,
            size: 18,
            color: AppColors.primary,
          ),
        ),
        const SizedBox(width: 10),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'Your saved ${plural.toLowerCase()}',
                style: Theme.of(
                  context,
                ).textTheme.titleSmall?.copyWith(fontWeight: FontWeight.w800),
              ),
              Text(
                '$count ${plural.toLowerCase()} ready for quick access',
                style: Theme.of(context).textTheme.labelSmall?.copyWith(
                  color: colorScheme.onSurfaceVariant,
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }
}

class _BookmarkCard extends StatelessWidget {
  final IconData icon;
  final String type;
  final String title;
  final String subtitle;
  final String metric;
  final VoidCallback onTap;
  final VoidCallback onRemove;

  const _BookmarkCard({
    required this.icon,
    required this.type,
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
      borderRadius: BorderRadius.circular(18),
      clipBehavior: Clip.antiAlias,
      child: InkWell(
        onTap: onTap,
        child: Container(
          padding: const EdgeInsets.fromLTRB(14, 14, 8, 14),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(18),
            border: Border.all(color: colorScheme.outlineVariant),
            boxShadow: [
              BoxShadow(
                color: colorScheme.shadow.withValues(alpha: 0.035),
                blurRadius: 14,
                offset: const Offset(0, 5),
              ),
            ],
          ),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Container(
                width: 44,
                height: 44,
                alignment: Alignment.center,
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    colors: [
                      AppColors.primary.withValues(alpha: 0.14),
                      AppColors.accent.withValues(alpha: 0.08),
                    ],
                    begin: Alignment.topLeft,
                    end: Alignment.bottomRight,
                  ),
                  borderRadius: BorderRadius.circular(13),
                ),
                child: Icon(icon, color: AppColors.primary, size: 21),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        _TypeBadge(label: type),
                        const Spacer(),
                        _MetricBadge(label: metric),
                      ],
                    ),
                    const SizedBox(height: 7),
                    Text(
                      title,
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                      style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                        color: colorScheme.onSurface,
                        fontWeight: FontWeight.w800,
                        height: 1.3,
                      ),
                    ),
                    if (subtitle.isNotEmpty) ...[
                      const SizedBox(height: 5),
                      Text(
                        subtitle,
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
              const SizedBox(width: 2),
              IconButton(
                tooltip: 'Remove bookmark',
                onPressed: onRemove,
                visualDensity: VisualDensity.compact,
                color: colorScheme.onSurfaceVariant,
                icon: const Icon(Icons.bookmark_remove_outlined),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _TypeBadge extends StatelessWidget {
  final String label;

  const _TypeBadge({required this.label});

  @override
  Widget build(BuildContext context) {
    return Text(
      label.toUpperCase(),
      style: Theme.of(context).textTheme.labelSmall?.copyWith(
        color: Theme.of(context).colorScheme.onSurfaceVariant,
        fontWeight: FontWeight.w800,
        letterSpacing: 0.7,
      ),
    );
  }
}

class _MetricBadge extends StatelessWidget {
  final String label;

  const _MetricBadge({required this.label});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
      decoration: BoxDecoration(
        color: AppColors.primary.withValues(alpha: 0.08),
        borderRadius: BorderRadius.circular(999),
      ),
      child: Text(
        label,
        style: Theme.of(context).textTheme.labelSmall?.copyWith(
          color: AppColors.primary,
          fontWeight: FontWeight.w800,
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
