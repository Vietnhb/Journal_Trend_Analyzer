import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:url_launcher/url_launcher.dart';

import '../../core/constants/app_colors.dart';
import '../../data/services/firebase_service.dart';
import '../providers/firebase_provider.dart';

class ReportHistoryScreen extends StatefulWidget {
  const ReportHistoryScreen({super.key});

  @override
  State<ReportHistoryScreen> createState() => _ReportHistoryScreenState();
}

class _ReportHistoryScreenState extends State<ReportHistoryScreen> {
  static const int _pageSize = 10;

  bool _newestFirst = true;
  int _pageIndex = 0;

  @override
  Widget build(BuildContext context) {
    final firebase = context.watch<FirebaseProvider>();
    final reports = _sortedReports(firebase.uploadedReports);
    final pageCount = reports.isEmpty
        ? 1
        : ((reports.length - 1) ~/ _pageSize) + 1;
    final currentPage = _pageIndex.clamp(0, pageCount - 1);
    final start = currentPage * _pageSize;
    final end = (start + _pageSize).clamp(0, reports.length);
    final pageReports = reports.sublist(start, end);

    if (currentPage != _pageIndex) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted) setState(() => _pageIndex = currentPage);
      });
    }

    return Scaffold(
      appBar: AppBar(
        title: const Text('Report history'),
        actions: [
          IconButton(
            tooltip: 'Refresh reports',
            onPressed: firebase.isLoadingReports
                ? null
                : () => context.read<FirebaseProvider>().loadUploadedReports(),
            icon: firebase.isLoadingReports
                ? const SizedBox(
                    width: 18,
                    height: 18,
                    child: CircularProgressIndicator(strokeWidth: 2),
                  )
                : const Icon(Icons.refresh_rounded),
          ),
        ],
      ),
      body: SafeArea(
        child: firebase.isLoadingReports && reports.isEmpty
            ? const Center(child: CircularProgressIndicator())
            : RefreshIndicator(
                onRefresh: context.read<FirebaseProvider>().loadUploadedReports,
                child: ListView(
                  padding: const EdgeInsets.fromLTRB(16, 8, 16, 28),
                  children: [
                    Row(
                      children: [
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              const _SectionLabel('Reports'),
                              const SizedBox(height: 4),
                              Text(
                                reports.isEmpty
                                    ? 'No uploaded report yet.'
                                    : '${reports.length} saved reports',
                                style: Theme.of(context).textTheme.bodySmall
                                    ?.copyWith(
                                      color: Theme.of(
                                        context,
                                      ).colorScheme.onSurfaceVariant,
                                    ),
                              ),
                            ],
                          ),
                        ),
                        PopupMenuButton<bool>(
                          tooltip: 'Sort reports',
                          initialValue: _newestFirst,
                          onSelected: (value) {
                            setState(() {
                              _newestFirst = value;
                              _pageIndex = 0;
                            });
                          },
                          itemBuilder: (context) => const [
                            PopupMenuItem(
                              value: true,
                              child: Text('Newest first'),
                            ),
                            PopupMenuItem(
                              value: false,
                              child: Text('Oldest first'),
                            ),
                          ],
                          child: _SortButton(
                            label: _newestFirst ? 'Newest' : 'Oldest',
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 10),
                    if (reports.isEmpty)
                      const _EmptyReports()
                    else
                      _SettingsCard(
                        children: [
                          for (
                            var index = 0;
                            index < pageReports.length;
                            index++
                          ) ...[
                            if (index > 0) const Divider(height: 1, indent: 56),
                            _ReportTile(
                              report: pageReports[index],
                              isDeleting:
                                  firebase.deletingReportPath ==
                                  pageReports[index].storagePath,
                              onOpen: () => _openUrl(
                                context,
                                pageReports[index].downloadUrl,
                              ),
                              onDelete: () => _confirmDeleteReport(
                                context,
                                context.read<FirebaseProvider>(),
                                pageReports[index],
                              ),
                            ),
                          ],
                        ],
                      ),
                    if (pageCount > 1) ...[
                      const SizedBox(height: 12),
                      _PaginationBar(
                        currentPage: currentPage,
                        pageCount: pageCount,
                        onPrevious: currentPage == 0
                            ? null
                            : () =>
                                  setState(() => _pageIndex = currentPage - 1),
                        onNext: currentPage >= pageCount - 1
                            ? null
                            : () =>
                                  setState(() => _pageIndex = currentPage + 1),
                      ),
                    ],
                  ],
                ),
              ),
      ),
    );
  }

  List<UploadedReportFile> _sortedReports(List<UploadedReportFile> reports) {
    final sorted = reports.toList();
    sorted.sort((a, b) {
      final left = a.uploadedAt ?? DateTime.fromMillisecondsSinceEpoch(0);
      final right = b.uploadedAt ?? DateTime.fromMillisecondsSinceEpoch(0);
      return _newestFirst ? right.compareTo(left) : left.compareTo(right);
    });
    return sorted;
  }

  Future<void> _confirmDeleteReport(
    BuildContext context,
    FirebaseProvider firebase,
    UploadedReportFile report,
  ) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: const Text('Delete uploaded report?'),
        content: Text(
          'This will remove the report uploaded on '
          '${_formatReportDate(report.uploadedAt)}.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(dialogContext, false),
            child: const Text('Cancel'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(dialogContext, true),
            child: const Text('Delete'),
          ),
        ],
      ),
    );
    if (confirmed == true) {
      await firebase.deleteUploadedReport(report);
    }
  }

  Future<void> _openUrl(BuildContext context, String value) async {
    final uri = Uri.tryParse(value);
    if (uri != null &&
        await launchUrl(uri, mode: LaunchMode.externalApplication)) {
      return;
    }
    if (!context.mounted) return;
    ScaffoldMessenger.of(
      context,
    ).showSnackBar(const SnackBar(content: Text('Could not open report URL.')));
  }
}

