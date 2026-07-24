import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:journal_trend_admin_web/core/core.dart';

import '../utils/ui_format.dart';
import '../widgets/admin_widgets.dart';

class RemoteConfigPage extends StatefulWidget {
  const RemoteConfigPage({required this.api, super.key});

  final AdminApi api;

  @override
  State<RemoteConfigPage> createState() => _RemoteConfigPageState();
}

class _RemoteConfigPageState extends State<RemoteConfigPage> {
  final _formKey = GlobalKey<FormState>();
  final _maxJournalsController = TextEditingController();
  final _maxKeywordsController = TextEditingController();
  final _descriptionController = TextEditingController();

  RemoteConfigData? _config;
  List<RemoteConfigVersion> _versions = const [];
  Object? _loadError;
  Object? _historyError;
  bool _loading = true;
  bool _refreshing = false;
  bool _mutating = false;

  @override
  void initState() {
    super.initState();
    _load(initial: true);
  }

  @override
  void dispose() {
    _maxJournalsController.dispose();
    _maxKeywordsController.dispose();
    _descriptionController.dispose();
    super.dispose();
  }

  Future<void> _load({bool initial = false, bool preserveDraft = false}) async {
    final draftJournals = _maxJournalsController.text;
    final draftKeywords = _maxKeywordsController.text;
    final draftDescription = _descriptionController.text;
    if (!initial) {
      setState(() => _refreshing = true);
    }

    final configFuture = _capture(widget.api.getRemoteConfig());
    final versionsFuture = _capture(
      widget.api.listRemoteConfigVersions(limit: 20),
    );
    final configResult = await configFuture;
    final versionsResult = await versionsFuture;
    if (!mounted) return;

    if (configResult.error != null || configResult.data == null) {
      setState(() {
        _loadError =
            configResult.error ??
            Exception('Dữ liệu Remote Config không hợp lệ.');
        _loading = false;
        _refreshing = false;
      });
      return;
    }

    final config = configResult.data!;
    _maxJournalsController.text = preserveDraft
        ? draftJournals
        : config.parameters.maxJournals?.toString() ?? '';
    _maxKeywordsController.text = preserveDraft
        ? draftKeywords
        : config.parameters.maxKeywords?.toString() ?? '';
    _descriptionController.text = preserveDraft ? draftDescription : '';
    setState(() {
      _config = config;
      _versions = versionsResult.data?.versions ?? const [];
      _historyError = versionsResult.error;
      _loadError = null;
      _loading = false;
      _refreshing = false;
    });
  }

  int? _parseLimit(TextEditingController controller) =>
      int.tryParse(controller.text.trim());

  String? _validateLimit(String? raw) {
    if (raw == null || raw.trim().isEmpty) {
      return 'Vui lòng nhập một số nguyên từ 1 đến 100.';
    }
    final value = int.tryParse(raw.trim());
    if (value == null || value < 1 || value > 100) {
      return 'Giá trị hợp lệ là số nguyên từ 1 đến 100.';
    }
    return null;
  }

  String? _validateDescription(String? raw) {
    if (!_hasChanges) return null;
    final length = raw?.trim().length ?? 0;
    if (length < 1) return 'Vui lòng nhập ghi chú thay đổi.';
    if (length > 300) return 'Ghi chú không được vượt quá 300 ký tự.';
    return null;
  }

  bool get _hasChanges {
    final config = _config;
    if (config == null) return false;
    return _parseLimit(_maxJournalsController) !=
            config.parameters.maxJournals ||
        _parseLimit(_maxKeywordsController) != config.parameters.maxKeywords;
  }

  bool get _canPublish {
    final description = _descriptionController.text.trim();
    return !_mutating &&
        _hasChanges &&
        _validateLimit(_maxJournalsController.text) == null &&
        _validateLimit(_maxKeywordsController.text) == null &&
        _validateDescription(description) == null;
  }

