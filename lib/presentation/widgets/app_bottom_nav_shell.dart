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
      icon: Icons.query_stats_outlined,
      selectedIcon: Icons.query_stats,
      label: 'Analytics',
    ),
    _NavDestination(
      icon: Icons.settings_outlined,
      selectedIcon: Icons.settings_rounded,
      label: 'Settings',
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
    final isDark = Theme.of(context).brightness == Brightness.dark;
    return AnnotatedRegion<SystemUiOverlayStyle>(
      value: (isDark ? SystemUiOverlayStyle.light : SystemUiOverlayStyle.dark)
          .copyWith(statusBarColor: Colors.transparent),
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
    final colorScheme = Theme.of(context).colorScheme;
    final isDark = Theme.of(context).brightness == Brightness.dark;
    return Container(
      decoration: BoxDecoration(
        color: colorScheme.surface,
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: isDark ? 0.28 : 0.07),
            blurRadius: 16,
            offset: const Offset(0, -4),
          ),
        ],
      ),
      child: SafeArea(
        child: SizedBox(
          height: 64,
          child: Row(
            children: [
              for (int i = 0; i < destinations.length; i++)
                Expanded(
                  child: _NavItem(
                    destination: destinations[i],
                    isSelected: selectedIndex == i,
                    onTap: () => onDestinationSelected(i),
                  ),
                ),
            ],
          ),
        ),
      ),
    );
  }
}

class _NavItem extends StatelessWidget {
  final _NavDestination destination;
  final bool isSelected;
  final VoidCallback onTap;

  const _NavItem({
    required this.destination,
    required this.isSelected,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    final activeColor = colorScheme.primary;
    final inactiveColor = colorScheme.onSurfaceVariant;
    final color = isSelected ? activeColor : inactiveColor;

    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(12),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          AnimatedSwitcher(
            duration: const Duration(milliseconds: 200),
            child: isSelected
                ? Container(
                    key: const ValueKey('selected'),
                    padding: const EdgeInsets.symmetric(
                      horizontal: 16,
                      vertical: 4,
                    ),
                    decoration: BoxDecoration(
                      color: activeColor.withValues(alpha: 0.12),
                      borderRadius: BorderRadius.circular(20),
                    ),
                    child: Icon(
                      destination.selectedIcon,
                      color: activeColor,
                      size: 22,
                    ),
                  )
                : Icon(
                    key: const ValueKey('unselected'),
                    destination.icon,
                    color: inactiveColor,
                    size: 22,
                  ),
          ),
          const SizedBox(height: 2),
          Text(
            destination.label,
            style: TextStyle(
              fontSize: 11,
              fontWeight: isSelected ? FontWeight.w600 : FontWeight.w400,
              color: color,
            ),
          ),
        ],
      ),
    );
  }
}
