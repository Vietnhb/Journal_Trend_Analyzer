import 'package:flutter/material.dart';
import 'publication_detail_screen.dart';

// --- MOCK DATA MODEL ---
// Tạm thời để Model ở đây. Sau này Minh làm xong, bạn đổi sang Model của Minh nhé.
class MockPublication {
  final String id;
  final String title;
  final List<String> authors;
  final int year;
  final String journal;
  final int citations;
  final String doi;
  final String abstractText;

  MockPublication({
    required this.id,
    required this.title,
    required this.authors,
    required this.year,
    required this.journal,
    required this.citations,
    required this.doi,
    required this.abstractText,
  });
}

// --- MOCK DATA ---
final List<MockPublication> mockData = [
  MockPublication(
    id: 'W123456',
    title: 'Attention Is All You Need',
    authors: ['Ashish Vaswani', 'Noam Shazeer', 'Niki Parmar'],
    year: 2017,
    journal: 'Advances in Neural Information Processing Systems',
    citations: 125000,
    doi: '10.48550/arXiv.1706.03762',
    abstractText: 'The dominant sequence transduction models are based on complex recurrent or convolutional neural networks...',
  ),
  MockPublication(
    id: 'W789012',
    title: 'Deep Residual Learning for Image Recognition',
    authors: ['Kaiming He', 'Xiangyu Zhang', 'Shaoqing Ren', 'Jian Sun'],
    year: 2016,
    journal: 'CVPR',
    citations: 180000,
    doi: '10.1109/CVPR.2016.90',
    abstractText: 'Deeper neural networks are more difficult to train. We present a residual learning framework to ease the training of networks that are substantially deeper than those used previously.',
  ),
  MockPublication(
    id: 'W345678',
    title: 'Artificial Intelligence in Healthcare: A Review',
    authors: ['Jane Doe', 'John Smith'],
    year: 2023,
    journal: 'Nature Medicine',
    citations: 540,
    doi: '10.1038/s41591-023-01',
    abstractText: 'This paper discusses the impact of AI on modern healthcare, highlighting recent breakthroughs in predictive analytics and medical imaging.',
  ),
];

class SearchScreen extends StatefulWidget {
  const SearchScreen({super.key});

  @override
  State<SearchScreen> createState() => _SearchScreenState();
}

class _SearchScreenState extends State<SearchScreen> {
  final _searchController = TextEditingController();
  bool _isLoading = false;
  List<MockPublication> _results = [];
  bool _hasSearched = false;

  void _performSearch() async {
    final query = _searchController.text.trim();
    if (query.isEmpty) return;

    setState(() {
      _isLoading = true;
      _hasSearched = true;
    });

    // Giả lập gọi API mất 1.5 giây để bạn thấy được hiệu ứng Loading
    await Future.delayed(const Duration(milliseconds: 1500));

    setState(() {
      _isLoading = false;
      // Tìm kiếm cơ bản giả lập dựa trên tiêu đề
      _results = mockData
          .where((p) => p.title.toLowerCase().contains(query.toLowerCase()))
          .toList();
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Journal Search')),
      body: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            TextField(
              controller: _searchController,
              decoration: InputDecoration(
                hintText: 'Enter a topic (e.g., Attention or AI)',
                prefixIcon: const Icon(Icons.search),
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(12),
                ),
                suffixIcon: IconButton(
                  icon: const Icon(Icons.clear),
                  onPressed: () => _searchController.clear(),
                ),
              ),
              onSubmitted: (_) => _performSearch(),
            ),
            const SizedBox(height: 16),
            SizedBox(
              width: double.infinity,
              child: FilledButton(
                onPressed: _isLoading ? null : _performSearch,
                child: _isLoading 
                    ? const SizedBox(
                        width: 20, 
                        height: 20, 
                        child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white)
                      ) 
                    : const Text('Search'),
              ),
            ),
            const SizedBox(height: 16),
            Expanded(
              child: _buildResults(),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildResults() {
    if (!_hasSearched) {
      return const Center(
        child: Text(
          'Enter a topic and press search',
          style: TextStyle(color: Colors.grey, fontSize: 16),
        ),
      );
    }

    if (_isLoading) {
      return const Center(child: CircularProgressIndicator());
    }

    if (_results.isEmpty) {
      return const Center(
        child: Text(
          'No publications found.',
          style: TextStyle(color: Colors.redAccent, fontSize: 16),
        ),
      );
    }

    return ListView.builder(
      itemCount: _results.length,
      itemBuilder: (context, index) {
        final pub = _results[index];
        return Card(
          elevation: 2,
          margin: const EdgeInsets.only(bottom: 12),
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
          child: ListTile(
            contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
            title: Text(
              pub.title, 
              style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16),
            ),
            subtitle: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const SizedBox(height: 6),
                Text('${pub.year} • ${pub.journal}'),
                const SizedBox(height: 4),
                Text('Citations: ${pub.citations}', style: const TextStyle(color: Colors.green, fontWeight: FontWeight.w600)),
              ],
            ),
            isThreeLine: true,
            trailing: const Icon(Icons.chevron_right),
            onTap: () {
              Navigator.push(
                context,
                MaterialPageRoute(
                  builder: (context) => PublicationDetailScreen(publication: pub),
                ),
              );
            },
          ),
        );
      },
    );
  }
}
