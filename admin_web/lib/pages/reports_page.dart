import 'package:flutter/material.dart';
import 'package:journal_trend_admin_web/core/core.dart';

import '../core/files/browser_storage_file_service.dart';
import '../theme/app_theme.dart';
import '../utils/ui_format.dart';
import '../widgets/admin_widgets.dart';

class ReportsPage extends StatefulWidget {
  const ReportsPage({required this.api, super.key});

  final AdminApi api;

  @override
  State<ReportsPage> createState() => _ReportsPageState();
}

class _ReportsPageState extends State<ReportsPage> {
  static const _pageSize = 20;
  final _searchController = TextEditingController();
  final List<String?> _pageTokens = [null];
  final _fileService = BrowserStorageFileService();

  late Future<ReportPage> _future;
  String _query = '';
  String? _busyPath;
  int _pageIndex = 0;
  AdminDateRange _range = AdminDateRange.last30Days;

  @override
  void initState() {
    super.initState();
    _load();
  }

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  void _load() {
    _future = widget.api.listReports(
      pageSize: _pageSize,
      pageToken: _pageTokens[_pageIndex],
    );
  }

  void _refresh() => setState(_load);

  void _updateSearch(String value) {
    setState(() => _query = value.trim().toLowerCase());
  }

  List<StoredReport> _filter(List<StoredReport> reports) {
    return reports
        .where((report) {
          final createdAt = DateTime.tryParse(report.createdAt ?? '');
          if (createdAt == null || !_range.contains(createdAt)) return false;
          if (_query.isEmpty) return true;
          final searchable = [
            report.name,
            report.path,
            report.ownerUid,
            report.ownerEmail,
            report.topic,
          ];
          return searchable.any(
            (value) => value?.toLowerCase().contains(_query) ?? false,
          );
        })
        .toList(growable: false);
  }

  void _previousPage() {
    if (_pageIndex == 0) return;
    setState(() {
      _pageIndex--;
      _load();
    });
  }

  void _nextPage(String nextPageToken) {
    setState(() {
      final nextIndex = _pageIndex + 1;
      if (_pageTokens.length > nextIndex) {
        _pageTokens[nextIndex] = nextPageToken;
        _pageTokens.removeRange(nextIndex + 1, _pageTokens.length);
      } else {
        _pageTokens.add(nextPageToken);
      }
      _pageIndex = nextIndex;
      _load();
    });
  }

  Future<void> _openReport(
    StoredReport report, {
    required bool download,
  }) async {
    if (_busyPath != null) return;

    final viewUrl = report.viewUrl;
    if (viewUrl == null) {
      showAppMessage(
        context,
        'Tệp chưa có liên kết Firebase Storage hợp lệ.',
        error: true,
      );
      return;
    }
    if (!download) {
      try {
        _fileService.previewUrl(viewUrl);
      } catch (error) {
        showAppMessage(context, errorText(error), error: true);
      }
      return;
    }

    setState(() => _busyPath = report.path);
    try {
      await _fileService.downloadFromUrl(
        url: viewUrl,
        name: report.name,
        expectedSize: report.sizeBytes,
      );
      if (mounted) {
        showAppMessage(context, 'Đã bắt đầu tải xuống ${report.name}.');
      }
    } catch (error) {
      if (mounted) {
        showAppMessage(context, errorText(error), error: true);
      }
    } finally {
      if (mounted) setState(() => _busyPath = null);
    }
  }

