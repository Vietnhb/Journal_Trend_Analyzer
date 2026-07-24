import 'package:fl_chart/fl_chart.dart';
import 'package:flutter/material.dart';
import 'package:journal_trend_admin_web/core/core.dart';

import '../utils/ui_format.dart';
import '../widgets/admin_widgets.dart';

class AnalyticsPage extends StatefulWidget {
  const AnalyticsPage({required this.api, super.key});

  final AdminApi api;

  @override
  State<AnalyticsPage> createState() => _AnalyticsPageState();
}

class _AnalyticsPageState extends State<AnalyticsPage> {
  AdminDateRange _range = AdminDateRange.last30Days;
  late Future<AnalyticsData> _future;

  @override
  void initState() {
    super.initState();
    _load();
  }

  @override
  void didUpdateWidget(covariant AnalyticsPage oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.api != widget.api) _load();
  }

  void _load() {
    _future = widget.api.getAnalytics(start: _range.start, end: _range.end);
  }

  void _refresh() => setState(_load);

  void _connectAnalytics() {
    setState(() {
      _future = widget.api.authorizeAnalytics().then(
        (_) => widget.api.getAnalytics(start: _range.start, end: _range.end),
      );
    });
  }

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
        eyebrow: 'Google Analytics for Firebase',
        title: 'Analytics sự kiện',
        description:
            'Theo dõi toàn bộ sự kiện GA4 và xu hướng sử dụng ứng dụng theo thời gian.',
        actions: [
          AdminDateRangeFilter(value: _range, onChanged: _changeRange),
          OutlinedButton.icon(
            onPressed: _refresh,
            icon: const Icon(Icons.refresh_rounded),
            label: const Text('Làm mới'),
          ),
        ],
      ),
      FutureBuilder<AnalyticsData>(
        future: _future,
        builder: (context, snapshot) {
          if (snapshot.connectionState != ConnectionState.done) {
            return const SectionCard(
              child: LoadingPanel(label: 'Đang tải dữ liệu Analytics…'),
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
          if (data.status != IntegrationStatus.ready) {
            return _AnalyticsIntegrationState(
              status: data.status,
              reason: data.reason,
              onRetry: _refresh,
              onConnect: _connectAnalytics,
            );
          }

          return _AnalyticsContent(data: data, rangeLabel: _range.label);
        },
      ),
    ],
  );
}

class _AnalyticsContent extends StatelessWidget {
  const _AnalyticsContent({required this.data, required this.rangeLabel});

  final AnalyticsData data;
  final String rangeLabel;

  @override
  Widget build(BuildContext context) => Column(
    crossAxisAlignment: CrossAxisAlignment.stretch,
    children: [
      if (data.reason?.trim().isNotEmpty == true) ...[
        _AnalyticsReadyNotice(message: data.reason!.trim()),
        const SizedBox(height: 22),
      ],
      AdaptiveGrid(
        minItemWidth: 245,
        children: [
          MetricCard(
            label: 'Tổng sự kiện',
            value: formatNumber(data.summary.eventCount),
            detail: rangeLabel,
            icon: Icons.ads_click_rounded,
            tone: MetricTone.violet,
          ),
          MetricCard(
            label: 'Người dùng hoạt động',
            value: formatNumber(data.summary.activeUsers),
            detail: 'Active users từ GA4',
            icon: Icons.people_alt_outlined,
            tone: MetricTone.green,
          ),
          MetricCard(
            label: 'Phiên truy cập',
            value: formatNumber(data.summary.sessions),
            detail: 'Sessions trong khoảng đã chọn',
            icon: Icons.query_stats_rounded,
          ),
        ],
      ),
      const SizedBox(height: 22),
      _AnalyticsChart(daily: data.daily, rangeLabel: rangeLabel),
      const SizedBox(height: 22),
      _EventsSection(
        events: data.events,
        eventDaily: data.eventDaily,
        rangeLabel: rangeLabel,
      ),
    ],
  );
}

