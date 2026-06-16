import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../core/widgets/app_error_view.dart';
import '../../core/widgets/app_loading.dart';
import '../providers/publication_provider.dart';

class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key});

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  final _searchController = TextEditingController();

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final provider = context.watch<PublicationProvider>();
    final recentSearches = provider.recentSearches;

    return Scaffold(
      appBar: AppBar(title: const Text('Home')),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          TextField(
            controller: _searchController,
            textInputAction: TextInputAction.search,
            decoration: InputDecoration(
              hintText: 'Search a research topic',
              prefixIcon: const Icon(Icons.search),
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(12),
              ),
              suffixIcon: IconButton(
                tooltip: 'Clear',
                icon: const Icon(Icons.clear),
                onPressed: () {
                  _searchController.clear();
                  context.read<PublicationProvider>().clear();
                },
              ),
            ),
            onSubmitted: (_) => _search(context),
          ),
          const SizedBox(height: 12),
          FilledButton.icon(
            onPressed: provider.isLoading ? null : () => _search(context),
            icon: provider.isLoading
                ? const SizedBox(
                    width: 18,
                    height: 18,
                    child: CircularProgressIndicator(
                      strokeWidth: 2,
                      color: Colors.white,
                    ),
                  )
                : const Icon(Icons.search),
            label: const Text('Search topic'),
          ),
          const SizedBox(height: 20),
          if (provider.isLoading)
            const AppLoading(message: 'Loading OpenAlex publications...')
          else if (provider.error != null && provider.publications.isEmpty)
            AppErrorView(
              error: provider.error!,
              onRetry: provider.query.isEmpty
                  ? null
                  : () => context.read<PublicationProvider>().search(
                      provider.query,
                    ),
            )
          else if (provider.hasSearched)
            _SearchSummary(provider: provider),
          const SizedBox(height: 24),
          Text(
            'Recent Searches',
            style: Theme.of(context).textTheme.titleLarge,
          ),
          const SizedBox(height: 12),
          if (recentSearches.isEmpty)
            Text(
              'No recent searches yet.',
              style: Theme.of(context).textTheme.bodyMedium,
            )
          else
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: [
                for (final query in recentSearches)
                  ActionChip(
                    label: Text(query),
                    avatar: const Icon(Icons.history, size: 18),
                    onPressed: provider.isLoading
                        ? null
                        : () {
                            _searchController.text = query;
                            context.read<PublicationProvider>().search(query);
                          },
                  ),
              ],
            ),
        ],
      ),
    );
  }

  void _search(BuildContext context) {
    context.read<PublicationProvider>().search(_searchController.text);
  }
}

class _SearchSummary extends StatelessWidget {
  final PublicationProvider provider;

  const _SearchSummary({required this.provider});

  @override
  Widget build(BuildContext context) {
    return DecoratedBox(
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: Theme.of(context).colorScheme.outlineVariant),
      ),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              provider.query,
              style: Theme.of(
                context,
              ).textTheme.titleMedium?.copyWith(fontWeight: FontWeight.w700),
            ),
            const SizedBox(height: 8),
            Text('${provider.totalAvailable} publications found'),
            Text('Most active year: ${provider.mostActiveYear ?? '-'}'),
            Text('Open the Journal tab to browse publications.'),
          ],
        ),
      ),
    );
  }
}
