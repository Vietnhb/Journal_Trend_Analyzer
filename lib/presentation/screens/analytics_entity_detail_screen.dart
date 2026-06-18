import 'package:flutter/material.dart';

import '../../core/constants/app_colors.dart';
import '../../core/errors/app_errors.dart';
import '../../core/widgets/app_error_view.dart';
import '../../core/widgets/app_loading.dart';
import '../../core/widgets/app_markup_text.dart';
import '../../data/repositories/journal_repository.dart';
import '../trends/widgets/trend_chart.dart';
import 'publication_detail_screen.dart';

enum AnalyticsEntityType { journal, author }

class AnalyticsEntityDetailScreen extends StatefulWidget {
  final AnalyticsEntityType type;
  final RankedEntity entity;
  final String keyword;
  final bool excludeFuturePublications;

  const AnalyticsEntityDetailScreen({
    super.key,
    required this.type,
    required this.entity,
    required this.keyword,
    required this.excludeFuturePublications,
  });

  @override
  State<AnalyticsEntityDetailScreen> createState() =>
      _AnalyticsEntityDetailScreenState();
}

class _AnalyticsEntityDetailScreenState
    extends State<AnalyticsEntityDetailScreen> {
  final JournalRepository _repository = JournalRepository();

  bool _isLoading = true;
  AppError? _error;
  List<Publication> _publications = const [];
  Map<int, int> _publicationsByYear = const {};
  int _totalPublications = 0;
  int? _averageCitations;

  @override
  void initState() {
    super.initState();
    _load();
  }

  @override
  void dispose() {
    _repository.dispose();
    super.dispose();
  }

  Future<void> _load() async {
    setState(() {
      _isLoading = true;
      _error = null;
    });

    try {
      final page = await _repository.getPublicationsByKeyword(
        widget.keyword,
        sourceId: _sourceId,
        authorId: _authorId,
        page: 1,
        excludeFuturePublications: widget.excludeFuturePublications,
        sortOverride: 'cited_by_count:desc',
      );

      final trend = await _repository.getPublicationTrendByKeyword(
        widget.keyword,
        sourceId: _sourceId,
        authorId: _authorId,
        excludeFuturePublications: widget.excludeFuturePublications,
      );

      final average = await _repository.getAverageCitationsByKeyword(
        widget.keyword,
        sourceId: _sourceId,
        authorId: _authorId,
        excludeFuturePublications: widget.excludeFuturePublications,
      );

      if (!mounted) return;
      setState(() {
        _publications = page.publications;
        _totalPublications = page.totalCount;
        _publicationsByYear = trend;
        _averageCitations = average;
      });
    } on AppError catch (error) {
      if (mounted) setState(() => _error = error);
    } catch (error) {
      if (mounted) {
        setState(() {
          _error = AppError(
            'Could not load filtered analytics.',
            details: error.toString(),
          );
        });
      }
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  String? get _sourceId =>
      widget.type == AnalyticsEntityType.journal ? widget.entity.id : null;

  String? get _authorId =>
      widget.type == AnalyticsEntityType.author ? widget.entity.id : null;

  int? get _mostActiveYear {
    if (_publicationsByYear.isEmpty) return null;
    final entries = _publicationsByYear.entries.toList()
      ..sort((a, b) {
        final countCompare = b.value.compareTo(a.value);
        return countCompare != 0 ? countCompare : b.key.compareTo(a.key);
      });
    return entries.first.key;
  }

  @override
  Widget build(BuildContext context) {
    final entityLabel = widget.type == AnalyticsEntityType.journal
        ? 'Journal'
        : 'Author';

    return Scaffold(
      appBar: AppBar(title: Text('$entityLabel Analytics')),
      body: _isLoading
          ? const AppLoading(message: 'Loading filtered analytics...')
          : _error != null
          ? AppErrorView(error: _error!, onRetry: _load)
          : ListView(
              padding: const EdgeInsets.fromLTRB(16, 8, 16, 24),
              children: [
                Text(
                  widget.entity.name,
                  style: Theme.of(
                    context,
                  ).textTheme.titleLarge?.copyWith(fontWeight: FontWeight.w800),
                ),
                const SizedBox(height: 4),
                Text(
                  '"${widget.keyword}" · journal articles only',
                  style: Theme.of(context).textTheme.bodySmall?.copyWith(
                    color: Theme.of(context).colorScheme.onSurfaceVariant,
                  ),
                ),
                const SizedBox(height: 16),
                _Metrics(
                  total: _totalPublications,
                  averageCitations: _averageCitations,
                  mostActiveYear: _mostActiveYear,
                ),
                if (_publicationsByYear.isNotEmpty) ...[
                  const SizedBox(height: 20),
                  const _SectionTitle(
                    icon: Icons.bar_chart_rounded,
                    title: 'Publication Trend',
                  ),
                  const SizedBox(height: 10),
                  _TrendCard(data: _publicationsByYear),
                ],
                const SizedBox(height: 20),
                _SectionTitle(
                  icon: Icons.article_outlined,
                  title: 'Filtered Publications',
                  trailing: '${_publications.length} of $_totalPublications',
                ),
                const SizedBox(height: 10),
                _PublicationList(publications: _publications),
              ],
            ),
    );
  }
}

class _Metrics extends StatelessWidget {
  final int total;
  final int? averageCitations;
  final int? mostActiveYear;

  const _Metrics({
    required this.total,
    required this.averageCitations,
    required this.mostActiveYear,
  });

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Expanded(
          child: _MetricCard(
            label: 'Articles',
            value: '$total',
            icon: Icons.article_rounded,
          ),
        ),
        const SizedBox(width: 8),
        Expanded(
          child: _MetricCard(
            label: 'Avg Citations',
            value: averageCitations?.toString() ?? '-',
            icon: Icons.format_quote_rounded,
          ),
        ),
        const SizedBox(width: 8),
        Expanded(
          child: _MetricCard(
            label: 'Top Year',
            value: mostActiveYear?.toString() ?? '-',
            icon: Icons.calendar_today_rounded,
          ),
        ),
      ],
    );
  }
}

