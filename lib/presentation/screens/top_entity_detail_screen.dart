import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';

import '../../core/constants/app_colors.dart';
import '../../core/widgets/app_error_view.dart';
import '../../data/models/publication.dart';
import '../../data/models/ranked_entity.dart';
import '../providers/journal_provider.dart';
import 'publication_detail_screen.dart';

enum TopEntityType { journal }

class TopEntityDetailScreen extends StatelessWidget {
  final TopEntityType type;
  final String entityId;
  final String name;
  final int worksCount;
  final String topic;

  const TopEntityDetailScreen({
    super.key,
    required this.type,
    required this.entityId,
    required this.name,
    required this.worksCount,
    required this.topic,
  });

  @override
  Widget build(BuildContext context) {
    final provider = context.watch<JournalProvider>();
    final matches = provider.journals.where((item) => item.id == entityId);
    final selected = provider.selectedJournal;
    final journal = selected?.id == entityId
        ? selected!
        : matches.isNotEmpty
        ? matches.first
        : RankedEntity(id: entityId, name: name, worksCount: worksCount);

    final detailCards = <Widget>[
      _OverviewCard(provider: provider),
      const SizedBox(height: 14),
      _JournalMetaCard(journal: journal),
      const SizedBox(height: 14),
      if (provider.analyticsError != null)
        AppErrorView(
          error: provider.analyticsError!,
          onRetry: () => provider.selectJournal(journal),
        )
      else
        _PublicationsCard(
          keyword: provider.selectedKeyword,
          publications: provider.journalPublications,
        ),
    ];

    return Scaffold(
      body: CustomScrollView(
        slivers: [
          _AppBar(
            journal: journal,
            topic: topic,
            relatedArticles: provider.totalWorks,
          ),
          SliverPadding(
            padding: const EdgeInsets.fromLTRB(16, 20, 16, 24),
            sliver: SliverList(
              delegate: SliverChildListDelegate.fixed(detailCards),
            ),
          ),
        ],
      ),
    );
  }
}

class _AppBar extends StatelessWidget {
  final RankedEntity journal;
  final String topic;
  final int relatedArticles;

  const _AppBar({
    required this.journal,
    required this.topic,
    required this.relatedArticles,
  });

