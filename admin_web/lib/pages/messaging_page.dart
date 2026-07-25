import 'dart:convert';

import 'package:flutter/material.dart';

import '../core/core.dart';
import '../theme/app_theme.dart';
import '../utils/ui_format.dart';
import '../widgets/admin_widgets.dart';

class MessagingPage extends StatefulWidget {
  const MessagingPage({required this.api, super.key});

  final AdminApi api;

  @override
  State<MessagingPage> createState() => _MessagingPageState();
}

class _MessagingPageState extends State<MessagingPage> {
  bool _showComposer = false;
  bool _loading = true;
  Object? _error;
  List<MessagingCampaign> _campaigns = const [];

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    setState(() {
      _loading = true;
      _error = null;
    });
    try {
      final campaigns = await widget.api.listCampaigns();
      if (mounted) setState(() => _campaigns = campaigns);
    } catch (error) {
      if (mounted) setState(() => _error = error);
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  Future<void> _campaignCreated(MessagingCampaign campaign) async {
    setState(() {
      _campaigns = [
        campaign,
        ..._campaigns.where((item) => item.id != campaign.id),
      ];
      _showComposer = false;
    });
    showAppMessage(
      context,
      campaign.status == CampaignStatus.scheduled
          ? 'Campaign scheduled.'
          : 'Firebase accepted the campaign.',
    );
  }

  Future<void> _cancel(MessagingCampaign campaign) async {
    final confirmed = await showTypedConfirmation(
      context: context,
      title: 'Cancel this scheduled campaign?',
      description:
          'Campaign “${campaign.name}” will not be sent. This action cannot be undone.',
      confirmationText: 'CANCEL SCHEDULE',
      actionLabel: 'Cancel schedule',
    );
    if (!confirmed || !mounted) return;
    try {
      final updated = await widget.api.cancelCampaign(campaign.id);
      if (!mounted) return;
      setState(() {
        _campaigns = [
          for (final item in _campaigns)
            if (item.id == updated.id) updated else item,
        ];
      });
      showAppMessage(context, 'Campaign canceled.');
    } catch (error) {
      if (mounted) showAppMessage(context, errorText(error), error: true);
    }
  }

  Future<void> _openCampaign(MessagingCampaign campaign) => showDialog<void>(
    context: context,
    builder: (context) => _CampaignDetailsDialog(campaign: campaign),
  );

  @override
  Widget build(BuildContext context) => PageBody(
    children: [
      PageHeading(
        eyebrow: 'Firebase Cloud Messaging',
        title: _showComposer ? 'New Campaign' : 'Messaging',
        description: _showComposer
            ? 'Compose the content, select audience, and set the delivery time.'
            : 'Create, schedule, and monitor push notification campaigns via FCM.',
        actions: [
          if (_showComposer)
            OutlinedButton.icon(
              onPressed: () => setState(() => _showComposer = false),
              icon: const Icon(Icons.arrow_back_rounded, size: 16),
              label: const Text('Back to campaigns'),
            )
          else
            FilledButton.icon(
              onPressed: () => setState(() => _showComposer = true),
              icon: const Icon(Icons.add_rounded, size: 16),
              label: const Text('New campaign'),
            ),
        ],
      ),
      if (_showComposer)
        _CampaignComposer(api: widget.api, onCreated: _campaignCreated)
      else
        _CampaignList(
          campaigns: _campaigns,
          loading: _loading,
          error: _error,
          onRetry: _load,
          onCreate: () => setState(() => _showComposer = true),
          onCancel: _cancel,
          onOpen: _openCampaign,
        ),
    ],
  );
}

class _CampaignComposer extends StatefulWidget {
  const _CampaignComposer({required this.api, required this.onCreated});

  final AdminApi api;
  final ValueChanged<MessagingCampaign> onCreated;

  @override
  State<_CampaignComposer> createState() => _CampaignComposerState();
}

class _CampaignComposerState extends State<_CampaignComposer> {
  static const _maxPayloadBytes = 4096;
  static const _reservedKeys = {'from', 'message_type'};
  static const _reservedPrefixes = ['google.', 'gcm.'];

  final _formKey = GlobalKey<FormState>();
  final _name = TextEditingController();
  final _title = TextEditingController();
  final _body = TextEditingController();
  final _data = TextEditingController(text: 'source=admin-web');
  CampaignAudience _audience = CampaignAudience.allUsers;
  bool _sendNow = true;
  DateTime? _scheduleAt;
  int _ttlSeconds = 86400;
  bool _sound = true;
  bool _sending = false;
  int _payloadBytes = 0;

  @override
  void initState() {
    super.initState();
    for (final controller in [_title, _body, _data]) {
      controller.addListener(_updatePayload);
    }
    _updatePayload();
  }

