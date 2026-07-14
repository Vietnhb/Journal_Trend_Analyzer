import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';

import '../../core/constants/app_colors.dart';
import '../providers/bookmark_provider.dart';
import '../providers/firebase_provider.dart';
import '../providers/journal_provider.dart';
import 'bookmarks_screen.dart';
import 'notification_center_screen.dart';
import 'report_history_screen.dart';

class ProfileScreen extends StatelessWidget {
  const ProfileScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final journal = context.watch<JournalProvider>();
    final firebase = context.watch<FirebaseProvider>();
    final bookmarks = context.watch<BookmarkProvider>();
    final colorScheme = Theme.of(context).colorScheme;

    return Scaffold(
      key: const Key('profile_screen'),
      backgroundColor: colorScheme.surfaceContainerLowest,
      body: SafeArea(
        child: Center(
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 800),
            child: ListView(
              padding: const EdgeInsets.fromLTRB(16, 18, 16, 36),
              children: [
                const _PageHeader(),
                const SizedBox(height: 18),
                _ProfileIdentityCard(firebase: firebase),
                const SizedBox(height: 12),
                _ProfileSummary(
                  bookmarkCount: bookmarks.totalCount,
                  reportCount: firebase.uploadedReports.length,
                  notificationCount: firebase.notifications.length,
                ),
                if (firebase.serviceError != null) ...[
                  const SizedBox(height: 12),
                  _MessagePanel(
                    message: firebase.serviceError!,
                    color: colorScheme.errorContainer,
                    foreground: colorScheme.onErrorContainer,
                  ),
                ],
                const SizedBox(height: 24),
                const _SectionLabel('Library'),
                const SizedBox(height: 10),
                _SettingsCard(
                  children: [
                    _SettingsTile(
                      icon: Icons.bookmark_border_rounded,
                      color: AppColors.primary,
                      title: 'Bookmarks',
                      subtitle: bookmarks.totalCount == 0
                          ? 'Save journals and publications for quick access.'
                          : '${bookmarks.journals.length} journals, '
                                '${bookmarks.publications.length} publications saved.',
                      trailing: bookmarks.isLoading
                          ? const SizedBox(
                              width: 20,
                              height: 20,
                              child: CircularProgressIndicator(strokeWidth: 2),
                            )
                          : _Badge('${bookmarks.totalCount}'),
                      onTap: () => Navigator.push(
                        context,
                        MaterialPageRoute(
                          builder: (_) => const BookmarksScreen(),
                        ),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 24),
                const _SectionLabel('Reports'),
                const SizedBox(height: 10),
                _SettingsCard(
                  children: [
                    _SettingsTile(
                      key: const Key('export_pdf_button'),
                      icon: Icons.picture_as_pdf_outlined,
                      color: AppColors.warning,
                      title: 'Dashboard report',
                      subtitle: journal.isLoadingAnalytics
                          ? 'Wait for dashboard analytics to finish loading.'
                          : journal.dashboardReportData == null
                          ? 'Search a topic on Home first.'
                          : firebase.isExporting
                          ? 'Creating your PDF report...'
                          : firebase.reportDownloadUrl != null
                          ? 'Latest report is ready.'
                          : 'Export the current dashboard as a PDF.',
                      trailing: firebase.isExporting
                          ? const SizedBox(
                              width: 20,
                              height: 20,
                              child: CircularProgressIndicator(strokeWidth: 2),
                            )
                          : const Icon(Icons.chevron_right_rounded),
                      onTap:
                          journal.dashboardReportData == null ||
                              firebase.isExporting
                          ? null
                          : () => firebase.exportDashboard(
                              journal.dashboardReportData!,
                            ),
                    ),
                    const Divider(height: 1, indent: 64, endIndent: 16),
                    if (firebase.isLoadingReports)
                      const _SettingsTile(
                        icon: Icons.cloud_sync_outlined,
                        color: AppColors.info,
                        title: 'Report history',
                        subtitle: 'Loading uploaded reports...',
                        trailing: SizedBox(
                          width: 20,
                          height: 20,
                          child: CircularProgressIndicator(strokeWidth: 2),
                        ),
                      )
                    else if (firebase.uploadedReports.isEmpty)
                      _SettingsTile(
                        icon: Icons.cloud_queue_outlined,
                        color: AppColors.info,
                        title: 'Report history',
                        subtitle: 'No uploaded report yet.',
                        trailing: IconButton(
                          tooltip: 'Refresh reports',
                          onPressed: firebase.loadUploadedReports,
                          icon: const Icon(Icons.refresh_rounded),
                        ),
                      )
                    else
                      _SettingsTile(
                        key: const Key('uploaded_report_status'),
                        icon: Icons.cloud_done_outlined,
                        color: AppColors.success,
                        title: 'Uploaded report',
                        subtitle:
                            '${firebase.uploadedReports.length} reports saved. '
                            'Latest ${_formatReportDate(firebase.uploadedReports.first.uploadedAt).replaceFirst('Uploaded ', '')}.',
                        trailing: const Icon(Icons.chevron_right_rounded),
                        onTap: () => Navigator.push(
                          context,
                          MaterialPageRoute(
                            builder: (_) => const ReportHistoryScreen(),
                          ),
                        ),
                      ),
                  ],
                ),
                const SizedBox(height: 24),
                const _SectionLabel('Notifications'),
                const SizedBox(height: 10),
                _SettingsCard(
                  children: [
                    _SettingsTile(
                      key: const Key('notification_center_button'),
                      icon: Icons.notifications_outlined,
                      color: AppColors.info,
                      title: 'Notifications',
                      subtitle: !firebase.notificationsAuthorized
                          ? 'Notifications are off. Tap to allow alerts.'
                          : firebase.notifications.isEmpty
                          ? 'Allowed. No campaign received yet.'
                          : '${firebase.notifications.length} updates received.',
                      trailing: firebase.isRequestingNotifications
                          ? const SizedBox(
                              width: 20,
                              height: 20,
                              child: CircularProgressIndicator(strokeWidth: 2),
                            )
                          : _Badge(
                              firebase.notificationsAuthorized
                                  ? '${firebase.notifications.length}'
                                  : 'Off',
                            ),
                      onTap: firebase.isRequestingNotifications
                          ? null
                          : () async {
                              if (!firebase.notificationsAuthorized) {
                                await firebase.enableNotifications();
                                if (!context.mounted) return;
                                if (!firebase.notificationsAuthorized) {
                                  ScaffoldMessenger.of(context).showSnackBar(
                                    const SnackBar(
                                      content: Text(
                                        'Notification permission is still off.',
                                      ),
                                    ),
                                  );
                                  return;
                                }
                              }
                              if (!context.mounted) return;
                              await Navigator.push(
                                context,
                                MaterialPageRoute(
                                  builder: (_) =>
                                      const NotificationCenterScreen(),
                                ),
                              );
                            },
                    ),
                  ],
                ),
                const SizedBox(height: 24),
                const _SectionLabel('Preferences'),
                const SizedBox(height: 10),
                _SettingsCard(
                  children: [
                    _SettingsTile(
                      icon: journal.isDarkMode
                          ? Icons.dark_mode_outlined
                          : Icons.light_mode_outlined,
                      color: AppColors.primary,
                      title: 'Dark mode',
                      subtitle: 'Switch the application theme.',
                      trailing: Switch(
                        value: journal.isDarkMode,
                        onChanged: context.read<JournalProvider>().setDarkMode,
                      ),
                    ),
                    const Divider(height: 1, indent: 64, endIndent: 16),
                    _SettingsTile(
                      icon: Icons.event_available_outlined,
                      color: AppColors.info,
                      title: 'Filter future years',
                      subtitle:
                          'Use the current device year as the upper limit.',
                      trailing: Switch(
                        value: journal.filterFutureSourceYears,
                        onChanged: context
                            .read<JournalProvider>()
                            .setFilterFutureSourceYears,
                      ),
                    ),
                    const Divider(height: 1, indent: 64, endIndent: 16),
                    _SettingsTile(
                      icon: Icons.history_rounded,
                      color: AppColors.warning,
                      title: 'Recent searches',
                      subtitle:
                          '${journal.recentSearches.length} searches saved.',
                      trailing: TextButton(
                        onPressed: journal.recentSearches.isEmpty
                            ? null
                            : () => _confirmClearSearches(context),
                        child: const Text('Clear'),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 24),
                const _SectionLabel('Advanced'),
                const SizedBox(height: 10),
                _SettingsCard(
                  children: [
                    ExpansionTile(
                      key: const Key('lab_tools_section'),
                      tilePadding: const EdgeInsets.symmetric(
                        horizontal: 16,
                        vertical: 4,
                      ),
                      childrenPadding: EdgeInsets.zero,
                      shape: const RoundedRectangleBorder(),
                      collapsedShape: const RoundedRectangleBorder(),
                      leading: Container(
                        width: 42,
                        height: 42,
                        alignment: Alignment.center,
                        decoration: BoxDecoration(
                          color: AppColors.accent.withValues(alpha: 0.1),
                          borderRadius: BorderRadius.circular(12),
                        ),
                        child: const Icon(
                          Icons.science_outlined,
                          size: 20,
                          color: AppColors.accent,
                        ),
                      ),
                      title: const Text(
                        'Lab verification',
                        style: TextStyle(fontWeight: FontWeight.w700),
                      ),
                      subtitle: const Text('Firebase checks for the lab demo.'),
                      children: [
                        const Divider(height: 1, indent: 64, endIndent: 16),
                        _SettingsTile(
                          key: const Key('remote_config_values'),
                          icon: Icons.tune_rounded,
                          color: AppColors.accent,
                          title: 'Remote Config',
                          subtitle:
                              'max_journals: ${firebase.maxJournals} | '
                              'max_keywords: ${firebase.maxKeywords}',
                          trailing: IconButton(
                            tooltip: 'Refresh Remote Config',
                            onPressed: firebase.isLoadingRemoteConfig
                                ? null
                                : firebase.refreshRemoteConfig,
                            icon: firebase.isLoadingRemoteConfig
                                ? const SizedBox(
                                    width: 18,
                                    height: 18,
                                    child: CircularProgressIndicator(
                                      strokeWidth: 2,
                                    ),
                                  )
                                : const Icon(Icons.refresh_rounded),
                          ),
                        ),
                        const Divider(height: 1, indent: 64, endIndent: 16),
                        _SettingsTile(
                          icon: Icons.bug_report_outlined,
                          color: AppColors.danger,
                          title: 'Handled exception',
                          subtitle: 'Send a non-fatal Crashlytics event.',
                          trailing: const _Badge('Safe'),
                          onTap: () =>
                              _recordHandledException(context, firebase),
                        ),
                        const Divider(height: 1, indent: 64, endIndent: 16),
                        _SettingsTile(
                          icon: Icons.warning_amber_rounded,
                          color: AppColors.danger,
                          title: 'Test crash',
                          subtitle: 'Force a Crashlytics test crash.',
                          trailing: const _Badge('Crash'),
                          onTap: () => _confirmTestCrash(context, firebase),
                        ),
                        const Divider(height: 1, indent: 64, endIndent: 16),
                        _SettingsTile(
                          icon: Icons.notifications_active_outlined,
                          color: AppColors.primary,
                          title: 'FCM campaign',
                          subtitle: firebase.messagingToken == null
                              ? 'Allow notifications first, then copy the test token.'
                              : 'Copy this device token for Firebase Console test.',
                          trailing: IconButton(
                            key: const Key('copy_fcm_token_button'),
                            tooltip: 'Copy FCM token',
                            onPressed: firebase.messagingToken == null
                                ? null
                                : () => _copyToClipboard(
                                    context,
                                    firebase.messagingToken!,
                                    'FCM token copied.',
                                  ),
                            icon: const Icon(Icons.copy_rounded),
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Future<void> _recordHandledException(
    BuildContext context,
    FirebaseProvider firebase,
  ) async {
    await firebase.recordHandledException();
    if (!context.mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text('Handled exception sent to Crashlytics.')),
    );
  }

  Future<void> _confirmTestCrash(
    BuildContext context,
    FirebaseProvider firebase,
  ) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: const Text('Force a test crash?'),
        content: const Text(
          'The application will close immediately. Reopen it afterward so '
          'Crashlytics can upload the report.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(dialogContext, false),
            child: const Text('Cancel'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(dialogContext, true),
            child: const Text('Crash app'),
          ),
        ],
      ),
    );
    if (confirmed == true) firebase.testCrash();
  }

  Future<void> _confirmClearSearches(BuildContext context) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: const Text('Clear recent searches?'),
        content: const Text('All saved topic searches will be removed.'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(dialogContext, false),
            child: const Text('Cancel'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(dialogContext, true),
            child: const Text('Clear'),
          ),
        ],
      ),
    );
    if (confirmed == true && context.mounted) {
      await context.read<JournalProvider>().clearRecentSearches();
    }
  }

  Future<void> _copyToClipboard(
    BuildContext context,
    String value,
    String message,
  ) async {
    await Clipboard.setData(ClipboardData(text: value));
    if (!context.mounted) return;
    ScaffoldMessenger.of(
      context,
    ).showSnackBar(SnackBar(content: Text(message)));
  }

  String _formatReportDate(DateTime? value) {
    if (value == null) return 'Upload time unavailable';
    final local = value.toLocal();
    String two(int number) => number.toString().padLeft(2, '0');
    return 'Uploaded ${local.year}-${two(local.month)}-${two(local.day)} '
        '${two(local.hour)}:${two(local.minute)}';
  }
}

class _PageHeader extends StatelessWidget {
  const _PageHeader();

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    return Row(
      children: [
        Container(
          width: 44,
          height: 44,
          alignment: Alignment.center,
          decoration: BoxDecoration(
            color: AppColors.primary.withValues(alpha: 0.10),
            borderRadius: BorderRadius.circular(14),
          ),
          child: const Icon(
            Icons.person_outline_rounded,
            color: AppColors.primary,
            size: 23,
          ),
        ),
        const SizedBox(width: 12),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'Profile',
                style: Theme.of(context).textTheme.headlineSmall?.copyWith(
                  color: colorScheme.onSurface,
                  fontWeight: FontWeight.w800,
                  letterSpacing: -0.3,
                ),
              ),
              Text(
                'Manage your account, reports, and preferences.',
                style: Theme.of(context).textTheme.bodySmall?.copyWith(
                  color: colorScheme.onSurfaceVariant,
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }
}

class _ProfileSummary extends StatelessWidget {
  final int bookmarkCount;
  final int reportCount;
  final int notificationCount;

  const _ProfileSummary({
    required this.bookmarkCount,
    required this.reportCount,
    required this.notificationCount,
  });

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 12),
      decoration: BoxDecoration(
        color: colorScheme.surface,
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: colorScheme.outlineVariant),
      ),
      child: Row(
        children: [
          Expanded(
            child: _SummaryMetric(
              icon: Icons.bookmark_outline_rounded,
              value: '$bookmarkCount',
              label: 'Saved',
              color: AppColors.primary,
            ),
          ),
          _SummaryDivider(color: colorScheme.outlineVariant),
          Expanded(
            child: _SummaryMetric(
              icon: Icons.cloud_done_outlined,
              value: '$reportCount',
              label: 'Reports',
              color: AppColors.success,
            ),
          ),
          _SummaryDivider(color: colorScheme.outlineVariant),
          Expanded(
            child: _SummaryMetric(
              icon: Icons.notifications_none_rounded,
              value: '$notificationCount',
              label: 'Updates',
              color: AppColors.info,
            ),
          ),
        ],
      ),
    );
  }
}

class _SummaryMetric extends StatelessWidget {
  final IconData icon;
  final String value;
  final String label;
  final Color color;

  const _SummaryMetric({
    required this.icon,
    required this.value,
    required this.label,
    required this.color,
  });

  @override
  Widget build(BuildContext context) {
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        Icon(icon, size: 18, color: color),
        const SizedBox(height: 4),
        Text(
          value,
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
          style: Theme.of(
            context,
          ).textTheme.titleSmall?.copyWith(fontWeight: FontWeight.w900),
        ),
        Text(
          label,
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
          style: Theme.of(context).textTheme.labelSmall?.copyWith(
            color: Theme.of(context).colorScheme.onSurfaceVariant,
          ),
        ),
      ],
    );
  }
}

class _SummaryDivider extends StatelessWidget {
  final Color color;

  const _SummaryDivider({required this.color});

  @override
  Widget build(BuildContext context) {
    return Container(width: 1, height: 44, color: color);
  }
}

class _ProfileIdentityCard extends StatelessWidget {
  final FirebaseProvider firebase;

  const _ProfileIdentityCard({required this.firebase});

  @override
  Widget build(BuildContext context) {
    final user = firebase.user;
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        gradient: const LinearGradient(
          colors: [Color(0xFF285CC2), AppColors.primary, AppColors.accent],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.circular(22),
        boxShadow: [
          BoxShadow(
            color: AppColors.primary.withValues(alpha: 0.18),
            blurRadius: 22,
            offset: const Offset(0, 9),
          ),
        ],
      ),
      child: Column(
        children: [
          Row(
            children: [
              Container(
                padding: const EdgeInsets.all(3),
                decoration: BoxDecoration(
                  color: Colors.white.withValues(alpha: 0.20),
                  shape: BoxShape.circle,
                ),
                child: CircleAvatar(
                  radius: 29,
                  backgroundColor: Colors.white.withValues(alpha: 0.16),
                  backgroundImage: user?.photoURL == null
                      ? null
                      : NetworkImage(user!.photoURL!),
                  child: user?.photoURL == null
                      ? const Icon(
                          Icons.person_outline_rounded,
                          color: Colors.white,
                          size: 30,
                        )
                      : null,
                ),
              ),
              const SizedBox(width: 14),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      user?.displayName ?? 'Google user',
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: Theme.of(context).textTheme.titleMedium?.copyWith(
                        color: Colors.white,
                        fontWeight: FontWeight.w800,
                      ),
                    ),
                    const SizedBox(height: 3),
                    Text(
                      user?.email ?? 'Email unavailable',
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: Theme.of(context).textTheme.bodySmall?.copyWith(
                        color: Colors.white.withValues(alpha: 0.82),
                      ),
                    ),
                    const SizedBox(height: 7),
                    Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 8,
                        vertical: 3,
                      ),
                      decoration: BoxDecoration(
                        color: Colors.white.withValues(alpha: 0.14),
                        borderRadius: BorderRadius.circular(999),
                      ),
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          const Icon(
                            Icons.verified_user_outlined,
                            size: 13,
                            color: Colors.white,
                          ),
                          const SizedBox(width: 4),
                          Text(
                            'Firebase account',
                            style: Theme.of(context).textTheme.labelSmall
                                ?.copyWith(
                                  color: Colors.white,
                                  fontWeight: FontWeight.w700,
                                ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 14),
          SizedBox(
            width: double.infinity,
            child: OutlinedButton.icon(
              key: const Key('logout_button'),
              onPressed: firebase.isSigningOut ? null : firebase.signOut,
              style: OutlinedButton.styleFrom(
                foregroundColor: Colors.white,
                backgroundColor: Colors.white.withValues(alpha: 0.08),
                side: BorderSide(color: Colors.white.withValues(alpha: 0.34)),
                minimumSize: const Size.fromHeight(46),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(13),
                ),
              ),
              icon: firebase.isSigningOut
                  ? const SizedBox(
                      width: 16,
                      height: 16,
                      child: CircularProgressIndicator(
                        strokeWidth: 2,
                        color: Colors.white,
                      ),
                    )
                  : const Icon(Icons.logout_rounded, size: 18),
              label: const Text('Sign Out'),
            ),
          ),
        ],
      ),
    );
  }
}

class _SectionLabel extends StatelessWidget {
  final String value;

  const _SectionLabel(this.value);

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    return Row(
      children: [
        Text(
          value.toUpperCase(),
          style: Theme.of(context).textTheme.labelSmall?.copyWith(
            color: colorScheme.onSurfaceVariant,
            letterSpacing: 1,
            fontWeight: FontWeight.w800,
          ),
        ),
        const SizedBox(width: 10),
        Expanded(child: Divider(color: colorScheme.outlineVariant)),
      ],
    );
  }
}

class _SettingsCard extends StatelessWidget {
  final List<Widget> children;

  const _SettingsCard({required this.children});

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    return Container(
      decoration: BoxDecoration(
        color: colorScheme.surface,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: colorScheme.outlineVariant),
        boxShadow: [
          BoxShadow(
            color: colorScheme.shadow.withValues(alpha: 0.03),
            blurRadius: 14,
            offset: const Offset(0, 5),
          ),
        ],
      ),
      clipBehavior: Clip.antiAlias,
      child: Column(children: children),
    );
  }
}

class _SettingsTile extends StatelessWidget {
  final IconData icon;
  final Color color;
  final String title;
  final String subtitle;
  final Widget trailing;
  final VoidCallback? onTap;

