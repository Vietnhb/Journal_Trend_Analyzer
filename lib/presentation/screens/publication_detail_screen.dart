import 'package:flutter/material.dart';

class PublicationDetailScreen extends StatelessWidget {
  final String? publicationId;

  const PublicationDetailScreen({super.key, this.publicationId});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Publication Details')),
      body: Padding(
        padding: const EdgeInsets.all(16),
        child: ListView(
          children: [
            Text(
              'Publication ID: ${publicationId ?? '-'}',
              style: Theme.of(context).textTheme.titleMedium,
            ),
            const SizedBox(height: 16),
            Card(
              child: Padding(
                padding: const EdgeInsets.all(16),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: const [
                    Text(
                      'Title (to be loaded)',
                      style: TextStyle(
                        fontSize: 18,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                    SizedBox(height: 8),
                    Text(
                      'Authors / Year / Journal / Citations / DOI',
                      style: TextStyle(color: Colors.black54),
                    ),
                    SizedBox(height: 12),
                    Text(
                      'Abstract (when available) ...',
                      style: TextStyle(color: Colors.black45),
                    ),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
