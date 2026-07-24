import 'package:flutter/material.dart';
import 'package:journal_trend_admin_web/core/core.dart';

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
        eyebrow: 'Bảng điều khiển',
        title: 'Tổng quan vận hành',
        description:
            'Theo dõi người dùng và các dịch vụ Firebase của Journal Trend Analyzer trong một màn hình.',
        actions: [
          FilledButton.icon(
            onPressed: () => widget.onNavigate(1),
            icon: const Icon(Icons.manage_accounts_outlined),
            label: const Text('Quản lý người dùng'),
          ),
          OutlinedButton.icon(
            onPressed: _refresh,
            icon: const Icon(Icons.refresh_rounded),
            label: const Text('Làm mới'),
          ),
        ],
      ),
      FutureBuilder(
        future: _future,
        builder: (context, snapshot) {
          if (snapshot.connectionState != ConnectionState.done) {
            return const SectionCard(child: LoadingPanel());
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
              AdaptiveGrid(
                children: [
                  MetricCard(
                    label: 'Tổng người dùng',
                    value: formatNumber(data.overview.users.total),
                    detail:
                        '${formatNumber(data.overview.users.newLast30Days)} tài khoản mới / 30 ngày',
                    icon: Icons.people_alt_outlined,
                    tone: MetricTone.violet,
                  ),
                  MetricCard(
                    label: 'Quản trị viên',
                    value: formatNumber(data.overview.users.admins),
                    detail:
                        '${formatNumber(data.overview.users.disabled)} tài khoản bị khóa',
                    icon: Icons.admin_panel_settings_outlined,
                    tone: MetricTone.green,
                  ),
                  MetricCard(
                    label: 'Báo cáo đã lưu',
                    value: formatNumber(data.overview.reports.count),
                    detail: formatBytes(data.overview.reports.totalBytes),
                    icon: Icons.picture_as_pdf_outlined,
                  ),
                  MetricCard(
                    label: 'Remote Config',
                    value: data.overview.remoteConfig.versionNumber == null
                        ? 'Chưa có'
                        : 'v${data.overview.remoteConfig.versionNumber}',
                    detail:
                        'Cập nhật ${formatDateTime(data.overview.remoteConfig.updatedAt)}',
                    icon: Icons.tune_rounded,
                    tone: MetricTone.amber,
                  ),
                ],
              ),
              const SizedBox(height: 22),
              LayoutBuilder(
                builder: (context, constraints) {
                  final services = SectionCard(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [
                        const SectionTitle(
                          title: 'Trạng thái dịch vụ',
                          description:
                              'Kiểm tra nhanh các tích hợp Firebase đang dùng.',
                        ),
                        const SizedBox(height: 18),
                        _ServiceRow(
                          icon: Icons.people_alt_outlined,
                          label: 'Authentication',
                          detail: 'Tài khoản và custom claim Admin',
                          status: IntegrationStatus.ready,
                        ),
                        _ServiceRow(
                          icon: Icons.cloud_outlined,
                          label: 'Cloud Storage',
                          detail: '${data.overview.reports.count} báo cáo PDF',
                          status: IntegrationStatus.ready,
                        ),
                        _ServiceRow(
                          icon: Icons.tune_rounded,
                          label: 'Remote Config',
                          detail: 'Cấu hình động cho mobile app',
                          status:
                              data.overview.remoteConfig.versionNumber == null
                              ? IntegrationStatus.unconfigured
                              : IntegrationStatus.ready,
                        ),
                        _ServiceRow(
                          icon: Icons.query_stats_rounded,
                          label: 'Analytics',
                          detail: 'Sự kiện người dùng trong 30 ngày',
                          status: data.analytics.status,
                        ),
                        _ServiceRow(
                          icon: Icons.bug_report_outlined,
                          label: 'Crashlytics',
                          detail: 'Phân tích lỗi qua BigQuery',
                          status: data.crashes.status,
                          last: true,
                        ),
                      ],
                    ),
                  );
                  final signals = SectionCard(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [
                        const SectionTitle(
                          title: 'Tín hiệu 30 ngày',
                          description: 'Chỉ số nổi bật cần theo dõi.',
                        ),
                        const SizedBox(height: 18),
                        _SignalTile(
                          icon: Icons.bolt_rounded,
                          label: 'Analytics events',
                          value: formatNumber(
                            data.analytics.summary.eventCount,
                          ),
                          onTap: () => widget.onNavigate(4),
                        ),
                        _SignalTile(
                          icon: Icons.person_outline_rounded,
                          label: 'Active users',
                          value: formatNumber(
                            data.analytics.summary.activeUsers,
                          ),
                          onTap: () => widget.onNavigate(4),
                        ),
                        _SignalTile(
                          icon: Icons.warning_amber_rounded,
                          label: 'Crash events',
                          value: formatNumber(data.crashes.summary.events),
                          color: Colors.red,
                          onTap: () => widget.onNavigate(5),
                        ),
                        const Divider(height: 28),
                        FilledButton.tonalIcon(
                          onPressed: () => widget.onNavigate(2),
                          icon: const Icon(Icons.tune_rounded),
                          label: const Text('Cập nhật cấu hình'),
                        ),
                        const SizedBox(height: 10),
                        OutlinedButton.icon(
                          onPressed: () => widget.onNavigate(6),
                          icon: const Icon(Icons.notifications_active_outlined),
                          label: const Text('Gửi thông báo thử'),
                        ),
                      ],
                    ),
                  );
                  if (constraints.maxWidth < 860) {
                    return Column(
                      children: [services, const SizedBox(height: 22), signals],
                    );
                  }
                  return Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Expanded(flex: 3, child: services),
                      const SizedBox(width: 22),
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
    final pill = switch (status) {
      IntegrationStatus.ready => const StatusPill(
        'Sẵn sàng',
        tone: StatusTone.success,
        icon: Icons.check_circle_outline,
      ),
      IntegrationStatus.authorizationRequired => const StatusPill(
        'Cần kết nối',
        tone: StatusTone.info,
        icon: Icons.lock_open_rounded,
      ),
      IntegrationStatus.pending => const StatusPill(
        'Đang đồng bộ',
        tone: StatusTone.info,
        icon: Icons.sync_rounded,
      ),
      IntegrationStatus.unconfigured => const StatusPill(
        'Cần cấu hình',
        tone: StatusTone.warning,
        icon: Icons.settings_outlined,
      ),
      IntegrationStatus.error => const StatusPill(
        'Có lỗi',
        tone: StatusTone.danger,
        icon: Icons.error_outline,
      ),
      IntegrationStatus.unknown => const StatusPill('Chưa xác định'),
    };
    return Column(
      children: [
        Padding(
          padding: const EdgeInsets.symmetric(vertical: 11),
          child: Row(
            children: [
              CircleAvatar(
                radius: 19,
                backgroundColor: Theme.of(
                  context,
                ).colorScheme.primary.withValues(alpha: .1),
                child: Icon(icon, size: 19),
              ),
              const SizedBox(width: 13),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      label,
                      style: const TextStyle(fontWeight: FontWeight.w800),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      detail,
                      style: TextStyle(
                        color: Theme.of(context).colorScheme.onSurfaceVariant,
                        fontSize: 12,
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 10),
              pill,
            ],
          ),
        ),
        if (!last) const Divider(height: 1),
      ],
    );
  }
}

class _SignalTile extends StatelessWidget {
  const _SignalTile({
    required this.icon,
    required this.label,
    required this.value,
    required this.onTap,
    this.color,
  });

  final IconData icon;
  final String label;
  final String value;
  final VoidCallback onTap;
  final Color? color;

  @override
  Widget build(BuildContext context) => ListTile(
    onTap: onTap,
    contentPadding: EdgeInsets.zero,
    leading: CircleAvatar(
      backgroundColor: (color ?? Theme.of(context).colorScheme.primary)
          .withValues(alpha: .1),
      child: Icon(
        icon,
        color: color ?? Theme.of(context).colorScheme.primary,
        size: 19,
      ),
    ),
    title: Text(label, style: const TextStyle(fontSize: 13)),
    subtitle: Text(
      value,
      style: Theme.of(
        context,
      ).textTheme.titleLarge?.copyWith(fontWeight: FontWeight.w900),
    ),
    trailing: const Icon(Icons.chevron_right_rounded),
  );
}