  @override
  Widget build(BuildContext context) {
    return SliverAppBar(
      expandedHeight: 196,
      pinned: true,
      backgroundColor: AppColors.primary,
      iconTheme: const IconThemeData(color: Colors.white),
      systemOverlayStyle: SystemUiOverlayStyle.light,
      title: Text(
        'Journal Detail',
        style: Theme.of(context).textTheme.titleMedium?.copyWith(
          color: Colors.white,
          fontWeight: FontWeight.w600,
        ),
      ),
      flexibleSpace: FlexibleSpaceBar(
        background: Container(
          decoration: const BoxDecoration(
            gradient: LinearGradient(
              colors: [AppColors.primary, AppColors.accent],
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
            ),
          ),
          padding: const EdgeInsets.fromLTRB(20, 88, 20, 18),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisAlignment: MainAxisAlignment.end,
            children: [
              Container(
                padding: const EdgeInsets.symmetric(
                  horizontal: 10,
                  vertical: 4,
                ),
                decoration: BoxDecoration(
                  color: Colors.white.withValues(alpha: 0.2),
                  borderRadius: BorderRadius.circular(20),
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    const Icon(
                      Icons.book_outlined,
                      size: 13,
                      color: Colors.white,
                    ),
                    const SizedBox(width: 4),
                    Text(
                      '$relatedArticles related articles for "$topic"',
                      style: const TextStyle(
                        color: Colors.white,
                        fontSize: 12,
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 8),
              Text(
                journal.name,
                maxLines: 3,
                overflow: TextOverflow.ellipsis,
                style: const TextStyle(
                  color: Colors.white,
                  fontSize: 20,
                  fontWeight: FontWeight.w800,
                  height: 1.2,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _OverviewCard extends StatelessWidget {
  final JournalProvider provider;

  const _OverviewCard({required this.provider});

  @override
  Widget build(BuildContext context) {
    return _Card(
      title: 'Journal Dashboard',
      children: [
        Row(
          children: [
            _Stat(
              icon: Icons.article_rounded,
              color: AppColors.primary,
              label: 'Related Articles',
              value: '${provider.totalWorks}',
            ),
            _Stat(
              icon: Icons.format_quote_rounded,
              color: AppColors.success,
              label: 'Avg Citations per Article',
              value: provider.avgCitationCount?.toString() ?? '-',
            ),
            _Stat(
              icon: Icons.calendar_today_rounded,
              color: AppColors.gold,
              label: 'Most Active Year',
              value: provider.mostActiveYear?.toString() ?? '-',
            ),
          ],
        ),
      ],
    );
  }
}

class _JournalMetaCard extends StatelessWidget {
  final RankedEntity journal;

  const _JournalMetaCard({required this.journal});

  @override
  Widget build(BuildContext context) {
    final years = [
      journal.firstPublicationYear,
      journal.lastPublicationYear,
    ].whereType<int>().toList();

    return _Card(
      title: 'About this Journal',
      children: [
        _MetaRow(label: 'Publisher', value: journal.publisher ?? '-'),
        _MetaRow(label: 'ISSN-L', value: journal.issnL ?? '-'),
        _MetaRow(
          label: 'Year range',
          value: years.length == 2 ? '${years.first}-${years.last}' : '-',
        ),
        _MetaRow(label: 'Homepage', value: journal.homepageUrl ?? '-'),
      ],
    );
  }
}

class _PublicationsCard extends StatelessWidget {
  final String keyword;
  final List<Publication> publications;

  const _PublicationsCard({required this.keyword, required this.publications});

  @override
  Widget build(BuildContext context) {
    return _Card(
      title: 'Publications related to "$keyword"',
      children: [
        if (publications.isEmpty)
          Text(
            'No relevant publications found.',
            style: Theme.of(context).textTheme.bodyMedium,
          ),
        for (var i = 0; i < publications.length; i++) ...[
          if (i > 0) const Divider(height: 18),
          _PublicationTile(
            publication: publications[i],
            onTap: () => Navigator.push(
              context,
              MaterialPageRoute(
                builder: (_) =>
                    PublicationDetailScreen(publication: publications[i]),
              ),
            ),
          ),
        ],
      ],
    );
  }
}

class _PublicationTile extends StatelessWidget {
  final Publication publication;
  final VoidCallback onTap;

  const _PublicationTile({required this.publication, required this.onTap});

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    final date = publication.publicationDate ?? publication.year?.toString();

    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(10),
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: 6),
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
                  Text(
                    publication.title,
                    maxLines: 3,
                    overflow: TextOverflow.ellipsis,
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
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                    style: Theme.of(context).textTheme.bodySmall?.copyWith(
                      color: colorScheme.onSurfaceVariant,
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(width: 6),
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

class _Card extends StatelessWidget {
  final String title;
  final List<Widget> children;

  const _Card({required this.title, required this.children});

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;

    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: colorScheme.surface,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: colorScheme.outlineVariant),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            title,
            style: Theme.of(context).textTheme.titleSmall?.copyWith(
              color: colorScheme.onSurface,
              fontWeight: FontWeight.w700,
            ),
          ),
          const SizedBox(height: 12),
          ...children,
        ],
      ),
    );
  }
}

class _Stat extends StatelessWidget {
  final IconData icon;
  final Color color;
  final String label;
  final String value;

  const _Stat({
    required this.icon,
    required this.color,
    required this.label,
    required this.value,
  });

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;

    return Expanded(
      child: Row(
        children: [
          Container(
            width: 34,
            height: 34,
            decoration: BoxDecoration(
              color: color.withValues(alpha: 0.12),
              borderRadius: BorderRadius.circular(9),
            ),
            alignment: Alignment.center,
            child: Icon(icon, size: 17, color: color),
          ),
          const SizedBox(width: 8),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  value,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: Theme.of(context).textTheme.titleMedium?.copyWith(
                    color: colorScheme.onSurface,
                    fontWeight: FontWeight.w800,
                  ),
                ),
                Text(
                  label,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: Theme.of(context).textTheme.labelSmall?.copyWith(
                    color: colorScheme.onSurfaceVariant,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _MetaRow extends StatelessWidget {
  final String label;
  final String value;

  const _MetaRow({required this.label, required this.value});

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;

    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 5),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Expanded(
            child: Text(
              label,
              style: Theme.of(context).textTheme.bodySmall?.copyWith(
                color: colorScheme.onSurfaceVariant,
              ),
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            flex: 2,
            child: Text(
              value,
              textAlign: TextAlign.right,
              style: Theme.of(context).textTheme.bodySmall?.copyWith(
                color: colorScheme.onSurface,
                fontWeight: FontWeight.w600,
              ),
            ),
          ),
        ],
      ),
    );
  }
}