  Future<void> _delete(
    StoredReport report, {
    required int pageItemCount,
  }) async {
    if (_busyPath != null) return;
    final confirmed = await showTypedConfirmation(
      context: context,
      title: 'Xóa báo cáo khỏi Storage?',
      description:
          'Tệp cloud sẽ bị xóa vĩnh viễn. Bản PDF đã lưu cục bộ trên thiết bị người dùng không bị ảnh hưởng.',
      confirmationText: report.name,
      actionLabel: 'Xóa báo cáo',
      danger: true,
    );
    if (!confirmed || !mounted) return;

    setState(() => _busyPath = report.path);
    try {
      await widget.api.deleteReport(
        path: report.path,
        generation: report.generation,
      );
      if (!mounted) return;
      if (pageItemCount == 1 && _pageIndex > 0) {
        _pageIndex--;
        _pageTokens.removeRange(_pageIndex + 1, _pageTokens.length);
      }
      showAppMessage(context, 'Đã xóa báo cáo khỏi Firebase Storage.');
      setState(_load);
    } catch (error) {
      if (mounted) {
        showAppMessage(context, errorText(error), error: true);
      }
    } finally {
      if (mounted) setState(() => _busyPath = null);
    }
  }

  @override
  Widget build(BuildContext context) => PageBody(
    children: [
      PageHeading(
        eyebrow: 'Firebase Cloud Storage',
        title: 'Báo cáo đã lưu',
        description:
            'Duyệt, xem trước và quản lý PDF của mọi người dùng trong phạm vi report/{uid}/analysis.',
        actions: [
          AdminDateRangeFilter(
            value: _range,
            onChanged: (range) => setState(() => _range = range),
          ),
          OutlinedButton.icon(
            onPressed: _busyPath == null ? _refresh : null,
            icon: const Icon(Icons.refresh_rounded),
            label: const Text('Làm mới'),
          ),
        ],
      ),
      FutureBuilder<ReportPage>(
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

          final page = snapshot.requireData;
          final reports = page.reports;
          final filtered = _filter(reports);
          final pageBytes = reports.fold<int>(
            0,
            (total, report) => total + report.sizeBytes,
          );
          return Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              AdaptiveGrid(
                children: [
                  MetricCard(
                    label: 'Tệp trên trang này',
                    value: formatNumber(reports.length),
                    detail: 'Trang ${_pageIndex + 1} · tối đa $_pageSize tệp',
                    icon: Icons.folder_open_rounded,
                    tone: MetricTone.violet,
                  ),
                  MetricCard(
                    label: 'Dung lượng trên trang',
                    value: formatBytes(pageBytes),
                    detail: 'Tổng dung lượng của các tệp đang hiển thị',
                    icon: Icons.storage_outlined,
                  ),
                  const MetricCard(
                    label: 'Định dạng cho phép',
                    value: 'PDF',
                    detail: 'Mỗi tệp tối đa 10 MB',
                    icon: Icons.picture_as_pdf_outlined,
                    tone: MetricTone.green,
                  ),
                ],
              ),
              const SizedBox(height: 22),
              SectionCard(
                padding: EdgeInsets.zero,
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    Padding(
                      padding: const EdgeInsets.all(20),
                      child: _ReportToolbar(
                        controller: _searchController,
                        query: _query,
                        onChanged: _updateSearch,
                        onClear: () {
                          _searchController.clear();
                          _updateSearch('');
                        },
                      ),
                    ),
                    const Divider(height: 1),
                    if (filtered.isEmpty)
                      EmptyPanel(
                        title: 'Không có báo cáo',
                        description: _query.isEmpty
                            ? 'Báo cáo PDF được mobile app tải lên sẽ xuất hiện tại đây.'
                            : 'Không tìm thấy báo cáo phù hợp trong trang hiện tại.',
                        icon: Icons.picture_as_pdf_outlined,
                      )
                    else
                      LayoutBuilder(
                        builder: (context, constraints) {
                          if (constraints.maxWidth < 820) {
                            return _ReportCards(
                              reports: filtered,
                              busyPath: _busyPath,
                              onPreview: (report) =>
                                  _openReport(report, download: false),
                              onDownload: (report) =>
                                  _openReport(report, download: true),
                              onDelete: (report) => _delete(
                                report,
                                pageItemCount: reports.length,
                              ),
                            );
                          }
                          return _ReportTable(
                            reports: filtered,
                            busyPath: _busyPath,
                            onPreview: (report) =>
                                _openReport(report, download: false),
                            onDownload: (report) =>
                                _openReport(report, download: true),
                            onDelete: (report) =>
                                _delete(report, pageItemCount: reports.length),
                          );
                        },
                      ),
                    if (_pageIndex > 0 || page.nextPageToken != null) ...[
                      const Divider(height: 1),
                      _PaginationBar(
                        page: _pageIndex + 1,
                        canPrevious: _pageIndex > 0 && _busyPath == null,
                        canNext:
                            page.nextPageToken != null && _busyPath == null,
                        onPrevious: _previousPage,
                        onNext: page.nextPageToken == null
                            ? null
                            : () => _nextPage(page.nextPageToken!),
                      ),
                    ],
                  ],
                ),
              ),
            ],
          );
        },
      ),
    ],
  );
}