  Future<void> _publish() async {
    final config = _config;
    if (config == null || _mutating) return;
    if (!(_formKey.currentState?.validate() ?? false)) return;
    if (!_hasChanges) {
      showAppMessage(
        context,
        'Chưa có giá trị cấu hình nào thay đổi.',
        error: true,
      );
      return;
    }

    final confirmed = await _confirmPublish(config);
    if (!confirmed || !mounted) return;

    setState(() => _mutating = true);
    try {
      await widget.api.updateRemoteConfig(
        RemoteConfigUpdate(
          maxJournals: _parseLimit(_maxJournalsController)!,
          maxKeywords: _parseLimit(_maxKeywordsController)!,
          expectedEtag: config.etag,
          description: _descriptionController.text.trim(),
        ),
      );
      if (!mounted) return;
      showAppMessage(context, 'Đã xuất bản Remote Config thành công.');
      await _load();
    } catch (error) {
      await _handleMutationError(error, action: 'xuất bản');
    } finally {
      if (mounted) setState(() => _mutating = false);
    }
  }

  Future<bool> _confirmPublish(RemoteConfigData config) async {
    final maxJournals = _parseLimit(_maxJournalsController)!;
    final maxKeywords = _parseLimit(_maxKeywordsController)!;
    final description = _descriptionController.text.trim();
    final result = await showDialog<bool>(
      context: context,
      barrierDismissible: false,
      builder: (dialogContext) => AlertDialog(
        scrollable: true,
        title: const Text('Xác nhận xuất bản cấu hình'),
        content: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 520),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              const Text(
                'Cấu hình mới sẽ được gửi tới ứng dụng ở lần fetch tiếp theo.',
              ),
              const SizedBox(height: 18),
              if (maxJournals != config.parameters.maxJournals)
                _PublishChangeRow(
                  name: 'max_journals',
                  before: config.parameters.maxJournals,
                  after: maxJournals,
                ),
              if (maxKeywords != config.parameters.maxKeywords)
                _PublishChangeRow(
                  name: 'max_keywords',
                  before: config.parameters.maxKeywords,
                  after: maxKeywords,
                ),
              const SizedBox(height: 8),
              Text(
                'Ghi chú',
                style: Theme.of(dialogContext).textTheme.labelLarge,
              ),
              const SizedBox(height: 6),
              Text(description),
              const SizedBox(height: 16),
              Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Icon(
                    Icons.verified_user_outlined,
                    size: 18,
                    color: Theme.of(dialogContext).colorScheme.primary,
                  ),
                  const SizedBox(width: 8),
                  const Expanded(
                    child: Text(
                      'Hệ thống sẽ kiểm tra xung đột để không ghi đè cấu hình mới hơn.',
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(dialogContext, false),
            child: const Text('Hủy'),
          ),
          FilledButton.icon(
            key: const Key('confirm_remote_config_publish'),
            onPressed: () => Navigator.pop(dialogContext, true),
            icon: const Icon(Icons.publish_rounded),
            label: const Text('Xác nhận xuất bản'),
          ),
        ],
      ),
    );
    return result ?? false;
  }

  Future<void> _rollback(RemoteConfigVersion version) async {
    final config = _config;
    final versionNumber = version.versionNumber;
    if (config == null || versionNumber == null || _mutating) return;

    RemoteConfigData target;
    setState(() => _mutating = true);
    try {
      target = await widget.api.getRemoteConfigVersion(versionNumber);
    } catch (error) {
      if (mounted) showAppMessage(context, errorText(error), error: true);
      if (mounted) setState(() => _mutating = false);
      return;
    }
    if (!mounted) return;
    setState(() => _mutating = false);

    final confirmed = await showTypedConfirmation(
      context: context,
      title: 'Khôi phục phiên bản $versionNumber?',
      description:
          'Xem trước: max_journals = ${target.parameters.maxJournals ?? 'chưa cấu hình'}, '
          'max_keywords = ${target.parameters.maxKeywords ?? 'chưa cấu hình'}.\n\n'
          'Nội dung của phiên bản này sẽ được xuất bản thành một phiên bản mới. '
          'Cấu hình đang hoạt động sẽ bị thay thế.',
      confirmationText: 'v$versionNumber',
      actionLabel: 'Khôi phục',
      danger: true,
    );
    if (!confirmed || !mounted) return;

    setState(() => _mutating = true);
    try {
      await widget.api.rollbackRemoteConfig(
        versionNumber: versionNumber,
        expectedEtag: config.etag,
      );
      if (!mounted) return;
      showAppMessage(
        context,
        'Đã khôi phục Remote Config về phiên bản $versionNumber.',
      );
      await _load();
    } catch (error) {
      await _handleMutationError(error, action: 'khôi phục');
    } finally {
      if (mounted) setState(() => _mutating = false);
    }
  }

  Future<void> _handleMutationError(
    Object error, {
    required String action,
  }) async {
    if (error is ApiException && error.isConflict) {
      await _load(preserveDraft: true);
      if (!mounted) return;
      showAppMessage(
        context,
        'Cấu hình vừa được thay đổi ở nơi khác. Dữ liệu mới đã được tải lại; '
        'hãy kiểm tra rồi xác nhận $action lần nữa.',
        error: true,
      );
      return;
    }
    if (mounted) showAppMessage(context, errorText(error), error: true);
  }

  @override
  Widget build(BuildContext context) => PageBody(
    children: [
      PageHeading(
        eyebrow: 'Firebase Remote Config',
        title: 'Cấu hình ứng dụng',
        description:
            'Quản lý giới hạn hiển thị, kiểm tra thay đổi và khôi phục an toàn '
            'mà không cần thao tác trực tiếp trên Firebase Console.',
        actions: [
          if (_config case final config?)
            StatusPill(
              config.version.versionNumber == null
                  ? 'Chưa có phiên bản'
                  : 'Phiên bản v${config.version.versionNumber}',
              tone: StatusTone.success,
              icon: Icons.cloud_done_outlined,
            ),
          OutlinedButton.icon(
            onPressed: _refreshing || _mutating ? null : _load,
            icon: _refreshing
                ? const SizedBox.square(
                    dimension: 17,
                    child: CircularProgressIndicator(strokeWidth: 2),
                  )
                : const Icon(Icons.refresh_rounded),
            label: const Text('Làm mới'),
          ),
        ],
      ),
      if (_loading)
        const SectionCard(child: LoadingPanel(label: 'Đang tải Remote Config…'))
      else if (_loadError != null)
        SectionCard(
          child: ErrorPanel(message: errorText(_loadError!), onRetry: _load),
        )
      else
        ..._buildContent(_config!),
    ],
  );

  List<Widget> _buildContent(RemoteConfigData config) => [
    LayoutBuilder(
      builder: (context, constraints) {
        final editor = _ConfigEditor(
          formKey: _formKey,
          maxJournalsController: _maxJournalsController,
          maxKeywordsController: _maxKeywordsController,
          descriptionController: _descriptionController,
          validateLimit: _validateLimit,
          validateDescription: _validateDescription,
          busy: _mutating,
          canPublish: _canPublish,
          updatedAt: config.version.updatedAt,
          onChanged: () => setState(() {}),
          onPublish: _publish,
        );
        final diff = _DiffCard(
          config: config,
          maxJournals: _parseLimit(_maxJournalsController),
          maxKeywords: _parseLimit(_maxKeywordsController),
          hasChanges: _hasChanges,
        );
        if (constraints.maxWidth < 920) {
          return Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [editor, const SizedBox(height: 22), diff],
          );
        }
        return Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Expanded(flex: 3, child: editor),
            const SizedBox(width: 22),
            Expanded(flex: 2, child: diff),
          ],
        );
      },
    ),
    SectionCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          const SectionTitle(
            title: 'Tham số hiện có trên Firebase',
            description:
                'Khu vực chỉ đọc. Các key không xuất hiện trong biểu mẫu vẫn được giữ nguyên khi xuất bản.',
            trailing: Icon(Icons.data_object_rounded),
          ),
          const SizedBox(height: 18),
          if (config.allParameters.isEmpty)
            AdaptiveGrid(
              minItemWidth: 280,
              children: [
                _ParameterTile(
                  keyName: 'max_journals',
                  value: config.parameters.maxJournals?.toString(),
                  description: 'Số journal tối đa trong bảng xếp hạng.',
                  valueType: 'NUMBER',
                ),
                _ParameterTile(
                  keyName: 'max_keywords',
                  value: config.parameters.maxKeywords?.toString(),
                  description: 'Số keyword tối đa trong bảng xu hướng.',
                  valueType: 'NUMBER',
                ),
              ],
            )
          else
            AdaptiveGrid(
              minItemWidth: 280,
              children: [
                for (final parameter in config.allParameters)
                  _ParameterTile(
                    keyName: parameter.key,
                    value: parameter.value,
                    description: parameter.description,
                    valueType: parameter.valueType,
                    group: parameter.group,
                  ),
              ],
            ),
        ],
      ),
    ),
    SectionCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          SectionTitle(
            title: 'Lịch sử phiên bản',
            description:
                '20 phiên bản gần nhất. Khôi phục sẽ tạo một phiên bản mới từ '
                'nội dung đã chọn.',
            trailing: IconButton(
              tooltip: 'Tải lại lịch sử',
              onPressed: _refreshing || _mutating ? null : _load,
              icon: const Icon(Icons.history_rounded),
            ),
          ),
          const SizedBox(height: 14),
          if (_historyError != null)
            ErrorPanel(message: errorText(_historyError!), onRetry: _load)
          else if (_versions.isEmpty)
            const EmptyPanel(
              title: 'Chưa có lịch sử phiên bản',
              description:
                  'Các lần xuất bản Remote Config sẽ xuất hiện tại đây.',
              icon: Icons.history_toggle_off_rounded,
            )
          else
            for (var index = 0; index < _versions.length; index++) ...[
              _VersionTile(
                version: _versions[index],
                isCurrent:
                    _versions[index].versionNumber ==
                    config.version.versionNumber,
                busy: _mutating,
                onRollback: () => _rollback(_versions[index]),
              ),
              if (index != _versions.length - 1) const Divider(height: 1),
            ],
        ],
      ),
    ),
  ];
}

