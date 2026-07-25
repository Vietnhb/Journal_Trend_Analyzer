import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../core/core.dart';
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
            configResult.error ?? Exception('Invalid Remote Config data.');
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
      return 'Enter an integer from 1 to 100.';
    }
    final value = int.tryParse(raw.trim());
    if (value == null || value < 1 || value > 100) {
      return 'Value must be an integer from 1 to 100.';
    }
    return null;
  }

  String? _validateDescription(String? raw) {
    if (!_hasChanges) return null;
    final length = raw?.trim().length ?? 0;
    if (length < 1) return 'Enter a change note.';
    if (length > 300) return 'Change note must not exceed 300 characters.';
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
        'No configuration values have changed.',
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
      showAppMessage(context, 'Remote Config published successfully.');
      await _load();
    } catch (error) {
      await _handleMutationError(error, action: 'publish');
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
        title: const Text('Publish Remote Config?'),
        content: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 520),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              const Text(
                'The new configuration will be delivered to the app on its '
                'next fetch.',
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
                'Change note',
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
                      'The system will check for conflicts to avoid '
                      'overwriting a newer configuration.',
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
            child: const Text('Cancel'),
          ),
          FilledButton.icon(
            key: const Key('confirm_remote_config_publish'),
            onPressed: () => Navigator.pop(dialogContext, true),
            icon: const Icon(Icons.publish_rounded),
            label: const Text('Confirm publish'),
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
      title: 'Roll back to version $versionNumber?',
      description:
          'Preview: max_journals = ${target.parameters.maxJournals ?? 'not configured'}, '
          'max_keywords = ${target.parameters.maxKeywords ?? 'not configured'}.\n\n'
          'This version will be published as a new version. The active '
          'configuration will be replaced.',
      confirmationText: 'v$versionNumber',
      actionLabel: 'Roll back',
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
        'Remote Config rolled back to version $versionNumber.',
      );
      await _load();
    } catch (error) {
      await _handleMutationError(error, action: 'roll back');
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
        'The configuration was changed elsewhere. The latest data has been '
        'reloaded; review it, then $action again.',
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
        title: 'Remote Config',
        description:
            'Manage display limits, review changes, and safely roll back '
            'without touching Firebase Console directly.',
        actions: [
          if (_config case final config?)
            StatusPill(
              config.version.versionNumber == null
                  ? 'No version yet'
                  : 'v${config.version.versionNumber} active',
              tone: StatusTone.success,
              icon: Icons.cloud_done_outlined,
            ),
          OutlinedButton.icon(
            onPressed: _refreshing || _mutating ? null : _load,
            icon: _refreshing
                ? const InlineSpinner(size: 16)
                : const Icon(Icons.refresh_rounded, size: 16),
            label: const Text('Refresh'),
          ),
        ],
      ),
      if (_loading)
        const SectionCard(
          child: LoadingPanel(
            style: LoadingStyle.spinner,
            label: 'Loading Remote Config…',
          ),
        )
      else if (_loadError != null)
        SectionCard(
          child: ErrorPanel(
            message: errorText(_loadError!),
            onRetry: _load,
            detail: _loadError.toString(),
          ),
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
        if (constraints.maxWidth < 1040) {
          return Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [editor, const SizedBox(height: 24), diff],
          );
        }
        return Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Expanded(flex: 7, child: editor),
            const SizedBox(width: 24),
            Expanded(flex: 4, child: diff),
          ],
        );
      },
    ),
    SectionCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          const SectionTitle(
            title: 'Existing Firebase Parameters',
            description:
                'Read-only. Keys not shown in the form are preserved when you publish.',
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
                  description: 'Maximum journals shown in the ranking.',
                  valueType: 'NUMBER',
                ),
                _ParameterTile(
                  keyName: 'max_keywords',
                  value: config.parameters.maxKeywords?.toString(),
                  description: 'Maximum keywords shown in trend results.',
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
            title: 'Version History',
            description:
                'The 20 most recent versions. Rolling back republishes the '
                'selected content as a new version.',
            trailing: IconButton(
              tooltip: 'Refresh version history',
              onPressed: _refreshing || _mutating ? null : _load,
              icon: const Icon(Icons.history_rounded),
            ),
          ),
          const SizedBox(height: 14),
          if (_historyError != null)
            ErrorPanel(message: errorText(_historyError!), onRetry: _load)
          else if (_versions.isEmpty)
            const EmptyPanel(
              title: 'No Version History Yet',
              description: 'Published Remote Config versions will appear here.',
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
            title: 'Active Parameters',
            description: 'Last updated ${formatDateTime(updatedAt)}',
            trailing: const Icon(Icons.tune_rounded),
          ),
          const SizedBox(height: 24),
          LayoutBuilder(
            builder: (context, constraints) {
              final maxJournals = _LimitField(
                controller: maxJournalsController,
                label: 'max_journals',
                helper: 'Maximum journals shown in the ranking.',
                validator: validateLimit,
                enabled: !busy,
                onChanged: onChanged,
              );
              final maxKeywords = _LimitField(
                controller: maxKeywordsController,
                label: 'max_keywords',
                helper: 'Maximum keywords shown in trend results.',
                validator: validateLimit,
                enabled: !busy,
                onChanged: onChanged,
              );
              if (constraints.maxWidth < 680) {
                return Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    maxJournals,
                    const SizedBox(height: 18),
                    maxKeywords,
                  ],
                );
              }
              return Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Expanded(child: maxJournals),
                  const SizedBox(width: 20),
                  Expanded(child: maxKeywords),
                ],
              );
            },
          ),
          const SizedBox(height: 20),
          TextFormField(
            controller: descriptionController,
            enabled: !busy,
            validator: validateDescription,
            maxLength: 300,
            maxLines: 3,
            minLines: 3,
            onChanged: (_) => onChanged(),
            decoration: const InputDecoration(
              labelText: 'Change note',
              alignLabelWithHint: true,
              hintText: 'Example: Increase the keyword limit for the demo…',
              helperText:
                  'This note will be saved with the Remote Config version.',
            ),
          ),
          const SizedBox(height: 8),
          Row(
            children: [
              Expanded(
                child: Text(
                  'The app receives this configuration on its next fetch.',
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
                label: const Text('Publish'),
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
      helperText: '$helper Valid values are 1 to 100.',
      suffixText: 'items',
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
          title: 'Pending Changes',
          description: 'Compared with the active template.',
          trailing: Icon(Icons.difference_outlined),
        ),
        const SizedBox(height: 20),
        if (!hasChanges)
          const EmptyPanel(
            title: 'No Changes Yet',
            description: 'Edit a value in the form to preview the difference.',
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
              title: const Text('Conflict Protection Enabled'),
              subtitle: const Text(
                'Prevents administrators from overwriting a newer configuration.',
              ),
              children: [
                Align(
                  alignment: Alignment.centerLeft,
                  child: SelectableText(
                    'Technical version ID: ${config.etag.isEmpty ? '—' : config.etag}',
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
              before?.toString() ?? 'Not configured',
              style: TextStyle(
                color: Theme.of(context).colorScheme.error,
                decoration: TextDecoration.lineThrough,
              ),
            ),
            const Icon(Icons.arrow_forward_rounded, size: 17),
            Text(
              after?.toString() ?? 'Invalid',
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
            Text(
              'Group: $group',
              style: Theme.of(context).textTheme.labelSmall,
            ),
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
                : 'No description.',
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
                      ? 'Unknown version'
                      : 'Version ${version.versionNumber}',
                  style: const TextStyle(fontWeight: FontWeight.w900),
                ),
                const SizedBox(height: 3),
                Text(
                  version.description?.trim().isNotEmpty == true
                      ? version.description!
                      : 'No change note.',
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
              'Active',
              tone: StatusTone.success,
              icon: Icons.check_circle_outline_rounded,
            )
          : OutlinedButton.icon(
              onPressed: busy || version.versionNumber == null
                  ? null
                  : onRollback,
              icon: const Icon(Icons.history_rounded, size: 17),
              label: const Text('Roll back'),
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