class _ReportToolbar extends StatelessWidget {
  const _ReportToolbar({
    required this.controller,
    required this.query,
    required this.onChanged,
    required this.onClear,
  });

  final TextEditingController controller;
  final String query;
  final ValueChanged<String> onChanged;
  final VoidCallback onClear;

  @override
  Widget build(BuildContext context) => LayoutBuilder(
    builder: (context, constraints) {
      final search = TextField(
        controller: controller,
        onChanged: onChanged,
        decoration: InputDecoration(
          prefixIcon: const Icon(Icons.search_rounded),
          hintText: 'Tìm theo owner, topic hoặc tên tệp…',
          suffixIcon: controller.text.isEmpty
              ? null
              : IconButton(
                  tooltip: 'Xóa từ khóa',
                  onPressed: onClear,
                  icon: const Icon(Icons.close_rounded),
                ),
        ),
      );
      final note = Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(
            Icons.filter_alt_outlined,
            size: 16,
            color: Theme.of(context).colorScheme.onSurfaceVariant,
          ),
          const SizedBox(width: 7),
          Text(
            query.isEmpty
                ? 'Tìm kiếm chỉ lọc trang hiện tại'
                : 'Đang lọc trang hiện tại',
            style: Theme.of(context).textTheme.bodySmall?.copyWith(
              color: Theme.of(context).colorScheme.onSurfaceVariant,
            ),
          ),
        ],
      );
      if (constraints.maxWidth < 650) {
        return Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [search, const SizedBox(height: 12), note],
        );
      }
      return Row(
        children: [
          Expanded(child: search),
          const SizedBox(width: 18),
          note,
        ],
      );
    },
  );
}

typedef _ReportCallback = void Function(StoredReport report);

class _ReportTable extends StatelessWidget {
  const _ReportTable({
    required this.reports,
    required this.busyPath,
    required this.onPreview,
    required this.onDownload,
    required this.onDelete,
  });

  final List<StoredReport> reports;
  final String? busyPath;
  final _ReportCallback onPreview;
  final _ReportCallback onDownload;
  final _ReportCallback onDelete;

  @override
  Widget build(BuildContext context) => SingleChildScrollView(
    scrollDirection: Axis.horizontal,
    child: DataTable(
      columns: const [
        DataColumn(label: Text('TỆP BÁO CÁO')),
        DataColumn(label: Text('CHỦ SỞ HỮU')),
        DataColumn(label: Text('CHỦ ĐỀ')),
        DataColumn(label: Text('DUNG LƯỢNG')),
        DataColumn(label: Text('NGÀY TẢI LÊN')),
        DataColumn(label: Text('THAO TÁC')),
      ],
      rows: [
        for (final report in reports)
          DataRow(
            cells: [
              DataCell(_FileIdentity(report: report)),
              DataCell(_OwnerIdentity(report: report)),
              DataCell(
                report.topic == null || report.topic!.isEmpty
                    ? Text(
                        'Không có metadata',
                        style: TextStyle(
                          color: Theme.of(context).colorScheme.onSurfaceVariant,
                        ),
                      )
                    : StatusPill(report.topic!, tone: StatusTone.info),
              ),
              DataCell(
                Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      formatBytes(report.sizeBytes),
                      style: const TextStyle(fontWeight: FontWeight.w800),
                    ),
                    Text(
                      report.contentType ?? 'application/pdf',
                      style: Theme.of(context).textTheme.bodySmall?.copyWith(
                        color: Theme.of(context).colorScheme.onSurfaceVariant,
                      ),
                    ),
                  ],
                ),
              ),
              DataCell(Text(formatDateTime(report.createdAt))),
              DataCell(
                _ReportActions(
                  report: report,
                  busy: busyPath == report.path,
                  disabled: busyPath != null,
                  onPreview: onPreview,
                  onDownload: onDownload,
                  onDelete: onDelete,
                ),
              ),
            ],
          ),
      ],
    ),
  );
}