class _ReportTile extends StatelessWidget {
  final UploadedReportFile report;
  final bool isDeleting;
  final VoidCallback onOpen;
  final VoidCallback onDelete;

  const _ReportTile({
    required this.report,
    required this.isDeleting,
    required this.onOpen,
    required this.onDelete,
  });

  @override
  Widget build(BuildContext context) {
    return ListTile(
      onTap: onOpen,
      contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 5),
      leading: Container(
        width: 38,
        height: 38,
        alignment: Alignment.center,
        decoration: BoxDecoration(
          color: AppColors.success.withValues(alpha: 0.1),
          borderRadius: BorderRadius.circular(10),
        ),
        child: const Icon(
          Icons.cloud_done_outlined,
          size: 19,
          color: AppColors.success,
        ),
      ),
      title: const Text(
        'Uploaded report',
        style: TextStyle(fontWeight: FontWeight.w700),
      ),
      subtitle: Text(
        '${_formatReportDate(report.uploadedAt)}'
        '${_formatReportSize(report.sizeBytes)}',
        maxLines: 2,
        overflow: TextOverflow.ellipsis,
      ),
      trailing: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          IconButton(
            tooltip: 'Open report',
            onPressed: onOpen,
            icon: const Icon(Icons.open_in_new_rounded),
          ),
          IconButton(
            tooltip: 'Delete report',
            onPressed: isDeleting ? null : onDelete,
            icon: isDeleting
                ? const SizedBox(
                    width: 18,
                    height: 18,
                    child: CircularProgressIndicator(strokeWidth: 2),
                  )
                : const Icon(Icons.delete_outline_rounded),
          ),
        ],
      ),
    );
  }
}

class _SortButton extends StatelessWidget {
  final String label;

  const _SortButton({required this.label});

  @override
  Widget build(BuildContext context) {
    return Container(
      height: 38,
      padding: const EdgeInsets.symmetric(horizontal: 12),
      decoration: BoxDecoration(
        color: Theme.of(context).colorScheme.surface,
        border: Border.all(color: Theme.of(context).colorScheme.outlineVariant),
        borderRadius: BorderRadius.circular(12),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          const Icon(Icons.sort_rounded, size: 18),
          const SizedBox(width: 6),
          Text(label, style: const TextStyle(fontWeight: FontWeight.w700)),
          const SizedBox(width: 2),
          const Icon(Icons.keyboard_arrow_down_rounded, size: 18),
        ],
      ),
    );
  }
}

class _PaginationBar extends StatelessWidget {
  final int currentPage;
  final int pageCount;
  final VoidCallback? onPrevious;
  final VoidCallback? onNext;

  const _PaginationBar({
    required this.currentPage,
    required this.pageCount,
    required this.onPrevious,
    required this.onNext,
  });

  @override
  Widget build(BuildContext context) {
    return _SettingsCard(
      children: [
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
          child: Row(
            children: [
              IconButton(
                tooltip: 'Previous page',
                onPressed: onPrevious,
                icon: const Icon(Icons.chevron_left_rounded),
              ),
              Expanded(
                child: Text(
                  'Page ${currentPage + 1} / $pageCount',
                  textAlign: TextAlign.center,
                  style: const TextStyle(fontWeight: FontWeight.w800),
                ),
              ),
              IconButton(
                tooltip: 'Next page',
                onPressed: onNext,
                icon: const Icon(Icons.chevron_right_rounded),
              ),
            ],
          ),
        ),
      ],
    );
  }
}

class _EmptyReports extends StatelessWidget {
  const _EmptyReports();

  @override
  Widget build(BuildContext context) {
    return _SettingsCard(
      children: [
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 28),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(
                Icons.cloud_queue_outlined,
                size: 42,
                color: Theme.of(context).colorScheme.onSurfaceVariant,
              ),
              const SizedBox(height: 12),
              Text(
                'No uploaded report yet.',
                style: Theme.of(
                  context,
                ).textTheme.titleMedium?.copyWith(fontWeight: FontWeight.w800),
              ),
            ],
          ),
        ),
      ],
    );
  }
}

class _SectionLabel extends StatelessWidget {
  final String value;

  const _SectionLabel(this.value);

  @override
  Widget build(BuildContext context) {
    return Text(
      value.toUpperCase(),
      style: Theme.of(context).textTheme.labelSmall?.copyWith(
        color: Theme.of(context).colorScheme.onSurfaceVariant,
        letterSpacing: 1,
        fontWeight: FontWeight.w800,
      ),
    );
  }
}

class _SettingsCard extends StatelessWidget {
  final List<Widget> children;

  const _SettingsCard({required this.children});

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        color: Theme.of(context).colorScheme.surface,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: Theme.of(context).colorScheme.outlineVariant),
      ),
      clipBehavior: Clip.antiAlias,
      child: Column(children: children),
    );
  }
}

String _formatReportDate(DateTime? value) {
  if (value == null) return 'Upload time unavailable';
  final local = value.toLocal();
  String two(int number) => number.toString().padLeft(2, '0');
  return 'Uploaded ${local.year}-${two(local.month)}-${two(local.day)} '
      '${two(local.hour)}:${two(local.minute)}';
}

String _formatReportSize(int? bytes) {
  if (bytes == null || bytes <= 0) return '';
  if (bytes < 1024) return ' | $bytes B';
  final kb = bytes / 1024;
  if (kb < 1024) return ' | ${kb.toStringAsFixed(1)} KB';
  final mb = kb / 1024;
  return ' | ${mb.toStringAsFixed(1)} MB';
}
