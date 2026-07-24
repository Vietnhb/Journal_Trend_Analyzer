import 'package:fl_chart/fl_chart.dart';
import 'package:flutter/material.dart';
import 'package:journal_trend_admin_web/core/core.dart';

import '../utils/ui_format.dart';
import '../widgets/admin_widgets.dart';

class CrashesPage extends StatefulWidget {
  const CrashesPage({required this.api, super.key});

  final AdminApi api;

  @override
  State<CrashesPage> createState() => _CrashesPageState();
}

class _CrashesPageState extends State<CrashesPage> {
  AdminDateRange _range = AdminDateRange.last30Days;
  late Future<CrashData> _future;

  @override
  void initState() {
    super.initState();
    _load();
  }

  @override
  void didUpdateWidget(covariant CrashesPage oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.api != widget.api) _load();
  }

  void _load() {
    _future = widget.api.getCrashes(start: _range.start, end: _range.end);
  }

  void _refresh() => setState(_load);

  void _changeRange(AdminDateRange range) {
    setState(() {
      _range = range;
      _load();
    });
  }

  @override
  Widget build(BuildContext context) => PageBody(
    children: [
      PageHeading(
        eyebrow: 'Firebase Crashlytics · BigQuery',
        title: 'Crash Analyzer',
        description:
            'Analyze fatal and non-fatal crashes, and issues affecting the most users.',
        actions: [
          AdminDateRangeFilter(value: _range, onChanged: _changeRange),
          OutlinedButton.icon(
            onPressed: _refresh,
            icon: const Icon(Icons.refresh_rounded, size: 16),
            label: const Text('Refresh'),
          ),
        ],
      ),
      FutureBuilder<CrashData>(
        future: _future,
        builder: (context, snapshot) {
          if (snapshot.connectionState != ConnectionState.done) {
            return const SectionCard(
              child: LoadingPanel(
                style: LoadingStyle.spinner,
                label: 'Loading Crashlytics data…',
              ),
            );
          }
          if (snapshot.hasError) {
            return SectionCard(
              child: ErrorPanel(
                message: errorText(snapshot.error!),
                onRetry: _refresh,
                detail: snapshot.error.toString(),
              ),
            );
          }

          final data = snapshot.requireData;
          if (data.status != IntegrationStatus.ready) {
            return _CrashIntegrationState(
              status: data.status,
              reason: data.reason,
              onRetry: _refresh,
            );
          }

          return _CrashContent(data: data, rangeLabel: _range.label);
        },
      ),
    ],
  );
}

class _CrashContent extends StatelessWidget {
  const _CrashContent({required this.data, required this.rangeLabel});

  final CrashData data;
  final String rangeLabel;

  @override
  Widget build(BuildContext context) => Column(
    crossAxisAlignment: CrossAxisAlignment.stretch,
    children: [
      if (data.summary.events == 0 &&
          data.reason?.trim().isNotEmpty == true) ...[
        SectionCard(
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Icon(
                Icons.cloud_done_outlined,
                color: Theme.of(context).colorScheme.primary,
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Text(
                  data.reason!.trim(),
                  style: TextStyle(
                    color: Theme.of(context).colorScheme.onSurfaceVariant,
                    height: 1.45,
                  ),
                ),
              ),
              const SizedBox(width: 12),
              const StatusPill(
                'Đã kết nối',
                tone: StatusTone.success,
                icon: Icons.check_circle_outline_rounded,
              ),
            ],
          ),
        ),
        const SizedBox(height: 22),
      ],
      _ReleaseBar(data: data, rangeLabel: rangeLabel),
      const SizedBox(height: 14),
      _CrashHealth(data: data, rangeLabel: rangeLabel),
      const SizedBox(height: 22),
      AdaptiveGrid(
        minItemWidth: 225,
        children: [
          MetricCard(
            label: 'Tổng crash events',
            value: formatNumber(data.summary.events),
            detail: rangeLabel,
            icon: Icons.bug_report_outlined,
            tone: MetricTone.violet,
          ),
          MetricCard(
            label: 'Fatal',
            value: formatNumber(data.summary.fatal),
            detail: 'Làm ứng dụng dừng',
            icon: Icons.gpp_bad_outlined,
            tone: MetricTone.red,
          ),
          MetricCard(
            label: 'Non-fatal',
            value: formatNumber(data.summary.nonFatal),
            detail: 'Đã ghi nhận, app tiếp tục chạy',
            icon: Icons.warning_amber_rounded,
            tone: MetricTone.amber,
          ),
          MetricCard(
            label: 'Thiết bị bị ảnh hưởng',
            value: formatNumber(data.summary.affectedUsers),
            detail: 'Unique installations',
            icon: Icons.devices_other_outlined,
            tone: MetricTone.green,
          ),
        ],
      ),
      const SizedBox(height: 22),
      _CrashChart(daily: data.daily, rangeLabel: rangeLabel),
      const SizedBox(height: 22),
      _IssuesSection(issues: data.issues),
    ],
  );
}

class _ReleaseBar extends StatelessWidget {
  const _ReleaseBar({required this.data, required this.rangeLabel});

  final CrashData data;
  final String rangeLabel;