class _ConfigEditor extends StatelessWidget {
  const _ConfigEditor({
    required this.formKey,
    required this.maxJournalsController,
    required this.maxKeywordsController,
    required this.descriptionController,
    required this.validateLimit,
    required this.validateDescription,
    required this.busy,
    required this.canPublish,
    required this.updatedAt,
    required this.onChanged,
    required this.onPublish,
  });

  final GlobalKey<FormState> formKey;
  final TextEditingController maxJournalsController;
  final TextEditingController maxKeywordsController;
  final TextEditingController descriptionController;
  final FormFieldValidator<String> validateLimit;
  final FormFieldValidator<String> validateDescription;
  final bool busy;
  final bool canPublish;
  final String? updatedAt;
  final VoidCallback onChanged;
  final VoidCallback onPublish;

  @override
  Widget build(BuildContext context) => SectionCard(
    child: Form(
      key: formKey,
      autovalidateMode: AutovalidateMode.onUserInteraction,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          SectionTitle(
            title: 'Tham số đang hoạt động',
            description: 'Cập nhật gần nhất ${formatDateTime(updatedAt)}',
            trailing: const Icon(Icons.tune_rounded),
          ),
          const SizedBox(height: 22),
          _LimitField(
            controller: maxJournalsController,
            label: 'max_journals',
            helper: 'Số journal tối đa trong bảng xếp hạng.',
            validator: validateLimit,
            enabled: !busy,
            onChanged: onChanged,
          ),
          const SizedBox(height: 18),
          _LimitField(
            controller: maxKeywordsController,
            label: 'max_keywords',
            helper: 'Số keyword tối đa trong bảng xu hướng.',
            validator: validateLimit,
            enabled: !busy,
            onChanged: onChanged,
          ),
          const SizedBox(height: 18),
          TextFormField(
            controller: descriptionController,
            enabled: !busy,
            validator: validateDescription,
            maxLength: 300,
            maxLines: 3,
            minLines: 3,
            onChanged: (_) => onChanged(),
            decoration: const InputDecoration(
              labelText: 'Ghi chú thay đổi',
              alignLabelWithHint: true,
              hintText: 'Ví dụ: Tăng giới hạn keyword cho bản demo…',
              helperText:
                  'Nội dung này sẽ được lưu cùng phiên bản Remote Config.',
            ),
          ),
          const SizedBox(height: 8),
          Row(
            children: [
              Expanded(
                child: Text(
                  'Ứng dụng nhận cấu hình ở lần fetch tiếp theo.',
                  style: Theme.of(context).textTheme.bodySmall?.copyWith(
                    color: Theme.of(context).colorScheme.onSurfaceVariant,
                  ),
                ),
              ),
              const SizedBox(width: 12),
              FilledButton.icon(
                onPressed: canPublish ? onPublish : null,
                icon: busy
                    ? const SizedBox.square(
                        dimension: 17,
                        child: CircularProgressIndicator(strokeWidth: 2),
                      )
                    : const Icon(Icons.publish_rounded),
                label: const Text('Xuất bản'),
              ),
            ],
          ),
        ],
      ),
    ),
  );
}

