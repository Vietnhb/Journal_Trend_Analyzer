import 'package:flutter/material.dart';

class ResearchDashboardScreen extends StatelessWidget {
  const ResearchDashboardScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Research Dashboard')),
      body: const Center(
        child: Text(
          'Dashboard metrics will be implemented here (to be done next).',
        ),
      ),
    );
  }
}