class _AnalyticsReadyNotice extends StatelessWidget {
  const _AnalyticsReadyNotice({required this.message});

  final String message;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return SectionCard(
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(Icons.cloud_done_outlined, color: scheme.primary),
          const SizedBox(width: 14),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text(
                  'Đã kết nối Google Analytics',
                  style: TextStyle(fontWeight: FontWeight.w900),
                ),
                const SizedBox(height: 4),
                Text(
                  message,
                  style: TextStyle(
                    color: scheme.onSurfaceVariant,
                    height: 1.45,
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(width: 12),
          const StatusPill(
            'Đang đồng bộ',
            tone: StatusTone.info,
            icon: Icons.sync_rounded,
          ),
        ],
      ),
    );
  }
}

class _AnalyticsIntegrationState extends StatelessWidget {
  const _AnalyticsIntegrationState({
    required this.status,
    required this.reason,
    required this.onRetry,
    required this.onConnect,
  });

  final IntegrationStatus status;
  final String? reason;
  final VoidCallback onRetry;
  final VoidCallback onConnect;

  @override
  Widget build(BuildContext context) {
    final isError = status == IntegrationStatus.error;
    final needsAuthorization =
        status == IntegrationStatus.authorizationRequired;
    final isPending = status == IntegrationStatus.pending;
    final color = isError
        ? Theme.of(context).colorScheme.error
        : isPending
        ? Theme.of(context).colorScheme.primary
        : Colors.amber.shade800;
    final title = isError
        ? 'Không thể đọc dữ liệu Analytics'
        : needsAuthorization
        ? 'Kết nối Google Analytics'
        : isPending
        ? 'Đang chờ lần export Analytics đầu tiên'
        : 'Chưa cấu hình Analytics BigQuery';
    final description = reason?.trim().isNotEmpty == true
        ? reason!.trim()
        : 'Backend cần dataset GA4 do Firebase xuất sang BigQuery.';

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
                    : isPending
                    ? Icons.sync_rounded
                    : Icons.analytics_outlined,
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
                    isError
                        ? 'Lỗi tích hợp'
                        : needsAuthorization
                        ? 'Cần cấp quyền'
                        : isPending
                        ? 'Đang đồng bộ'
                        : 'Cần cấu hình',
                    tone: isError
                        ? StatusTone.danger
                        : needsAuthorization
                        ? StatusTone.info
                        : isPending
                        ? StatusTone.info
                        : StatusTone.warning,
                    icon: isError
                        ? Icons.error_outline_rounded
                        : needsAuthorization
                        ? Icons.lock_open_rounded
                        : isPending
                        ? Icons.sync_rounded
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
              if (needsAuthorization) ...[
                const _SetupStep(
                  number: 1,
                  text:
                      'Nhấn Kết nối Google Analytics và chọn tài khoản admin hiện tại.',
                ),
                const _SetupStep(
                  number: 2,
                  text:
                      'Chấp nhận quyền chỉ đọc Analytics; web không có quyền thay đổi Property.',
                ),
                const _SetupStep(
                  number: 3,
                  text:
                      'Dữ liệu được đọc theo đúng quyền GA4 của tài khoản đang đăng nhập.',
                ),
              ] else if (isPending) ...[
                const _SetupStep(
                  number: 1,
                  text:
                      'Giữ Daily export bật cho Google Analytics; ảnh cấu hình hiện tại đã đúng.',
                ),
                const _SetupStep(
                  number: 2,
                  text:
                      'Mở mobile app và thực hiện đăng nhập, tìm kiếm hoặc xuất PDF để phát sinh sự kiện.',
                ),
                const _SetupStep(
                  number: 3,
                  text:
                      'Chờ Firebase tạo dataset và bảng events_* (lần đầu có thể tới 48 giờ), sau đó bấm Kiểm tra lại.',
                ),
              ] else ...[
                const _SetupStep(
                  number: 1,
                  text:
                      'Mở Firebase Console > Project settings > Integrations > BigQuery.',
                ),
                const _SetupStep(
                  number: 2,
                  text:
                      'Chọn Manage/Link rồi bật export cho Google Analytics và các app cần quản lý.',
                ),
                const _SetupStep(
                  number: 3,
                  text: 'Chờ lần đồng bộ đầu tiên, sau đó bấm Kiểm tra lại.',
                ),
              ],
              const SizedBox(height: 18),
              OutlinedButton.icon(
                onPressed: needsAuthorization ? onConnect : onRetry,
                icon: Icon(
                  needsAuthorization
                      ? Icons.login_rounded
                      : Icons.refresh_rounded,
                ),
                label: Text(
                  needsAuthorization
                      ? 'Kết nối Google Analytics'
                      : 'Kiểm tra lại',
                ),
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

class _AnalyticsChart extends StatelessWidget {
  const _AnalyticsChart({required this.daily, required this.rangeLabel});

  final List<AnalyticsDaily> daily;
  final String rangeLabel;

  @override
  Widget build(BuildContext context) {
    final ordered = [...daily]..sort((a, b) => a.date.compareTo(b.date));
    return SectionCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          SectionTitle(
            title: 'Xu hướng sự kiện',
            description:
                'Tổng số event được ghi nhận trong khoảng $rangeLabel.',
            trailing: StatusPill(
              rangeLabel,
              tone: StatusTone.info,
              icon: Icons.calendar_month_outlined,
            ),
          ),
          const SizedBox(height: 22),
          if (ordered.isEmpty)
            const EmptyPanel(
              title: 'Chưa có dữ liệu theo ngày',
              description:
                  'GA4 chưa trả về số sự kiện trong khoảng thời gian này.',
              icon: Icons.show_chart_rounded,
            )
          else
            LayoutBuilder(
              builder: (context, constraints) => Semantics(
                image: true,
                label:
                    'Biểu đồ đường số sự kiện theo ngày, gồm ${ordered.length} mốc dữ liệu.',
                child: ExcludeSemantics(
                  child: SizedBox(
                    height: constraints.maxWidth < 680 ? 260 : 320,
                    child: _AnalyticsLineChart(data: ordered),
                  ),
                ),
              ),
            ),
        ],
      ),
    );
  }
}