  @override
  void dispose() {
    _name.dispose();
    _title.dispose();
    _body.dispose();
    _data.dispose();
    super.dispose();
  }

  void _updatePayload() {
    final payload = {
      'notification': {'title': _title.text.trim(), 'body': _body.text.trim()},
      'data': _tryParseData(_data.text) ?? const <String, String>{},
    };
    if (mounted) {
      setState(() => _payloadBytes = utf8.encode(jsonEncode(payload)).length);
    }
  }

  Map<String, String>? _tryParseData(String raw) {
    try {
      return _parseData(raw);
    } on FormatException {
      return null;
    }
  }

  Map<String, String> _parseData(String raw) {
    final result = <String, String>{};
    final lines = const LineSplitter().convert(raw);
    for (var index = 0; index < lines.length; index++) {
      final line = lines[index].trim();
      if (line.isEmpty) continue;
      final separator = line.indexOf('=');
      if (separator <= 0) {
        throw FormatException(
          'Line ${index + 1} must use the key=value format.',
        );
      }
      final key = line.substring(0, separator).trim();
      final value = line.substring(separator + 1).trim();
      if (key.isEmpty || key.length > 128) {
        throw FormatException('The key on line ${index + 1} is invalid.');
      }
      if (value.length > 2048) {
        throw FormatException('The value for “$key” exceeds 2,048 characters.');
      }
      if (_reservedKeys.contains(key) ||
          _reservedPrefixes.any(key.startsWith)) {
        throw FormatException('The key “$key” is reserved by FCM.');
      }
      if (result.containsKey(key)) {
        throw FormatException('The key “$key” is duplicated.');
      }
      result[key] = value;
    }
    if (result.length > 50) {
      throw const FormatException(
        'Custom data supports a maximum of 50 lines.',
      );
    }
    return result;
  }

  String? _required(String? value, String label, int maxLength) {
    final text = value?.trim() ?? '';
    if (text.isEmpty) return '$label is required.';
    if (text.length > maxLength) {
      return '$label cannot exceed $maxLength characters.';
    }
    return null;
  }

  String? _validateData(String? value) {
    try {
      _parseData(value ?? '');
      if (_payloadBytes > _maxPayloadBytes) {
        return 'Payload exceeds 4,096 UTF-8 bytes.';
      }
    } on FormatException catch (error) {
      return error.message.toString();
    }
    return null;
  }

  Future<void> _pickSchedule() async {
    final now = DateTime.now();
    final date = await showDatePicker(
      context: context,
      initialDate: _scheduleAt ?? now.add(const Duration(days: 1)),
      firstDate: now,
      lastDate: now.add(const Duration(days: 366)),
    );
    if (date == null || !mounted) return;
    final time = await showTimePicker(
      context: context,
      initialTime: _scheduleAt == null
          ? TimeOfDay.fromDateTime(now.add(const Duration(hours: 1)))
          : TimeOfDay.fromDateTime(_scheduleAt!),
    );
    if (time == null) return;
    setState(() {
      _scheduleAt = DateTime(
        date.year,
        date.month,
        date.day,
        time.hour,
        time.minute,
      );
    });
  }

  Future<void> _submit() async {
    if (_sending || !(_formKey.currentState?.validate() ?? false)) return;
    if (!_sendNow &&
        (_scheduleAt == null ||
            _scheduleAt!.isBefore(
              DateTime.now().add(const Duration(minutes: 1)),
            ))) {
      showAppMessage(
        context,
        'The delivery time must be at least 1 minute from now.',
        error: true,
      );
      return;
    }
    final data = _parseData(_data.text);
    final confirmed = await showTypedConfirmation(
      context: context,
      title: _sendNow ? 'Send this campaign now?' : 'Schedule this campaign?',
      description: _sendNow
          ? 'This notification will be sent to ${_audience.label}. An active fanout cannot be canceled.'
          : 'This notification will be sent to ${_audience.label} at ${_formatLocal(_scheduleAt!)} and can be canceled before delivery begins.',
      confirmationText: _sendNow ? 'SEND NOW' : 'SCHEDULE',
      actionLabel: _sendNow ? 'Send campaign' : 'Schedule campaign',
    );
    if (!confirmed || !mounted) return;

    setState(() => _sending = true);
    try {
      final campaign = await widget.api.createCampaign(
        CampaignDraft(
          name: _name.text.trim(),
          title: _title.text.trim(),
          body: _body.text.trim(),
          data: data,
          audience: _audience,
          scheduleAt: _sendNow ? null : _scheduleAt,
          ttlSeconds: _ttlSeconds,
          sound: _sound,
        ),
      );
      if (mounted) widget.onCreated(campaign);
    } catch (error) {
      if (mounted) showAppMessage(context, errorText(error), error: true);
    } finally {
      if (mounted) setState(() => _sending = false);
    }
  }

