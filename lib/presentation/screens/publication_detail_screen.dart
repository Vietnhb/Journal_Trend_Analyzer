import 'dart:async';
import 'dart:ui' show lerpDouble;

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:url_launcher/url_launcher.dart';

import '../../core/constants/app_colors.dart';
import '../../core/widgets/app_markup_text.dart';
import '../../data/models/publication.dart';
import '../../data/services/firebase_service.dart';

class PublicationDetailScreen extends StatefulWidget {
  final Publication publication;

  const PublicationDetailScreen({super.key, required this.publication});

  @override
  State<PublicationDetailScreen> createState() =>
      _PublicationDetailScreenState();
}

class _PublicationDetailScreenState extends State<PublicationDetailScreen> {
  @override
  void initState() {
    super.initState();
    unawaited(
      FirebaseService.instance.logEvent(
        'view_publication',
        parameters: {
          'publication_title': widget.publication.title,
          if (widget.publication.year != null)
            'publication_year': widget.publication.year!,
        },
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final publication = widget.publication;
    return AnnotatedRegion<SystemUiOverlayStyle>(
      value: SystemUiOverlayStyle.light,
      child: Scaffold(
        body: CustomScrollView(
          slivers: [
            SliverPersistentHeader(
              pinned: true,
              delegate: _PublicationHeaderDelegate(
                title: publication.title,
                topPadding: MediaQuery.paddingOf(context).top,
              ),
            ),
            SliverPadding(
              padding: const EdgeInsets.fromLTRB(16, 16, 16, 24),
              sliver: SliverList(
                delegate: SliverChildListDelegate.fixed([
                  _InfoCard(publication: publication),
                  const SizedBox(height: 14),
                  _AbstractCard(publication: publication),
                ]),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _PublicationHeaderDelegate extends SliverPersistentHeaderDelegate {
  static const double _toolbarHeight = 56;
  static const double _expandedContentHeight = 112;

  final String title;
  final double topPadding;

  const _PublicationHeaderDelegate({
    required this.title,
    required this.topPadding,
  });

  @override
  double get minExtent => topPadding + _toolbarHeight;

  @override
  double get maxExtent => topPadding + _toolbarHeight + _expandedContentHeight;

  @override
  Widget build(
    BuildContext context,
    double shrinkOffset,
    bool overlapsContent,
  ) {
    final scrollProgress = (shrinkOffset / (maxExtent - minExtent)).clamp(
      0.0,
      1.0,
    );
    final expandedProgress = 1.0 - scrollProgress;
    final toolbarTitleOpacity = ((scrollProgress - 0.62) / 0.38).clamp(
      0.0,
      1.0,
    );
    final expandedTitleOpacity = (1.0 - (scrollProgress / 0.7)).clamp(0.0, 1.0);
    final expandedTitleBottom = lerpDouble(20, 10, scrollProgress)!;

    return Material(
      color: AppColors.primary,
      elevation: overlapsContent ? 2 : 0,
      child: Stack(
        fit: StackFit.expand,
        children: [
          const DecoratedBox(
            decoration: BoxDecoration(
              gradient: LinearGradient(
                colors: [AppColors.primary, AppColors.accent],
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
              ),
            ),
          ),
          PositionedDirectional(
            start: 4,
            top: topPadding + 4,
            child: IconButton(
              icon: const Icon(Icons.arrow_back, color: Colors.white),
              tooltip: MaterialLocalizations.of(context).backButtonTooltip,
              onPressed: () => Navigator.maybePop(context),
            ),
          ),
          PositionedDirectional(
            start: 56,
            end: 16,
            top: topPadding,
            height: _toolbarHeight,
            child: ClipRect(
              child: Align(
                alignment: Alignment.centerLeft,
                child: Opacity(
                  opacity: toolbarTitleOpacity,
                  child: Text(
                    title,
                    maxLines: 1,
                    overflow: TextOverflow.clip,
                    softWrap: false,
                    style: Theme.of(context).textTheme.titleMedium?.copyWith(
                      color: Colors.white,
                      fontSize: 15,
                      fontWeight: FontWeight.w700,
                      height: 1.15,
                    ),
                  ),
                ),
              ),
            ),
          ),
          PositionedDirectional(
            start: 16,
            end: 16,
            bottom: expandedTitleBottom,
            child: IgnorePointer(
              child: Opacity(
                opacity: expandedTitleOpacity,
                child: Text(
                  title,
                  maxLines: expandedProgress > 0.45 ? 4 : 3,
                  overflow: TextOverflow.clip,
                  softWrap: true,
                  style: Theme.of(context).textTheme.titleLarge?.copyWith(
                    color: Colors.white,
                    fontSize: 20,
                    fontWeight: FontWeight.w800,
                    height: 1.15,
                  ),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  @override
  bool shouldRebuild(covariant _PublicationHeaderDelegate oldDelegate) {
    return title != oldDelegate.title || topPadding != oldDelegate.topPadding;
  }
}

class _InfoCard extends StatelessWidget {
  final Publication publication;

  const _InfoCard({required this.publication});

  @override
  Widget build(BuildContext context) {
    final doi = publication.doi;
    final url = publication.url;
    final hasSeparateUrl =
        url != null &&
        (doi == null ||
            _normalizeUrl(url).toLowerCase() !=
                _normalizeUrl(doi).toLowerCase());

    return _Card(
      title: 'Journal Publication',
      children: [
        _Row(label: 'Journal', value: publication.journalName),
        _Row(label: 'Publication year', value: '${publication.year ?? '-'}'),
        _Row(label: 'Citations', value: '${publication.citationCount}'),
        _ExpandableRow(
          label: 'Authors',
          value: publication.authors.isEmpty
              ? '-'
              : publication.authors.join(', '),
        ),
        if (doi != null) _UrlRow(label: 'DOI', value: doi),
        if (hasSeparateUrl) _UrlRow(label: 'Original link', value: url),
      ],
    );
  }

  String _normalizeUrl(String value) {
    return value.trim().replaceFirst(RegExp(r'/$'), '');
  }
}

class _UrlRow extends StatelessWidget {
  final String label;
  final String value;

  const _UrlRow({required this.label, required this.value});

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;

    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 5),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(
            width: 112,
            child: Text(
              label,
              style: Theme.of(context).textTheme.bodySmall?.copyWith(
                color: colorScheme.onSurfaceVariant,
              ),
            ),
          ),
          Expanded(
            child: InkWell(
              onTap: () => _openUrl(context),
              child: Text(
                value,
                style: Theme.of(context).textTheme.bodySmall?.copyWith(
                  color: AppColors.primary,
                  fontWeight: FontWeight.w700,
                  decoration: TextDecoration.underline,
                  decorationColor: AppColors.primary,
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Future<void> _openUrl(BuildContext context) async {
    final target = label == 'DOI' && !value.contains('://')
        ? 'https://doi.org/$value'
        : value;
    final uri = Uri.tryParse(target);
    if (uri == null || !uri.hasScheme) {
      _showUrlError(context);
      return;
    }

    final opened = await launchUrl(
      uri,
      mode: LaunchMode.externalApplication,
    ).catchError((_) => false);
    if (!opened && context.mounted) {
      _showUrlError(context);
    }
  }

  void _showUrlError(BuildContext context) {
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(
        content: Text('Could not open URL.'),
        duration: Duration(seconds: 2),
      ),
    );
  }
}

class _AbstractCard extends StatelessWidget {
  final Publication publication;

  const _AbstractCard({required this.publication});

  @override
  Widget build(BuildContext context) {
    return _Card(
      title: 'Abstract',
      children: [
        AppMarkupText(
          publication.abstractMarkup ??
              publication.abstractText ??
              'No abstract available.',
          style: Theme.of(context).textTheme.bodyMedium?.copyWith(height: 1.55),
        ),
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
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: colorScheme.outlineVariant),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            title,
            style: Theme.of(context).textTheme.titleMedium?.copyWith(
              color: colorScheme.onSurface,
              fontWeight: FontWeight.w800,
            ),
          ),
          const SizedBox(height: 12),
          ...children,
        ],
      ),
    );
  }
}

class _Row extends StatelessWidget {
  final String label;
  final String value;

  const _Row({required this.label, required this.value});

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;

    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 5),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(
            width: 112,
            child: Text(
              label,
              style: Theme.of(context).textTheme.bodySmall?.copyWith(
                color: colorScheme.onSurfaceVariant,
              ),
            ),
          ),
          Expanded(
            child: Text(
              value,
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

class _ExpandableRow extends StatefulWidget {
  final String label;
  final String value;

  const _ExpandableRow({required this.label, required this.value});

  @override
  State<_ExpandableRow> createState() => _ExpandableRowState();
}

class _ExpandableRowState extends State<_ExpandableRow> {
  bool _isExpanded = false;

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    final valueStyle = Theme.of(context).textTheme.bodySmall?.copyWith(
      color: colorScheme.onSurface,
      fontWeight: FontWeight.w600,
    );

    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 5),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(
            width: 112,
            child: Text(
              widget.label,
              style: Theme.of(context).textTheme.bodySmall?.copyWith(
                color: colorScheme.onSurfaceVariant,
              ),
            ),
          ),
          Expanded(
            child: LayoutBuilder(
              builder: (context, constraints) {
                final textPainter = TextPainter(
                  text: TextSpan(text: widget.value, style: valueStyle),
                  maxLines: 3,
                  textDirection: Directionality.of(context),
                )..layout(maxWidth: constraints.maxWidth);
                final canExpand = textPainter.didExceedMaxLines;

                return Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      widget.value,
                      maxLines: _isExpanded ? null : 3,
                      overflow: _isExpanded
                          ? TextOverflow.visible
                          : TextOverflow.ellipsis,
                      style: valueStyle,
                    ),
                    if (canExpand || _isExpanded)
                      GestureDetector(
                        onTap: () => setState(() => _isExpanded = !_isExpanded),
                        child: Padding(
                          padding: const EdgeInsets.only(top: 4),
                          child: Text(
                            _isExpanded ? 'Show less' : 'Read more',
                            style: Theme.of(context).textTheme.labelMedium
                                ?.copyWith(
                                  color: AppColors.primary,
                                  fontWeight: FontWeight.w700,
                                ),
                          ),
                        ),
                      ),
                  ],
                );
              },
            ),
          ),
        ],
      ),
    );
  }
}
