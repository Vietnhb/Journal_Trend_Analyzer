import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

import '../core/core.dart';
import '../theme/app_theme.dart';
import '../utils/ui_format.dart';
import '../widgets/admin_widgets.dart';

class OverviewPage extends StatefulWidget {
  const OverviewPage({required this.api, required this.onNavigate, super.key});

  final AdminApi api;
  final ValueChanged<int> onNavigate;

  @override
  State<OverviewPage> createState() => _OverviewPageState();
}

class _OverviewPageState extends State<OverviewPage> {
  late Future<
    ({OverviewData overview, AnalyticsData analytics, CrashData crashes})
  >
  _future;

  @override
  void initState() {
    super.initState();
    _load();
  }

  void _load() {
    _future = _fetchOverview();
  }

  Future<({OverviewData overview, AnalyticsData analytics, CrashData crashes})>
  _fetchOverview() async {
    final overview = widget.api.getOverview();
    final analytics = widget.api.getAnalytics(days: 30);
    final crashes = widget.api.getCrashes(days: 30);
    return (
      overview: await overview,
      analytics: await analytics,
      crashes: await crashes,
    );
  }

  void _refresh() => setState(_load);

  @override
  Widget build(BuildContext context) => PageBody(
    children: [
      PageHeading(
        eyebrow: 'Dashboard',
        title: 'System Overview',
        description: 'Current user activity and Firebase service status.',
        actions: [
          FilledButton.icon(
            onPressed: () => widget.onNavigate(1),
            icon: const Icon(Icons.manage_accounts_outlined, size: 16),
            label: const Text('Manage Users'),
          ),
          OutlinedButton.icon(
            onPressed: _refresh,
            icon: const Icon(Icons.refresh_rounded, size: 16),
            label: const Text('Refresh'),
          ),
        ],
      ),
      FutureBuilder(
        future: _future,
        builder: (context, snapshot) {
          if (snapshot.connectionState != ConnectionState.done) {
            return const Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                MetricCardSkeletonGrid(),
                SizedBox(height: 20),
                SectionCard(child: LoadingPanel(rowCount: 5)),
              ],
            );
          }
          if (snapshot.hasError) {
            return SectionCard(
              child: ErrorPanel(
                message: errorText(snapshot.error!),
                onRetry: _refresh,
              ),
            );
          }
          final data = snapshot.requireData;
          return Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              // ── Metric cards ──────────────────────────────────────────────
              AdaptiveGrid(
                children: [
                  MetricCard(
                    label: 'Total Users',
                    value: formatNumber(data.overview.users.total),
                    detail:
                        '${formatNumber(data.overview.users.newLast30Days)} new / 30 days',
                    icon: Icons.people_alt_outlined,
                    tone: MetricTone.violet,
                    onTap: () => widget.onNavigate(1),
                  ),
                  MetricCard(
                    label: 'Administrators',
                    value: formatNumber(data.overview.users.admins),
                    detail:
                        '${formatNumber(data.overview.users.disabled)} accounts disabled',
                    icon: Icons.admin_panel_settings_outlined,
                    tone: MetricTone.green,
                  ),
                  MetricCard(
                    label: 'Reports Stored',
                    value: formatNumber(data.overview.reports.count),
                    detail: formatBytes(data.overview.reports.totalBytes),
                    icon: Icons.picture_as_pdf_outlined,
                    onTap: () => widget.onNavigate(3),
                  ),
                  MetricCard(
                    label: 'Remote Config',
                    value: data.overview.remoteConfig.versionNumber == null
                        ? 'Not set'
                        : 'v${data.overview.remoteConfig.versionNumber}',
                    detail:
                        'Updated ${formatDateTime(data.overview.remoteConfig.updatedAt)}',
                    icon: Icons.tune_rounded,
                    tone: MetricTone.amber,
                    onTap: () => widget.onNavigate(2),
                  ),
                  MetricCard(
                    label: 'Current App Version',
                    value: data.crashes.currentVersion ?? 'No data',
                    detail: data.crashes.currentVersion == null
                        ? 'Waiting for a Crashlytics event'
                        : 'Latest version observed by Crashlytics',
                    icon: Icons.system_update_alt_rounded,
                    tone: MetricTone.blue,
                    onTap: () => widget.onNavigate(5),
                  ),
                ],
              ),
              const SizedBox(height: 20),
              // ── Service status + signals ──────────────────────────────────
              LayoutBuilder(
                builder: (context, constraints) {
                  final services = SectionCard(
                    padding: EdgeInsets.zero,
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [
                        // Header
                        Padding(
                          padding: const EdgeInsets.fromLTRB(20, 18, 20, 0),
                          child: SectionTitle(
                            title: 'Service Status',
                            description: 'Active Firebase integrations.',
                          ),
                        ),
                        const SizedBox(height: 4),
                        const Divider(height: 1),
                        // Rows
                        _ServiceRow(
                          icon: Icons.people_alt_outlined,
                          label: 'Authentication',
                          detail: 'Accounts · custom claims',
                          status: IntegrationStatus.ready,
                        ),
                        _ServiceRow(
                          icon: Icons.cloud_outlined,
                          label: 'Cloud Storage',
                          detail: '${data.overview.reports.count} PDF reports',
                          status: IntegrationStatus.ready,
                        ),
                        _ServiceRow(
                          icon: Icons.tune_rounded,
                          label: 'Remote Config',
                          detail: 'Dynamic config for mobile',
                          status:
                              data.overview.remoteConfig.versionNumber == null
                              ? IntegrationStatus.unconfigured
                              : IntegrationStatus.ready,
                        ),
                        _ServiceRow(
                          icon: Icons.query_stats_rounded,
                          label: 'Google Analytics',
                          detail: 'Events in 30 days',
                          status: data.analytics.status,
                        ),
                        _ServiceRow(
                          icon: Icons.bug_report_outlined,
                          label: 'Crashlytics',
                          detail: 'Crash analysis via BigQuery',
                          status: data.crashes.status,
                          last: true,
                        ),
                      ],
                    ),
                  );

                  final signals = SectionCard(
                    padding: EdgeInsets.zero,
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [
                        Padding(
                          padding: const EdgeInsets.fromLTRB(20, 18, 20, 0),
                          child: SectionTitle(
                            title: '30-day Signals',
                            description: 'Key metrics to watch.',
                          ),
                        ),
                        const SizedBox(height: 4),
                        const Divider(height: 1),
                        _SignalTile(
                          icon: Icons.bolt_rounded,
                          label: 'Analytics events',
                          value: formatNumber(
                            data.analytics.summary.eventCount,
                          ),
                          onTap: () => widget.onNavigate(4),
                          tone: MetricTone.blue,
                        ),
                        _SignalTile(
                          icon: Icons.person_outline_rounded,
                          label: 'Active users',
                          value: formatNumber(
                            data.analytics.summary.activeUsers,
                          ),
                          onTap: () => widget.onNavigate(4),
                          tone: MetricTone.violet,
                        ),
                        _SignalTile(
                          icon: Icons.warning_amber_rounded,
                          label: 'Crash events',
                          value: formatNumber(data.crashes.summary.events),
                          onTap: () => widget.onNavigate(5),
                          tone: MetricTone.red,
                        ),
                        const SizedBox(height: 8),
                        const Divider(height: 1),
                        Padding(
                          padding: const EdgeInsets.fromLTRB(16, 12, 16, 16),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.stretch,
                            children: [
                              FilledButton.icon(
                                onPressed: () => widget.onNavigate(2),
                                icon: const Icon(Icons.tune_rounded, size: 16),
                                label: const Text('Update Config'),
                              ),
                              const SizedBox(height: 8),
                              OutlinedButton.icon(
                                onPressed: () => widget.onNavigate(6),
                                icon: const Icon(
                                  Icons.notifications_active_outlined,
                                  size: 16,
                                ),
                                label: const Text('Send Test Notification'),
                              ),
                            ],
                          ),
                        ),
                      ],
                    ),
                  );

                  if (constraints.maxWidth < 860) {
                    return Column(
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [services, const SizedBox(height: 20), signals],
                    );
                  }
                  return Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Expanded(flex: 3, child: services),
                      const SizedBox(width: 20),
                      Expanded(flex: 2, child: signals),
                    ],
                  );
                },
              ),
            ],
          );
        },
      ),
    ],
  );
}