class _MetricCard extends StatelessWidget {
  final String label;
  final String value;
  final IconData icon;

  const _MetricCard({
    required this.label,
    required this.value,
    required this.icon,
  });

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    return Container(
      padding: const EdgeInsets.all(11),
      decoration: BoxDecoration(
        color: colorScheme.surface,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: colorScheme.outlineVariant),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(icon, size: 17, color: AppColors.primary),
          const SizedBox(height: 6),
          FittedBox(
            fit: BoxFit.scaleDown,
            child: Text(
              value,
              style: Theme.of(
                context,
              ).textTheme.titleMedium?.copyWith(fontWeight: FontWeight.w800),
            ),
          ),
          Text(
            label,
            style: Theme.of(context).textTheme.labelSmall?.copyWith(
              color: colorScheme.onSurfaceVariant,
            ),
          ),
        ],
      ),
    );
  }
}

class _SectionTitle extends StatelessWidget {
  final IconData icon;
  final String title;
  final String? trailing;

  const _SectionTitle({required this.icon, required this.title, this.trailing});

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Icon(icon, size: 18, color: AppColors.primary),
        const SizedBox(width: 8),
        Expanded(
          child: Text(
            title,
            style: Theme.of(
              context,
            ).textTheme.titleMedium?.copyWith(fontWeight: FontWeight.w800),
          ),
        ),
        if (trailing != null)
          Text(
            trailing!,
            style: Theme.of(context).textTheme.labelSmall?.copyWith(
              color: Theme.of(context).colorScheme.onSurfaceVariant,
            ),
          ),
      ],
    );
  }
}

class _TrendCard extends StatelessWidget {
  final Map<int, int> data;

  const _TrendCard({required this.data});

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    return Container(
      height: 300,
      padding: const EdgeInsets.fromLTRB(10, 14, 10, 8),
      decoration: BoxDecoration(
        color: colorScheme.surface,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: colorScheme.outlineVariant),
      ),
      child: LayoutBuilder(
        builder: (context, constraints) {
          final minWidth = data.length * 44.0;
          return SingleChildScrollView(
            scrollDirection: Axis.horizontal,
            child: SizedBox(
              width: minWidth > constraints.maxWidth
                  ? minWidth
                  : constraints.maxWidth,
              child: TrendChart(
                data: data,
                yearSort: PublicationYearSort.descending,
              ),
            ),
          );
        },
      ),
    );
  }
}

class _PublicationList extends StatelessWidget {
  final List<Publication> publications;

  const _PublicationList({required this.publications});

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    if (publications.isEmpty) {
      return const Text('No filtered publications found.');
    }

    return Container(
      decoration: BoxDecoration(
        color: colorScheme.surface,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: colorScheme.outlineVariant),
      ),
      child: Column(
        children: [
          for (var index = 0; index < publications.length; index++) ...[
            if (index > 0) const Divider(height: 1, indent: 14, endIndent: 14),
            ListTile(
              dense: true,
              title: AppMarkupText(
                publications[index].titleMarkup ?? publications[index].title,
                style: const TextStyle(fontWeight: FontWeight.w700),
              ),
              subtitle: Text(
                [
                  publications[index].year?.toString() ?? 'No year',
                  '${publications[index].citationCount} citations',
                  publications[index].journalName,
                ].join(' · '),
              ),
              trailing: const Icon(Icons.chevron_right_rounded),
              onTap: () => Navigator.push(
                context,
                MaterialPageRoute(
                  builder: (_) =>
                      PublicationDetailScreen(publication: publications[index]),
                ),
              ),
            ),
          ],
        ],
      ),
    );
  }
}
