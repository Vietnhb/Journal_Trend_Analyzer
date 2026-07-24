import 'package:flutter/material.dart';
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

  void _select(int index) {
    setState(() => _selected = index);
  }

  Future<void> _confirmSignOut() async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Đăng xuất?'),
        content: const Text('Phiên quản trị trên trình duyệt này sẽ kết thúc.'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Hủy'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(context, true),
            child: const Text('Đăng xuất'),
          ),
        ],
      ),
    );
    if (confirmed == true) await widget.onSignOut();
  }

  @override
  Widget build(BuildContext context) => LayoutBuilder(
    builder: (context, constraints) {
      final wide = constraints.maxWidth >= 1160;
      final rail = !wide && constraints.maxWidth >= 760;
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
                    closeOnSelect: true,
                  ),
                ),
              ),
        appBar: AppBar(
          toolbarHeight: 66,
          leading: wide || rail ? null : null,
          automaticallyImplyLeading: !wide && !rail,
          titleSpacing: wide || rail ? 22 : 4,
          title: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                _destinations[_selected].label,
                style: const TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.w900,
                ),
              ),
              Text(
                _destinations[_selected].caption,
                style: TextStyle(
                  color: Theme.of(context).colorScheme.onSurfaceVariant,
                  fontSize: 11,
                ),
              ),
            ],
          ),
          actions: [
            IconButton(
              tooltip: 'Đổi giao diện sáng/tối',
              onPressed: widget.onToggleTheme,
              icon: Icon(
                Theme.of(context).brightness == Brightness.dark
                    ? Icons.light_mode_outlined
                    : Icons.dark_mode_outlined,
              ),
            ),
            const SizedBox(width: 4),
            _ProfileMenu(
              identity: widget.session.identity,
              onSignOut: _confirmSignOut,
            ),
            const SizedBox(width: 14),
          ],
          bottom: PreferredSize(
            preferredSize: const Size.fromHeight(1),
            child: Divider(height: 1, color: Theme.of(context).dividerColor),
          ),
        ),
        body: Row(
          children: [
            if (wide)
              SizedBox(
                width: 266,
                child: _SideNavigation(
                  selected: _selected,
                  onSelected: _select,
                  identity: widget.session.identity,
                  onSignOut: _confirmSignOut,
                ),
              )
            else if (rail)
              NavigationRail(
                selectedIndex: _selected,
                onDestinationSelected: _select,
                labelType: NavigationRailLabelType.all,
                groupAlignment: -.75,
                leading: Padding(
                  padding: const EdgeInsets.only(bottom: 20),
                  child: _LogoIcon(),
                ),
                destinations: [
                  for (final destination in _destinations)
                    NavigationRailDestination(
                      icon: Icon(destination.icon),
                      selectedIcon: Icon(destination.selectedIcon),
                      label: Text(destination.shortLabel),
                    ),
                ],
              ),
            if (wide || rail)
              VerticalDivider(width: 1, color: Theme.of(context).dividerColor),
            Expanded(
              child: KeyedSubtree(
                key: ValueKey(_selected),
                child: _page(_selected),
              ),
            ),
          ],
        ),
      );
    },
  );
}

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
  _Destination(
    label: 'Tổng quan',
    shortLabel: 'Tổng quan',
    caption: 'Tình trạng hệ thống',
    icon: Icons.grid_view_outlined,
    selectedIcon: Icons.grid_view_rounded,
  ),
  _Destination(
    label: 'Người dùng',
    shortLabel: 'Users',
    caption: 'Authentication & roles',
    icon: Icons.people_alt_outlined,
    selectedIcon: Icons.people_alt_rounded,
  ),
  _Destination(
    label: 'Remote Config',
    shortLabel: 'Config',
    caption: 'Cấu hình ứng dụng',
    icon: Icons.tune_outlined,
    selectedIcon: Icons.tune_rounded,
  ),
  _Destination(
    label: 'Báo cáo',
    shortLabel: 'PDF',
    caption: 'Cloud Storage',
    icon: Icons.picture_as_pdf_outlined,
    selectedIcon: Icons.picture_as_pdf_rounded,
  ),
  _Destination(
    label: 'Analytics',
    shortLabel: 'GA4',
    caption: 'Hành vi người dùng',
    icon: Icons.query_stats_outlined,
    selectedIcon: Icons.query_stats_rounded,
  ),
  _Destination(
    label: 'Crash Analyzer',
    shortLabel: 'Crash',
    caption: 'Crashlytics & BigQuery',
    icon: Icons.bug_report_outlined,
    selectedIcon: Icons.bug_report_rounded,
  ),
  _Destination(
    label: 'Messaging',
    shortLabel: 'FCM',
    caption: 'Gửi thông báo thử',
    icon: Icons.notifications_active_outlined,
    selectedIcon: Icons.notifications_active_rounded,
  ),
  _Destination(
    label: 'Nhật ký',
    shortLabel: 'Audit',
    caption: 'Hoạt động quản trị',
    icon: Icons.receipt_long_outlined,
    selectedIcon: Icons.receipt_long_rounded,
  ),
];