  @override
  Widget build(BuildContext context) {
    final release = data.releases.isEmpty
        ? 'Chưa xác định'
        : data.releases.first;
    return SectionCard(
      child: Wrap(
        spacing: 18,
        runSpacing: 12,
        crossAxisAlignment: WrapCrossAlignment.center,
        children: [
          Icon(
            Icons.rocket_launch_outlined,
            size: 20,
            color: Theme.of(context).colorScheme.primary,
          ),
          Text(
            'Bản phát hành mới nhất $release',
            style: const TextStyle(fontWeight: FontWeight.w800),
          ),
          Text(
            '${formatNumber(data.summary.affectedUsers)} thiết bị bị ảnh hưởng · $rangeLabel',
            style: TextStyle(
              color: Theme.of(context).colorScheme.onSurfaceVariant,
            ),
          ),
          StatusPill(
            data.summary.fatal == 0
                ? 'Không có fatal'
                : '${formatNumber(data.summary.fatal)} fatal',
            tone: data.summary.fatal == 0
                ? StatusTone.success
                : StatusTone.danger,
            icon: data.summary.fatal == 0
                ? Icons.verified_outlined
                : Icons.warning_amber_rounded,
          ),
        ],
      ),
    );
  }
}

class _CrashHealth extends StatelessWidget {
  const _CrashHealth({required this.data, required this.rangeLabel});

  final CrashData data;
  final String rangeLabel;

  @override
  Widget build(BuildContext context) => LayoutBuilder(
    builder: (context, constraints) {
      final cards = [
        _CrashFreeCard(crashFree: data.crashFree),
        _TrendSummaryCard(data: data, rangeLabel: rangeLabel),
      ];
      if (constraints.maxWidth < 900) {
        return Column(
          children: [cards.first, const SizedBox(height: 14), cards.last],
        );
      }
      return Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Expanded(child: cards.first),
          const SizedBox(width: 14),
          Expanded(child: cards.last),
        ],
      );
    },
  );
}

class _CrashFreeCard extends StatelessWidget {
  const _CrashFreeCard({required this.crashFree});

  final CrashFree crashFree;

  @override
  Widget build(BuildContext context) => SectionCard(
    child: Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        const SectionTitle(
          title: 'Độ ổn định',
          description: 'Tính từ Firebase Sessions và fatal Crashlytics.',
        ),
        const SizedBox(height: 18),
        if (!crashFree.available)
          const EmptyPanel(
            title: 'Chưa đủ dữ liệu Sessions',
            description:
                'Crash-free users và sessions sẽ xuất hiện khi session đầu tiên được export.',
            icon: Icons.hourglass_top_rounded,
          )
        else
          Row(
            children: [
              Expanded(
                child: _PercentMetric(
                  label: 'Crash-free users',
                  percent: crashFree.usersPercent,
                  sample: '${formatNumber(crashFree.totalUsers)} users',
                ),
              ),
              const SizedBox(width: 18),
              Expanded(
                child: _PercentMetric(
                  label: 'Crash-free sessions',
                  percent: crashFree.sessionsPercent,
                  sample: '${formatNumber(crashFree.totalSessions)} sessions',
                ),
              ),
            ],
          ),
      ],
    ),
  );
}

class _PercentMetric extends StatelessWidget {
  const _PercentMetric({
    required this.label,
    required this.percent,
    required this.sample,
  });

  final String label;
  final double? percent;
  final String sample;

  @override
  Widget build(BuildContext context) {
    final value = (percent ?? 0).clamp(0, 100);
    final color = value >= 99
        ? Colors.green
        : value >= 95
        ? Colors.orange
        : Theme.of(context).colorScheme.error;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(label, style: const TextStyle(fontWeight: FontWeight.w700)),
        const SizedBox(height: 7),
        Text(
          '${value.toStringAsFixed(2)}%',
          style: TextStyle(
            color: color,
            fontSize: 26,
            fontWeight: FontWeight.w900,
          ),
        ),
        const SizedBox(height: 9),
        LinearProgressIndicator(
          value: value / 100,
          minHeight: 7,
          borderRadius: BorderRadius.circular(99),
          color: color,
          backgroundColor: color.withValues(alpha: .12),
        ),
        const SizedBox(height: 7),
        Text(
          sample,
          style: TextStyle(
            color: Theme.of(context).colorScheme.onSurfaceVariant,
            fontSize: 12,
          ),
        ),
      ],
    );
  }
}

class _TrendSummaryCard extends StatelessWidget {
  const _TrendSummaryCard({required this.data, required this.rangeLabel});

  final CrashData data;
  final String rangeLabel;

  @override
  Widget build(BuildContext context) => SectionCard(
    child: Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        SectionTitle(
          title: 'Trends',
          description: 'Tổng quan sự cố · $rangeLabel.',
          trailing: StatusPill(
            '${formatNumber(data.issues.length)} issues',
            tone: data.issues.isEmpty ? StatusTone.success : StatusTone.warning,
            icon: Icons.show_chart_rounded,
          ),
        ),
        const SizedBox(height: 18),
        Row(
          children: [
            Expanded(
              child: _IssueMetric(
                label: 'Crashes',
                value: formatNumber(data.summary.events),
              ),
            ),
            Expanded(
              child: _IssueMetric(
                label: 'Users',
                value: formatNumber(data.summary.affectedUsers),
              ),
            ),
            Expanded(
              child: _IssueMetric(
                label: 'Fatal',
                value: formatNumber(data.summary.fatal),
              ),
            ),
          ],
        ),
        const SizedBox(height: 14),
        SizedBox(
          height: 92,
          child: data.daily.isEmpty
              ? const Center(child: Text('Chưa có dữ liệu xu hướng'))
              : _MiniDailyChart(data: data.daily),
        ),
      ],
    ),
  );
}

class _MiniDailyChart extends StatelessWidget {
  const _MiniDailyChart({required this.data});
  final List<CrashDaily> data;

