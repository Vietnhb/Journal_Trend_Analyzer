import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

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

  static const _destinations = [
    _NavDestination(
      icon: Icons.home_outlined,
      selectedIcon: Icons.home_rounded,
      label: 'Home',
    ),
    _NavDestination(
      icon: Icons.article_outlined,
      selectedIcon: Icons.article_rounded,
      label: 'Journals',
    ),
    _NavDestination(
      icon: Icons.key_outlined,
      selectedIcon: Icons.key_rounded,
      label: 'Keywords',
    ),
    _NavDestination(
      icon: Icons.settings_outlined,
      selectedIcon: Icons.settings_rounded,
      label: 'Profile',
    ),
  ];

  final _screens = const [
    HomeScreen(),
    JournalScreen(),
    KeywordsScreen(),
    ProfileScreen(),
  ];

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;
    return AnnotatedRegion<SystemUiOverlayStyle>(
      value: (isDark ? SystemUiOverlayStyle.light : SystemUiOverlayStyle.dark)
          .copyWith(
            statusBarColor: Colors.transparent,
            systemNavigationBarColor: theme.colorScheme.surfaceContainerLowest,
            systemNavigationBarDividerColor: theme.colorScheme.outlineVariant,
            systemNavigationBarIconBrightness: isDark
                ? Brightness.light
                : Brightness.dark,
          ),
      child: Scaffold(
        body: IndexedStack(index: index, children: _screens),
        bottomNavigationBar: _BottomNavBar(
          selectedIndex: index,
          destinations: _destinations,
          onDestinationSelected: (i) => setState(() => index = i),
        ),
      ),
    );
  }
}

class _NavDestination {
  final IconData icon;
  final IconData selectedIcon;
  final String label;
  const _NavDestination({
    required this.icon,
    required this.selectedIcon,
    required this.label,
  });
}

class _BottomNavBar extends StatelessWidget {
  final int selectedIndex;
  final List<_NavDestination> destinations;
  final ValueChanged<int> onDestinationSelected;

  const _BottomNavBar({
    required this.selectedIndex,
    required this.destinations,
    required this.onDestinationSelected,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return DecoratedBox(
      decoration: BoxDecoration(
        color: theme.colorScheme.surfaceContainerLowest,
        border: Border(
          top: BorderSide(color: theme.colorScheme.outlineVariant),
        ),
      ),
      child: NavigationBar(
        selectedIndex: selectedIndex,
        onDestinationSelected: onDestinationSelected,
        labelBehavior: NavigationDestinationLabelBehavior.alwaysShow,
        destinations: [
          for (final destination in destinations)
            NavigationDestination(
              key: Key('nav_${destination.label.toLowerCase()}'),
              icon: Icon(destination.icon),
              selectedIcon: Icon(destination.selectedIcon),
              label: destination.label,
              tooltip: destination.label,
            ),
        ],
      ),
    );
  }
}
