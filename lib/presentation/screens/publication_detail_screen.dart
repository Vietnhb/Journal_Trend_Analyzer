import 'package:flutter/material.dart';
import 'search_screen.dart'; // Để dùng MockPublication

class PublicationDetailScreen extends StatelessWidget {
  final MockPublication publication;

  const PublicationDetailScreen({super.key, required this.publication});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Publication Details')),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              publication.title,
              style: Theme.of(context).textTheme.headlineSmall?.copyWith(
                fontWeight: FontWeight.bold,
                color: Theme.of(context).colorScheme.primary,
              ),
            ),
            const SizedBox(height: 20),
            Card(
              elevation: 3,
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
              child: Padding(
                padding: const EdgeInsets.all(16),
                child: Column(
                  children: [
                    _buildInfoRow(Icons.person, 'Authors', publication.authors.join(', ')),
                    const Divider(),
                    _buildInfoRow(Icons.calendar_today, 'Year', publication.year.toString()),
                    const Divider(),
                    _buildInfoRow(Icons.book, 'Journal', publication.journal),
                    const Divider(),
                    _buildInfoRow(Icons.star, 'Citations', publication.citations.toString(), valueColor: Colors.green),
                    const Divider(),
                    _buildInfoRow(Icons.link, 'DOI', publication.doi, valueColor: Colors.blue),
                  ],
                ),
              ),
            ),
            const SizedBox(height: 24),
            const Text(
              'Abstract',
              style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 12),
            Text(
              publication.abstractText,
              style: const TextStyle(fontSize: 16, height: 1.6, color: Colors.black87),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildInfoRow(IconData icon, String label, String value, {Color? valueColor}) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 8),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(icon, size: 22, color: Colors.blueGrey),
          const SizedBox(width: 12),
          Expanded(
            child: RichText(
              text: TextSpan(
                style: const TextStyle(color: Colors.black87, fontSize: 16),
                children: [
                  TextSpan(text: '$label: ', style: const TextStyle(fontWeight: FontWeight.bold)),
                  TextSpan(
                    text: value,
                    style: TextStyle(color: valueColor ?? Colors.black87, fontWeight: valueColor != null ? FontWeight.w600 : FontWeight.normal),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}