class _AnalyticsLineChart extends StatelessWidget {
  const _AnalyticsLineChart({required this.data});

  final List<AnalyticsDaily> data;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final axisColor = scheme.onSurfaceVariant;
    final gridColor = scheme.outlineVariant.withValues(alpha: .65);
    var maximum = 0;
    for (final point in data) {
      if (point.count > maximum) maximum = point.count;
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
                  '${formatChartDate(data[spot.x.round()].date)}\n'
                  '${formatNumber(spot.y.round())} sự kiện',
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
                FlSpot(index.toDouble(), data[index].count.toDouble()),
            ],
            color: scheme.primary,
            barWidth: 3,
            isCurved: data.length > 2,
            curveSmoothness: .22,
            preventCurveOverShooting: true,
            isStrokeCapRound: true,
            dotData: FlDotData(show: data.length <= 14),
            belowBarData: BarAreaData(
              show: true,
              color: scheme.primary.withValues(alpha: .09),
            ),
          ),
        ],
      ),
      duration: const Duration(milliseconds: 350),
      curve: Curves.easeOutCubic,
    );
  }
}

class _EventsSection extends StatefulWidget {
  const _EventsSection({
    required this.events,
    required this.eventDaily,
    required this.rangeLabel,
  });

  final List<AnalyticsEvent> events;
  final List<AnalyticsEventDaily> eventDaily;
  final String rangeLabel;

  @override
  State<_EventsSection> createState() => _EventsSectionState();
}

class _EventsSectionState extends State<_EventsSection> {
  static const _pageSize = 10;
  String _query = '';
  int _page = 0;