  Future<void> _sendTest() async {
    if (_sending) return;
    final titleError = _required(_title.text, 'Notification title', 100);
    final bodyError = _required(_body.text, 'Notification body', 500);
    final dataError = _validateData(_data.text);
    if (titleError != null || bodyError != null || dataError != null) {
      showAppMessage(
        context,
        titleError ?? bodyError ?? dataError!,
        error: true,
      );
      return;
    }
    final controller = TextEditingController();
    final target = await showDialog<String>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: const Text('Send test notification'),
        content: SizedBox(
          width: 520,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              const Text(
                'Enter an FCM registration token or Firebase Installation ID. '
                'This action does not create a campaign.',
              ),
              const SizedBox(height: 16),
              TextField(
                controller: controller,
                minLines: 2,
                maxLines: 4,
                autofocus: true,
                style: const TextStyle(fontFamily: 'monospace', fontSize: 13),
                decoration: const InputDecoration(
                  labelText: 'Token or Installation ID',
                  alignLabelWithHint: true,
                ),
              ),
            ],
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(dialogContext),
            child: const Text('Close'),
          ),
          FilledButton.icon(
            onPressed: () {
              final value = controller.text.trim();
              if (value.length >= 20 && value.length <= 4096) {
                Navigator.pop(dialogContext, value);
              }
            },
            icon: const Icon(Icons.send_rounded),
            label: const Text('Send test'),
          ),
        ],
      ),
    );
    controller.dispose();
    if (target == null || !mounted) return;
    setState(() => _sending = true);
    try {
      await widget.api.sendTestMessage(
        TestMessage(
          target: target,
          title: _title.text.trim(),
          body: _body.text.trim(),
          data: _parseData(_data.text),
        ),
      );
      if (mounted) showAppMessage(context, 'Test notification sent.');
    } catch (error) {
      if (mounted) showAppMessage(context, errorText(error), error: true);
    } finally {
      if (mounted) setState(() => _sending = false);
    }
  }

  @override
  Widget build(BuildContext context) => LayoutBuilder(
    builder: (context, constraints) {
      final form = Form(
        key: _formKey,
        autovalidateMode: AutovalidateMode.onUserInteraction,
        child: Column(
          children: [
            _ComposerSection(
              number: 1,
              title: 'Notification content',
              subtitle: 'What recipients will see on their devices.',
              child: Column(
                children: [
                  TextFormField(
                    controller: _name,
                    enabled: !_sending,
                    maxLength: 120,
                    validator: (value) =>
                        _required(value, 'Campaign name', 120),
                    decoration: const InputDecoration(
                      labelText: 'Campaign name',
                      hintText: 'Example: July reporting feature launch',
                      prefixIcon: Icon(Icons.campaign_outlined),
                    ),
                  ),
                  const SizedBox(height: 12),
                  TextFormField(
                    controller: _title,
                    enabled: !_sending,
                    maxLength: 100,
                    validator: (value) =>
                        _required(value, 'Notification title', 100),
                    decoration: const InputDecoration(
                      labelText: 'Notification title',
                      prefixIcon: Icon(Icons.title_rounded),
                    ),
                  ),
                  const SizedBox(height: 12),
                  TextFormField(
                    controller: _body,
                    enabled: !_sending,
                    minLines: 3,
                    maxLines: 5,
                    maxLength: 500,
                    validator: (value) =>
                        _required(value, 'Notification body', 500),
                    decoration: const InputDecoration(
                      labelText: 'Notification body',
                      alignLabelWithHint: true,
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 18),
            _ComposerSection(
              number: 2,
              title: 'Audience',
              subtitle:
                  'Devices join an audience automatically when the app starts.',
              child: DropdownButtonFormField<CampaignAudience>(
                initialValue: _audience,
                items: [
                  for (final audience in CampaignAudience.values)
                    DropdownMenuItem(
                      value: audience,
                      child: Text(audience.label),
                    ),
                ],
                onChanged: _sending
                    ? null
                    : (value) => setState(
                        () => _audience = value ?? CampaignAudience.allUsers,
                      ),
                decoration: const InputDecoration(
                  labelText: 'Audience',
                  prefixIcon: Icon(Icons.groups_2_outlined),
                ),
              ),
            ),
            const SizedBox(height: 18),
            _ComposerSection(
              number: 3,
              title: 'Delivery schedule',
              subtitle:
                  'Send immediately or choose a time within the next year.',
              child: Column(
                children: [
                  SegmentedButton<bool>(
                    segments: const [
                      ButtonSegment(
                        value: true,
                        icon: Icon(Icons.send_rounded),
                        label: Text('Send now'),
                      ),
                      ButtonSegment(
                        value: false,
                        icon: Icon(Icons.schedule_rounded),
                        label: Text('Schedule'),
                      ),
                    ],
                    selected: {_sendNow},
                    expandedInsets: EdgeInsets.zero,
                    onSelectionChanged: _sending
                        ? null
                        : (value) => setState(() => _sendNow = value.first),
                  ),
                  if (!_sendNow) ...[
                    const SizedBox(height: 14),
                    ListTile(
                      tileColor: Theme.of(
                        context,
                      ).colorScheme.surfaceContainerHighest,
                      leading: const Icon(Icons.event_rounded),
                      title: Text(
                        _scheduleAt == null
                            ? 'No delivery time selected'
                            : _formatLocal(_scheduleAt!),
                      ),
                      subtitle: const Text('Administrator device time zone'),
                      trailing: OutlinedButton(
                        onPressed: _sending ? null : _pickSchedule,
                        child: const Text('Choose time'),
                      ),
                    ),
                  ],
                ],
              ),
            ),
            const SizedBox(height: 18),
            _ComposerSection(
              number: 4,
              title: 'Advanced options',
              subtitle: 'Configure time to live, sound, and app data.',
              child: Column(
                children: [
                  DropdownButtonFormField<int>(
                    initialValue: _ttlSeconds,
                    decoration: const InputDecoration(
                      labelText: 'Expire while device is offline',
                      prefixIcon: Icon(Icons.timer_outlined),
                    ),
                    items: const [
                      DropdownMenuItem(value: 3600, child: Text('1 hour')),
                      DropdownMenuItem(value: 21600, child: Text('6 hours')),
                      DropdownMenuItem(value: 86400, child: Text('1 day')),
                      DropdownMenuItem(value: 604800, child: Text('7 days')),
                      DropdownMenuItem(value: 2419200, child: Text('28 days')),
                    ],
                    onChanged: _sending
                        ? null
                        : (value) =>
                              setState(() => _ttlSeconds = value ?? 86400),
                  ),
                  const SizedBox(height: 12),
                  SwitchListTile(
                    contentPadding: const EdgeInsets.symmetric(horizontal: 12),
                    value: _sound,
                    onChanged: _sending
                        ? null
                        : (value) => setState(() => _sound = value),
                    title: const Text('Default sound'),
                    subtitle: const Text(
                      'Play a sound when the operating system displays the notification.',
                    ),
                    secondary: const Icon(Icons.volume_up_outlined),
                  ),
                  const SizedBox(height: 12),
                  TextFormField(
                    controller: _data,
                    validator: _validateData,
                    enabled: !_sending,
                    minLines: 4,
                    maxLines: 8,
                    style: const TextStyle(
                      fontFamily: 'monospace',
                      fontSize: 13,
                    ),
                    decoration: const InputDecoration(
                      labelText: 'Custom data',
                      hintText: 'screen=report\nsource=admin-web',
                      helperText: 'One key=value pair per line.',
                      alignLabelWithHint: true,
                      prefixIcon: Icon(Icons.data_object_rounded),
                    ),
                  ),
                  const SizedBox(height: 12),
                  _PayloadMeter(bytes: _payloadBytes),
                ],
              ),
            ),
            const SizedBox(height: 20),
            Wrap(
              alignment: WrapAlignment.end,
              spacing: 12,
              runSpacing: 10,
              children: [
                OutlinedButton.icon(
                  onPressed: _sending ? null : _sendTest,
                  icon: const Icon(Icons.science_outlined),
                  label: const Text('Send test notification'),
                ),
                FilledButton.icon(
                  onPressed: _sending ? null : _submit,
                  icon: _sending
                      ? const SizedBox.square(
                          dimension: 17,
                          child: CircularProgressIndicator(
                            strokeWidth: 2,
                            color: Colors.white,
                          ),
                        )
                      : Icon(
                          _sendNow
                              ? Icons.send_rounded
                              : Icons.schedule_send_rounded,
                        ),
                  label: Text(
                    _sending
                        ? 'Processing…'
                        : _sendNow
                        ? 'Review and send'
                        : 'Review and schedule',
                  ),
                ),
              ],
            ),
          ],
        ),
      );
      final preview = _NotificationPreview(
        title: _title,
        body: _body,
        audience: _audience,
      );
      if (constraints.maxWidth < 980) {
        return Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [form, const SizedBox(height: 18), preview],
        );
      }
      return Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Expanded(flex: 3, child: form),
          const SizedBox(width: 22),
          Expanded(flex: 2, child: preview),
        ],
      );
    },
  );
}