  @override
  Widget build(BuildContext context) => LineChart(
    LineChartData(
      minY: 0,
      titlesData: const FlTitlesData(show: false),
      borderData: FlBorderData(show: false),
      gridData: const FlGridData(show: false),
      lineTouchData: const LineTouchData(enabled: false),
      lineBarsData: [
        LineChartBarData(
          spots: [
            for (var index = 0; index < data.length; index++)
              FlSpot(
                index.toDouble(),
                (data[index].fatal + data[index].nonFatal).toDouble(),
              ),
          ],
          color: Theme.of(context).colorScheme.primary,
          barWidth: 3,
          isCurved: true,
          dotData: const FlDotData(show: false),
          belowBarData: BarAreaData(
            show: true,
            color: Theme.of(context).colorScheme.primary.withValues(alpha: .09),
          ),
        ),
      ],
    ),
  );
}

class _CrashIntegrationState extends StatelessWidget {
  const _CrashIntegrationState({
    required this.status,
    required this.reason,
    required this.onRetry,
  });

  final IntegrationStatus status;
  final String? reason;
  final VoidCallback onRetry;

  @override
  Widget build(BuildContext context) {
    final isError = status == IntegrationStatus.error;
    final color = isError
        ? Theme.of(context).colorScheme.error
        : Colors.amber.shade800;
    final title = isError
        ? 'Không thể đọc dữ liệu Crashlytics'
        : 'Chưa có dữ liệu Crashlytics BigQuery';
    final description = reason?.trim().isNotEmpty == true
        ? reason!.trim()
        : 'Trang này cần Crashlytics BigQuery export để phân tích dữ liệu lỗi thực tế.';

    return SectionCard(
      child: LayoutBuilder(
        builder: (context, constraints) {
          final icon = DecoratedBox(
            decoration: BoxDecoration(
              color: color.withValues(alpha: .11),
              borderRadius: BorderRadius.circular(18),
            ),
            child: Padding(
              padding: const EdgeInsets.all(15),
              child: Icon(
                isError
                    ? Icons.error_outline_rounded
                    : Icons.bug_report_outlined,
                color: color,
                size: 30,
              ),
            ),
          );
          final content = Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Wrap(
                spacing: 12,
                runSpacing: 8,
                crossAxisAlignment: WrapCrossAlignment.center,
                children: [
                  Text(
                    title,
                    style: Theme.of(context).textTheme.titleLarge?.copyWith(
                      fontWeight: FontWeight.w900,
                    ),
                  ),
                  StatusPill(
                    isError ? 'Lỗi tích hợp' : 'Cần cấu hình',
                    tone: isError ? StatusTone.danger : StatusTone.warning,
                    icon: isError
                        ? Icons.error_outline_rounded
                        : Icons.settings_outlined,
                  ),
                ],
              ),
              const SizedBox(height: 8),
              Text(
                description,
                style: TextStyle(
                  color: Theme.of(context).colorScheme.onSurfaceVariant,
                  height: 1.5,
                ),
              ),
              const SizedBox(height: 18),
              const _SetupStep(
                number: 1,
                text:
                    'Liên kết Firebase project với BigQuery trong Settings > Integrations.',
              ),
              const _SetupStep(
                number: 2,
                text:
                    'Bật Crashlytics export; bật streaming nếu cần dữ liệu gần thời gian thực.',
              ),
              const _SetupStep(
                number: 3,
                text:
                    'Cấp BigQuery Data Viewer và Job User cho service account, sau đó đặt CRASHLYTICS_TABLE.',
              ),
              const SizedBox(height: 18),
              OutlinedButton.icon(
                onPressed: onRetry,
                icon: const Icon(Icons.refresh_rounded),
                label: const Text('Kiểm tra lại'),
              ),
            ],
          );

          if (constraints.maxWidth < 620) {
            return Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [icon, const SizedBox(height: 18), content],
            );
          }
          return Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              icon,
              const SizedBox(width: 20),
              Expanded(child: content),
            ],
          );
        },
      ),
    );
  }
}

class _SetupStep extends StatelessWidget {
  const _SetupStep({required this.number, required this.text});

  final int number;
  final String text;

  @override
  Widget build(BuildContext context) => Padding(
    padding: const EdgeInsets.only(bottom: 10),
    child: Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        CircleAvatar(
          radius: 11,
          backgroundColor: Theme.of(
            context,
          ).colorScheme.primary.withValues(alpha: .12),
          child: Text(
            '$number',
            style: TextStyle(
              color: Theme.of(context).colorScheme.primary,
              fontSize: 11,
              fontWeight: FontWeight.w900,
            ),
          ),
        ),
        const SizedBox(width: 10),
        Expanded(
          child: Text(
            text,
            style: TextStyle(
              color: Theme.of(context).colorScheme.onSurfaceVariant,
              height: 1.4,
            ),
          ),
        ),
      ],
    ),
  );
}

class _CrashChart extends StatelessWidget {
  const _CrashChart({required this.daily, required this.rangeLabel});

  final List<CrashDaily> daily;
  final String rangeLabel;