class _LimitField extends StatelessWidget {
  const _LimitField({
    required this.controller,
    required this.label,
    required this.helper,
    required this.validator,
    required this.enabled,
    required this.onChanged,
  });

  final TextEditingController controller;
  final String label;
  final String helper;
  final FormFieldValidator<String> validator;
  final bool enabled;
  final VoidCallback onChanged;

  @override
  Widget build(BuildContext context) => TextFormField(
    controller: controller,
    enabled: enabled,
    validator: validator,
    keyboardType: TextInputType.number,
    inputFormatters: [FilteringTextInputFormatter.digitsOnly],
    onChanged: (_) => onChanged(),
    decoration: InputDecoration(
      labelText: label,
      helperText: '$helper Giá trị hợp lệ từ 1 đến 100.',
      suffixText: 'mục',
    ),
  );
}

class _DiffCard extends StatelessWidget {
  const _DiffCard({
    required this.config,
    required this.maxJournals,
    required this.maxKeywords,
    required this.hasChanges,
  });

  final RemoteConfigData config;
  final int? maxJournals;
  final int? maxKeywords;
  final bool hasChanges;

  @override
  Widget build(BuildContext context) => SectionCard(
    child: Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        const SectionTitle(
          title: 'Thay đổi chờ xuất bản',
          description: 'So sánh với template đang hoạt động.',
          trailing: Icon(Icons.difference_outlined),
        ),
        const SizedBox(height: 20),
        if (!hasChanges)
          const EmptyPanel(
            title: 'Chưa có thay đổi',
            description:
                'Chỉnh một giá trị trong biểu mẫu để xem trước khác biệt.',
            icon: Icons.compare_arrows_rounded,
          )
        else ...[
          if (maxJournals != config.parameters.maxJournals)
            _DiffRow(
              name: 'max_journals',
              before: config.parameters.maxJournals,
              after: maxJournals,
            ),
          if (maxKeywords != config.parameters.maxKeywords)
            _DiffRow(
              name: 'max_keywords',
              before: config.parameters.maxKeywords,
              after: maxKeywords,
            ),
        ],
        const SizedBox(height: 18),
        DecoratedBox(
          decoration: BoxDecoration(
            color: Theme.of(context).colorScheme.surfaceContainerHighest,
            borderRadius: BorderRadius.circular(12),
          ),
          child: Padding(
            padding: const EdgeInsets.all(14),
            child: ExpansionTile(
              tilePadding: EdgeInsets.zero,
              childrenPadding: const EdgeInsets.only(top: 4),
              leading: Icon(
                Icons.verified_user_outlined,
                color: Theme.of(context).colorScheme.primary,
              ),
              title: const Text('Đã bật bảo vệ xung đột'),
              subtitle: const Text(
                'Ngăn quản trị viên ghi đè cấu hình mới hơn.',
              ),
              children: [
                Align(
                  alignment: Alignment.centerLeft,
                  child: SelectableText(
                    'Mã phiên bản kỹ thuật: ${config.etag.isEmpty ? '—' : config.etag}',
                    style: const TextStyle(
                      fontFamily: 'monospace',
                      fontSize: 11,
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
      ],
    ),
  );
}

class _DiffRow extends StatelessWidget {
  const _DiffRow({
    required this.name,
    required this.before,
    required this.after,
  });

  final String name;
  final int? before;
  final int? after;

  @override
  Widget build(BuildContext context) => Container(
    margin: const EdgeInsets.only(bottom: 12),
    padding: const EdgeInsets.all(14),
    decoration: BoxDecoration(
      border: Border.all(color: Theme.of(context).dividerColor),
      borderRadius: BorderRadius.circular(12),
    ),
    child: Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          name,
          style: const TextStyle(
            fontFamily: 'monospace',
            fontWeight: FontWeight.w800,
          ),
        ),
        const SizedBox(height: 10),
        Wrap(
          crossAxisAlignment: WrapCrossAlignment.center,
          spacing: 10,
          runSpacing: 6,
          children: [
            Text(
              before?.toString() ?? 'Chưa cấu hình',
              style: TextStyle(
                color: Theme.of(context).colorScheme.error,
                decoration: TextDecoration.lineThrough,
              ),
            ),
            const Icon(Icons.arrow_forward_rounded, size: 17),
            Text(
              after?.toString() ?? 'Không hợp lệ',
              style: TextStyle(
                color: Theme.of(context).colorScheme.primary,
                fontWeight: FontWeight.w900,
              ),
            ),
          ],
        ),
      ],
    ),
  );
}

class _PublishChangeRow extends StatelessWidget {
  const _PublishChangeRow({
    required this.name,
    required this.before,
    required this.after,
  });

  final String name;
  final int? before;
  final int after;

  @override
  Widget build(BuildContext context) => Container(
    margin: const EdgeInsets.only(bottom: 10),
    padding: const EdgeInsets.all(12),
    decoration: BoxDecoration(
      color: Theme.of(context).colorScheme.surfaceContainerHighest,
      borderRadius: BorderRadius.circular(12),
    ),
    child: Row(
      children: [
        Expanded(
          child: Text(
            name,
            style: const TextStyle(
              fontFamily: 'monospace',
              fontWeight: FontWeight.w800,
            ),
          ),
        ),
        Text(before?.toString() ?? '—'),
        const Padding(
          padding: EdgeInsets.symmetric(horizontal: 9),
          child: Icon(Icons.arrow_forward_rounded, size: 17),
        ),
        Text(
          after.toString(),
          style: TextStyle(
            color: Theme.of(context).colorScheme.primary,
            fontWeight: FontWeight.w900,
          ),
        ),
      ],
    ),
  );
}

class _ParameterTile extends StatelessWidget {
  const _ParameterTile({
    required this.keyName,
    required this.value,
    required this.description,
    required this.valueType,
    this.group,
  });

  final String keyName;
  final String? value;
  final String? description;
  final String? valueType;
  final String? group;

  @override
  Widget build(BuildContext context) => DecoratedBox(
    decoration: BoxDecoration(
      color: Theme.of(context).colorScheme.surfaceContainerLowest,
      border: Border.all(color: Theme.of(context).dividerColor),
      borderRadius: BorderRadius.circular(14),
    ),
    child: Padding(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Expanded(
                child: Text(
                  keyName,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(
                    fontFamily: 'monospace',
                    fontWeight: FontWeight.w900,
                  ),
                ),
              ),
              StatusPill(valueType ?? 'STRING'),
            ],
          ),
          if (group != null && group!.isNotEmpty) ...[
            const SizedBox(height: 7),
            Text('Nhóm: $group', style: Theme.of(context).textTheme.labelSmall),
          ],
          const SizedBox(height: 14),
          SelectableText(
            value ?? '—',
            style: Theme.of(
              context,
            ).textTheme.titleMedium?.copyWith(fontWeight: FontWeight.w900),
          ),
          const SizedBox(height: 8),
          Text(
            description?.trim().isNotEmpty == true
                ? description!
                : 'Không có mô tả.',
            maxLines: 3,
            overflow: TextOverflow.ellipsis,
            style: Theme.of(context).textTheme.bodySmall?.copyWith(
              color: Theme.of(context).colorScheme.onSurfaceVariant,
              height: 1.4,
            ),
          ),
        ],
      ),
    ),
  );
}

