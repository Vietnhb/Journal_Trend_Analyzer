import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:url_launcher/url_launcher.dart';

import '../../core/constants/app_colors.dart';
import '../../core/widgets/app_empty_view.dart';
import '../../core/widgets/app_loading.dart';
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
    final colorScheme = Theme.of(context).colorScheme;

    if (currentPage != _pageIndex) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted) setState(() => _pageIndex = currentPage);
      });
    }

    return Scaffold(
      backgroundColor: colorScheme.surfaceContainerLowest,
      appBar: AppBar(
        title: const Text('Report history'),
        actions: [
          IconButton.filledTonal(
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
          const SizedBox(width: 12),
        ],
      ),
      body: SafeArea(
        top: false,
        child: firebase.isLoadingReports && reports.isEmpty
            ? const AppLoading(message: 'Loading uploaded reports...')
            : RefreshIndicator(
                color: AppColors.primary,
                onRefresh: context.read<FirebaseProvider>().loadUploadedReports,
                child: Center(
                  child: ConstrainedBox(
                    constraints: const BoxConstraints(maxWidth: 820),
                    child: ListView(
                      physics: const AlwaysScrollableScrollPhysics(),
                      padding: const EdgeInsets.fromLTRB(16, 12, 16, 28),
                      children: [
                        _ReportSummary(
                          count: reports.length,
                          totalBytes: _totalBytes(reports),
                        ),
                        if (_reportError(firebase.serviceError)
                            case final error?) ...[
                          const SizedBox(height: 12),
                          _InlineError(
                            message: error,
                            onRetry: firebase.loadUploadedReports,
                          ),
                        ],
                        const SizedBox(height: 22),
                        _ListHeader(
                          count: reports.length,
                          newestFirst: _newestFirst,
                          onSortChanged: (value) {
                            setState(() {
                              _newestFirst = value;
                              _pageIndex = 0;
                            });
                          },
                        ),
                        const SizedBox(height: 12),
                        if (reports.isEmpty)
                          _EmptyReports(onRefresh: firebase.loadUploadedReports)
                        else
                          for (
                            var index = 0;
                            index < pageReports.length;
                            index++
                          ) ...[
                            if (index > 0) const SizedBox(height: 10),
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
                        if (pageCount > 1) ...[
                          const SizedBox(height: 14),
                          _PaginationBar(
                            currentPage: currentPage,
                            pageCount: pageCount,
                            onPrevious: currentPage == 0
                                ? null
                                : () => setState(
                                    () => _pageIndex = currentPage - 1,
                                  ),
                            onNext: currentPage >= pageCount - 1
                                ? null
                                : () => setState(
                                    () => _pageIndex = currentPage + 1,
                                  ),
                          ),
                        ],
                      ],
                    ),
                  ),
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

  int _totalBytes(List<UploadedReportFile> reports) {
    return reports.fold(0, (sum, report) => sum + (report.sizeBytes ?? 0));
  }

  String? _reportError(String? error) {
    if (error == null) return null;
    if (error.startsWith('Report history:') ||
        error.startsWith('Delete report:')) {
      return error;
    }
    return null;
  }

  Future<void> _confirmDeleteReport(
    BuildContext context,
    FirebaseProvider firebase,
    UploadedReportFile report,
  ) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        icon: const Icon(Icons.delete_outline_rounded, color: AppColors.danger),
        title: const Text('Delete uploaded report?'),
        content: Text(
          'This will remove the report uploaded on '
          '${_formatReportDate(report.uploadedAt)}.',
          textAlign: TextAlign.center,
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(dialogContext, false),
            child: const Text('Cancel'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(dialogContext, true),
            style: FilledButton.styleFrom(backgroundColor: AppColors.danger),
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

class _ReportSummary extends StatelessWidget {
  final int count;
  final int totalBytes;

  const _ReportSummary({required this.count, required this.totalBytes});

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    return Container(
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: [
            AppColors.primary.withValues(alpha: 0.13),
            AppColors.accent.withValues(alpha: 0.07),
          ],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: AppColors.primary.withValues(alpha: 0.14)),
      ),
      child: Row(
        children: [
          Container(
            width: 50,
            height: 50,
            alignment: Alignment.center,
            decoration: BoxDecoration(
              color: colorScheme.surface,
              borderRadius: BorderRadius.circular(15),
            ),
            child: const Icon(
              Icons.cloud_done_outlined,
              color: AppColors.primary,
              size: 25,
            ),
          ),
          const SizedBox(width: 14),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  count == 0
                      ? 'Your cloud reports'
                      : '$count ${count == 1 ? 'report' : 'reports'} in Firebase',
                  style: Theme.of(context).textTheme.titleMedium?.copyWith(
                    color: colorScheme.onSurface,
                    fontWeight: FontWeight.w800,
                  ),
                ),
                const SizedBox(height: 3),
                Text(
                  count == 0
                      ? 'Uploaded PDF reports will be available here.'
                      : '${_formatByteValue(totalBytes)} stored securely in the cloud',
                  style: Theme.of(context).textTheme.labelSmall?.copyWith(
                    color: colorScheme.onSurfaceVariant,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _ListHeader extends StatelessWidget {
  final int count;
  final bool newestFirst;
  final ValueChanged<bool> onSortChanged;

  const _ListHeader({
    required this.count,
    required this.newestFirst,
    required this.onSortChanged,
  });

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    return Row(
      children: [
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'REPORTS',
                style: Theme.of(context).textTheme.labelSmall?.copyWith(
                  color: colorScheme.onSurfaceVariant,
                  letterSpacing: 1,
                  fontWeight: FontWeight.w800,
                ),
              ),
              const SizedBox(height: 3),
              Text(
                count == 0 ? 'No uploaded report yet.' : '$count saved reports',
                style: Theme.of(context).textTheme.bodySmall?.copyWith(
                  color: colorScheme.onSurfaceVariant,
                ),
              ),
            ],
          ),
        ),
        PopupMenuButton<bool>(
          tooltip: 'Sort reports',
          initialValue: newestFirst,
          onSelected: onSortChanged,
          itemBuilder: (context) => const [
            PopupMenuItem(value: true, child: Text('Newest first')),
            PopupMenuItem(value: false, child: Text('Oldest first')),
          ],
          child: _SortButton(label: newestFirst ? 'Newest' : 'Oldest'),
        ),
      ],
    );
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
    final colorScheme = Theme.of(context).colorScheme;
    return Material(
      color: colorScheme.surface,
      borderRadius: BorderRadius.circular(18),
      clipBehavior: Clip.antiAlias,
      child: InkWell(
        onTap: isDeleting ? null : onOpen,
        child: Container(
          padding: const EdgeInsets.fromLTRB(14, 14, 8, 14),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(18),
            border: Border.all(color: colorScheme.outlineVariant),
            boxShadow: [
              BoxShadow(
                color: colorScheme.shadow.withValues(alpha: 0.035),
                blurRadius: 14,
                offset: const Offset(0, 5),
              ),
            ],
          ),
          child: Row(
            children: [
              Container(
                width: 44,
                height: 44,
                alignment: Alignment.center,
                decoration: BoxDecoration(
                  color: AppColors.success.withValues(alpha: 0.10),
                  borderRadius: BorderRadius.circular(13),
                ),
                child: const Icon(
                  Icons.picture_as_pdf_outlined,
                  size: 22,
                  color: AppColors.success,
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text(
                      'Uploaded report',
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(fontWeight: FontWeight.w800),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      _formatReportDate(report.uploadedAt),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: Theme.of(context).textTheme.labelSmall?.copyWith(
                        color: colorScheme.onSurfaceVariant,
                      ),
                    ),
                    if (report.sizeBytes case final bytes? when bytes > 0) ...[
                      const SizedBox(height: 3),
                      Text(
                        _formatByteValue(bytes),
                        style: Theme.of(context).textTheme.labelSmall?.copyWith(
                          color: AppColors.success,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                    ],
                  ],
                ),
              ),
              IconButton(
                tooltip: 'Open report',
                onPressed: isDeleting ? null : onOpen,
                visualDensity: VisualDensity.compact,
                icon: const Icon(Icons.open_in_new_rounded),
              ),
              IconButton(
                tooltip: 'Delete report',
                onPressed: isDeleting ? null : onDelete,
                visualDensity: VisualDensity.compact,
                color: AppColors.danger,
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
        ),
      ),
    );
  }
}

class _SortButton extends StatelessWidget {
  final String label;

  const _SortButton({required this.label});

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    return Container(
      height: 40,
      padding: const EdgeInsets.symmetric(horizontal: 12),
      decoration: BoxDecoration(
        color: colorScheme.surface,
        border: Border.all(color: colorScheme.outlineVariant),
        borderRadius: BorderRadius.circular(12),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          const Icon(Icons.swap_vert_rounded, size: 18),
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
    final colorScheme = Theme.of(context).colorScheme;
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 6),
      decoration: BoxDecoration(
        color: colorScheme.surface,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: colorScheme.outlineVariant),
      ),
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
    );
  }
}

class _EmptyReports extends StatelessWidget {
  final Future<void> Function() onRefresh;

  const _EmptyReports({required this.onRefresh});

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    return Container(
      padding: const EdgeInsets.only(bottom: 22),
      decoration: BoxDecoration(
        color: colorScheme.surface,
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: colorScheme.outlineVariant),
      ),
      child: Column(
        children: [
          const SizedBox(
            height: 180,
            child: AppEmptyView(
              message: 'No uploaded report yet.',
              icon: Icons.cloud_queue_outlined,
            ),
          ),
          OutlinedButton.icon(
            onPressed: onRefresh,
            icon: const Icon(Icons.refresh_rounded, size: 18),
            label: const Text('Refresh reports'),
          ),
        ],
      ),
    );
  }
}

class _InlineError extends StatelessWidget {
  final String message;
  final Future<void> Function() onRetry;

  const _InlineError({required this.message, required this.onRetry});

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: colorScheme.errorContainer,
        borderRadius: BorderRadius.circular(14),
      ),
      child: Row(
        children: [
          Icon(
            Icons.error_outline_rounded,
            color: colorScheme.onErrorContainer,
          ),
          const SizedBox(width: 10),
          Expanded(
            child: Text(
              message,
              style: Theme.of(context).textTheme.bodySmall?.copyWith(
                color: colorScheme.onErrorContainer,
              ),
            ),
          ),
          IconButton(
            tooltip: 'Try again',
            onPressed: onRetry,
            color: colorScheme.onErrorContainer,
            icon: const Icon(Icons.refresh_rounded),
          ),
        ],
      ),
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

String _formatByteValue(int bytes) {
  if (bytes <= 0) return '0 B';
  if (bytes < 1024) return '$bytes B';
  final kb = bytes / 1024;
  if (kb < 1024) return '${kb.toStringAsFixed(1)} KB';
  final mb = kb / 1024;
  return '${mb.toStringAsFixed(1)} MB';
}