  @override
  Widget build(BuildContext context) {
    final ordered = [...daily]..sort((a, b) => a.date.compareTo(b.date));
    final scheme = Theme.of(context).colorScheme;
    return SectionCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          SectionTitle(
            title: 'Xu hướng lỗi',
            description:
                'So sánh fatal và non-fatal theo ngày trong khoảng đã chọn.',
            trailing: StatusPill(
              rangeLabel,
              tone: StatusTone.info,
              icon: Icons.calendar_month_outlined,
            ),
          ),
          const SizedBox(height: 16),
          Wrap(
            spacing: 20,
            runSpacing: 8,
            children: [
              _ChartLegend(color: scheme.error, label: 'Fatal'),
              _ChartLegend(color: scheme.primary, label: 'Non-fatal'),
            ],
          ),
          const SizedBox(height: 14),
          if (ordered.isEmpty)
            const EmptyPanel(
              title: 'Chưa có xu hướng lỗi',
              description:
                  'Không có Crashlytics event trong khoảng thời gian này.',
              icon: Icons.monitor_heart_outlined,
            )
          else
            LayoutBuilder(
              builder: (context, constraints) {
                var fatal = 0;
                var nonFatal = 0;
                for (final item in ordered) {
                  fatal += item.fatal;
                  nonFatal += item.nonFatal;
                }
                return Semantics(
                  image: true,
                  label:
                      'Biểu đồ đường lỗi theo ngày, ${ordered.length} mốc dữ liệu, '
                      '${formatNumber(fatal)} fatal và ${formatNumber(nonFatal)} non-fatal.',
                  child: ExcludeSemantics(
                    child: SizedBox(
                      height: constraints.maxWidth < 680 ? 260 : 320,
                      child: _CrashLineChart(data: ordered),
                    ),
                  ),
                );
              },
            ),
        ],
      ),
    );
  }
}

class _ChartLegend extends StatelessWidget {
  const _ChartLegend({required this.color, required this.label});

  final Color color;
  final String label;

  @override
  Widget build(BuildContext context) => Row(
    mainAxisSize: MainAxisSize.min,
    children: [
      DecoratedBox(
        decoration: BoxDecoration(
          color: color,
          borderRadius: BorderRadius.circular(999),
        ),
        child: const SizedBox(width: 18, height: 4),
      ),
      const SizedBox(width: 7),
      Text(
        label,
        style: TextStyle(
          color: Theme.of(context).colorScheme.onSurfaceVariant,
          fontSize: 12,
          fontWeight: FontWeight.w700,
        ),
      ),
    ],
  );
}

class _CrashLineChart extends StatelessWidget {
  const _CrashLineChart({required this.data});

  final List<CrashDaily> data;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final fatalColor = scheme.error;
    final nonFatalColor = scheme.primary;
    final axisColor = scheme.onSurfaceVariant;
    final gridColor = scheme.outlineVariant.withValues(alpha: .65);
    var maximum = 0;
    for (final point in data) {
      if (point.fatal > maximum) maximum = point.fatal;
      if (point.nonFatal > maximum) maximum = point.nonFatal;
    }
    final interval = (maximum / 4).ceil().clamp(1, maximum + 1).toDouble();
    final maxY = interval * 4 < maximum ? interval * 5 : interval * 4;
    final maxX = data.length == 1 ? 1.0 : (data.length - 1).toDouble();
    final labelStep = (data.length / 5).ceil().clamp(1, data.length);

    return LineChart(
      LineChartData(
        minX: 0,
        maxX: maxX,
        minY: 0,
        maxY: maxY,
        clipData: const FlClipData.all(),
        gridData: FlGridData(
          drawVerticalLine: false,
          horizontalInterval: interval,
          getDrawingHorizontalLine: (_) =>
              FlLine(color: gridColor, strokeWidth: 1, dashArray: [5, 5]),
        ),
        borderData: FlBorderData(
          show: true,
          border: Border(
            left: BorderSide(color: gridColor),
            bottom: BorderSide(color: gridColor),
            right: BorderSide.none,
            top: BorderSide.none,
          ),
        ),
        titlesData: FlTitlesData(
          topTitles: const AxisTitles(
            sideTitles: SideTitles(showTitles: false),
          ),
          rightTitles: const AxisTitles(
            sideTitles: SideTitles(showTitles: false),
          ),
          leftTitles: AxisTitles(
            sideTitles: SideTitles(
              showTitles: true,
              reservedSize: 48,
              interval: interval,
              getTitlesWidget: (value, meta) => SideTitleWidget(
                meta: meta,
                space: 8,
                child: Text(
                  _compactAxisNumber(value),
                  style: TextStyle(color: axisColor, fontSize: 11),
                ),
              ),
            ),
          ),
          bottomTitles: AxisTitles(
            sideTitles: SideTitles(
              showTitles: true,
              reservedSize: 34,
              interval: 1,
              getTitlesWidget: (value, meta) {
                final index = value.round();
                if ((value - index).abs() > .01 ||
                    index < 0 ||
                    index >= data.length ||
                    (index != 0 &&
                        index != data.length - 1 &&
                        index % labelStep != 0)) {
                  return const SizedBox.shrink();
                }
                return SideTitleWidget(
                  meta: meta,
                  space: 10,
                  fitInside: SideTitleFitInsideData.fromTitleMeta(
                    meta,
                    distanceFromEdge: 4,
                  ),
                  child: Text(
                    formatChartDate(data[index].date),
                    style: TextStyle(color: axisColor, fontSize: 11),
                  ),
                );
              },
            ),
          ),
        ),
        lineTouchData: LineTouchData(
          touchTooltipData: LineTouchTooltipData(
            fitInsideHorizontally: true,
            fitInsideVertically: true,
            tooltipBorderRadius: BorderRadius.circular(10),
            getTooltipColor: (_) => scheme.inverseSurface,
            getTooltipItems: (spots) => [
              for (final spot in spots)
                LineTooltipItem(
                  spot.barIndex == 0
                      ? '${formatChartDate(data[spot.x.round()].date)}\n'
                            'Fatal: ${formatNumber(spot.y.round())}'
                      : 'Non-fatal: ${formatNumber(spot.y.round())}',
                  TextStyle(
                    color: scheme.onInverseSurface,
                    fontSize: 12,
                    fontWeight: FontWeight.w700,
                  ),
                ),
            ],
          ),
        ),
        lineBarsData: [
          LineChartBarData(
            spots: [
              for (var index = 0; index < data.length; index++)
                FlSpot(index.toDouble(), data[index].fatal.toDouble()),
            ],
            color: fatalColor,
            barWidth: 3,
            isCurved: data.length > 2,
            curveSmoothness: .2,
            preventCurveOverShooting: true,
            isStrokeCapRound: true,
            dotData: FlDotData(show: data.length <= 14),
            belowBarData: BarAreaData(
              show: true,
              color: fatalColor.withValues(alpha: .07),
            ),
          ),
          LineChartBarData(
            spots: [
              for (var index = 0; index < data.length; index++)
                FlSpot(index.toDouble(), data[index].nonFatal.toDouble()),
            ],
            color: nonFatalColor,
            barWidth: 3,
            isCurved: data.length > 2,
            curveSmoothness: .2,
            preventCurveOverShooting: true,
            isStrokeCapRound: true,
            dotData: FlDotData(show: data.length <= 14),
            belowBarData: BarAreaData(
              show: true,
              color: nonFatalColor.withValues(alpha: .07),
            ),
          ),
        ],
      ),
      duration: const Duration(milliseconds: 350),
      curve: Curves.easeOutCubic,
    );
  }
}