class _ComposerSection extends StatelessWidget {
  const _ComposerSection({
    required this.number,
    required this.title,
    required this.subtitle,
    required this.child,
  });

  final int number;
  final String title;
  final String subtitle;
  final Widget child;

  @override
  Widget build(BuildContext context) => SectionCard(
    child: Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            CircleAvatar(
              radius: 17,
              backgroundColor: Theme.of(context).colorScheme.primaryContainer,
              child: Text(
                '$number',
                style: TextStyle(
                  color: Theme.of(context).colorScheme.onPrimaryContainer,
                  fontWeight: FontWeight.w900,
                ),
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    title,
                    style: Theme.of(context).textTheme.titleMedium?.copyWith(
                      fontWeight: FontWeight.w900,
                    ),
                  ),
                  const SizedBox(height: 2),
                  Text(
                    subtitle,
                    style: Theme.of(context).textTheme.bodySmall?.copyWith(
                      color: Theme.of(context).colorScheme.onSurfaceVariant,
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
        const SizedBox(height: 20),
        child,
      ],
    ),
  );
}

class _CampaignList extends StatelessWidget {
  const _CampaignList({
    required this.campaigns,
    required this.loading,
    required this.error,
    required this.onRetry,
    required this.onCreate,
    required this.onCancel,
    required this.onOpen,
  });

