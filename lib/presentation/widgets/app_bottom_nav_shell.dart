import 'package:flutter/material.dart';

import '../screens/search_screen.dart';
import '../screens/research_dashboard_screen.dart';
import '../trends/screens/trend_analysis_screen.dart';

class AppBottomNavShell extends StatefulWidget {
  const AppBottomNavShell({super.key});

  @override
  State<AppBottomNavShell> createState() => _AppBottomNavShellState();
}

class _AppBottomNavShellState extends State<AppBottomNavShell> {
  int index = 0;

  final screens = const [
    SearchScreen(),
    TrendAnalysisScreen(),
    ResearchDashboardScreen(),
  ];

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: IndexedStack(index: index, children: screens),
      bottomNavigationBar: NavigationBar(
        selectedIndex: index,
        onDestinationSelected: (i) => setState(() => index = i),
        destinations: const [
          NavigationDestination(icon: Icon(Icons.search), label: 'Search'),
          NavigationDestination(icon: Icon(Icons.bar_chart), label: 'Trends'),
          NavigationDestination(
            icon: Icon(Icons.dashboard),
            label: 'Dashboard',
          ),
        ],
      ),
    );
  }
}
