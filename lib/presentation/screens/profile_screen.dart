import 'package:flutter/material.dart';

class ProfileScreen extends StatelessWidget {
  const ProfileScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Profile')),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          Text('Settings', style: Theme.of(context).textTheme.titleLarge),
          const SizedBox(height: 12),
          SwitchListTile(
            value: true,
            onChanged: null,
            title: const Text('Filter future publication metadata'),
            subtitle: const Text('Uses the current year from the device.'),
            secondary: const Icon(Icons.event_available),
          ),
          const SizedBox(height: 24),
          Text('About', style: Theme.of(context).textTheme.titleLarge),
          const SizedBox(height: 12),
          const _AboutRow(label: 'App', value: 'Journal Trend Analyzer'),
          const _AboutRow(label: 'Data source', value: 'OpenAlex API'),
          const _AboutRow(label: 'Framework', value: 'Flutter'),
          const _AboutRow(
            label: 'Scope',
            value: 'Search, publications, trends, authors, journals, dashboard',
          ),
        ],
      ),
    );
  }
}

class _AboutRow extends StatelessWidget {
  final String label;
  final String value;

  const _AboutRow({required this.label, required this.value});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(
            width: 96,
            child: Text(
              label,
              style: const TextStyle(fontWeight: FontWeight.w700),
            ),
          ),
          Expanded(child: Text(value)),
        ],
      ),
    );
  }
}