  final List<MessagingCampaign> campaigns;
  final bool loading;
  final Object? error;
  final VoidCallback onRetry;
  final VoidCallback onCreate;
  final ValueChanged<MessagingCampaign> onCancel;
  final ValueChanged<MessagingCampaign> onOpen;

  @override
  Widget build(BuildContext context) {
    if (loading) {
      return const SectionCard(
        child: Center(
          child: Padding(
            padding: EdgeInsets.all(36),
            child: CircularProgressIndicator(),
          ),
        ),
      );
    }
    if (error != null) {
      return ErrorPanel(message: errorText(error!), onRetry: onRetry);
    }
    if (campaigns.isEmpty) {
      return SectionCard(
        child: Padding(
          padding: const EdgeInsets.symmetric(vertical: 38),
          child: Column(
            children: [
              const Icon(
                Icons.campaign_outlined,
                size: 46,
                color: AppTheme.accent,
              ),
              const SizedBox(height: 14),
              Text(
                'No campaigns yet',
                style: Theme.of(
                  context,
                ).textTheme.titleLarge?.copyWith(fontWeight: FontWeight.w900),
              ),
              const SizedBox(height: 7),
              Text(
                'Create your first campaign to send or schedule a notification.',
                style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                  color: Theme.of(context).colorScheme.onSurfaceVariant,
                ),
              ),
              const SizedBox(height: 18),
              FilledButton.icon(
                onPressed: onCreate,
                icon: const Icon(Icons.add_rounded),
                label: const Text('Create campaign'),
              ),
            ],
          ),
        ),
      );
    }

    return SizedBox(
      width: double.infinity,
      child: SectionCard(
        padding: EdgeInsets.zero,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Padding(
              padding: const EdgeInsets.all(20),
              child: SectionTitle(
                title: 'All campaigns',
                description:
                    '${campaigns.length} most recent campaigns · select one to inspect delivery details',
                trailing: IconButton(
                  tooltip: 'Refresh',
                  onPressed: onRetry,
                  icon: const Icon(Icons.refresh_rounded),
                ),
              ),
            ),
            const Divider(),
            for (var index = 0; index < campaigns.length; index++) ...[
              _CampaignRow(
                campaign: campaigns[index],
                onCancel: () => onCancel(campaigns[index]),
                onOpen: () => onOpen(campaigns[index]),
              ),
              if (index < campaigns.length - 1) const Divider(),
            ],
          ],
        ),
      ),
    );
  }
}

class _CampaignRow extends StatelessWidget {
  const _CampaignRow({
    required this.campaign,
    required this.onCancel,
    required this.onOpen,
  });

  final MessagingCampaign campaign;
  final VoidCallback onCancel;
  final VoidCallback onOpen;

  @override
  Widget build(BuildContext context) => InkWell(
    onTap: onOpen,
    child: Padding(
      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 15),
      child: Row(
        children: [
          CircleAvatar(
            backgroundColor: _statusColor(
              campaign.status,
            ).withValues(alpha: .12),
            foregroundColor: _statusColor(campaign.status),
            child: Icon(_statusIcon(campaign.status)),
          ),
          const SizedBox(width: 14),
          Expanded(
            flex: 3,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  campaign.name,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(fontWeight: FontWeight.w900),
                ),
                const SizedBox(height: 3),
                Text(
                  campaign.title,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: Theme.of(context).textTheme.bodySmall?.copyWith(
                    color: Theme.of(context).colorScheme.onSurfaceVariant,
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(width: 16),
          if (MediaQuery.sizeOf(context).width >= 760) ...[
            Expanded(
              child: Text(
                campaign.audience.label,
                style: Theme.of(context).textTheme.bodySmall,
              ),
            ),
            Expanded(
              child: Text(
                _campaignTime(campaign),
                style: Theme.of(context).textTheme.bodySmall,
              ),
            ),
          ],
          StatusPill(
            _statusLabel(campaign.status),
            tone: _statusTone(campaign.status),
          ),
          if (campaign.status == CampaignStatus.scheduled) ...[
            const SizedBox(width: 8),
            IconButton(
              tooltip: 'Cancel schedule',
              onPressed: onCancel,
              icon: const Icon(Icons.cancel_schedule_send_outlined),
            ),
          ],
          const SizedBox(width: 8),
          const Icon(Icons.chevron_right_rounded, size: 20),
        ],
      ),
    ),
  );
}

class _CampaignDetailsDialog extends StatelessWidget {
  const _CampaignDetailsDialog({required this.campaign});