class _ReportCards extends StatelessWidget {
  const _ReportCards({
    required this.reports,
    required this.busyPath,
    required this.onPreview,
    required this.onDownload,
    required this.onDelete,
  });

  final List<StoredReport> reports;
  final String? busyPath;
  final _ReportCallback onPreview;
  final _ReportCallback onDownload;
  final _ReportCallback onDelete;

  @override
  Widget build(BuildContext context) => Padding(
    padding: const EdgeInsets.all(16),
    child: Column(
      children: [
        for (var index = 0; index < reports.length; index++) ...[
          _ReportMobileCard(
            report: reports[index],
            busy: busyPath == reports[index].path,
            disabled: busyPath != null,
            onPreview: onPreview,
            onDownload: onDownload,
            onDelete: onDelete,
          ),
          if (index != reports.length - 1) const SizedBox(height: 12),
        ],
      ],
    ),
  );
}

class _ReportMobileCard extends StatelessWidget {
  const _ReportMobileCard({
    required this.report,
    required this.busy,
    required this.disabled,
    required this.onPreview,
    required this.onDownload,
    required this.onDelete,
  });

  final StoredReport report;
  final bool busy;
  final bool disabled;
  final _ReportCallback onPreview;
  final _ReportCallback onDownload;
  final _ReportCallback onDelete;

  @override
  Widget build(BuildContext context) => DecoratedBox(
    decoration: BoxDecoration(
      color: Theme.of(context).colorScheme.surfaceContainerLowest,
      border: Border.all(color: Theme.of(context).dividerColor),
      borderRadius: BorderRadius.circular(15),
    ),
    child: Padding(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          _FileIdentity(report: report),
          const SizedBox(height: 14),
          _OwnerIdentity(report: report),
          const SizedBox(height: 13),
          Wrap(
            spacing: 8,
            runSpacing: 8,
            crossAxisAlignment: WrapCrossAlignment.center,
            children: [
              StatusPill(
                report.topic?.isNotEmpty == true
                    ? report.topic!
                    : 'Không có chủ đề',
                tone: report.topic?.isNotEmpty == true
                    ? StatusTone.info
                    : StatusTone.neutral,
              ),
              StatusPill(
                formatBytes(report.sizeBytes),
                icon: Icons.storage_outlined,
              ),
              StatusPill(
                formatDateTime(report.createdAt),
                icon: Icons.schedule_rounded,
              ),
            ],
          ),
          const SizedBox(height: 14),
          _ReportActions(
            report: report,
            busy: busy,
            disabled: disabled,
            onPreview: onPreview,
            onDownload: onDownload,
            onDelete: onDelete,
            expanded: true,
          ),
        ],
      ),
    ),
  );
}

class _FileIdentity extends StatelessWidget {
  const _FileIdentity({required this.report});

  final StoredReport report;

