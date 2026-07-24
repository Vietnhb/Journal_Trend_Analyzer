import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:journal_trend_admin_web/core/core.dart';

import '../pages/analytics_page.dart';
import '../pages/audit_logs_page.dart';
import '../pages/crashes_page.dart';
import '../pages/messaging_page.dart';
import '../pages/overview_page.dart';
import '../pages/remote_config_page.dart';
import '../pages/reports_page.dart';
import '../pages/users_page.dart';
import '../theme/app_theme.dart';

// ─── Shell ────────────────────────────────────────────────────────────────────

class AdminShell extends StatefulWidget {
  const AdminShell({
    required this.api,
    required this.session,
    required this.onSignOut,
    required this.onToggleTheme,
    super.key,
  });

  final AdminApi api;
  final AdminSession session;
  final Future<void> Function() onSignOut;
  final VoidCallback onToggleTheme;

  @override
  State<AdminShell> createState() => _AdminShellState();
}

class _AdminShellState extends State<AdminShell> {
  int _selected = 0;
  final Map<int, Widget> _pageCache = {};

  Widget _page(int index) => _pageCache.putIfAbsent(
    index,
    () => switch (index) {
      0 => OverviewPage(api: widget.api, onNavigate: _select),
      1 => UsersPage(api: widget.api, currentUid: widget.session.identity.uid),
      2 => RemoteConfigPage(api: widget.api),
      3 => ReportsPage(api: widget.api),
      4 => AnalyticsPage(api: widget.api),
      5 => CrashesPage(api: widget.api),
      6 => MessagingPage(api: widget.api),
      7 => AuditLogsPage(api: widget.api),
      _ => OverviewPage(api: widget.api, onNavigate: _select),
    },
  );

  void _select(int index) => setState(() => _selected = index);

  Future<void> _confirmSignOut() async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => _SignOutDialog(),
    );
    if (confirmed == true) await widget.onSignOut();
  }

  @override
  Widget build(BuildContext context) => LayoutBuilder(
    builder: (context, constraints) {
      final wide = constraints.maxWidth >= 1160;
      final rail = !wide && constraints.maxWidth >= 760;
      final border = Theme.of(context).dividerColor;

      return Scaffold(
        drawer: wide || rail
            ? null
            : Drawer(
                child: SafeArea(
                  child: _SideNavigation(
                    selected: _selected,
                    onSelected: _select,
                    identity: widget.session.identity,
                    onSignOut: _confirmSignOut,
                    onToggleTheme: widget.onToggleTheme,
                    closeOnSelect: true,
                  ),
                ),
              ),
        // ── Slim AppBar — only contextual controls, no page title duplication ─
        appBar: AppBar(
          toolbarHeight: 52,
          leading: wide || rail ? null : null,
          automaticallyImplyLeading: !wide && !rail,
          titleSpacing: wide || rail ? 0 : 4,
          title: wide || rail
              ? null // page title lives in PageHeading on wide/rail layouts
              : Text(
                  _destinations[_selected].label,
                  style: GoogleFonts.inter(
                    fontSize: 14,
                    fontWeight: FontWeight.w700,
                    letterSpacing: -0.2,
                  ),
                ),
          actions: [
            // Theme toggle
            _ThemeToggle(onToggle: widget.onToggleTheme),
            const SizedBox(width: 4),
            // Profile
            _ProfileMenu(
              identity: widget.session.identity,
              onSignOut: _confirmSignOut,
            ),
            const SizedBox(width: 12),
          ],
          bottom: PreferredSize(
            preferredSize: const Size.fromHeight(0.5),
            child: Divider(height: 0.5, color: border),
          ),
        ),
        body: Row(
          children: [
            if (wide)
              SizedBox(
                width: 256,
                child: _SideNavigation(
                  selected: _selected,
                  onSelected: _select,
                  identity: widget.session.identity,
                  onSignOut: _confirmSignOut,
                  onToggleTheme: widget.onToggleTheme,
                ),
              )
            else if (rail)
              _CompactRail(selected: _selected, onSelected: _select),
            if (wide || rail) VerticalDivider(width: 0.5, color: border),
            Expanded(
              child: AnimatedSwitcher(
                duration: const Duration(milliseconds: 180),
                switchInCurve: Curves.easeOut,
                switchOutCurve: Curves.easeIn,
                transitionBuilder: (child, anim) => FadeTransition(
                  opacity: anim,
                  child: SlideTransition(
                    position: Tween<Offset>(
                      begin: const Offset(0, 0.02),
                      end: Offset.zero,
                    ).animate(anim),
                    child: child,
                  ),
                ),
                child: KeyedSubtree(
                  key: ValueKey(_selected),
                  child: _page(_selected),
                ),
              ),
            ),
          ],
        ),
      );
    },
  );
}

