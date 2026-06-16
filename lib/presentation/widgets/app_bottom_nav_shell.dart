import 'package:flutter/material.dart';

import '../screens/home_screen.dart';
import '../screens/journal_screen.dart';
import '../screens/keywords_screen.dart';
import '../screens/profile_screen.dart';

class AppBottomNavShell extends StatefulWidget {
  const AppBottomNavShell({super.key});

  @override
  State<AppBottomNavShell> createState() => _AppBottomNavShellState();
}

class _AppBottomNavShellState extends State<AppBottomNavShell> {
  int index = 0;

  final screens = const [
    HomeScreen(),
    JournalScreen(),
    KeywordsScreen(),
    ProfileScreen(),
  ];

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: IndexedStack(index: index, children: screens),
      bottomNavigationBar: NavigationBar(
        selectedIndex: index,
        onDestinationSelected: (i) => setState(() => index = i),
        destinations: const [
          NavigationDestination(icon: Icon(Icons.home), label: 'Home'),
          NavigationDestination(icon: Icon(Icons.article), label: 'Journal'),
          NavigationDestination(
            icon: Icon(Icons.manage_search),
            label: 'Keywords',
          ),
          NavigationDestination(icon: Icon(Icons.person), label: 'Profile'),
        ],
      ),
    );
  }
}