// ─── _ServiceRow ──────────────────────────────────────────────────────────────

class _ServiceRow extends StatelessWidget {
  const _ServiceRow({
    required this.icon,
    required this.label,
    required this.detail,
    required this.status,
    this.last = false,
  });

  final IconData icon;
  final String label;
  final String detail;
  final IntegrationStatus status;
  final bool last;

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final isDark = Theme.of(context).brightness == Brightness.dark;

    final statusWidget = switch (status) {
      IntegrationStatus.ready => const StatusDot(
        'Ready',
        tone: StatusTone.success,
      ),
      IntegrationStatus.authorizationRequired => const StatusDot(
        'Connect required',
        tone: StatusTone.info,
      ),
      IntegrationStatus.pending => Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          const PulsingDot(color: AppColors.info),
          const SizedBox(width: 6),
          Text(
            'Syncing',
            style: GoogleFonts.inter(
              fontSize: 12.5,
              fontWeight: FontWeight.w500,
              color: AppColors.info,
            ),
          ),
        ],
      ),
      IntegrationStatus.unconfigured => const StatusDot(
        'Not configured',
        tone: StatusTone.warning,
      ),
      IntegrationStatus.error => const StatusDot(
        'Error',
        tone: StatusTone.danger,
      ),
      IntegrationStatus.unknown => const StatusDot('Unknown'),
    };

    return Column(
      children: [
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 13),
          child: Row(
            children: [
              DecoratedBox(
                decoration: BoxDecoration(
                  color: isDark
                      ? cs.primary.withValues(alpha: .12)
                      : cs.primary.withValues(alpha: .07),
                  borderRadius: BorderRadius.circular(AppRadius.sm),
                ),
                child: Padding(
                  padding: const EdgeInsets.all(8),
                  child: Icon(icon, size: 16, color: cs.primary),
                ),
              ),
              const SizedBox(width: 14),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      label,
                      style: GoogleFonts.inter(
                        fontSize: 13,
                        fontWeight: FontWeight.w600,
                        color: cs.onSurface,
                      ),
                    ),
                    const SizedBox(height: 1),
                    Text(
                      detail,
                      style: GoogleFonts.inter(
                        color: cs.onSurfaceVariant,
                        fontSize: 11.5,
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 12),
              statusWidget,
            ],
          ),
        ),
        if (!last) const Divider(height: 0.5, indent: 20, endIndent: 20),
      ],
    );
  }
}