  const _SettingsTile({
    super.key,
    required this.icon,
    required this.color,
    required this.title,
    required this.subtitle,
    required this.trailing,
    this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return ListTile(
      onTap: onTap,
      contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 7),
      enabled: onTap != null || trailing is Switch || trailing is IconButton,
      leading: Container(
        width: 42,
        height: 42,
        alignment: Alignment.center,
        decoration: BoxDecoration(
          color: color.withValues(alpha: 0.1),
          borderRadius: BorderRadius.circular(12),
        ),
        child: Icon(icon, size: 20, color: color),
      ),
      title: Text(
        title,
        style: const TextStyle(fontWeight: FontWeight.w700),
        maxLines: 1,
        overflow: TextOverflow.ellipsis,
      ),
      subtitle: Padding(
        padding: const EdgeInsets.only(top: 2),
        child: Text(subtitle, maxLines: 3, overflow: TextOverflow.ellipsis),
      ),
      trailing: trailing,
    );
  }
}

class _Badge extends StatelessWidget {
  final String label;

  const _Badge(this.label);

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      decoration: BoxDecoration(
        color: AppColors.primary.withValues(alpha: 0.09),
        borderRadius: BorderRadius.circular(999),
      ),
      child: Text(
        label,
        style: Theme.of(context).textTheme.labelSmall?.copyWith(
          color: AppColors.primary,
          fontWeight: FontWeight.w800,
        ),
      ),
    );
  }
}

class _MessagePanel extends StatelessWidget {
  final String message;
  final Color color;
  final Color foreground;

  const _MessagePanel({
    required this.message,
    required this.color,
    required this.foreground,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: color,
        borderRadius: BorderRadius.circular(12),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(Icons.error_outline_rounded, color: foreground, size: 20),
          const SizedBox(width: 10),
          Expanded(
            child: Text(
              message,
              style: Theme.of(
                context,
              ).textTheme.bodySmall?.copyWith(color: foreground),
            ),
          ),
        ],
      ),
    );
  }
}