  final MessagingCampaign campaign;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Dialog(
      child: ConstrainedBox(
        constraints: BoxConstraints(
          maxWidth: 720,
          maxHeight: MediaQuery.sizeOf(context).height * .88,
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(24, 20, 14, 18),
              child: Row(
                children: [
                  CircleAvatar(
                    backgroundColor: _statusColor(
                      campaign.status,
                    ).withValues(alpha: .12),
                    foregroundColor: _statusColor(campaign.status),
                    child: Icon(_statusIcon(campaign.status)),
                  ),
                  const SizedBox(width: 14),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          campaign.name,
                          style: theme.textTheme.titleLarge?.copyWith(
                            fontWeight: FontWeight.w900,
                          ),
                        ),
                        const SizedBox(height: 3),
                        Text(
                          'Campaign details',
                          style: theme.textTheme.bodySmall?.copyWith(
                            color: theme.colorScheme.onSurfaceVariant,
                          ),
                        ),
                      ],
                    ),
                  ),
                  StatusPill(
                    _statusLabel(campaign.status),
                    tone: _statusTone(campaign.status),
                  ),
                  const SizedBox(width: 8),
                  IconButton(
                    tooltip: 'Close',
                    onPressed: () => Navigator.of(context).pop(),
                    icon: const Icon(Icons.close_rounded),
                  ),
                ],
              ),
            ),
            const Divider(height: 1),
            Flexible(
              child: SingleChildScrollView(
                padding: const EdgeInsets.all(24),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    Text(
                      'Notification content',
                      style: theme.textTheme.titleMedium?.copyWith(
                        fontWeight: FontWeight.w900,
                      ),
                    ),
                    const SizedBox(height: 12),
                    Container(
                      padding: const EdgeInsets.all(18),
                      decoration: BoxDecoration(
                        color: theme.colorScheme.surfaceContainerHighest,
                        borderRadius: BorderRadius.circular(16),
                        border: Border.all(color: theme.dividerColor),
                      ),
                      child: Row(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          const CircleAvatar(
                            backgroundColor: Color(0xFFE0E7FF),
                            foregroundColor: AppTheme.accent,
                            child: Icon(Icons.notifications_none_rounded),
                          ),
                          const SizedBox(width: 14),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                SelectableText(
                                  campaign.title,
                                  style: const TextStyle(
                                    fontWeight: FontWeight.w900,
                                    fontSize: 16,
                                  ),
                                ),
                                const SizedBox(height: 6),
                                SelectableText(
                                  campaign.body,
                                  style: theme.textTheme.bodyMedium,
                                ),
                              ],
                            ),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(height: 24),
                    Text(
                      'Delivery details',
                      style: theme.textTheme.titleMedium?.copyWith(
                        fontWeight: FontWeight.w900,
                      ),
                    ),
                    const SizedBox(height: 12),
                    Wrap(
                      spacing: 12,
                      runSpacing: 12,
                      children: [
                        _CampaignDetailItem(
                          label: 'Audience',
                          value: campaign.audience.label,
                        ),
                        _CampaignDetailItem(
                          label: 'Sound',
                          value: campaign.sound ? 'On' : 'Off',
                        ),
                        _CampaignDetailItem(
                          label: 'Time to live',
                          value: _formatTtl(campaign.ttlSeconds),
                        ),
                        _CampaignDetailItem(
                          label: 'Created',
                          value: _optionalTime(campaign.createdAt),
                        ),
                        if (campaign.scheduleAt != null)
                          _CampaignDetailItem(
                            label: 'Scheduled for',
                            value: _optionalTime(campaign.scheduleAt),
                          ),
                        if (campaign.sentAt != null)
                          _CampaignDetailItem(
                            label: 'Sent',
                            value: _optionalTime(campaign.sentAt),
                          ),
                        if (campaign.canceledAt != null)
                          _CampaignDetailItem(
                            label: 'Canceled',
                            value: _optionalTime(campaign.canceledAt),
                          ),
                        _CampaignDetailItem(
                          label: 'Created by',
                          value:
                              campaign.createdByEmail ??
                              campaign.createdByUid ??
                              'Not available',
                        ),
                      ],
                    ),
                    if (campaign.data.isNotEmpty) ...[
                      const SizedBox(height: 24),
                      Text(
                        'Custom data',
                        style: theme.textTheme.titleMedium?.copyWith(
                          fontWeight: FontWeight.w900,
                        ),
                      ),
                      const SizedBox(height: 12),
                      Container(
                        decoration: BoxDecoration(
                          border: Border.all(color: theme.dividerColor),
                          borderRadius: BorderRadius.circular(14),
                        ),
                        child: Column(
                          children: [
                            for (
                              var index = 0;
                              index < campaign.data.entries.length;
                              index++
                            ) ...[
                              Padding(
                                padding: const EdgeInsets.symmetric(
                                  horizontal: 16,
                                  vertical: 12,
                                ),
                                child: Row(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    SizedBox(
                                      width: 180,
                                      child: SelectableText(
                                        campaign.data.entries
                                            .elementAt(index)
                                            .key,
                                        style: const TextStyle(
                                          fontWeight: FontWeight.w800,
                                        ),
                                      ),
                                    ),
                                    Expanded(
                                      child: SelectableText(
                                        campaign.data.entries
                                            .elementAt(index)
                                            .value,
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                              if (index < campaign.data.length - 1)
                                const Divider(height: 1),
                            ],
                          ],
                        ),
                      ),
                    ],
                    if (campaign.messageId != null ||
                        campaign.errorCode != null) ...[
                      const SizedBox(height: 24),
                      Text(
                        'Result',
                        style: theme.textTheme.titleMedium?.copyWith(
                          fontWeight: FontWeight.w900,
                        ),
                      ),
                      const SizedBox(height: 12),
                      if (campaign.messageId != null)
                        _CampaignResultValue(
                          label: 'Firebase message ID',
                          value: campaign.messageId!,
                        ),
                      if (campaign.errorCode != null)
                        _CampaignResultValue(
                          label: 'Error code',
                          value: campaign.errorCode!,
                          danger: true,
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

class _CampaignDetailItem extends StatelessWidget {
  const _CampaignDetailItem({required this.label, required this.value});

  final String label;
  final String value;

  @override
  Widget build(BuildContext context) => Container(
    width: 205,
    padding: const EdgeInsets.all(14),
    decoration: BoxDecoration(
      border: Border.all(color: Theme.of(context).dividerColor),
      borderRadius: BorderRadius.circular(14),
    ),
    child: Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          label,
          style: Theme.of(context).textTheme.bodySmall?.copyWith(
            color: Theme.of(context).colorScheme.onSurfaceVariant,
          ),
        ),
        const SizedBox(height: 5),
        SelectableText(
          value,
          style: const TextStyle(fontWeight: FontWeight.w800),
        ),
      ],
    ),
  );
}

class _CampaignResultValue extends StatelessWidget {
  const _CampaignResultValue({
    required this.label,
    required this.value,
    this.danger = false,
  });

  final String label;
  final String value;
  final bool danger;

  @override
  Widget build(BuildContext context) => Padding(
    padding: const EdgeInsets.only(bottom: 10),
    child: Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(label, style: Theme.of(context).textTheme.bodySmall),
        const SizedBox(height: 4),
        SelectableText(
          value,
          style: TextStyle(
            fontFamily: 'monospace',
            color: danger ? AppTheme.danger : null,
          ),
        ),
      ],
    ),
  );
}

class _NotificationPreview extends StatelessWidget {
  const _NotificationPreview({
    required this.title,
    required this.body,
    required this.audience,
  });

  final TextEditingController title;
  final TextEditingController body;
  final CampaignAudience audience;

  @override
  Widget build(BuildContext context) => Column(
    crossAxisAlignment: CrossAxisAlignment.stretch,
    children: [
      SectionCard(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            const SectionTitle(
              title: 'Notification preview',
              description:
                  'Preview how the notification will appear on a device.',
              trailing: Icon(Icons.phone_android_rounded),
            ),
            const SizedBox(height: 20),
            Container(
              constraints: const BoxConstraints(minHeight: 230),
              padding: const EdgeInsets.all(18),
              decoration: BoxDecoration(
                gradient: const LinearGradient(
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                  colors: [Color(0xFF1E293B), Color(0xFF334155)],
                ),
                borderRadius: BorderRadius.circular(24),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  Text(
                    'JOURNAL TREND ANALYZER · NOW',
                    style: TextStyle(
                      color: Colors.white.withValues(alpha: .72),
                      fontSize: 10,
                      fontWeight: FontWeight.w800,
                    ),
                  ),
                  const SizedBox(height: 34),
                  DecoratedBox(
                    decoration: BoxDecoration(
                      color: Colors.white,
                      borderRadius: BorderRadius.circular(16),
                    ),
                    child: Padding(
                      padding: const EdgeInsets.all(14),
                      child: AnimatedBuilder(
                        animation: Listenable.merge([title, body]),
                        builder: (context, _) => Row(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            const CircleAvatar(
                              backgroundColor: Color(0xFFE0E7FF),
                              foregroundColor: AppTheme.accent,
                              child: Icon(Icons.auto_stories_rounded),
                            ),
                            const SizedBox(width: 11),
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(
                                    title.text.trim().isEmpty
                                        ? 'Notification title'
                                        : title.text.trim(),
                                    style: const TextStyle(
                                      color: Color(0xFF111827),
                                      fontWeight: FontWeight.w900,
                                    ),
                                  ),
                                  const SizedBox(height: 4),
                                  Text(
                                    body.text.trim().isEmpty
                                        ? 'Notification body will appear here.'
                                        : body.text.trim(),
                                    style: const TextStyle(
                                      color: Color(0xFF475569),
                                      fontSize: 12,
                                      height: 1.35,
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
      const SizedBox(height: 16),
      SectionCard(
        child: Row(
          children: [
            const Icon(Icons.groups_2_outlined, color: AppTheme.accent),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text(
                    'Current audience',
                    style: TextStyle(fontWeight: FontWeight.w900),
                  ),
                  const SizedBox(height: 3),
                  Text(audience.label),
                ],
              ),
            ),
          ],
        ),
      ),
    ],
  );
}

class _PayloadMeter extends StatelessWidget {
  const _PayloadMeter({required this.bytes});

  final int bytes;

  @override
  Widget build(BuildContext context) {
    final invalid = bytes > _CampaignComposerState._maxPayloadBytes;
    final color = invalid ? AppTheme.danger : AppTheme.success;
    return Row(
      children: [
        Expanded(
          child: LinearProgressIndicator(
            value: (bytes / _CampaignComposerState._maxPayloadBytes).clamp(
              0.0,
              1.0,
            ),
            color: color,
            minHeight: 6,
            borderRadius: BorderRadius.circular(99),
          ),
        ),
        const SizedBox(width: 12),
        Text(
          '$bytes / ${_CampaignComposerState._maxPayloadBytes} byte',
          style: TextStyle(
            color: color,
            fontSize: 12,
            fontWeight: FontWeight.w800,
          ),
        ),
      ],
    );
  }
}

String _formatLocal(DateTime value) {
  final local = value.toLocal();
  String two(int number) => number.toString().padLeft(2, '0');
  return '${two(local.hour)}:${two(local.minute)} · '
      '${two(local.day)}/${two(local.month)}/${local.year}';
}

String _campaignTime(MessagingCampaign campaign) {
  final value = campaign.sentAt ?? campaign.scheduleAt ?? campaign.createdAt;
  return value == null ? '—' : _formatLocal(value);
}

String _optionalTime(DateTime? value) =>
    value == null ? 'Not available' : _formatLocal(value);

String _formatTtl(int seconds) {
  if (seconds % 86400 == 0) {
    final days = seconds ~/ 86400;
    return '$days ${days == 1 ? 'day' : 'days'}';
  }
  if (seconds % 3600 == 0) {
    final hours = seconds ~/ 3600;
    return '$hours ${hours == 1 ? 'hour' : 'hours'}';
  }
  if (seconds % 60 == 0) {
    final minutes = seconds ~/ 60;
    return '$minutes ${minutes == 1 ? 'minute' : 'minutes'}';
  }
  return '$seconds ${seconds == 1 ? 'second' : 'seconds'}';
}

String _statusLabel(CampaignStatus status) => switch (status) {
  CampaignStatus.scheduled => 'Scheduled',
  CampaignStatus.sending => 'Sending',
  CampaignStatus.sent => 'Sent',
  CampaignStatus.failed => 'Failed',
  CampaignStatus.canceled => 'Canceled',
};

StatusTone _statusTone(CampaignStatus status) => switch (status) {
  CampaignStatus.scheduled => StatusTone.info,
  CampaignStatus.sending => StatusTone.warning,
  CampaignStatus.sent => StatusTone.success,
  CampaignStatus.failed => StatusTone.danger,
  CampaignStatus.canceled => StatusTone.neutral,
};

Color _statusColor(CampaignStatus status) => switch (status) {
  CampaignStatus.scheduled => AppTheme.accent,
  CampaignStatus.sending => AppTheme.warning,
  CampaignStatus.sent => AppTheme.success,
  CampaignStatus.failed => AppTheme.danger,
  CampaignStatus.canceled => const Color(0xFF64748B),
};

IconData _statusIcon(CampaignStatus status) => switch (status) {
  CampaignStatus.scheduled => Icons.schedule_send_rounded,
  CampaignStatus.sending => Icons.outgoing_mail,
  CampaignStatus.sent => Icons.check_rounded,
  CampaignStatus.failed => Icons.error_outline_rounded,
  CampaignStatus.canceled => Icons.cancel_outlined,
};