class _IssuesSection extends StatefulWidget {
  const _IssuesSection({required this.issues});

  final List<CrashIssue> issues;

  @override
  State<_IssuesSection> createState() => _IssuesSectionState();
}

class _IssuesSectionState extends State<_IssuesSection> {
  final _search = TextEditingController();
  String _type = 'ALL';
  String _release = 'ALL';

  @override
  void dispose() {
    _search.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final query = _search.text.trim().toLowerCase();
    final releases =
        widget.issues.expand((issue) => issue.versions).toSet().toList()
          ..sort();
    final ordered =
        widget.issues.where((issue) {
          final matchesType =
              _type == 'ALL' || _errorType(issue.errorType) == _type;
          final matchesRelease =
              _release == 'ALL' || issue.versions.contains(_release);
          final searchable =
              '${issue.title ?? ''} ${issue.subtitle ?? ''} ${issue.issueId}'
                  .toLowerCase();
          return matchesType && matchesRelease && searchable.contains(query);
        }).toList()..sort((a, b) {
          final byEvents = b.events.compareTo(a.events);
          return byEvents != 0
              ? byEvents
              : (b.lastSeen ?? '').compareTo(a.lastSeen ?? '');
        });
    return SectionCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          SectionTitle(
            title: 'Issue nổi bật',
            description:
                'Nhóm lỗi theo issue ID từ Crashlytics BigQuery export.',
            trailing: StatusPill(
              '${formatNumber(ordered.length)} issue',
              tone: ordered.isEmpty ? StatusTone.success : StatusTone.warning,
              icon: ordered.isEmpty
                  ? Icons.check_circle_outline_rounded
                  : Icons.bug_report_outlined,
            ),
          ),
          const SizedBox(height: 18),
          Wrap(
            spacing: 12,
            runSpacing: 12,
            crossAxisAlignment: WrapCrossAlignment.center,
            children: [
              SizedBox(
                width: 390,
                child: TextField(
                  controller: _search,
                  onChanged: (_) => setState(() {}),
                  decoration: const InputDecoration(
                    prefixIcon: Icon(Icons.search_rounded),
                    hintText: 'Tìm theo tiêu đề, subtitle hoặc issue ID',
                    isDense: true,
                    border: OutlineInputBorder(),
                  ),
                ),
              ),
              DropdownButton<String>(
                value: _type,
                items: const [
                  DropdownMenuItem(value: 'ALL', child: Text('Mọi loại lỗi')),
                  DropdownMenuItem(value: 'FATAL', child: Text('Fatal')),
                  DropdownMenuItem(
                    value: 'NON_FATAL',
                    child: Text('Non-fatal'),
                  ),
                ],
                onChanged: (value) => setState(() => _type = value ?? 'ALL'),
              ),
              DropdownButton<String>(
                value: releases.contains(_release) ? _release : 'ALL',
                items: [
                  const DropdownMenuItem(
                    value: 'ALL',
                    child: Text('Mọi phiên bản'),
                  ),
                  for (final release in releases)
                    DropdownMenuItem(value: release, child: Text(release)),
                ],
                onChanged: (value) => setState(() => _release = value ?? 'ALL'),
              ),
            ],
          ),
          const SizedBox(height: 14),
          if (ordered.isEmpty)
            EmptyPanel(
              title: widget.issues.isEmpty
                  ? 'Không có issue'
                  : 'Không có issue khớp bộ lọc',
              description: widget.issues.isEmpty
                  ? 'Đây là tín hiệu tốt: chưa ghi nhận lỗi trong khoảng đã chọn.'
                  : 'Thử đổi loại lỗi, phiên bản hoặc từ khóa tìm kiếm.',
              icon: Icons.verified_outlined,
            )
          else
            LayoutBuilder(
              builder: (context, constraints) {
                if (constraints.maxWidth < 840) {
                  return Column(
                    children: [
                      for (var index = 0; index < ordered.length; index++) ...[
                        _IssueCard(issue: ordered[index]),
                        if (index != ordered.length - 1)
                          const SizedBox(height: 12),
                      ],
                    ],
                  );
                }
                return SingleChildScrollView(
                  scrollDirection: Axis.horizontal,
                  child: ConstrainedBox(
                    constraints: BoxConstraints(minWidth: constraints.maxWidth),
                    child: DataTable(
                      columnSpacing: 28,
                      headingRowHeight: 46,
                      dataRowMinHeight: 68,
                      dataRowMaxHeight: 78,
                      columns: const [
                        DataColumn(label: Text('Issue')),
                        DataColumn(label: Text('Loại')),
                        DataColumn(label: Text('Phiên bản')),
                        DataColumn(label: Text('Trends')),
                        DataColumn(label: Text('Events'), numeric: true),
                        DataColumn(label: Text('Users'), numeric: true),
                      ],
                      rows: [
                        for (final issue in ordered) _issueRow(issue, context),
                      ],
                    ),
                  ),
                );
              },
            ),
        ],
      ),
    );
  }

  DataRow _issueRow(CrashIssue issue, BuildContext context) => DataRow(
    onSelectChanged: (_) => _showIssueDetails(context, issue),
    cells: [
      DataCell(_IssueIdentity(issue: issue)),
      DataCell(_IssueTypePill(type: issue.errorType)),
      DataCell(
        Tooltip(
          message: issue.versions.join(', '),
          child: Text(
            issue.versions.isEmpty ? '—' : issue.versions.first,
            style: const TextStyle(fontWeight: FontWeight.w700),
          ),
        ),
      ),
      DataCell(_IssueSparkline(points: issue.trend)),
      DataCell(
        Text(
          formatNumber(issue.events),
          style: const TextStyle(fontWeight: FontWeight.w900),
        ),
      ),
      DataCell(Text(formatNumber(issue.affectedUsers))),
    ],
  );

  void _showIssueDetails(BuildContext context, CrashIssue issue) {
    showDialog<void>(
      context: context,
      builder: (context) => _IssueDetailsDialog(issue: issue),
    );
  }
}

