import 'package:flutter/material.dart';

import '../../core/constants/app_colors.dart';
import '../../core/errors/app_errors.dart';
import '../../core/widgets/app_error_view.dart';
import '../../core/widgets/app_loading.dart';
import '../../core/widgets/app_markup_text.dart';
import '../../data/repositories/journal_repository.dart'
    show Publication, PublicationYearSort, RankedEntity;
import '../providers/entity_analytics_provider.dart';
import '../trends/widgets/trend_chart.dart';
import '../widgets/analytics_ui.dart';
import 'publication_detail_screen.dart';

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
  late final EntityAnalyticsProvider _viewModel;
  bool get _isLoading => _viewModel.isLoading;
  AppError? get _error => _viewModel.error;
  List<Publication> get _publications => _viewModel.publications;
  Map<int, int> get _publicationsByYear => _viewModel.publicationsByYear;
  int get _totalPublications => _viewModel.totalPublications;
  int get _totalCitations => _viewModel.totalCitations;
  double? get _averageCitations => _viewModel.averageCitations;

  @override
  void initState() {
    super.initState();
    _viewModel = EntityAnalyticsProvider(
      type: widget.type,
      entity: widget.entity,
      keyword: widget.keyword,
      excludeFuturePublications: widget.excludeFuturePublications,
    )..addListener(_onViewModelChanged);
    _load();
  }

  void _onViewModelChanged() {
    if (mounted) setState(() {});
  }

  @override
  void dispose() {
    _viewModel
      ..removeListener(_onViewModelChanged)
      ..dispose();
    super.dispose();
  }

  Future<void> _load() async {
    await _viewModel.load();
  }

  @override
  Widget build(BuildContext context) {
    final entityLabel = widget.type == AnalyticsEntityType.journal
        ? 'Journal'
        : 'Author';

    return Scaffold(
      appBar: AppBar(title: Text('$entityLabel Detail')),
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
                  '"${widget.keyword}" - ${entityLabel.toLowerCase()} analysis',
                  style: Theme.of(context).textTheme.bodySmall?.copyWith(
                    color: Theme.of(context).colorScheme.onSurfaceVariant,
                  ),
                ),
                const SizedBox(height: 16),
                _Metrics(
                  total: _totalPublications,
                  totalCitations: _totalCitations,
                  averageCitations: _averageCitations,
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
                  title: 'Related Publications',
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
  final int totalCitations;
  final double? averageCitations;

  const _Metrics({
    required this.total,
    required this.totalCitations,
    required this.averageCitations,
  });

  @override
  Widget build(BuildContext context) {
    return ResponsiveMetricGrid(
      minItemWidth: 145,
      children: [
        AnalyticsMetricCard(
          label: 'Publications',
          value: '$total',
          icon: Icons.article_rounded,
          color: AppColors.primary,
        ),
        AnalyticsMetricCard(
          label: 'Total Citations',
          value: '$totalCitations',
          icon: Icons.format_quote_rounded,
          color: AppColors.success,
        ),
        AnalyticsMetricCard(
          label: 'Avg Citations',
          value: averageCitations?.toStringAsFixed(1) ?? '-',
          icon: Icons.analytics_outlined,
          color: AppColors.info,
        ),
      ],
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
    return AnalyticsSectionHeader(
      icon: icon,
      title: title,
      trailing: trailing == null
          ? null
          : Text(
              trailing!,
              style: Theme.of(context).textTheme.labelSmall?.copyWith(
                color: Theme.of(context).colorScheme.onSurfaceVariant,
              ),
            ),
    );
  }
}

class _TrendCard extends StatelessWidget {
  final Map<int, int> data;

  const _TrendCard({required this.data});

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      height: 300,
      child: AnalyticsSurfaceCard(
        padding: const EdgeInsets.fromLTRB(12, 14, 12, 8),
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
                ].join(' - '),
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
