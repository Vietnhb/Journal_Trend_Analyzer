import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';

import '../../core/constants/app_colors.dart';
import '../../core/errors/app_errors.dart';
import '../../core/widgets/app_error_view.dart';
import '../../core/widgets/app_loading.dart';
import '../../data/models/publication.dart';
import '../providers/publication_provider.dart';
import 'publication_detail_screen.dart';

enum TopEntityType { journal, author }

class TopEntityDetailScreen extends StatefulWidget {
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
  State<TopEntityDetailScreen> createState() => _TopEntityDetailScreenState();
}

class _TopEntityDetailScreenState extends State<TopEntityDetailScreen> {
  bool _isLoading = true;
  AppError? _error;
  List<Publication> _publications = const [];
  int _totalCount = 0;

  bool get _isJournal => widget.type == TopEntityType.journal;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    setState(() {
      _isLoading = true;
      _error = null;
    });

    try {
      final page = await context.read<PublicationProvider>().loadEntityPublications(
        sourceId: _isJournal ? widget.entityId : null,
        authorId: _isJournal ? null : widget.entityId,
      );
      if (!mounted) return;
      setState(() {
        _publications = page.publications;
        _totalCount = page.totalCount;
        _isLoading = false;
      });
    } on AppError catch (error) {
      if (!mounted) return;
      setState(() {
        _error = error;
        _isLoading = false;
      });
    } catch (error) {
      if (!mounted) return;
      setState(() {
        _error = AppError('Failed to load publications.', details: error.toString());
        _isLoading = false;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: CustomScrollView(
        slivers: [
          _buildAppBar(context),
          if (!_isLoading && _error == null && _publications.isNotEmpty)
            SliverToBoxAdapter(
              child: Padding(
                padding: const EdgeInsets.fromLTRB(16, 20, 16, 8),
                child: _StatsCard(
                  totalWorks: _totalCount,
                  loaded: _publications,
                ),
              ),
            ),
          _buildBody(context),
        ],
      ),
    );
  }

  Widget _buildAppBar(BuildContext context) {
    return SliverAppBar(
      expandedHeight: 196,
      pinned: true,
      backgroundColor: AppColors.primary,
      iconTheme: const IconThemeData(color: Colors.white),
      systemOverlayStyle: SystemUiOverlayStyle.light,
      title: Text(
        _isJournal ? 'Journal' : 'Author',
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
                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                decoration: BoxDecoration(
                  color: Colors.white.withValues(alpha: 0.2),
                  borderRadius: BorderRadius.circular(20),
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(
                      _isJournal
                          ? Icons.book_outlined
                          : Icons.person_outline_rounded,
                      size: 13,
                      color: Colors.white,
                    ),
                    const SizedBox(width: 4),
                    Text(
                      '${widget.worksCount} publications on "${widget.topic}"',
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
                widget.name,
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

  Widget _buildBody(BuildContext context) {
    if (_isLoading) {
      return const SliverFillRemaining(
        hasScrollBody: false,
        child: AppLoading(message: 'Loading publications...'),
      );
    }

    if (_error != null) {
      return SliverFillRemaining(
        hasScrollBody: false,
        child: AppErrorView(error: _error!, onRetry: _load),
      );
    }

    if (_publications.isEmpty) {
      return const SliverFillRemaining(
        hasScrollBody: false,
        child: Center(child: Text('No publications found.')),
      );
    }

    return SliverPadding(
      padding: const EdgeInsets.fromLTRB(16, 8, 16, 24),
      sliver: SliverList.separated(
        itemCount: _publications.length,
        separatorBuilder: (context, index) => const SizedBox(height: 10),
        itemBuilder: (context, index) {
          final pub = _publications[index];
          return _PublicationTile(
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
    );
  }
}

class _StatsCard extends StatelessWidget {
  final int totalWorks;
  final List<Publication> loaded;

  const _StatsCard({
    required this.totalWorks,
    required this.loaded,
  });

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;

    final loadedCitations = loaded.fold<int>(
      0,
      (sum, pub) => sum + pub.citationCount,
    );
    final avgCitations = loaded.isEmpty ? 0 : loadedCitations ~/ loaded.length;
    final years = loaded
        .map((pub) => pub.year)
        .whereType<int>()
        .toList(growable: false);
    final yearRange = years.isEmpty
        ? '—'
        : years.reduce((a, b) => a < b ? a : b) ==
              years.reduce((a, b) => a > b ? a : b)
        ? '${years.first}'
        : '${years.reduce((a, b) => a < b ? a : b)}–${years.reduce((a, b) => a > b ? a : b)}';

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
            'Overview',
            style: Theme.of(context).textTheme.titleSmall?.copyWith(
              color: colorScheme.onSurface,
              fontWeight: FontWeight.w700,
            ),
          ),
          const SizedBox(height: 12),
          Row(
            children: [
              _Stat(
                icon: Icons.article_rounded,
                color: AppColors.primary,
                label: 'Total works',
                value: '$totalWorks',
              ),
              _Stat(
                icon: Icons.download_done_rounded,
                color: AppColors.info,
                label: 'Loaded',
                value: '${loaded.length}',
              ),
            ],
          ),
          const SizedBox(height: 14),
          Row(
            children: [
              _Stat(
                icon: Icons.format_quote_rounded,
                color: AppColors.success,
                label: 'Avg cites (loaded)',
                value: '$avgCitations',
              ),
              _Stat(
                icon: Icons.date_range_rounded,
                color: AppColors.gold,
                label: 'Year range',
                value: yearRange,
              ),
            ],
          ),
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

class _PublicationTile extends StatelessWidget {
  final Publication publication;
  final VoidCallback onTap;

  const _PublicationTile({required this.publication, required this.onTap});

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    final year = publication.year;

    return Container(
      decoration: BoxDecoration(
        color: colorScheme.surface,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: colorScheme.outlineVariant),
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
                publication.title,
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
                style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                  fontWeight: FontWeight.w700,
                  color: colorScheme.onSurface,
                  height: 1.4,
                ),
              ),
              const SizedBox(height: 6),
              Text(
                publication.authors.isEmpty
                    ? publication.journalName
                    : publication.authors.take(3).join(', '),
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: Theme.of(context).textTheme.bodySmall?.copyWith(
                  color: colorScheme.onSurfaceVariant,
                ),
              ),
              const SizedBox(height: 10),
              Row(
                children: [
                  if (year != null) ...[
                    Icon(
                      Icons.calendar_today_outlined,
                      size: 12,
                      color: colorScheme.onSurfaceVariant,
                    ),
                    const SizedBox(width: 4),
                    Text(
                      '$year',
                      style: Theme.of(context).textTheme.labelSmall?.copyWith(
                        color: colorScheme.onSurfaceVariant,
                      ),
                    ),
                    const SizedBox(width: 12),
                  ],
                  Icon(
                    Icons.format_quote_rounded,
                    size: 12,
                    color: publication.citationCount > 50
                        ? AppColors.success
                        : colorScheme.onSurfaceVariant,
                  ),
                  const SizedBox(width: 4),
                  Text(
                    '${publication.citationCount} citations',
                    style: Theme.of(context).textTheme.labelSmall?.copyWith(
                      color: publication.citationCount > 50
                          ? AppColors.success
                          : colorScheme.onSurfaceVariant,
                    ),
                  ),
                  const Spacer(),
                  const Icon(
                    Icons.arrow_forward_ios_rounded,
                    size: 12,
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