class _IssueCard extends StatelessWidget {
  const _IssueCard({required this.issue});

  final CrashIssue issue;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return Material(
      color: scheme.surfaceContainerLow,
      shape: RoundedRectangleBorder(
        side: BorderSide(color: scheme.outlineVariant),
        borderRadius: BorderRadius.circular(16),
      ),
      child: InkWell(
        borderRadius: BorderRadius.circular(16),
        onTap: () => showDialog<void>(
          context: context,
          builder: (context) => _IssueDetailsDialog(issue: issue),
        ),
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Expanded(child: _IssueIdentity(issue: issue)),
                  const SizedBox(width: 10),
                  _IssueTypePill(type: issue.errorType),
                ],
              ),
              const Divider(height: 24),
              Wrap(
                spacing: 24,
                runSpacing: 12,
                children: [
                  _IssueMetric(
                    label: 'Events',
                    value: formatNumber(issue.events),
                  ),
                  _IssueMetric(
                    label: 'Thiết bị',
                    value: formatNumber(issue.affectedUsers),
                  ),
                  _IssueMetric(
                    label: 'Phiên bản',
                    value: issue.versions.isEmpty ? '—' : issue.versions.first,
                  ),
                  _IssueMetric(
                    label: 'Lần cuối',
                    value: formatDateTime(issue.lastSeen),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _IssueSparkline extends StatelessWidget {
  const _IssueSparkline({required this.points});

  final List<CrashIssueTrend> points;

  @override
  Widget build(BuildContext context) {
    if (points.isEmpty) return const SizedBox(width: 92, child: Text('—'));
    return SizedBox(
      width: 92,
      height: 36,
      child: LineChart(
        LineChartData(
          minY: 0,
          titlesData: const FlTitlesData(show: false),
          borderData: FlBorderData(show: false),
          gridData: const FlGridData(show: false),
          lineTouchData: const LineTouchData(enabled: false),
          lineBarsData: [
            LineChartBarData(
              spots: [
                for (var index = 0; index < points.length; index++)
                  FlSpot(index.toDouble(), points[index].events.toDouble()),
              ],
              color: Theme.of(context).colorScheme.primary,
              barWidth: 2,
              isCurved: points.length > 2,
              dotData: const FlDotData(show: false),
            ),
          ],
        ),
      ),
    );
  }
}

class _IssueDetailsDialog extends StatelessWidget {
  const _IssueDetailsDialog({required this.issue});

  final CrashIssue issue;

  @override
  Widget build(BuildContext context) {
    final latest = issue.latest;
    final scheme = Theme.of(context).colorScheme;
    return Dialog(
      insetPadding: const EdgeInsets.all(24),
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 980, maxHeight: 820),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(24, 20, 16, 16),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Wrap(
                          spacing: 10,
                          runSpacing: 8,
                          crossAxisAlignment: WrapCrossAlignment.center,
                          children: [
                            _IssueTypePill(type: issue.errorType),
                            Text(
                              issue.versions.isEmpty
                                  ? 'Không rõ phiên bản'
                                  : issue.versions.join(', '),
                              style: TextStyle(
                                color: scheme.onSurfaceVariant,
                                fontWeight: FontWeight.w700,
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 10),
                        Text(
                          _issueTitle(issue),
                          style: Theme.of(context).textTheme.titleLarge
                              ?.copyWith(fontWeight: FontWeight.w900),
                        ),
                        if (issue.subtitle?.trim().isNotEmpty == true) ...[
                          const SizedBox(height: 6),
                          Text(
                            issue.subtitle!.trim(),
                            style: TextStyle(
                              color: scheme.onSurfaceVariant,
                              height: 1.4,
                            ),
                          ),
                        ],
                      ],
                    ),
                  ),
                  IconButton(
                    tooltip: 'Đóng',
                    onPressed: () => Navigator.of(context).pop(),
                    icon: const Icon(Icons.close_rounded),
                  ),
                ],
              ),
            ),
            const Divider(height: 1),
            Expanded(
              child: SingleChildScrollView(
                padding: const EdgeInsets.all(24),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    AdaptiveGrid(
                      minItemWidth: 180,
                      children: [
                        _DetailTile(
                          label: 'Events',
                          value: formatNumber(issue.events),
                        ),
                        _DetailTile(
                          label: 'Users',
                          value: formatNumber(issue.affectedUsers),
                        ),
                        _DetailTile(
                          label: 'Variants',
                          value: formatNumber(issue.variants),
                        ),
                        _DetailTile(
                          label: 'Lần gần nhất',
                          value: formatDateTime(issue.lastSeen),
                        ),
                      ],
                    ),
                    const SizedBox(height: 22),
                    _DialogSection(
                      title: 'Sự kiện gần nhất',
                      child: Wrap(
                        spacing: 28,
                        runSpacing: 14,
                        children: [
                          _DetailPair(
                            label: 'Event ID',
                            value: latest.eventId ?? '—',
                          ),
                          _DetailPair(
                            label: 'Thời gian',
                            value: formatDateTime(latest.occurredAt),
                          ),
                          _DetailPair(
                            label: 'Thiết bị',
                            value: [
                              latest.device.manufacturer,
                              latest.device.model,
                            ].whereType<String>().join(' '),
                          ),
                          _DetailPair(
                            label: 'Hệ điều hành',
                            value: [
                              latest.operatingSystem.name,
                              latest.operatingSystem.version,
                            ].whereType<String>().join(' '),
                          ),
                          _DetailPair(
                            label: 'Kiến trúc',
                            value: latest.device.architecture ?? '—',
                          ),
                          _DetailPair(
                            label: 'RAM',
                            value:
                                '${_formatBytes(latest.memoryUsed)} dùng / ${_formatBytes(latest.memoryFree)} trống',
                          ),
                          _DetailPair(
                            label: 'Storage',
                            value:
                                '${_formatBytes(latest.storageUsed)} dùng / ${_formatBytes(latest.storageFree)} trống',
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(height: 18),
                    _DialogSection(
                      title: latest.exceptionType ?? 'Stack trace',
                      subtitle: latest.exceptionMessage,
                      child: latest.frames.isEmpty
                          ? const Text('Không có stack frame trong event này.')
                          : DecoratedBox(
                              decoration: BoxDecoration(
                                color: scheme.surfaceContainerHighest,
                                borderRadius: BorderRadius.circular(12),
                              ),
                              child: Padding(
                                padding: const EdgeInsets.all(14),
                                child: Column(
                                  crossAxisAlignment:
                                      CrossAxisAlignment.stretch,
                                  children: [
                                    for (final frame in latest.frames)
                                      _StackFrameRow(frame: frame),
                                  ],
                                ),
                              ),
                            ),
                    ),
                    if (latest.customKeys.isNotEmpty) ...[
                      const SizedBox(height: 18),
                      _DialogSection(
                        title: 'Custom keys',
                        child: Wrap(
                          spacing: 10,
                          runSpacing: 10,
                          children: [
                            for (final item in latest.customKeys)
                              Chip(
                                label: Text(
                                  '${item.key ?? 'key'}: ${item.value ?? '—'}',
                                ),
                              ),
                          ],
                        ),
                      ),
                    ],
                    if (latest.logs.isNotEmpty) ...[
                      const SizedBox(height: 18),
                      _DialogSection(
                        title: 'Logs',
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.stretch,
                          children: [
                            for (final log in latest.logs)
                              Text(
                                '${formatDateTime(log.timestamp)}  ${log.message ?? ''}',
                                style: const TextStyle(
                                  fontFamily: 'monospace',
                                  height: 1.55,
                                ),
                              ),
                          ],
                        ),
                      ),
                    ],
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _DetailTile extends StatelessWidget {
  const _DetailTile({required this.label, required this.value});
  final String label;
  final String value;

  @override
  Widget build(BuildContext context) => DecoratedBox(
    decoration: BoxDecoration(
      color: Theme.of(context).colorScheme.surfaceContainerLow,
      borderRadius: BorderRadius.circular(12),
      border: Border.all(color: Theme.of(context).colorScheme.outlineVariant),
    ),
    child: Padding(
      padding: const EdgeInsets.all(14),
      child: _DetailPair(label: label, value: value),
    ),
  );
}

class _DetailPair extends StatelessWidget {
  const _DetailPair({required this.label, required this.value});
  final String label;
  final String value;

  @override
  Widget build(BuildContext context) => ConstrainedBox(
    constraints: const BoxConstraints(minWidth: 150, maxWidth: 340),
    child: Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          label,
          style: TextStyle(
            color: Theme.of(context).colorScheme.onSurfaceVariant,
            fontSize: 11,
            fontWeight: FontWeight.w700,
          ),
        ),
        const SizedBox(height: 4),
        SelectableText(
          value.isEmpty ? '—' : value,
          style: const TextStyle(fontWeight: FontWeight.w800),
        ),
      ],
    ),
  );
}

class _DialogSection extends StatelessWidget {
  const _DialogSection({
    required this.title,
    required this.child,
    this.subtitle,
  });
  final String title;
  final String? subtitle;
  final Widget child;

  @override
  Widget build(BuildContext context) => Column(
    crossAxisAlignment: CrossAxisAlignment.stretch,
    children: [
      Text(
        title,
        style: Theme.of(
          context,
        ).textTheme.titleMedium?.copyWith(fontWeight: FontWeight.w900),
      ),
      if (subtitle?.trim().isNotEmpty == true) ...[
        const SizedBox(height: 4),
        Text(
          subtitle!,
          style: TextStyle(
            color: Theme.of(context).colorScheme.onSurfaceVariant,
          ),
        ),
      ],
      const SizedBox(height: 12),
      child,
    ],
  );
}

class _StackFrameRow extends StatelessWidget {
  const _StackFrameRow({required this.frame});
  final CrashFrame frame;

  @override
  Widget build(BuildContext context) {
    final color = frame.blamed
        ? Theme.of(context).colorScheme.error
        : Theme.of(context).colorScheme.onSurfaceVariant;
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(
            frame.blamed
                ? Icons.radio_button_checked
                : Icons.radio_button_unchecked,
            size: 13,
            color: color,
          ),
          const SizedBox(width: 9),
          Expanded(
            child: SelectableText(
              '${frame.symbol ?? 'unknown'}'
              '${frame.file == null ? '' : '  (${frame.file}${frame.line > 0 ? ':${frame.line}' : ''})'}',
              style: TextStyle(
                color: color,
                fontFamily: 'monospace',
                fontSize: 12,
                fontWeight: frame.blamed ? FontWeight.w800 : FontWeight.w500,
                height: 1.35,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _IssueIdentity extends StatelessWidget {
  const _IssueIdentity({required this.issue});

  final CrashIssue issue;

  @override
  Widget build(BuildContext context) => SizedBox(
    width: 280,
    child: Row(
      children: [
        CircleAvatar(
          radius: 18,
          backgroundColor: Theme.of(
            context,
          ).colorScheme.error.withValues(alpha: .1),
          child: Icon(
            Icons.bug_report_outlined,
            size: 18,
            color: Theme.of(context).colorScheme.error,
          ),
        ),
        const SizedBox(width: 11),
        Expanded(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                _issueTitle(issue),
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: const TextStyle(fontWeight: FontWeight.w800),
              ),
              const SizedBox(height: 2),
              if (issue.subtitle?.trim().isNotEmpty == true) ...[
                Text(
                  issue.subtitle!.trim(),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(
                    color: Theme.of(context).colorScheme.onSurfaceVariant,
                    fontSize: 11,
                  ),
                ),
                const SizedBox(height: 2),
              ],
              Tooltip(
                message: issue.issueId,
                child: Text(
                  truncateMiddle(issue.issueId, keep: 9),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(
                    color: Theme.of(context).colorScheme.onSurfaceVariant,
                    fontFamily: 'monospace',
                    fontSize: 12,
                  ),
                ),
              ),
            ],
          ),
        ),
      ],
    ),
  );
}

class _IssueTypePill extends StatelessWidget {
  const _IssueTypePill({required this.type});

  final String? type;

  @override
  Widget build(BuildContext context) {
    final label = _errorType(type);
    final fatal = label == 'FATAL';
    return StatusPill(
      label,
      tone: fatal ? StatusTone.danger : StatusTone.warning,
      icon: fatal ? Icons.dangerous_outlined : Icons.warning_amber_rounded,
    );
  }
}

class _IssueMetric extends StatelessWidget {
  const _IssueMetric({required this.label, required this.value});

  final String label;
  final String value;

  @override
  Widget build(BuildContext context) => Semantics(
    label: '$label: $value',
    child: ExcludeSemantics(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            label,
            style: TextStyle(
              color: Theme.of(context).colorScheme.onSurfaceVariant,
              fontSize: 11,
              fontWeight: FontWeight.w700,
            ),
          ),
          const SizedBox(height: 3),
          Text(value, style: const TextStyle(fontWeight: FontWeight.w900)),
        ],
      ),
    ),
  );
}

String _issueTitle(CrashIssue issue) {
  final title = issue.title?.trim();
  return title == null || title.isEmpty ? 'Không có tiêu đề' : title;
}

String _errorType(String? raw) {
  final value = raw?.trim().toUpperCase();
  return value == null || value.isEmpty ? 'UNKNOWN' : value;
}

String _compactAxisNumber(double value) {
  final absolute = value.abs();
  if (absolute < 1000) return value.round().toString();
  if (absolute < 1000000) {
    final scaled = value / 1000;
    return '${scaled >= 10 ? scaled.toStringAsFixed(0) : scaled.toStringAsFixed(1)}K';
  }
  final scaled = value / 1000000;
  return '${scaled >= 10 ? scaled.toStringAsFixed(0) : scaled.toStringAsFixed(1)}M';
}

String _formatBytes(int value) {
  if (value <= 0) return '—';
  const units = ['B', 'KB', 'MB', 'GB', 'TB'];
  var amount = value.toDouble();
  var unit = 0;
  while (amount >= 1024 && unit < units.length - 1) {
    amount /= 1024;
    unit++;
  }
  return '${amount.toStringAsFixed(unit < 2 ? 0 : 1)} ${units[unit]}';
}