  @override
  Widget build(BuildContext context) => ConstrainedBox(
    constraints: const BoxConstraints(maxWidth: 300),
    child: Row(
      children: [
        DecoratedBox(
          decoration: BoxDecoration(
            color: AppTheme.danger.withValues(alpha: .1),
            borderRadius: BorderRadius.circular(11),
          ),
          child: const Padding(
            padding: EdgeInsets.all(9),
            child: Icon(
              Icons.picture_as_pdf_outlined,
              color: AppTheme.danger,
              size: 20,
            ),
          ),
        ),
        const SizedBox(width: 11),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Tooltip(
                message: report.name,
                child: Text(
                  report.name,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(fontWeight: FontWeight.w800),
                ),
              ),
              const SizedBox(height: 2),
              Tooltip(
                message: report.path,
                child: Text(
                  truncateMiddle(report.path, keep: 14),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: Theme.of(context).textTheme.bodySmall?.copyWith(
                    color: Theme.of(context).colorScheme.onSurfaceVariant,
                    fontFamily: 'monospace',
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

class _OwnerIdentity extends StatelessWidget {
  const _OwnerIdentity({required this.report});

  final StoredReport report;

  @override
  Widget build(BuildContext context) => ConstrainedBox(
    constraints: const BoxConstraints(maxWidth: 260),
    child: Row(
      children: [
        const Icon(Icons.person_outline_rounded, size: 18),
        const SizedBox(width: 8),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                report.ownerEmail ?? 'Không rõ email',
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: const TextStyle(fontWeight: FontWeight.w700),
              ),
              Tooltip(
                message: report.ownerUid,
                child: Text(
                  truncateMiddle(report.ownerUid, keep: 9),
                  style: Theme.of(context).textTheme.bodySmall?.copyWith(
                    color: Theme.of(context).colorScheme.onSurfaceVariant,
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

class _ReportActions extends StatelessWidget {
  const _ReportActions({
    required this.report,
    required this.busy,
    required this.disabled,
    required this.onPreview,
    required this.onDownload,
    required this.onDelete,
    this.expanded = false,
  });

  final StoredReport report;
  final bool busy;
  final bool disabled;
  final _ReportCallback onPreview;
  final _ReportCallback onDownload;
  final _ReportCallback onDelete;
  final bool expanded;

  @override
  Widget build(BuildContext context) {
    if (busy) {
      return const SizedBox.square(
        dimension: 28,
        child: Padding(
          padding: EdgeInsets.all(4),
          child: CircularProgressIndicator(strokeWidth: 2.5),
        ),
      );
    }
    final actions = [
      IconButton(
        tooltip: 'Xem trước',
        onPressed: disabled ? null : () => onPreview(report),
        icon: const Icon(Icons.visibility_outlined),
      ),
      IconButton(
        tooltip: 'Tải xuống',
        onPressed: disabled ? null : () => onDownload(report),
        icon: const Icon(Icons.download_rounded),
      ),
      IconButton(
        tooltip: 'Xóa báo cáo',
        color: AppTheme.danger,
        onPressed: disabled ? null : () => onDelete(report),
        icon: const Icon(Icons.delete_outline_rounded),
      ),
    ];
    if (!expanded) {
      return Row(mainAxisSize: MainAxisSize.min, children: actions);
    }
    return Row(
      mainAxisAlignment: MainAxisAlignment.end,
      children: [const Spacer(), ...actions],
    );
  }
}

class _PaginationBar extends StatelessWidget {
  const _PaginationBar({
    required this.page,
    required this.canPrevious,
    required this.canNext,
    required this.onPrevious,
    required this.onNext,
  });

  final int page;
  final bool canPrevious;
  final bool canNext;
  final VoidCallback onPrevious;
  final VoidCallback? onNext;

  @override
  Widget build(BuildContext context) => Padding(
    padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 13),
    child: Row(
      mainAxisAlignment: MainAxisAlignment.end,
      children: [
        Text(
          'Trang $page',
          style: Theme.of(
            context,
          ).textTheme.bodySmall?.copyWith(fontWeight: FontWeight.w800),
        ),
        const SizedBox(width: 12),
        IconButton.outlined(
          tooltip: 'Trang trước',
          onPressed: canPrevious ? onPrevious : null,
          icon: const Icon(Icons.chevron_left_rounded),
        ),
        const SizedBox(width: 7),
        IconButton.outlined(
          tooltip: 'Trang sau',
          onPressed: canNext ? onNext : null,
          icon: const Icon(Icons.chevron_right_rounded),
        ),
      ],
    ),
  );
}