// ─── Navigation destination data ─────────────────────────────────────────────

class _Destination {
  const _Destination({
    required this.label,
    required this.shortLabel,
    required this.caption,
    required this.icon,
    required this.selectedIcon,
  });

  final String label;
  final String shortLabel;
  final String caption;
  final IconData icon;
  final IconData selectedIcon;
}

const _destinations = [
  // Group 0: Operations (indices 0–3)
  _Destination(
    label: 'Overview',
    shortLabel: 'Overview',
    caption: 'System status',
    icon: Icons.grid_view_outlined,
    selectedIcon: Icons.grid_view_rounded,
  ),
  _Destination(
    label: 'Users',
    shortLabel: 'Users',
    caption: 'Authentication & roles',
    icon: Icons.people_alt_outlined,
    selectedIcon: Icons.people_alt_rounded,
  ),
  _Destination(
    label: 'Remote Config',
    shortLabel: 'Config',
    caption: 'App configuration',
    icon: Icons.tune_outlined,
    selectedIcon: Icons.tune_rounded,
  ),
  _Destination(
    label: 'Reports',
    shortLabel: 'PDF',
    caption: 'Cloud Storage',
    icon: Icons.picture_as_pdf_outlined,
    selectedIcon: Icons.picture_as_pdf_rounded,
  ),
  // Group 1: Observability (indices 4–7)
  _Destination(
    label: 'Analytics',
    shortLabel: 'GA4',
    caption: 'User behavior',
    icon: Icons.query_stats_outlined,
    selectedIcon: Icons.query_stats_rounded,
  ),
  _Destination(
    label: 'Crashlytics',
    shortLabel: 'Crash',
    caption: 'Crashlytics · BigQuery',
    icon: Icons.bug_report_outlined,
    selectedIcon: Icons.bug_report_rounded,
  ),
  _Destination(
    label: 'Messaging',
    shortLabel: 'FCM',
    caption: 'Push notifications',
    icon: Icons.notifications_active_outlined,
    selectedIcon: Icons.notifications_active_rounded,
  ),
  _Destination(
    label: 'Audit Log',
    shortLabel: 'Audit',
    caption: 'Admin activity',
    icon: Icons.receipt_long_outlined,
    selectedIcon: Icons.receipt_long_rounded,
  ),
];

// Groups: label → list of destination indices
const _navGroups = [
  ('Operations', [0, 1, 2, 3]),
  ('Observability', [4, 5, 6, 7]),
];

// ─── SideNavigation ───────────────────────────────────────────────────────────

class _SideNavigation extends StatelessWidget {
  const _SideNavigation({
    required this.selected,
    required this.onSelected,
    required this.identity,
    required this.onSignOut,
    required this.onToggleTheme,
    this.closeOnSelect = false,
  });

  final int selected;
  final ValueChanged<int> onSelected;
  final AdminIdentity identity;
  final VoidCallback onSignOut;
  final VoidCallback onToggleTheme;
  final bool closeOnSelect;