class _VersionTile extends StatelessWidget {
  const _VersionTile({
    required this.version,
    required this.isCurrent,
    required this.busy,
    required this.onRollback,
  });

  final RemoteConfigVersion version;
  final bool isCurrent;
  final bool busy;
  final VoidCallback onRollback;

  @override
  Widget build(BuildContext context) => LayoutBuilder(
    builder: (context, constraints) {
      final identity = Row(
        children: [
          CircleAvatar(
            backgroundColor: Theme.of(
              context,
            ).colorScheme.primary.withValues(alpha: .1),
            child: const Icon(Icons.file_copy_outlined, size: 18),
          ),
          const SizedBox(width: 13),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  version.versionNumber == null
                      ? 'Phiên bản không xác định'
                      : 'Phiên bản ${version.versionNumber}',
                  style: const TextStyle(fontWeight: FontWeight.w900),
                ),
                const SizedBox(height: 3),
                Text(
                  version.description?.trim().isNotEmpty == true
                      ? version.description!
                      : 'Không có ghi chú thay đổi.',
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                  style: Theme.of(context).textTheme.bodySmall,
                ),
              ],
            ),
          ),
        ],
      );
      final metadata = Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            formatDateTime(version.updatedAt),
            style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 12),
          ),
          if (version.updatedBy?.isNotEmpty == true)
            Text(
              version.updatedBy!,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: Theme.of(context).textTheme.bodySmall?.copyWith(
                color: Theme.of(context).colorScheme.onSurfaceVariant,
              ),
            ),
        ],
      );
      final action = isCurrent
          ? const StatusPill(
              'Đang hoạt động',
              tone: StatusTone.success,
              icon: Icons.check_circle_outline_rounded,
            )
          : OutlinedButton.icon(
              onPressed: busy || version.versionNumber == null
                  ? null
                  : onRollback,
              icon: const Icon(Icons.history_rounded, size: 17),
              label: const Text('Khôi phục'),
            );

      if (constraints.maxWidth < 720) {
        return Padding(
          padding: const EdgeInsets.symmetric(vertical: 15),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              identity,
              const SizedBox(height: 13),
              metadata,
              const SizedBox(height: 13),
              Align(alignment: Alignment.centerLeft, child: action),
            ],
          ),
        );
      }
      return Padding(
        padding: const EdgeInsets.symmetric(vertical: 15),
        child: Row(
          children: [
            Expanded(flex: 5, child: identity),
            const SizedBox(width: 18),
            Expanded(flex: 2, child: metadata),
            const SizedBox(width: 18),
            action,
          ],
        ),
      );
    },
  );
}

Future<({T? data, Object? error})> _capture<T>(Future<T> future) async {
  try {
    return (data: await future, error: null);
  } catch (error) {
    return (data: null, error: error);
  }
}
