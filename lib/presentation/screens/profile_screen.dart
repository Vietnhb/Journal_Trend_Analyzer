import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';

import '../../core/constants/app_colors.dart';
import '../providers/firebase_provider.dart';
import '../providers/journal_provider.dart';
import 'notification_center_screen.dart';
import 'report_history_screen.dart';

class ProfileScreen extends StatelessWidget {
  const ProfileScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final journal = context.watch<JournalProvider>();
    final firebase = context.watch<FirebaseProvider>();
    final colorScheme = Theme.of(context).colorScheme;

    return Scaffold(
      key: const Key('profile_screen'),
      body: SafeArea(
        child: ListView(
          padding: const EdgeInsets.fromLTRB(16, 16, 16, 32),
          children: [
            Text(
              'Profile',
              style: Theme.of(
                context,
              ).textTheme.headlineSmall?.copyWith(fontWeight: FontWeight.w800),
            ),
            Text(
              'Manage your account, reports, and preferences.',
              style: Theme.of(context).textTheme.bodySmall?.copyWith(
                color: colorScheme.onSurfaceVariant,
              ),
            ),
            const SizedBox(height: 16),
            _ProfileIdentityCard(firebase: firebase),
            if (firebase.serviceError != null) ...[
              const SizedBox(height: 12),
              _MessagePanel(
                message: firebase.serviceError!,
                color: colorScheme.errorContainer,
                foreground: colorScheme.onErrorContainer,
              ),
            ],
            const SizedBox(height: 22),
            const _SectionLabel('Reports'),
            const SizedBox(height: 10),
            _SettingsCard(
              children: [
                _SettingsTile(
                  key: const Key('export_pdf_button'),
                  icon: Icons.picture_as_pdf_outlined,
                  color: AppColors.warning,
                  title: 'Dashboard report',
                  subtitle: journal.dashboardReportData == null
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
                const Divider(height: 1, indent: 56),
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
            const SizedBox(height: 22),
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
                              builder: (_) => const NotificationCenterScreen(),
                            ),
                          );
                        },
                ),
              ],
            ),
            const SizedBox(height: 22),
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
                const Divider(height: 1, indent: 56),
                _SettingsTile(
                  icon: Icons.event_available_outlined,
                  color: AppColors.info,
                  title: 'Filter future years',
                  subtitle: 'Use the current device year as the upper limit.',
                  trailing: Switch(
                    value: journal.filterFutureSourceYears,
                    onChanged: context
                        .read<JournalProvider>()
                        .setFilterFutureSourceYears,
                  ),
                ),
                const Divider(height: 1, indent: 56),
                _SettingsTile(
                  icon: Icons.history_rounded,
                  color: AppColors.warning,
                  title: 'Recent searches',
                  subtitle: '${journal.recentSearches.length} searches saved.',
                  trailing: TextButton(
                    onPressed: journal.recentSearches.isEmpty
                        ? null
                        : () => _confirmClearSearches(context),
                    child: const Text('Clear'),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 22),
            const _SectionLabel('Advanced'),
            const SizedBox(height: 10),
            _SettingsCard(
              children: [
                ExpansionTile(
                  key: const Key('lab_tools_section'),
                  leading: Container(
                    width: 38,
                    height: 38,
                    alignment: Alignment.center,
                    decoration: BoxDecoration(
                      color: AppColors.accent.withValues(alpha: 0.1),
                      borderRadius: BorderRadius.circular(10),
                    ),
                    child: const Icon(
                      Icons.science_outlined,
                      size: 19,
                      color: AppColors.accent,
                    ),
                  ),
                  title: const Text(
                    'Lab verification',
                    style: TextStyle(fontWeight: FontWeight.w700),
                  ),
                  subtitle: const Text('Firebase checks for the lab demo.'),
                  childrenPadding: EdgeInsets.zero,
                  children: [
                    const Divider(height: 1, indent: 56),
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
                    const Divider(height: 1, indent: 56),
                    _SettingsTile(
                      icon: Icons.bug_report_outlined,
                      color: AppColors.danger,
                      title: 'Handled exception',
                      subtitle: 'Send a non-fatal Crashlytics event.',
                      trailing: const _Badge('Safe'),
                      onTap: () => _recordHandledException(context, firebase),
                    ),
                    const Divider(height: 1, indent: 56),
                    _SettingsTile(
                      icon: Icons.warning_amber_rounded,
                      color: AppColors.danger,
                      title: 'Test crash',
                      subtitle: 'Force a Crashlytics test crash.',
                      trailing: const _Badge('Crash'),
                      onTap: () => _confirmTestCrash(context, firebase),
                    ),
                    const Divider(height: 1, indent: 56),
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

class _ProfileIdentityCard extends StatelessWidget {
  final FirebaseProvider firebase;

  const _ProfileIdentityCard({required this.firebase});

  @override
  Widget build(BuildContext context) {
    final user = firebase.user;
    return Container(
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        gradient: const LinearGradient(
          colors: [AppColors.primary, AppColors.accent],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.circular(18),
      ),
      child: Column(
        children: [
          Row(
            children: [
              CircleAvatar(
                radius: 29,
                backgroundColor: Colors.white.withValues(alpha: 0.2),
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
              const SizedBox(width: 14),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      user?.displayName ?? 'Google user',
                      style: Theme.of(context).textTheme.titleMedium?.copyWith(
                        color: Colors.white,
                        fontWeight: FontWeight.w800,
                      ),
                    ),
                    const SizedBox(height: 3),
                    Text(
                      user?.email ?? 'Email unavailable',
                      style: Theme.of(context).textTheme.bodySmall?.copyWith(
                        color: Colors.white.withValues(alpha: 0.82),
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
                side: BorderSide(color: Colors.white.withValues(alpha: 0.5)),
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
      contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 5),
      leading: Container(
        width: 38,
        height: 38,
        alignment: Alignment.center,
        decoration: BoxDecoration(
          color: color.withValues(alpha: 0.1),
          borderRadius: BorderRadius.circular(10),
        ),
        child: Icon(icon, size: 19, color: color),
      ),
      title: Text(title, style: const TextStyle(fontWeight: FontWeight.w700)),
      subtitle: Text(subtitle, maxLines: 3, overflow: TextOverflow.ellipsis),
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
        color: Theme.of(context).colorScheme.surfaceContainerHighest,
        borderRadius: BorderRadius.circular(12),
      ),
      child: Text(
        label,
        style: Theme.of(
          context,
        ).textTheme.labelSmall?.copyWith(fontWeight: FontWeight.w800),
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
      child: Text(message, style: TextStyle(color: foreground)),
    );
  }
}