  @override
  Widget build(BuildContext context) {
    final ordered =
        widget.events
            .where(
              (event) =>
                  event.name.toLowerCase().contains(_query.toLowerCase()) ||
                  _eventLabel(
                    event.name,
                  ).toLowerCase().contains(_query.toLowerCase()),
            )
            .toList()
          ..sort((left, right) => right.count.compareTo(left.count));
    final pageCount = (ordered.length / _pageSize).ceil().clamp(1, 999999);
    final safePage = _page.clamp(0, pageCount - 1);
    final start = safePage * _pageSize;
    final visible = ordered.skip(start).take(_pageSize).toList();
    return SectionCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          SectionTitle(
            title: 'Sự kiện: Tên sự kiện',
            description:
                '${widget.events.length} event GA4 · ${widget.rangeLabel}',
            trailing: SizedBox(
              width: 280,
              child: TextField(
                onChanged: (value) => setState(() {
                  _query = value.trim();
                  _page = 0;
                }),
                decoration: const InputDecoration(
                  hintText: 'Tìm kiếm sự kiện',
                  prefixIcon: Icon(Icons.search_rounded),
                  isDense: true,
                ),
              ),
            ),
          ),
          const SizedBox(height: 18),
          if (ordered.isEmpty)
            EmptyPanel(
              title: _query.isEmpty
                  ? 'Chưa có sự kiện'
                  : 'Không tìm thấy sự kiện',
              description: _query.isEmpty
                  ? 'GA4 chưa ghi nhận event trong khoảng thời gian này.'
                  : 'Không có event phù hợp với “$_query”.',
              icon: Icons.bolt_outlined,
            )
          else
            LayoutBuilder(
              builder: (context, constraints) {
                if (constraints.maxWidth < 760) {
                  return Column(
                    children: [
                      for (var index = 0; index < visible.length; index++) ...[
                        _EventCard(
                          event: visible[index],
                          onTap: () => _showDetails(visible[index]),
                        ),
                        if (index != visible.length - 1)
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
                      dataRowMinHeight: 66,
                      dataRowMaxHeight: 76,
                      columns: const [
                        DataColumn(label: Text('Sự kiện')),
                        DataColumn(label: Text('Số sự kiện'), numeric: true),
                        DataColumn(
                          label: Text('Tổng người dùng'),
                          numeric: true,
                        ),
                        DataColumn(
                          label: Text('Sự kiện/người dùng'),
                          numeric: true,
                        ),
                        DataColumn(
                          label: Text('Tổng doanh thu'),
                          numeric: true,
                        ),
                        DataColumn(label: Text('Chi tiết')),
                      ],
                      rows: [
                        for (final event in visible) _eventRow(event, context),
                      ],
                    ),
                  ),
                );
              },
            ),
          if (ordered.isNotEmpty) ...[
            const SizedBox(height: 14),
            Row(
              children: [
                Text(
                  '${start + 1}–${start + visible.length} / ${ordered.length}',
                  style: TextStyle(
                    color: Theme.of(context).colorScheme.onSurfaceVariant,
                    fontSize: 12,
                  ),
                ),
                const Spacer(),
                IconButton(
                  tooltip: 'Trang trước',
                  onPressed: safePage > 0
                      ? () => setState(() => _page = safePage - 1)
                      : null,
                  icon: const Icon(Icons.chevron_left_rounded),
                ),
                Text('${safePage + 1} / $pageCount'),
                IconButton(
                  tooltip: 'Trang sau',
                  onPressed: safePage + 1 < pageCount
                      ? () => setState(() => _page = safePage + 1)
                      : null,
                  icon: const Icon(Icons.chevron_right_rounded),
                ),
              ],
            ),
          ],
        ],
      ),
    );
  }

  DataRow _eventRow(AnalyticsEvent event, BuildContext context) {
    final count = event.count;
    return DataRow(
      cells: [
        DataCell(
          _EventIdentity(label: _eventLabel(event.name), eventName: event.name),
          onTap: () => _showDetails(event),
        ),
        DataCell(
          Text(
            formatNumber(count),
            style: const TextStyle(fontWeight: FontWeight.w900),
          ),
        ),
        DataCell(Text(formatNumber(event.users))),
        DataCell(
          Text(
            event.countPerUser.toStringAsFixed(2),
            style: const TextStyle(fontWeight: FontWeight.w700),
          ),
        ),
        DataCell(Text(formatCurrency(event.revenue))),
        DataCell(
          IconButton(
            tooltip: 'Xem chi tiết ${event.name}',
            onPressed: () => _showDetails(event),
            icon: const Icon(Icons.open_in_new_rounded, size: 19),
          ),
        ),
      ],
    );
  }

  void _showDetails(AnalyticsEvent event) {
    final daily = widget.eventDaily
        .where((point) => point.name == event.name)
        .map((point) => AnalyticsDaily(date: point.date, count: point.count))
        .toList();
    showDialog<void>(
      context: context,
      builder: (context) => AlertDialog(
        title: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(_eventLabel(event.name)),
            const SizedBox(height: 3),
            Text(
              event.name,
              style: TextStyle(
                color: Theme.of(context).colorScheme.primary,
                fontFamily: 'monospace',
                fontSize: 13,
              ),
            ),
          ],
        ),
        content: SizedBox(
          width: 760,
          child: SingleChildScrollView(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Wrap(
                  spacing: 12,
                  runSpacing: 12,
                  children: [
                    _EventDetailMetric(
                      label: 'Số sự kiện',
                      value: formatNumber(event.count),
                    ),
                    _EventDetailMetric(
                      label: 'Tổng người dùng',
                      value: formatNumber(event.users),
                    ),
                    _EventDetailMetric(
                      label: 'Sự kiện/người dùng',
                      value: event.countPerUser.toStringAsFixed(2),
                    ),
                    _EventDetailMetric(
                      label: 'Tổng doanh thu',
                      value: formatCurrency(event.revenue),
                    ),
                  ],
                ),
                const SizedBox(height: 24),
                Text(
                  'Xu hướng · ${widget.rangeLabel}',
                  style: const TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.w900,
                  ),
                ),
                const SizedBox(height: 12),
                if (daily.isEmpty)
                  const EmptyPanel(
                    title: 'Chưa có dữ liệu theo ngày',
                    description:
                        'GA4 chưa trả về chuỗi thời gian cho event này.',
                    icon: Icons.show_chart_rounded,
                  )
                else
                  SizedBox(
                    height: 300,
                    child: _AnalyticsLineChart(data: daily),
                  ),
              ],
            ),
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(),
            child: const Text('Đóng'),
          ),
        ],
      ),
    );
  }
}