  @override
  Widget build(BuildContext context) {
    final surface = Theme.of(context).colorScheme.surface;
    final border = Theme.of(context).dividerColor;
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return ColoredBox(
      color: surface,
      child: Column(
        children: [
          // ── Brand ─────────────────────────────────────────────────────────
          Padding(
            padding: const EdgeInsets.fromLTRB(18, 14, 18, 12),
            child: _SidebarBrand(),
          ),
          Divider(height: 0.5, color: border),

          // ── Nav groups ────────────────────────────────────────────────────
          Expanded(
            child: ListView(
              padding: const EdgeInsets.fromLTRB(10, 12, 10, 12),
              children: [
                for (final group in _navGroups) ...[
                  _NavGroupLabel(label: group.$1),
                  const SizedBox(height: 4),
                  for (final i in group.$2)
                    _NavItem(
                      destination: _destinations[i],
                      index: i,
                      selected: selected == i,
                      onTap: () {
                        onSelected(i);
                        if (closeOnSelect) Navigator.pop(context);
                      },
                    ),
                  const SizedBox(height: 16),
                ],
              ],
            ),
          ),

          // ── Footer ────────────────────────────────────────────────────────
          Divider(height: 0.5, color: border),
          _SidebarFooter(
            identity: identity,
            onSignOut: onSignOut,
            onToggleTheme: onToggleTheme,
            isDark: isDark,
          ),
        ],
      ),
    );
  }
}

class _NavGroupLabel extends StatelessWidget {
  const _NavGroupLabel({required this.label});
  final String label;

  @override
  Widget build(BuildContext context) => Padding(
    padding: const EdgeInsets.fromLTRB(10, 0, 10, 2),
    child: Text(
      label.toUpperCase(),
      style: GoogleFonts.inter(
        color: Theme.of(
          context,
        ).colorScheme.onSurfaceVariant.withValues(alpha: .6),
        fontSize: 9.5,
        fontWeight: FontWeight.w700,
        letterSpacing: 1.0,
      ),
    ),
  );
}

class _NavItem extends StatefulWidget {
  const _NavItem({
    required this.destination,
    required this.index,
    required this.selected,
    required this.onTap,
  });

  final _Destination destination;
  final int index;
  final bool selected;
  final VoidCallback onTap;

  @override
  State<_NavItem> createState() => _NavItemState();
}

class _NavItemState extends State<_NavItem> {
  bool _hovered = false;

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final isSelected = widget.selected;

    final bgSelected = cs.primary.withValues(alpha: .09);
    final bgHover = isDark
        ? Colors.white.withValues(alpha: .04)
        : Colors.black.withValues(alpha: .03);

