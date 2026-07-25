import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

import '../core/core.dart';
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
      // Keep the content width monotonic as the browser grows. The previous
      // 1160px jump from a compact rail to a full sidebar made pages narrower.
      final wide = constraints.maxWidth >= 1360;
      final rail = !wide && constraints.maxWidth >= 840;
      final border = Theme.of(context).dividerColor;
      final desktopChrome = wide || rail;

      return Scaffold(
        drawer: desktopChrome
            ? null
            : Drawer(
                child: SafeArea(
                  child: _SideNavigation(
                    selected: _selected,
                    onSelected: _select,
                    identity: widget.session.identity,
                    closeOnSelect: true,
                  ),
                ),
              ),
        appBar: desktopChrome
            ? null
            : AppBar(
                automaticallyImplyLeading: true,
                titleSpacing: 4,
                title: Text(
                  _destinations[_selected].label,
                  style: GoogleFonts.inter(
                    fontSize: 14,
                    fontWeight: FontWeight.w700,
                    letterSpacing: -.2,
                  ),
                ),
                actions: [
                  _ThemeToggle(onToggle: widget.onToggleTheme),
                  const SizedBox(width: 4),
                  _ProfileMenu(
                    identity: widget.session.identity,
                    onSignOut: _confirmSignOut,
                  ),
                  const SizedBox(width: 12),
                ],
                bottom: PreferredSize(
                  preferredSize: const Size.fromHeight(.5),
                  child: Divider(height: .5, color: border),
                ),
              ),
        body: Row(
          children: [
            if (wide)
              SizedBox(
                width: 276,
                child: _SideNavigation(
                  selected: _selected,
                  onSelected: _select,
                  identity: widget.session.identity,
                ),
              )
            else if (rail)
              _CompactRail(selected: _selected, onSelected: _select),
            if (desktopChrome) VerticalDivider(width: .5, color: border),
            Expanded(
              child: Column(
                children: [
                  if (desktopChrome)
                    _WorkspaceBar(
                      destination: _destinations[_selected],
                      identity: widget.session.identity,
                      onToggleTheme: widget.onToggleTheme,
                      onSignOut: _confirmSignOut,
                    ),
                  Expanded(
                    child: AnimatedSwitcher(
                      duration: const Duration(milliseconds: 180),
                      switchInCurve: Curves.easeOut,
                      switchOutCurve: Curves.easeIn,
                      transitionBuilder: (child, anim) => FadeTransition(
                        opacity: anim,
                        child: SlideTransition(
                          position: Tween<Offset>(
                            begin: const Offset(0, .012),
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
    this.closeOnSelect = false,
  });

  final int selected;
  final ValueChanged<int> onSelected;
  final AdminIdentity identity;
  final bool closeOnSelect;

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final surface = isDark ? const Color(0xFF0A0C13) : AppColors.navigation;
    final border = Colors.white.withValues(alpha: .08);

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
          _SidebarFooter(identity: identity),
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
        color: Colors.white.withValues(alpha: .42),
        fontSize: 9,
        fontWeight: FontWeight.w800,
        letterSpacing: 1.25,
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
    final isSelected = widget.selected;

    final bgSelected = Colors.white.withValues(alpha: .095);
    final bgHover = Colors.white.withValues(alpha: .05);
    const selectedColor = Color(0xFF9B9DFF);
    final mutedColor = Colors.white.withValues(alpha: .58);

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
                    color: selectedColor,
                    borderRadius: BorderRadius.circular(2),
                  ),
                ),
                // Item content
                Padding(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 12,
                    vertical: 10,
                  ),
                  child: Row(
                    children: [
                      Icon(
                        isSelected
                            ? widget.destination.selectedIcon
                            : widget.destination.icon,
                        size: 18,
                        color: isSelected ? selectedColor : mutedColor,
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
                            color: isSelected
                                ? Colors.white
                                : Colors.white.withValues(alpha: .78),
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
  const _SidebarFooter({required this.identity});

  final AdminIdentity identity;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 16),
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
                    color: Colors.white,
                  ),
                ),
                const SizedBox(height: 1),
                Row(
                  children: [
                    Container(
                      width: 6,
                      height: 6,
                      decoration: const BoxDecoration(
                        color: AppColors.success,
                        shape: BoxShape.circle,
                      ),
                    ),
                    const SizedBox(width: 6),
                    Text(
                      'AUTHORIZED ADMIN',
                      style: GoogleFonts.inter(
                        fontSize: 9,
                        fontWeight: FontWeight.w700,
                        letterSpacing: .65,
                        color: Colors.white.withValues(alpha: .5),
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
          Tooltip(
            message: 'Admin access active',
            child: Icon(
              Icons.verified_user_outlined,
              size: 18,
              color: Colors.white.withValues(alpha: .42),
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
    backgroundColor: AppColors.navigation,
    selectedIndex: selected,
    onDestinationSelected: onSelected,
    labelType: NavigationRailLabelType.all,
    groupAlignment: -0.85,
    indicatorColor: Colors.white.withValues(alpha: .1),
    selectedIconTheme: const IconThemeData(color: Color(0xFF9B9DFF), size: 20),
    unselectedIconTheme: IconThemeData(
      color: Colors.white.withValues(alpha: .52),
      size: 20,
    ),
    selectedLabelTextStyle: GoogleFonts.inter(
      color: Colors.white,
      fontSize: 10,
      fontWeight: FontWeight.w700,
    ),
    unselectedLabelTextStyle: GoogleFonts.inter(
      color: Colors.white.withValues(alpha: .5),
      fontSize: 10,
      fontWeight: FontWeight.w500,
    ),
    leading: Padding(
      padding: const EdgeInsets.only(bottom: 16),
      child: _LogoIcon(),
    ),
    minWidth: 84,
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

class _WorkspaceBar extends StatelessWidget {
  const _WorkspaceBar({
    required this.destination,
    required this.identity,
    required this.onToggleTheme,
    required this.onSignOut,
  });

  final _Destination destination;
  final AdminIdentity identity;
  final VoidCallback onToggleTheme;
  final VoidCallback onSignOut;

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final border = Theme.of(context).dividerColor;
    return DecoratedBox(
      decoration: BoxDecoration(
        color: cs.surface.withValues(alpha: .97),
        border: Border(bottom: BorderSide(color: border, width: .7)),
      ),
      child: SizedBox(
        height: 64,
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 24),
          child: Row(
            children: [
              DecoratedBox(
                decoration: BoxDecoration(
                  color: cs.primary.withValues(alpha: .09),
                  borderRadius: BorderRadius.circular(AppRadius.md),
                ),
                child: Padding(
                  padding: const EdgeInsets.all(9),
                  child: Icon(
                    destination.selectedIcon,
                    size: 17,
                    color: cs.primary,
                  ),
                ),
              ),
              const SizedBox(width: 12),
              Column(
                mainAxisAlignment: MainAxisAlignment.center,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    destination.label,
                    style: GoogleFonts.inter(
                      color: cs.onSurface,
                      fontSize: 13,
                      fontWeight: FontWeight.w700,
                      letterSpacing: -.15,
                    ),
                  ),
                  const SizedBox(height: 2),
                  Text(
                    destination.caption,
                    style: GoogleFonts.inter(
                      color: cs.onSurfaceVariant,
                      fontSize: 10.5,
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                ],
              ),
              const Spacer(),
              DecoratedBox(
                decoration: BoxDecoration(
                  color: AppColors.success.withValues(alpha: .08),
                  borderRadius: BorderRadius.circular(AppRadius.full),
                  border: Border.all(
                    color: AppColors.success.withValues(alpha: .16),
                  ),
                ),
                child: Padding(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 10,
                    vertical: 6,
                  ),
                  child: Row(
                    children: [
                      const _WorkspaceStatusDot(),
                      const SizedBox(width: 7),
                      Text(
                        'ADMIN WORKSPACE',
                        style: GoogleFonts.inter(
                          color: AppColors.success,
                          fontSize: 9,
                          fontWeight: FontWeight.w800,
                          letterSpacing: .75,
                        ),
                      ),
                    ],
                  ),
                ),
              ),
              const SizedBox(width: 10),
              _ThemeToggle(onToggle: onToggleTheme),
              const SizedBox(width: 4),
              _ProfileMenu(identity: identity, onSignOut: onSignOut),
            ],
          ),
        ),
      ),
    );
  }
}

class _WorkspaceStatusDot extends StatelessWidget {
  const _WorkspaceStatusDot();

  @override
  Widget build(BuildContext context) => Container(
    width: 7,
    height: 7,
    decoration: BoxDecoration(
      color: AppColors.success,
      shape: BoxShape.circle,
      boxShadow: [
        BoxShadow(
          color: AppColors.success.withValues(alpha: .35),
          blurRadius: 7,
        ),
      ],
    ),
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
              'JOURNAL TREND',
              style: GoogleFonts.manrope(
                fontSize: 13,
                fontWeight: FontWeight.w700,
                letterSpacing: -.15,
                color: Colors.white,
              ),
            ),
            Text(
              'OBSERVATORY',
              style: GoogleFonts.inter(
                color: const Color(0xFF9B9DFF),
                fontSize: 9,
                fontWeight: FontWeight.w800,
                letterSpacing: 1.45,
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
  Widget build(BuildContext context) => ClipRRect(
    borderRadius: BorderRadius.circular(AppRadius.lg),
    child: Image.asset(
      'web/icons/jta-icon-192.png',
      width: 38,
      height: 38,
      fit: BoxFit.cover,
      filterQuality: FilterQuality.high,
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