class _EventCard extends StatelessWidget {
  const _EventCard({required this.event, required this.onTap});

  final AnalyticsEvent event;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final count = event.count;
    final scheme = Theme.of(context).colorScheme;
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(16),
      child: Ink(
        decoration: BoxDecoration(
          color: scheme.surfaceContainerLow,
          border: Border.all(color: scheme.outlineVariant),
          borderRadius: BorderRadius.circular(16),
        ),
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Expanded(
                    child: _EventIdentity(
                      label: _eventLabel(event.name),
                      eventName: event.name,
                    ),
                  ),
                  const SizedBox(width: 10),
                  StatusPill(
                    count > 0 ? 'Đã ghi nhận' : 'Chưa có',
                    tone: count > 0 ? StatusTone.success : StatusTone.neutral,
                  ),
                ],
              ),
              const SizedBox(height: 12),
              const Divider(height: 24),
              Wrap(
                spacing: 24,
                runSpacing: 10,
                children: [
                  _InlineMetric(label: 'Lượt ghi nhận', value: count),
                  _InlineMetric(label: 'Người dùng', value: event.users),
                  _InlineTextMetric(
                    label: 'Sự kiện/người',
                    value: event.countPerUser.toStringAsFixed(2),
                  ),
                  _InlineTextMetric(
                    label: 'Doanh thu',
                    value: formatCurrency(event.revenue),
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

class _EventDetailMetric extends StatelessWidget {
  const _EventDetailMetric({required this.label, required this.value});

  final String label;
  final String value;

  @override
  Widget build(BuildContext context) => Container(
    width: 165,
    padding: const EdgeInsets.all(14),
    decoration: BoxDecoration(
      color: Theme.of(context).colorScheme.surfaceContainerLow,
      borderRadius: BorderRadius.circular(14),
      border: Border.all(color: Theme.of(context).colorScheme.outlineVariant),
    ),
    child: Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          value,
          style: const TextStyle(fontSize: 20, fontWeight: FontWeight.w900),
        ),
        const SizedBox(height: 4),
        Text(
          label,
          style: TextStyle(
            color: Theme.of(context).colorScheme.onSurfaceVariant,
            fontSize: 12,
          ),
        ),
      ],
    ),
  );
}

