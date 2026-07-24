import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:journal_trend_admin_web/core/core.dart';

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
          ? 'Đã lên lịch chiến dịch.'
          : 'Firebase đã nhận chiến dịch.',
    );
  }

  Future<void> _cancel(MessagingCampaign campaign) async {
    final confirmed = await showTypedConfirmation(
      context: context,
      title: 'Hủy chiến dịch đã lên lịch?',
      description:
          'Chiến dịch “${campaign.name}” sẽ không được gửi. Thao tác này không thể hoàn tác.',
      confirmationText: 'HUY LICH',
      actionLabel: 'Hủy chiến dịch',
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
      showAppMessage(context, 'Đã hủy chiến dịch.');
    } catch (error) {
      if (mounted) showAppMessage(context, errorText(error), error: true);
    }
  }

  @override
  Widget build(BuildContext context) => PageBody(
    children: [
      PageHeading(
        eyebrow: 'Firebase Cloud Messaging',
        title: _showComposer ? 'Tạo chiến dịch' : 'Chiến dịch thông báo',
        description: _showComposer
            ? 'Soạn nội dung, chọn đối tượng và thời điểm phân phối.'
            : 'Tạo, lên lịch và theo dõi các chiến dịch gửi qua FCM.',
        actions: [
          if (_showComposer)
            OutlinedButton.icon(
              onPressed: () => setState(() => _showComposer = false),
              icon: const Icon(Icons.arrow_back_rounded),
              label: const Text('Danh sách chiến dịch'),
            )
          else
            FilledButton.icon(
              onPressed: () => setState(() => _showComposer = true),
              icon: const Icon(Icons.add_rounded),
              label: const Text('Chiến dịch mới'),
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
        throw FormatException('Dòng ${index + 1} phải có định dạng key=value.');
      }
      final key = line.substring(0, separator).trim();
      final value = line.substring(separator + 1).trim();
      if (key.isEmpty || key.length > 128) {
        throw FormatException('Key ở dòng ${index + 1} không hợp lệ.');
      }
      if (value.length > 2048) {
        throw FormatException('Value của “$key” vượt quá 2048 ký tự.');
      }
      if (_reservedKeys.contains(key) ||
          _reservedPrefixes.any(key.startsWith)) {
        throw FormatException('Key “$key” được FCM dành riêng.');
      }
      if (result.containsKey(key)) {
        throw FormatException('Key “$key” bị lặp lại.');
      }
      result[key] = value;
    }
    if (result.length > 50) {
      throw const FormatException('Custom data chỉ được có tối đa 50 dòng.');
    }
    return result;
  }

  String? _required(String? value, String label, int maxLength) {
    final text = value?.trim() ?? '';
    if (text.isEmpty) return '$label không được để trống.';
    if (text.length > maxLength) {
      return '$label không được vượt quá $maxLength ký tự.';
    }
    return null;
  }

  String? _validateData(String? value) {
    try {
      _parseData(value ?? '');
      if (_payloadBytes > _maxPayloadBytes) {
        return 'Payload vượt quá 4096 byte UTF-8.';
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
        'Thời gian gửi phải sau hiện tại ít nhất 1 phút.',
        error: true,
      );
      return;
    }
    final data = _parseData(_data.text);
    final confirmed = await showTypedConfirmation(
      context: context,
      title: _sendNow ? 'Gửi chiến dịch ngay?' : 'Lên lịch chiến dịch?',
      description: _sendNow
          ? 'Thông báo sẽ được phát tới ${_audience.label}. Fanout đang chạy không thể hủy.'
          : 'Thông báo sẽ được gửi tới ${_audience.label} lúc ${_formatLocal(_scheduleAt!)} và có thể hủy trước khi bắt đầu.',
      confirmationText: _sendNow ? 'GUI NGAY' : 'LEN LICH',
      actionLabel: _sendNow ? 'Gửi chiến dịch' : 'Lên lịch',
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
    final titleError = _required(_title.text, 'Tiêu đề', 100);
    final bodyError = _required(_body.text, 'Nội dung', 500);
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
        title: const Text('Gửi thông báo thử'),
        content: SizedBox(
          width: 520,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              const Text(
                'Nhập FCM registration token hoặc Firebase Installation ID. '
                'Thao tác này không tạo chiến dịch.',
              ),
              const SizedBox(height: 16),
              TextField(
                controller: controller,
                minLines: 2,
                maxLines: 4,
                autofocus: true,
                style: const TextStyle(fontFamily: 'monospace', fontSize: 13),
                decoration: const InputDecoration(
                  labelText: 'Token hoặc Installation ID',
                  alignLabelWithHint: true,
                ),
              ),
            ],
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(dialogContext),
            child: const Text('Đóng'),
          ),
          FilledButton.icon(
            onPressed: () {
              final value = controller.text.trim();
              if (value.length >= 20 && value.length <= 4096) {
                Navigator.pop(dialogContext, value);
              }
            },
            icon: const Icon(Icons.send_rounded),
            label: const Text('Gửi thử'),
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
      if (mounted) showAppMessage(context, 'Đã gửi thông báo thử.');
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
              title: 'Nội dung thông báo',
              subtitle: 'Nội dung người dùng sẽ nhìn thấy trên thiết bị.',
              child: Column(
                children: [
                  TextFormField(
                    controller: _name,
                    enabled: !_sending,
                    maxLength: 120,
                    validator: (value) =>
                        _required(value, 'Tên chiến dịch', 120),
                    decoration: const InputDecoration(
                      labelText: 'Tên chiến dịch',
                      hintText: 'Ví dụ: Ra mắt tính năng báo cáo tháng 7',
                      prefixIcon: Icon(Icons.campaign_outlined),
                    ),
                  ),
                  const SizedBox(height: 12),
                  TextFormField(
                    controller: _title,
                    enabled: !_sending,
                    maxLength: 100,
                    validator: (value) => _required(value, 'Tiêu đề', 100),
                    decoration: const InputDecoration(
                      labelText: 'Tiêu đề thông báo',
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
                    validator: (value) => _required(value, 'Nội dung', 500),
                    decoration: const InputDecoration(
                      labelText: 'Nội dung thông báo',
                      alignLabelWithHint: true,
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 18),
            _ComposerSection(
              number: 2,
              title: 'Đối tượng',
              subtitle:
                  'Các thiết bị tự tham gia audience khi khởi động ứng dụng.',
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
              title: 'Lịch gửi',
              subtitle: 'Gửi ngay hoặc chọn thời điểm trong vòng một năm.',
              child: Column(
                children: [
                  SegmentedButton<bool>(
                    segments: const [
                      ButtonSegment(
                        value: true,
                        icon: Icon(Icons.send_rounded),
                        label: Text('Gửi ngay'),
                      ),
                      ButtonSegment(
                        value: false,
                        icon: Icon(Icons.schedule_rounded),
                        label: Text('Lên lịch'),
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
                            ? 'Chưa chọn thời gian'
                            : _formatLocal(_scheduleAt!),
                      ),
                      subtitle: const Text('Múi giờ thiết bị quản trị'),
                      trailing: OutlinedButton(
                        onPressed: _sending ? null : _pickSchedule,
                        child: const Text('Chọn'),
                      ),
                    ),
                  ],
                ],
              ),
            ),
            const SizedBox(height: 18),
            _ComposerSection(
              number: 4,
              title: 'Tùy chọn bổ sung',
              subtitle: 'Cấu hình thời hạn, âm thanh và dữ liệu cho ứng dụng.',
              child: Column(
                children: [
                  DropdownButtonFormField<int>(
                    initialValue: _ttlSeconds,
                    decoration: const InputDecoration(
                      labelText: 'Hết hạn nếu thiết bị offline',
                      prefixIcon: Icon(Icons.timer_outlined),
                    ),
                    items: const [
                      DropdownMenuItem(value: 3600, child: Text('1 giờ')),
                      DropdownMenuItem(value: 21600, child: Text('6 giờ')),
                      DropdownMenuItem(value: 86400, child: Text('1 ngày')),
                      DropdownMenuItem(value: 604800, child: Text('7 ngày')),
                      DropdownMenuItem(value: 2419200, child: Text('28 ngày')),
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
                    title: const Text('Âm thanh mặc định'),
                    subtitle: const Text(
                      'Phát âm thanh khi hệ điều hành hiển thị notification.',
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
                      helperText: 'Mỗi dòng theo định dạng key=value.',
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
            Row(
              mainAxisAlignment: MainAxisAlignment.end,
              children: [
                OutlinedButton.icon(
                  onPressed: _sending ? null : _sendTest,
                  icon: const Icon(Icons.science_outlined),
                  label: const Text('Gửi thông báo thử'),
                ),
                const SizedBox(width: 12),
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
                        ? 'Đang xử lý…'
                        : _sendNow
                        ? 'Xem lại và gửi'
                        : 'Xem lại và lên lịch',
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
          children: [preview, const SizedBox(height: 18), form],
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
  });

  final List<MessagingCampaign> campaigns;
  final bool loading;
  final Object? error;
  final VoidCallback onRetry;
  final VoidCallback onCreate;
  final ValueChanged<MessagingCampaign> onCancel;

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
                'Chưa có chiến dịch',
                style: Theme.of(
                  context,
                ).textTheme.titleLarge?.copyWith(fontWeight: FontWeight.w900),
              ),
              const SizedBox(height: 7),
              Text(
                'Tạo chiến dịch đầu tiên để gửi hoặc lên lịch notification.',
                style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                  color: Theme.of(context).colorScheme.onSurfaceVariant,
                ),
              ),
              const SizedBox(height: 18),
              FilledButton.icon(
                onPressed: onCreate,
                icon: const Icon(Icons.add_rounded),
                label: const Text('Tạo chiến dịch'),
              ),
            ],
          ),
        ),
      );
    }

    return SectionCard(
      padding: EdgeInsets.zero,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Padding(
            padding: const EdgeInsets.all(20),
            child: SectionTitle(
              title: 'Tất cả chiến dịch',
              description:
                  '${campaigns.length} chiến dịch gần nhất · tự động làm mới khi tải lại trang',
              trailing: IconButton(
                tooltip: 'Tải lại',
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
            ),
            if (index < campaigns.length - 1) const Divider(),
          ],
        ],
      ),
    );
  }
}

class _CampaignRow extends StatelessWidget {
  const _CampaignRow({required this.campaign, required this.onCancel});

  final MessagingCampaign campaign;
  final VoidCallback onCancel;

  @override
  Widget build(BuildContext context) => Padding(
    padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 15),
    child: Row(
      children: [
        CircleAvatar(
          backgroundColor: _statusColor(campaign.status).withValues(alpha: .12),
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
            tooltip: 'Hủy lịch',
            onPressed: onCancel,
            icon: const Icon(Icons.cancel_schedule_send_outlined),
          ),
        ],
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
              title: 'Xem trước',
              description: 'Mô phỏng notification trên thiết bị.',
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
                    'JOURNAL TREND ANALYZER · BÂY GIỜ',
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
                                        ? 'Tiêu đề thông báo'
                                        : title.text.trim(),
                                    style: const TextStyle(
                                      color: Color(0xFF111827),
                                      fontWeight: FontWeight.w900,
                                    ),
                                  ),
                                  const SizedBox(height: 4),
                                  Text(
                                    body.text.trim().isEmpty
                                        ? 'Nội dung thông báo sẽ hiển thị tại đây.'
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
                    'Đối tượng hiện tại',
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

String _statusLabel(CampaignStatus status) => switch (status) {
  CampaignStatus.scheduled => 'Đã lên lịch',
  CampaignStatus.sending => 'Đang gửi',
  CampaignStatus.sent => 'Đã gửi',
  CampaignStatus.failed => 'Thất bại',
  CampaignStatus.canceled => 'Đã hủy',
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