class _SideNavigation extends StatelessWidget {
  const _SideNavigation({
    required this.selected,
    required this.onSelected,
    required this.identity,
    required this.onSignOut,
    this.closeOnSelect = false,
  });

  final int selected;
  final ValueChanged<int> onSelected;
  final AdminIdentity identity;
  final VoidCallback onSignOut;
  final bool closeOnSelect;

  @override
  Widget build(BuildContext context) => ColoredBox(
    color: Theme.of(context).colorScheme.surface,
    child: Column(
      children: [
        const Padding(
          padding: EdgeInsets.fromLTRB(22, 23, 22, 18),
          child: _SidebarBrand(),
        ),
        Expanded(
          child: ListView(
            padding: const EdgeInsets.symmetric(horizontal: 12),
            children: [
              Padding(
                padding: const EdgeInsets.fromLTRB(11, 5, 11, 8),
                child: Text(
                  'ĐIỀU HƯỚNG',
                  style: TextStyle(
                    color: Theme.of(context).colorScheme.outline,
                    fontSize: 10,
                    fontWeight: FontWeight.w900,
                    letterSpacing: 1.2,
                  ),
                ),
              ),
              for (var i = 0; i < _destinations.length; i++)
                Padding(
                  padding: const EdgeInsets.only(bottom: 4),
                  child: ListTile(
                    selected: selected == i,
                    onTap: () {
                      onSelected(i);
                      if (closeOnSelect) Navigator.pop(context);
                    },
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(11),
                    ),
                    selectedTileColor: Theme.of(
                      context,
                    ).colorScheme.primary.withValues(alpha: .1),
                    leading: Icon(
                      selected == i
                          ? _destinations[i].selectedIcon
                          : _destinations[i].icon,
                      size: 20,
                      color: selected == i
                          ? Theme.of(context).colorScheme.primary
                          : Theme.of(context).colorScheme.onSurfaceVariant,
                    ),
                    title: Text(
                      _destinations[i].label,
                      style: TextStyle(
                        fontSize: 13,
                        fontWeight: selected == i
                            ? FontWeight.w900
                            : FontWeight.w600,
                      ),
                    ),
                    dense: true,
                    visualDensity: const VisualDensity(vertical: -1),
                  ),
                ),
            ],
          ),
        ),
        Divider(height: 1, color: Theme.of(context).dividerColor),
        Padding(
          padding: const EdgeInsets.all(14),
          child: Row(
            children: [
              _Avatar(identity: identity, radius: 18),
              const SizedBox(width: 10),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      identity.label,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(
                        fontSize: 12,
                        fontWeight: FontWeight.w800,
                      ),
                    ),
                    const Text(
                      'Administrator',
                      style: TextStyle(color: AppTheme.success, fontSize: 10),
                    ),
                  ],
                ),
              ),
              IconButton(
                tooltip: 'Đăng xuất',
                onPressed: onSignOut,
                icon: const Icon(Icons.logout_rounded, size: 19),
              ),
            ],
          ),
        ),
      ],
    ),
  );
}

class _ProfileMenu extends StatelessWidget {
  const _ProfileMenu({required this.identity, required this.onSignOut});
  final AdminIdentity identity;
  final VoidCallback onSignOut;

  @override
  Widget build(BuildContext context) => PopupMenuButton<String>(
    tooltip: 'Tài khoản quản trị',
    onSelected: (value) {
      if (value == 'logout') onSignOut();
    },
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
                style: const TextStyle(fontWeight: FontWeight.w900),
              ),
              Text(
                identity.email ?? identity.uid,
                style: const TextStyle(fontSize: 11),
              ),
            ],
          ),
        ),
      ),
      const PopupMenuDivider(),
      const PopupMenuItem(
        value: 'logout',
        child: ListTile(
          dense: true,
          leading: Icon(Icons.logout_rounded),
          title: Text('Đăng xuất'),
        ),
      ),
    ],
    child: _Avatar(identity: identity, radius: 18),
  );
}

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
            style: const TextStyle(fontWeight: FontWeight.w900),
          )
        : null,
  );
}

class _SidebarBrand extends StatelessWidget {
  const _SidebarBrand();

  @override
  Widget build(BuildContext context) => Row(
    children: [
      const _LogoIcon(),
      const SizedBox(width: 11),
      Expanded(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Journal Trend',
              style: Theme.of(
                context,
              ).textTheme.titleSmall?.copyWith(fontWeight: FontWeight.w900),
            ),
            Text(
              'ADMIN CONSOLE',
              style: TextStyle(
                color: Theme.of(context).colorScheme.primary,
                fontSize: 9,
                fontWeight: FontWeight.w900,
                letterSpacing: 1.2,
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
      gradient: const LinearGradient(colors: [AppTheme.brand, AppTheme.accent]),
      borderRadius: BorderRadius.circular(11),
    ),
    child: const Padding(
      padding: EdgeInsets.all(9),
      child: Icon(Icons.auto_graph_rounded, color: Colors.white, size: 20),
    ),
  );
}