    return MouseRegion(
      onEnter: (_) => setState(() => _hovered = true),
      onExit: (_) => setState(() => _hovered = false),
      cursor: SystemMouseCursors.click,
      child: GestureDetector(
        onTap: widget.onTap,
        child: Padding(
          padding: const EdgeInsets.only(bottom: 2),
          child: AnimatedContainer(
            duration: const Duration(milliseconds: 140),
            curve: Curves.easeOut,
            decoration: BoxDecoration(
              color: isSelected
                  ? bgSelected
                  : (_hovered ? bgHover : Colors.transparent),
              borderRadius: BorderRadius.circular(AppRadius.md),
            ),
            child: Stack(
              alignment: Alignment.centerLeft,
              children: [
                // Left accent bar
                AnimatedContainer(
                  duration: const Duration(milliseconds: 180),
                  width: isSelected ? 3 : 0,
                  height: isSelected ? 20 : 0,
                  decoration: BoxDecoration(
                    color: cs.primary,
                    borderRadius: BorderRadius.circular(2),
                  ),
                ),
                // Item content
                Padding(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 12,
                    vertical: 9,
                  ),
                  child: Row(
                    children: [
                      Icon(
                        isSelected
                            ? widget.destination.selectedIcon
                            : widget.destination.icon,
                        size: 17,
                        color: isSelected ? cs.primary : cs.onSurfaceVariant,
                      ),
                      const SizedBox(width: 11),
                      Expanded(
                        child: AnimatedDefaultTextStyle(
                          duration: const Duration(milliseconds: 140),
                          style: GoogleFonts.inter(
                            fontSize: 13,
                            fontWeight: isSelected
                                ? FontWeight.w700
                                : FontWeight.w500,
                            color: isSelected ? cs.primary : cs.onSurface,
                          ),
                          child: Text(widget.destination.label),
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _SidebarFooter extends StatelessWidget {
  const _SidebarFooter({
    required this.identity,
    required this.onSignOut,
    required this.onToggleTheme,
    required this.isDark,
  });

  final AdminIdentity identity;
  final VoidCallback onSignOut;
  final VoidCallback onToggleTheme;
  final bool isDark;

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
      child: Row(
        children: [
          _Avatar(identity: identity, radius: 17),
          const SizedBox(width: 10),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  identity.label,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: GoogleFonts.inter(
                    fontSize: 12.5,
                    fontWeight: FontWeight.w700,
                    color: cs.onSurface,
                  ),
                ),
                const SizedBox(height: 1),
                Text(
                  'Administrator',
                  style: GoogleFonts.inter(
                    fontSize: 10.5,
                    fontWeight: FontWeight.w600,
                    color: AppColors.success,
                  ),
                ),
              ],
            ),
          ),
          // Theme toggle
          Tooltip(
            message: isDark ? 'Light mode' : 'Dark mode',
            child: InkWell(
              onTap: onToggleTheme,
              borderRadius: BorderRadius.circular(AppRadius.sm),
              child: Padding(
                padding: const EdgeInsets.all(6),
                child: Icon(
                  isDark ? Icons.light_mode_outlined : Icons.dark_mode_outlined,
                  size: 16,
                  color: cs.onSurfaceVariant,
                ),
              ),
            ),
          ),
          const SizedBox(width: 2),
          // Sign out
          Tooltip(
            message: 'Sign out',
            child: InkWell(
              onTap: onSignOut,
              borderRadius: BorderRadius.circular(AppRadius.sm),
              child: Padding(
                padding: const EdgeInsets.all(6),
                child: Icon(
                  Icons.logout_rounded,
                  size: 16,
                  color: cs.onSurfaceVariant,
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

// ─── Compact rail (tablet) ───────────────────────────────────────────────────

class _CompactRail extends StatelessWidget {
  const _CompactRail({required this.selected, required this.onSelected});

  final int selected;
  final ValueChanged<int> onSelected;

  @override
  Widget build(BuildContext context) => NavigationRail(
    selectedIndex: selected,
    onDestinationSelected: onSelected,
    labelType: NavigationRailLabelType.all,
    groupAlignment: -0.85,
    leading: Padding(
      padding: const EdgeInsets.only(bottom: 16),
      child: _LogoIcon(),
    ),
    minWidth: 72,
    destinations: [
      for (final d in _destinations)
        NavigationRailDestination(
          icon: Icon(d.icon),
          selectedIcon: Icon(d.selectedIcon),
          label: Text(d.shortLabel),
          padding: const EdgeInsets.symmetric(vertical: 2),
        ),
    ],
  );
}

// ─── ProfileMenu ─────────────────────────────────────────────────────────────

class _ProfileMenu extends StatelessWidget {
  const _ProfileMenu({required this.identity, required this.onSignOut});
  final AdminIdentity identity;
  final VoidCallback onSignOut;

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;

    return PopupMenuButton<String>(
      tooltip: 'Account',
      onSelected: (value) {
        if (value == 'logout') onSignOut();
      },
      offset: const Offset(0, 44),
      itemBuilder: (context) => [
        PopupMenuItem(
          enabled: false,
          child: SizedBox(
            width: 220,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  identity.label,
                  style: GoogleFonts.inter(
                    fontWeight: FontWeight.w700,
                    color: cs.onSurface,
                  ),
                ),
                Text(
                  identity.email ?? identity.uid,
                  style: GoogleFonts.inter(
                    fontSize: 11.5,
                    color: cs.onSurfaceVariant,
                  ),
                ),
              ],
            ),
          ),
        ),
        PopupMenuDivider(height: 0.5),
        PopupMenuItem(
          value: 'logout',
          child: Row(
            children: [
              Icon(Icons.logout_rounded, size: 16, color: cs.onSurface),
              const SizedBox(width: 10),
              Text(
                'Sign out',
                style: GoogleFonts.inter(
                  fontSize: 13,
                  fontWeight: FontWeight.w500,
                ),
              ),
            ],
          ),
        ),
      ],
      child: _Avatar(identity: identity, radius: 15),
    );
  }
}

// ─── Avatar ───────────────────────────────────────────────────────────────────

class _Avatar extends StatelessWidget {
  const _Avatar({required this.identity, required this.radius});
  final AdminIdentity identity;
  final double radius;

  @override
  Widget build(BuildContext context) => CircleAvatar(
    radius: radius,
    backgroundColor: Theme.of(context).colorScheme.primaryContainer,
    backgroundImage: identity.photoUrl == null
        ? null
        : NetworkImage(identity.photoUrl!),
    child: identity.photoUrl == null
        ? Text(
            (identity.displayName ?? identity.email ?? 'A')
                .substring(0, 1)
                .toUpperCase(),
            style: GoogleFonts.inter(
              fontWeight: FontWeight.w800,
              fontSize: radius * 0.8,
            ),
          )
        : null,
  );
}

// ─── SidebarBrand ─────────────────────────────────────────────────────────────

class _SidebarBrand extends StatelessWidget {
  const _SidebarBrand();

  @override
  Widget build(BuildContext context) => Row(
    children: [
      _LogoIcon(),
      const SizedBox(width: 11),
      Expanded(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Journal Trend',
              style: GoogleFonts.inter(
                fontSize: 13.5,
                fontWeight: FontWeight.w800,
                letterSpacing: -0.3,
                color: Theme.of(context).colorScheme.onSurface,
              ),
            ),
            Text(
              'ADMIN CONSOLE',
              style: GoogleFonts.inter(
                color: Theme.of(context).colorScheme.primary,
                fontSize: 9,
                fontWeight: FontWeight.w800,
                letterSpacing: 1.3,
              ),
            ),
          ],
        ),
      ),
    ],
  );
}

class _LogoIcon extends StatelessWidget {
  const _LogoIcon();

  @override
  Widget build(BuildContext context) => DecoratedBox(
    decoration: BoxDecoration(
      gradient: const LinearGradient(
        begin: Alignment.topLeft,
        end: Alignment.bottomRight,
        colors: [AppColors.brand, AppColors.accent],
      ),
      borderRadius: BorderRadius.circular(AppRadius.md),
    ),
    child: const Padding(
      padding: EdgeInsets.all(8),
      child: Icon(Icons.show_chart_rounded, color: Colors.white, size: 18),
    ),
  );
}

// ─── ThemeToggle ─────────────────────────────────────────────────────────────

class _ThemeToggle extends StatelessWidget {
  const _ThemeToggle({required this.onToggle});
  final VoidCallback onToggle;

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    return Tooltip(
      message: isDark ? 'Light mode' : 'Dark mode',
      child: IconButton(
        onPressed: onToggle,
        icon: AnimatedSwitcher(
          duration: const Duration(milliseconds: 200),
          transitionBuilder: (child, anim) => RotationTransition(
            turns: anim,
            child: FadeTransition(opacity: anim, child: child),
          ),
          child: Icon(
            isDark ? Icons.light_mode_outlined : Icons.dark_mode_outlined,
            key: ValueKey(isDark),
            size: 18,
          ),
        ),
        iconSize: 18,
        padding: const EdgeInsets.all(8),
      ),
    );
  }
}

// ─── SignOut dialog ───────────────────────────────────────────────────────────

class _SignOutDialog extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final border = Theme.of(context).dividerColor;

    return Dialog(
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 400),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(24, 24, 24, 0),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'Sign out?',
                    style: GoogleFonts.inter(
                      fontSize: 16,
                      fontWeight: FontWeight.w700,
                      letterSpacing: -0.3,
                      color: cs.onSurface,
                    ),
                  ),
                  const SizedBox(height: 8),
                  Text(
                    'Your admin session on this browser will end.',
                    style: GoogleFonts.inter(
                      fontSize: 13.5,
                      color: cs.onSurfaceVariant,
                      height: 1.5,
                    ),
                  ),
                  const SizedBox(height: 24),
                ],
              ),
            ),
            Divider(height: 0.5, color: border),
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 14),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.end,
                children: [
                  TextButton(
                    onPressed: () => Navigator.pop(context, false),
                    child: const Text('Cancel'),
                  ),
                  const SizedBox(width: 8),
                  FilledButton(
                    onPressed: () => Navigator.pop(context, true),
                    child: const Text('Sign out'),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}
