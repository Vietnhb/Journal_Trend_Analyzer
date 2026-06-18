import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';

import '../../core/constants/app_colors.dart';
import '../../core/widgets/app_error_view.dart';
import '../../core/widgets/app_loading.dart';
import '../../data/models/openalex_topic.dart';
import '../providers/journal_provider.dart';

class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key});

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  final _searchController = TextEditingController();
  final _focusNode = FocusNode();

  @override
  void dispose() {
    _searchController.dispose();
    _focusNode.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final provider = context.watch<JournalProvider>();

    return AnnotatedRegion<SystemUiOverlayStyle>(
      value: SystemUiOverlayStyle.light.copyWith(
        statusBarColor: Colors.transparent,
      ),
      child: Scaffold(
        body: CustomScrollView(
          slivers: [
            SliverToBoxAdapter(child: _buildHeader(context, provider)),
            SliverToBoxAdapter(
              child: Padding(
                padding: const EdgeInsets.fromLTRB(20, 0, 20, 0),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    _buildStateSection(context, provider),
                    const SizedBox(height: 24),
                    _buildRecentSearches(context, provider),
                    const SizedBox(height: 24),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildHeader(BuildContext context, JournalProvider provider) {
    final topInset = MediaQuery.paddingOf(context).top;
    final colorScheme = Theme.of(context).colorScheme;
    final inputSurface = colorScheme.surface;
    final inputText = colorScheme.onSurface;
    final inputHint = colorScheme.onSurfaceVariant;

    return Container(
      padding: EdgeInsets.fromLTRB(20, topInset + 18, 20, 28),
      decoration: const BoxDecoration(
        gradient: LinearGradient(
          colors: [AppColors.primary, AppColors.accent],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.vertical(bottom: Radius.circular(24)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                  color: Colors.white.withValues(alpha: 0.15),
                  borderRadius: BorderRadius.circular(10),
                ),
                child: const Icon(
                  Icons.auto_stories_rounded,
                  color: Colors.white,
                  size: 22,
                ),
              ),
              const SizedBox(width: 10),
              Text(
                'Journal Trends',
                style: Theme.of(context).textTheme.titleMedium?.copyWith(
                  color: Colors.white.withValues(alpha: 0.9),
                  fontWeight: FontWeight.w500,
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),
          Text(
            'Search Research Topic',
            style: Theme.of(context).textTheme.headlineMedium?.copyWith(
              color: Colors.white,
              fontWeight: FontWeight.w800,
              height: 1.2,
            ),
          ),
          const SizedBox(height: 20),
          // Search bar
          Container(
            decoration: BoxDecoration(
              color: inputSurface,
              borderRadius: BorderRadius.circular(14),
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withValues(alpha: 0.14),
                  blurRadius: 16,
                  offset: const Offset(0, 4),
                ),
              ],
            ),
            child: TextField(
              controller: _searchController,
              focusNode: _focusNode,
              textInputAction: TextInputAction.search,
              style: TextStyle(
                color: inputText,
                fontWeight: FontWeight.w500,
                fontSize: 15,
              ),
              decoration: InputDecoration(
                hintText: 'Enter a topic keyword, e.g. machine learning',
                hintStyle: TextStyle(
                  color: inputHint,
                  fontWeight: FontWeight.w400,
                  fontSize: 14,
                ),
                prefixIcon: const Icon(
                  Icons.search_rounded,
                  color: AppColors.primary,
                ),
                suffixIcon: _searchController.text.isNotEmpty
                    ? IconButton(
                        icon: const Icon(Icons.close_rounded, size: 20),
                        onPressed: () {
                          _searchController.clear();
                          context.read<JournalProvider>().clear();
                          setState(() {});
                        },
                      )
                    : null,
                filled: false,
                border: InputBorder.none,
                enabledBorder: InputBorder.none,
                focusedBorder: InputBorder.none,
                contentPadding: const EdgeInsets.symmetric(
                  horizontal: 16,
                  vertical: 14,
                ),
              ),
              onChanged: (_) => setState(() {}),
              onSubmitted: (_) => _search(context),
            ),
          ),
          const SizedBox(height: 12),
          SizedBox(
            width: double.infinity,
            child: FilledButton.icon(
              onPressed: provider.isLoading ? null : () => _search(context),
              style: FilledButton.styleFrom(
                backgroundColor: Colors.white,
                foregroundColor: AppColors.primary,
                padding: const EdgeInsets.symmetric(vertical: 14),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12),
                ),
              ),
              icon: provider.isLoading
                  ? SizedBox(
                      width: 18,
                      height: 18,
                      child: CircularProgressIndicator(
                        strokeWidth: 2,
                        color: AppColors.primary,
                      ),
                    )
                  : const Icon(Icons.analytics_rounded, size: 20),
              label: Text(
                provider.isLoading ? 'Analyzing...' : 'Analyze Keyword',
                style: const TextStyle(
                  fontWeight: FontWeight.w700,
                  fontSize: 15,
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildStateSection(BuildContext context, JournalProvider provider) {
    if (provider.isLoading) {
      return const Padding(
        padding: EdgeInsets.only(top: 24),
        child: AppLoading(message: 'Analyzing keyword...'),
      );
    }

    if (provider.error != null) {
      return Padding(
        padding: const EdgeInsets.only(top: 24),
        child: AppErrorView(
          error: provider.error!,
          onRetry: provider.query.isEmpty
              ? null
              : () => context.read<JournalProvider>().analyzeKeyword(
                  provider.query,
                ),
        ),
      );
    }

    if (provider.hasSearched && provider.selectedKeyword.isNotEmpty) {
      return Padding(
        padding: const EdgeInsets.only(top: 20),
        child: _AnalysisSummaryCard(provider: provider),
      );
    }

    return const SizedBox.shrink();
  }

  Widget _buildRecentSearches(BuildContext context, JournalProvider provider) {
    final recentSearches = provider.recentSearches;
    final colorScheme = Theme.of(context).colorScheme;
    final mutedText = colorScheme.onSurfaceVariant;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Icon(Icons.history_rounded, size: 18, color: mutedText),
            const SizedBox(width: 6),
            Text(
              'Recent Searches',
              style: Theme.of(
                context,
              ).textTheme.titleMedium?.copyWith(color: colorScheme.onSurface),
            ),
          ],
        ),
        const SizedBox(height: 12),
        if (recentSearches.isEmpty)
          Container(
            width: double.infinity,
            padding: const EdgeInsets.all(20),
            decoration: BoxDecoration(
              color: colorScheme.surfaceContainerHighest,
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: colorScheme.outlineVariant),
            ),
            child: Column(
              children: [
                Icon(Icons.manage_search_rounded, size: 36, color: mutedText),
                const SizedBox(height: 8),
                Text(
                  'No recent searches yet.\nSearch a topic to find related journals.',
                  textAlign: TextAlign.center,
                  style: Theme.of(
                    context,
                  ).textTheme.bodyMedium?.copyWith(color: mutedText),
                ),
              ],
            ),
          )
        else
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: [
              for (final query in recentSearches)
                ActionChip(
                  label: Text(query),
                  avatar: const Icon(
                    Icons.history_rounded,
                    size: 16,
                    color: AppColors.primary,
                  ),
                  backgroundColor: colorScheme.surface,
                  side: BorderSide(color: colorScheme.outlineVariant),
                  labelStyle: TextStyle(
                    fontSize: 13,
                    fontWeight: FontWeight.w500,
                    color: colorScheme.onSurface,
                  ),
                  onPressed: provider.isLoading
                      ? null
                      : () {
                          _searchController.text = query;
                          context.read<JournalProvider>().analyzeKeyword(query);
                        },
                ),
            ],
          ),
      ],
    );
  }

  void _search(BuildContext context) {
    _focusNode.unfocus();
    context.read<JournalProvider>().analyzeKeyword(_searchController.text);
  }
}

class _AnalysisSummaryCard extends StatelessWidget {
  final JournalProvider provider;

  const _AnalysisSummaryCard({required this.provider});

  String _compact(num count) {
    if (count >= 1000000) return '${(count / 1000000).toStringAsFixed(1)}M';
    if (count >= 1000) return '${(count / 1000).toStringAsFixed(1)}K';
    return count.toString();
  }

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    final mutedText = colorScheme.onSurfaceVariant;

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: colorScheme.surface,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: colorScheme.outlineVariant),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(
              alpha: Theme.of(context).brightness == Brightness.dark
                  ? 0.18
                  : 0.06,
            ),
            blurRadius: 12,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                  color: AppColors.primary.withValues(alpha: 0.1),
                  borderRadius: BorderRadius.circular(10),
                ),
                child: const Icon(
                  Icons.analytics_rounded,
                  color: AppColors.primary,
                  size: 18,
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: Text(
                  '"${provider.selectedKeyword}"',
                  style: Theme.of(context).textTheme.titleMedium?.copyWith(
                    color: AppColors.primary,
                    fontWeight: FontWeight.w700,
                  ),
                  overflow: TextOverflow.ellipsis,
                  maxLines: 1,
                ),
              ),
            ],
          ),
          const SizedBox(height: 14),
          const Divider(height: 1),
          const SizedBox(height: 14),
          _ResultStat(
            icon: Icons.book_outlined,
            label: 'Top journals found',
            value: '${provider.journals.length}',
          ),
          const SizedBox(height: 10),
          _ResultStat(
            icon: Icons.article_outlined,
            label: 'Total related articles',
            value: _compact(provider.totalWorks),
          ),
          if (provider.avgCitationCount != null) ...[
            const SizedBox(height: 10),
            _ResultStat(
              icon: Icons.format_quote_rounded,
              label: 'Avg citations',
              value: '${provider.avgCitationCount}',
            ),
          ],
          if (provider.mostActiveYear != null) ...[
            const SizedBox(height: 10),
            _ResultStat(
              icon: Icons.calendar_today_rounded,
              label: 'Most active year',
              value: '${provider.mostActiveYear}',
            ),
          ],
          const SizedBox(height: 14),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
            decoration: BoxDecoration(
              color: colorScheme.surfaceContainerHighest,
              borderRadius: BorderRadius.circular(8),
            ),
            child: Row(
              children: [
                Icon(Icons.info_outline_rounded, size: 14, color: mutedText),
                const SizedBox(width: 6),
                Expanded(
                  child: Text(
                    'View detailed analytics in the Journals and Keywords tabs.',
                    style: Theme.of(
                      context,
                    ).textTheme.bodySmall?.copyWith(color: mutedText),
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

@Deprecated(
  'Topic selection is now optional. Use _AnalysisSummaryCard instead.',
)
// ignore: unused_element
class _TopicSuggestionsCard extends StatelessWidget {
  final JournalProvider provider;

  const _TopicSuggestionsCard({required this.provider});

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    final mutedText = colorScheme.onSurfaceVariant;

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: colorScheme.surface,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: colorScheme.outlineVariant),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(
              alpha: Theme.of(context).brightness == Brightness.dark
                  ? 0.18
                  : 0.06,
            ),
            blurRadius: 12,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                  color: AppColors.primary.withValues(alpha: 0.1),
                  borderRadius: BorderRadius.circular(10),
                ),
                child: const Icon(
                  Icons.check_circle_outline_rounded,
                  color: AppColors.primary,
                  size: 18,
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: Text(
                  '"${provider.query}"',
                  style: Theme.of(context).textTheme.titleMedium?.copyWith(
                    color: AppColors.primary,
                    fontWeight: FontWeight.w700,
                  ),
                  overflow: TextOverflow.ellipsis,
                  maxLines: 1,
                ),
              ),
            ],
          ),
          const SizedBox(height: 14),
          const Divider(height: 1),
          const SizedBox(height: 14),
          if (provider.topicSuggestions.isEmpty)
            Text(
              'No OpenAlex topics found. Try a broader keyword.',
              style: Theme.of(
                context,
              ).textTheme.bodyMedium?.copyWith(color: mutedText),
            )
          else ...[
            _ResultStat(
              icon: Icons.topic_outlined,
              label: 'Topic suggestions',
              value: '${provider.topicSuggestions.length}',
            ),
            if (provider.selectedTopic != null) ...[
              const SizedBox(height: 10),
              _ResultStat(
                icon: Icons.check_circle_outline_rounded,
                label: 'Selected topic',
                value: provider.selectedTopic!.name,
              ),
              const SizedBox(height: 10),
              _ResultStat(
                icon: Icons.book_outlined,
                label: 'Related journals',
                value: '${provider.journals.length}',
              ),
            ],
            const SizedBox(height: 14),
            for (final topic in provider.topicSuggestions.take(8)) ...[
              _TopicOption(
                topic: topic,
                isSelected: provider.selectedTopic?.id == topic.id,
                isLoading: provider.isLoadingJournals,
                onTap: () => context.read<JournalProvider>().selectTopic(topic),
              ),
              const SizedBox(height: 10),
            ],
          ],
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
            decoration: BoxDecoration(
              color: colorScheme.surfaceContainerHighest,
              borderRadius: BorderRadius.circular(8),
            ),
            child: Row(
              children: [
                Icon(Icons.info_outline_rounded, size: 14, color: mutedText),
                const SizedBox(width: 6),
                Expanded(
                  child: Text(
                    provider.selectedTopic == null
                        ? 'Choose a topic to load top journals by OpenAlex Topic ID.'
                        : 'Open the Journal tab to view top journals for the selected topic.',
                    style: Theme.of(
                      context,
                    ).textTheme.bodySmall?.copyWith(color: mutedText),
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

class _TopicOption extends StatelessWidget {
  final OpenAlexTopic topic;
  final bool isSelected;
  final bool isLoading;
  final VoidCallback onTap;

  const _TopicOption({
    required this.topic,
    required this.isSelected,
    required this.isLoading,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    final mutedText = colorScheme.onSurfaceVariant;
    final taxonomy = [
      topic.domainName,
      topic.fieldName,
      topic.subfieldName,
    ].whereType<String>().join(' / ');

    return InkWell(
      onTap: isLoading ? null : onTap,
      borderRadius: BorderRadius.circular(12),
      child: Container(
        width: double.infinity,
        padding: const EdgeInsets.all(12),
        decoration: BoxDecoration(
          color: isSelected
              ? AppColors.primary.withValues(alpha: 0.08)
              : colorScheme.surfaceContainerHighest,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(
            color: isSelected ? AppColors.primary : colorScheme.outlineVariant,
          ),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Icon(
                  isSelected
                      ? Icons.radio_button_checked
                      : Icons.radio_button_unchecked,
                  size: 18,
                  color: isSelected ? AppColors.primary : mutedText,
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    topic.name,
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                    style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                      color: colorScheme.onSurface,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                ),
                const SizedBox(width: 8),
                Text(
                  _compact(topic.worksCount),
                  style: Theme.of(context).textTheme.labelSmall?.copyWith(
                    color: AppColors.primary,
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ],
            ),
            if (taxonomy.isNotEmpty) ...[
              const SizedBox(height: 6),
              Text(
                taxonomy,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: Theme.of(
                  context,
                ).textTheme.bodySmall?.copyWith(color: mutedText),
              ),
            ],
            if (topic.description != null) ...[
              const SizedBox(height: 6),
              Text(
                topic.description!,
                maxLines: 3,
                overflow: TextOverflow.ellipsis,
                style: Theme.of(
                  context,
                ).textTheme.bodySmall?.copyWith(color: mutedText),
              ),
            ],
          ],
        ),
      ),
    );
  }

  String _compact(int count) {
    if (count >= 1000000) return '${(count / 1000000).toStringAsFixed(1)}M';
    if (count >= 1000) return '${(count / 1000).toStringAsFixed(1)}K';
    return count.toString();
  }
}

class _ResultStat extends StatelessWidget {
  final IconData icon;
  final String label;
  final String value;

  const _ResultStat({
    required this.icon,
    required this.label,
    required this.value,
  });

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    final mutedText = colorScheme.onSurfaceVariant;

    return Row(
      children: [
        Icon(icon, size: 16, color: mutedText),
        const SizedBox(width: 8),
        Expanded(
          child: Text(
            label,
            style: Theme.of(
              context,
            ).textTheme.bodyMedium?.copyWith(color: mutedText),
          ),
        ),
        Text(
          value,
          style: Theme.of(context).textTheme.titleSmall?.copyWith(
            color: colorScheme.onSurface,
            fontWeight: FontWeight.w700,
          ),
        ),
      ],
    );
  }
}
