import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../core/widgets/app_empty_view.dart';
import '../../core/widgets/app_error_view.dart';
import '../../core/widgets/app_loading.dart';
import '../providers/publication_provider.dart';

class ResearchDashboardScreen extends StatelessWidget {
  const ResearchDashboardScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final provider = context.watch<PublicationProvider>();

    return Scaffold(
      appBar: AppBar(title: const Text('Research Dashboard')),
      body: _DashboardBody(provider: provider),
    );
  }
}

class _DashboardBody extends StatelessWidget {
  final PublicationProvider provider;

  const _DashboardBody({required this.provider});

  @override
  Widget build(BuildContext context) {
    if (!provider.hasSearched) {
      return const AppEmptyView(
        message: 'Search a topic first to populate the dashboard.',
        icon: Icons.dashboard,
      );
    }

    if (provider.isLoading) {
      return const AppLoading(message: 'Calculating dashboard metrics...');
    }

    final error = provider.error;
    if (error != null) {
      return AppErrorView(error: error);
    }

    if (provider.analysisPublications.isEmpty) {
      return const AppEmptyView(
        message: 'No dashboard data for this topic.',
        icon: Icons.search_off,
      );
    }

    return ListView(
      padding: const EdgeInsets.all(16),
      children: [
        Wrap(
          spacing: 12,
          runSpacing: 12,
          children: [
            _MetricCard(
              title: 'Publications',
              value: provider.totalPublications.toString(),
              icon: Icons.article,
            ),
            _MetricCard(
              title: 'Avg citations',
              value: provider.averageCitations.toStringAsFixed(1),
              icon: Icons.trending_up,
            ),
            _MetricCard(
              title: 'Most active year',
              value: provider.mostActiveYear?.toString() ?? '-',
              icon: Icons.calendar_month,
            ),
            _MetricCard(
              title: 'Total citations',
              value: provider.totalCitations.toString(),
              icon: Icons.format_quote,
            ),
          ],
        ),
        const SizedBox(height: 20),
        _TextMetric(label: 'Top journal', value: provider.topJournal ?? '-'),
        _TextMetric(label: 'Top author', value: provider.topAuthor ?? '-'),
        _TextMetric(
          label: 'Most influential paper',
          value: provider.mostInfluentialPaper?.title ?? '-',
        ),
        const SizedBox(height: 20),
        _RankedSection(
          title: 'Top Influential Papers',
          children: provider.topPapers
              .map(
                (paper) => ListTile(
                  dense: true,
                  title: Text(paper.title),
                  subtitle: Text(
                    '${paper.year ?? 'No year'} | ${paper.journalName}',
                  ),
                  trailing: Text('${paper.citationCount}'),
                ),
              )
              .toList(),
        ),
        _RankedSection(
          title: 'Top Journals',
          children: provider.topJournals
              .map(
                (entry) => ListTile(
                  dense: true,
                  title: Text(entry.key),
                  trailing: Text('${entry.value}'),
                ),
              )
              .toList(),
        ),
        _RankedSection(
          title: 'Top Authors',
          children: provider.topAuthors
              .map(
                (entry) => ListTile(
                  dense: true,
                  title: Text(entry.key),
                  trailing: Text('${entry.value}'),
                ),
              )
              .toList(),
        ),
      ],
    );
  }
}

class _MetricCard extends StatelessWidget {
  final String title;
  final String value;
  final IconData icon;

  const _MetricCard({
    required this.title,
    required this.value,
    required this.icon,
  });

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    return SizedBox(
      width: 170,
      child: DecoratedBox(
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(8),
          border: Border.all(color: colorScheme.outlineVariant),
        ),
        child: Padding(
          padding: const EdgeInsets.all(14),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Icon(icon, color: colorScheme.primary),
              const SizedBox(height: 12),
              Text(value, style: Theme.of(context).textTheme.headlineSmall),
              const SizedBox(height: 4),
              Text(title, style: Theme.of(context).textTheme.labelMedium),
            ],
          ),
        ),
      ),
    );
  }
}

class _TextMetric extends StatelessWidget {
  final String label;
  final String value;

  const _TextMetric({required this.label, required this.value});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 10),
      child: Text.rich(
        TextSpan(
          children: [
            TextSpan(
              text: '$label: ',
              style: const TextStyle(fontWeight: FontWeight.w700),
            ),
            TextSpan(text: value),
          ],
        ),
      ),
    );
  }
}

class _RankedSection extends StatelessWidget {
  final String title;
  final List<Widget> children;

  const _RankedSection({required this.title, required this.children});

  @override
  Widget build(BuildContext context) {
    if (children.isEmpty) {
      return const SizedBox.shrink();
    }

    return Padding(
      padding: const EdgeInsets.only(bottom: 16),
      child: DecoratedBox(
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(8),
          border: Border.all(
            color: Theme.of(context).colorScheme.outlineVariant,
          ),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 14, 16, 4),
              child: Text(
                title,
                style: Theme.of(context).textTheme.titleMedium,
              ),
            ),
            ...children,
          ],
        ),
      ),
    );
  }
}