// ─── _SignalTile ──────────────────────────────────────────────────────────────

class _SignalTile extends StatefulWidget {
  const _SignalTile({
    required this.icon,
    required this.label,
    required this.value,
    required this.onTap,
    this.tone = MetricTone.blue,
  });

  final IconData icon;
  final String label;
  final String value;
  final VoidCallback onTap;
  final MetricTone tone;

  @override
  State<_SignalTile> createState() => _SignalTileState();
}

class _SignalTileState extends State<_SignalTile> {
  bool _hovered = false;

  Color _toneColor() => switch (widget.tone) {
    MetricTone.blue => AppColors.brand,
    MetricTone.violet => AppColors.accent,
    MetricTone.green => AppColors.success,
    MetricTone.amber => AppColors.warning,
    MetricTone.red => AppColors.danger,
  };

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final color = _toneColor();
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return MouseRegion(
      onEnter: (_) => setState(() => _hovered = true),
      onExit: (_) => setState(() => _hovered = false),
      cursor: SystemMouseCursors.click,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 120),
        color: _hovered
            ? (isDark
                  ? Colors.white.withValues(alpha: .03)
                  : Colors.black.withValues(alpha: .015))
            : Colors.transparent,
        child: InkWell(
          onTap: widget.onTap,
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 13),
            child: Row(
              children: [
                DecoratedBox(
                  decoration: BoxDecoration(
                    color: color.withValues(alpha: .1),
                    borderRadius: BorderRadius.circular(AppRadius.sm),
                  ),
                  child: Padding(
                    padding: const EdgeInsets.all(8),
                    child: Icon(widget.icon, size: 16, color: color),
                  ),
                ),
                const SizedBox(width: 14),
                Expanded(
                  child: Text(
                    widget.label,
                    style: GoogleFonts.inter(
                      fontSize: 13,
                      fontWeight: FontWeight.w500,
                      color: cs.onSurface,
                    ),
                  ),
                ),
                Text(
                  widget.value,
                  style: GoogleFonts.inter(
                    fontSize: 18,
                    fontWeight: FontWeight.w800,
                    letterSpacing: -0.5,
                    color: cs.onSurface,
                  ),
                ),
                const SizedBox(width: 6),
                Icon(
                  Icons.chevron_right_rounded,
                  size: 16,
                  color: cs.onSurfaceVariant,
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
