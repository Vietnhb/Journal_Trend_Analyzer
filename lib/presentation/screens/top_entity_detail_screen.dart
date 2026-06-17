import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';

import '../../core/constants/app_colors.dart';
import '../../data/models/ranked_entity.dart';
import '../providers/journal_provider.dart';

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
    final journal = matches.isNotEmpty
        ? matches.first
        : provider.selectedJournal ??
              RankedEntity(id: entityId, name: name, worksCount: worksCount);

    return Scaffold(
      body: CustomScrollView(
        slivers: [
          _AppBar(journal: journal, topic: topic),
          SliverPadding(
            padding: const EdgeInsets.fromLTRB(16, 20, 16, 24),
            sliver: SliverList(
              delegate: SliverChildListDelegate.fixed([
                _OverviewCard(journal: journal),
                const SizedBox(height: 14),
                _JournalMetaCard(journal: journal),
                const SizedBox(height: 14),
                _TopicsCard(topics: journal.topics),
              ]),
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

  const _AppBar({required this.journal, required this.topic});

  @override
  Widget build(BuildContext context) {
    return SliverAppBar(
      expandedHeight: 196,
      pinned: true,
      backgroundColor: AppColors.primary,
      iconTheme: const IconThemeData(color: Colors.white),
      systemOverlayStyle: SystemUiOverlayStyle.light,
      title: Text(
        'Journal Source',
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
                      '${journal.worksCount} source works for "$topic"',
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
  final RankedEntity journal;

  const _OverviewCard({required this.journal});

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
              label: 'Works',
              value: '${journal.worksCount}',
            ),
            _Stat(
              icon: Icons.format_quote_rounded,
              color: AppColors.success,
              label: 'Citations',
              value: '${journal.citedByCount}',
            ),
          ],
        ),
        const SizedBox(height: 14),
        Row(
          children: [
            _Stat(
              icon: Icons.insights_rounded,
              color: AppColors.info,
              label: 'H-index',
              value: journal.hIndex?.toString() ?? '-',
            ),
            _Stat(
              icon: Icons.stacked_bar_chart_rounded,
              color: AppColors.gold,
              label: 'i10-index',
              value: journal.i10Index?.toString() ?? '-',
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
      title: 'Source Metadata',
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

class _TopicsCard extends StatelessWidget {
  final List<RankedEntity> topics;

  const _TopicsCard({required this.topics});

  @override
  Widget build(BuildContext context) {
    if (topics.isEmpty) {
      return const SizedBox.shrink();
    }

    return _Card(
      title: 'Source Topics',
      children: [
        for (var i = 0; i < topics.take(10).length; i++) ...[
          if (i > 0) const Divider(height: 18),
          _MetaRow(
            label: topics[i].name,
            value: '${topics[i].worksCount} works',
          ),
        ],
      ],
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