class _EventIdentity extends StatelessWidget {
  const _EventIdentity({required this.label, required this.eventName});

  final String label;
  final String eventName;

  @override
  Widget build(BuildContext context) => Row(
    mainAxisSize: MainAxisSize.min,
    children: [
      CircleAvatar(
        radius: 18,
        backgroundColor: Theme.of(
          context,
        ).colorScheme.primary.withValues(alpha: .1),
        child: Icon(
          Icons.bolt_rounded,
          size: 18,
          color: Theme.of(context).colorScheme.primary,
        ),
      ),
      const SizedBox(width: 11),
      Flexible(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              label,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: const TextStyle(fontWeight: FontWeight.w800),
            ),
            const SizedBox(height: 2),
            Text(
              eventName,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: TextStyle(
                color: Theme.of(context).colorScheme.primary,
                fontFamily: 'monospace',
                fontSize: 12,
              ),
            ),
          ],
        ),
      ),
    ],
  );
}

class _InlineMetric extends StatelessWidget {
  const _InlineMetric({required this.label, required this.value});

  final String label;
  final int value;

  @override
  Widget build(BuildContext context) => Semantics(
    label: '$label: ${formatNumber(value)}',
    child: ExcludeSemantics(
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(
            formatNumber(value),
            style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w900),
          ),
          const SizedBox(width: 6),
          Text(
            label,
            style: TextStyle(
              color: Theme.of(context).colorScheme.onSurfaceVariant,
              fontSize: 12,
            ),
          ),
        ],
      ),
    ),
  );
}

class _InlineTextMetric extends StatelessWidget {
  const _InlineTextMetric({required this.label, required this.value});

  final String label;
  final String value;

  @override
  Widget build(BuildContext context) => Row(
    mainAxisSize: MainAxisSize.min,
    children: [
      Text(
        value,
        style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w900),
      ),
      const SizedBox(width: 6),
      Text(
        label,
        style: TextStyle(
          color: Theme.of(context).colorScheme.onSurfaceVariant,
          fontSize: 12,
        ),
      ),
    ],
  );
}

String _eventLabel(String name) => switch (name) {
  'login' => 'Đăng nhập',
  'search_topic' => 'Tìm chủ đề',
  'view_publication' => 'Xem publication',
  'view_journal' => 'Xem journal',
  'view_keyword' => 'Xem keyword',
  'export_pdf' => 'Xuất PDF',
  'logout' => 'Đăng xuất',
  'screen_view' => 'Lượt xem màn hình',
  'user_engagement' => 'Tương tác người dùng',
  'session_start' => 'Bắt đầu phiên',
  'first_open' => 'Mở lần đầu',
  'app_exception' => 'Lỗi ứng dụng',
  'app_remove' => 'Gỡ ứng dụng',
  _ => name,
};

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
