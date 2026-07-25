import 'package:flutter/material.dart';

import '../core/core.dart';
import '../utils/ui_format.dart';
import '../widgets/admin_widgets.dart';

class AuditLogsPage extends StatefulWidget {
  const AuditLogsPage({required this.api, super.key});

  final AdminApi api;

  @override
  State<AuditLogsPage> createState() => _AuditLogsPageState();
}

class _AuditLogsPageState extends State<AuditLogsPage> {
  final _searchController = TextEditingController();

  List<AuditLog> _logs = const [];
  Object? _error;
  bool _loading = true;
  int _limit = 50;
  String _action = _allActions;
  AdminDateRange _range = AdminDateRange.last30Days();

  static const _allActions = '__all__';

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

  Future<void> _load() async {
    setState(() {
      _loading = true;
      _error = null;
    });
    try {
      final page = await widget.api.listAuditLogs(limit: _limit);
      if (!mounted) return;
      final availableActions = page.logs.map((log) => log.action).toSet();
      setState(() {
        _logs = page.logs;
        if (_action != _allActions && !availableActions.contains(_action)) {
          _action = _allActions;
        }
        _loading = false;
      });
    } catch (error) {
      if (!mounted) return;
      setState(() {
        _error = error;
        _loading = false;
      });
    }
  }

  List<String> get _actions {
    final result = _logs.map((log) => log.action).toSet().toList()..sort();
    return result;
  }

  List<AuditLog> get _filteredLogs {
    final query = _searchController.text.trim().toLowerCase();
    return _logs.where((log) {
      if (_action != _allActions && log.action != _action) return false;
      final createdAt = DateTime.tryParse(log.createdAt ?? '');
      if (createdAt == null || !_range.contains(createdAt)) return false;
      if (query.isEmpty) return true;
      return [
        log.actorEmail,
        log.actorUid,
        log.action,
        friendlyAction(log.action),
        log.targetType,
        log.targetId,
        log.summary,
      ].any((value) => value?.toLowerCase().contains(query) ?? false);
    }).toList();
  }

  @override
  Widget build(BuildContext context) {
    final filtered = _filteredLogs;
    final actions = _actions;
    return PageBody(
      children: [
        PageHeading(
          eyebrow: 'Structured Admin Audit',
          title: 'Audit Log',
          description:
              'Track what administrators did, on which resource, and when.',
          actions: [
            AdminDateRangeFilter(
              value: _range,
              onChanged: (range) => setState(() => _range = range),
            ),
            OutlinedButton.icon(
              onPressed: _loading ? null : _load,
              icon: _loading
                  ? const InlineSpinner(size: 16)
                  : const Icon(Icons.refresh_rounded, size: 16),
              label: const Text('Refresh'),
            ),
          ],
        ),
        _PrivacyNotice(),
        SectionCard(
          padding: EdgeInsets.zero,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Padding(
                padding: const EdgeInsets.all(20),
                child: _AuditToolbar(
                  searchController: _searchController,
                  action: _action,
                  actions: actions,
                  limit: _limit,
                  shown: filtered.length,
                  total: _logs.length,
                  enabled: !_loading,
                  onSearchChanged: () => setState(() {}),
                  onActionChanged: (value) => setState(() => _action = value),
                  onLimitChanged: (value) {
                    setState(() => _limit = value);
                    _load();
                  },
                ),
              ),
              const Divider(height: 1),
              if (_loading && _logs.isEmpty)
                const LoadingPanel(rowCount: 5)
              else if (_error != null)
                ErrorPanel(
                  message: errorText(_error!),
                  onRetry: _load,
                  detail: _error.toString(),
                )
              else if (filtered.isEmpty)
                EmptyPanel(
                  title: _logs.isEmpty
                      ? 'No audit logs yet'
                      : 'No records match your filters',
                  description: _logs.isEmpty
                      ? 'Data-modifying operations from the Admin panel will appear here.'
                      : 'Try changing the search term or action filter.',
                  icon: Icons.manage_search_rounded,
                )
              else
                LayoutBuilder(
                  builder: (context, constraints) => constraints.maxWidth < 860
                      ? _AuditCards(logs: filtered)
                      : _AuditTable(logs: filtered),
                ),
            ],
          ),
        ),
      ],
    );
  }
}

class _PrivacyNotice extends StatelessWidget {
  @override
  Widget build(BuildContext context) => DecoratedBox(
    decoration: BoxDecoration(
      color: Theme.of(context).colorScheme.primary.withValues(alpha: .08),
      borderRadius: BorderRadius.circular(14),
      border: Border.all(
        color: Theme.of(context).colorScheme.primary.withValues(alpha: .18),
      ),
    ),
    child: Padding(
      padding: const EdgeInsets.symmetric(horizontal: 17, vertical: 14),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(
            Icons.shield_outlined,
            size: 20,
            color: Theme.of(context).colorScheme.primary,
          ),
          const SizedBox(width: 11),
          Expanded(
            child: Text(
              'Audit logs show operational metadata only. ID tokens, App Check '
              'tokens, and full FCM targets are never exposed in this interface.',
              style: Theme.of(
                context,
              ).textTheme.bodySmall?.copyWith(height: 1.45),
            ),
          ),
        ],
      ),
    ),
  );
}

class _AuditToolbar extends StatelessWidget {
  const _AuditToolbar({
    required this.searchController,
    required this.action,
    required this.actions,
    required this.limit,
    required this.shown,
    required this.total,
    required this.enabled,
    required this.onSearchChanged,
    required this.onActionChanged,
    required this.onLimitChanged,
  });

  final TextEditingController searchController;
  final String action;
  final List<String> actions;
  final int limit;
  final int shown;
  final int total;
  final bool enabled;
  final VoidCallback onSearchChanged;
  final ValueChanged<String> onActionChanged;
  final ValueChanged<int> onLimitChanged;

  @override
  Widget build(BuildContext context) => LayoutBuilder(
    builder: (context, constraints) {
      final search = TextField(
        controller: searchController,
        enabled: enabled,
        onChanged: (_) => onSearchChanged(),
        decoration: InputDecoration(
          prefixIcon: const Icon(Icons.search_rounded),
          hintText: 'Filter by administrator, action, or target…',
          suffixIcon: searchController.text.isEmpty
              ? null
              : IconButton(
                  tooltip: 'Clear search',
                  onPressed: () {
                    searchController.clear();
                    onSearchChanged();
                  },
                  icon: const Icon(Icons.close_rounded),
                ),
        ),
      );
      final actionFilter = DropdownButtonFormField<String>(
        key: ValueKey('audit-action-$action-${actions.join('|')}'),
        initialValue: action,
        isExpanded: true,
        decoration: const InputDecoration(
          labelText: 'Action',
          prefixIcon: Icon(Icons.filter_alt_outlined),
        ),
        items: [
          const DropdownMenuItem(
            value: _AuditLogsPageState._allActions,
            child: Text('All actions'),
          ),
          for (final item in actions)
            DropdownMenuItem(
              value: item,
              child: Text(
                friendlyAction(item),
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
              ),
            ),
        ],
        onChanged: enabled
            ? (value) {
                if (value != null) onActionChanged(value);
              }
            : null,
      );
      final limitFilter = DropdownButtonFormField<int>(
        key: ValueKey('audit-limit-$limit'),
        initialValue: limit,
        decoration: const InputDecoration(
          labelText: 'Record limit',
          prefixIcon: Icon(Icons.format_list_numbered_rounded),
        ),
        items: const [
          DropdownMenuItem(value: 25, child: Text('25')),
          DropdownMenuItem(value: 50, child: Text('50')),
          DropdownMenuItem(value: 100, child: Text('100')),
        ],
        onChanged: enabled
            ? (value) {
                if (value != null && value != limit) onLimitChanged(value);
              }
            : null,
      );
      final count = Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          const Icon(Icons.receipt_long_outlined, size: 17),
          const SizedBox(width: 7),
          Text(
            '$shown / $total records',
            style: Theme.of(
              context,
            ).textTheme.bodySmall?.copyWith(fontWeight: FontWeight.w800),
          ),
        ],
      );

      if (constraints.maxWidth < 720) {
        return Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            search,
            const SizedBox(height: 12),
            actionFilter,
            const SizedBox(height: 12),
            Row(
              children: [
                Expanded(child: limitFilter),
                const SizedBox(width: 14),
                count,
              ],
            ),
          ],
        );
      }
      return Row(
        children: [
          Expanded(flex: 4, child: search),
          const SizedBox(width: 12),
          SizedBox(width: 220, child: actionFilter),
          const SizedBox(width: 12),
          SizedBox(width: 140, child: limitFilter),
          const SizedBox(width: 16),
          count,
        ],
      );
    },
  );
}

class _AuditTable extends StatelessWidget {
  const _AuditTable({required this.logs});

  final List<AuditLog> logs;

  @override
  Widget build(BuildContext context) => LayoutBuilder(
    builder: (context, constraints) => SingleChildScrollView(
      scrollDirection: Axis.horizontal,
      child: ConstrainedBox(
        constraints: BoxConstraints(minWidth: constraints.maxWidth),
        child: DataTable(
          columnSpacing: 32,
          headingRowHeight: 48,
          dataRowMinHeight: 72,
          dataRowMaxHeight: 88,
          columns: const [
            DataColumn(label: Text('TIME')),
            DataColumn(label: Text('ADMINISTRATOR')),
            DataColumn(label: Text('ACTION')),
            DataColumn(label: Text('TARGET')),
            DataColumn(label: Text('SUMMARY')),
          ],
          rows: [
            for (final log in logs)
              DataRow(
                cells: [
                  DataCell(
                    SizedBox(
                      width: 132,
                      child: Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            formatDateTime(log.createdAt),
                            style: const TextStyle(fontWeight: FontWeight.w700),
                          ),
                          const SizedBox(height: 3),
                          Tooltip(
                            message: log.id,
                            child: Text(
                              truncateMiddle(log.id, keep: 7),
                              style: Theme.of(context).textTheme.labelSmall
                                  ?.copyWith(
                                    fontFamily: 'monospace',
                                    color: Theme.of(
                                      context,
                                    ).colorScheme.outline,
                                  ),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                  DataCell(
                    SizedBox(width: 210, child: _ActorIdentity(log: log)),
                  ),
                  DataCell(
                    SizedBox(
                      width: 175,
                      child: StatusPill(
                        friendlyAction(log.action),
                        tone: StatusTone.purple,
                        icon: Icons.task_alt_rounded,
                      ),
                    ),
                  ),
                  DataCell(
                    SizedBox(width: 185, child: _TargetIdentity(log: log)),
                  ),
                  DataCell(
                    SizedBox(
                      width: 270,
                      child: Text(
                        log.summary?.trim().isNotEmpty == true
                            ? log.summary!
                            : 'No additional description.',
                        maxLines: 3,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                  ),
                ],
              ),
          ],
        ),
      ),
    ),
  );
}

class _AuditCards extends StatelessWidget {
  const _AuditCards({required this.logs});

  final List<AuditLog> logs;

  @override
  Widget build(BuildContext context) => ListView.separated(
    padding: const EdgeInsets.all(16),
    shrinkWrap: true,
    physics: const NeverScrollableScrollPhysics(),
    itemCount: logs.length,
    separatorBuilder: (_, _) => const SizedBox(height: 11),
    itemBuilder: (context, index) {
      final log = logs[index];
      return DecoratedBox(
        decoration: BoxDecoration(
          border: Border.all(color: Theme.of(context).dividerColor),
          borderRadius: BorderRadius.circular(14),
        ),
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Expanded(child: _ActorIdentity(log: log)),
                  const SizedBox(width: 10),
                  Text(
                    formatDateTime(log.createdAt),
                    style: Theme.of(context).textTheme.labelSmall,
                  ),
                ],
              ),
              const SizedBox(height: 13),
              Align(
                alignment: Alignment.centerLeft,
                child: StatusPill(
                  friendlyAction(log.action),
                  tone: StatusTone.purple,
                  icon: Icons.task_alt_rounded,
                ),
              ),
              const SizedBox(height: 13),
              _TargetIdentity(log: log),
              const SizedBox(height: 12),
              Text(
                log.summary?.trim().isNotEmpty == true
                    ? log.summary!
                    : 'No additional description.',
                style: Theme.of(
                  context,
                ).textTheme.bodySmall?.copyWith(height: 1.45),
              ),
              const SizedBox(height: 10),
              Tooltip(
                message: log.id,
                child: Text(
                  'Log ID: ${truncateMiddle(log.id, keep: 9)}',
                  style: Theme.of(context).textTheme.labelSmall?.copyWith(
                    fontFamily: 'monospace',
                    color: Theme.of(context).colorScheme.outline,
                  ),
                ),
              ),
            ],
          ),
        ),
      );
    },
  );
}

class _ActorIdentity extends StatelessWidget {
  const _ActorIdentity({required this.log});

  final AuditLog log;

  @override
  Widget build(BuildContext context) => Row(
    children: [
      CircleAvatar(
        radius: 18,
        backgroundColor: Theme.of(context).colorScheme.primaryContainer,
        child: const Icon(Icons.person_outline_rounded, size: 18),
      ),
      const SizedBox(width: 10),
      Expanded(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              log.actorEmail?.trim().isNotEmpty == true
                  ? log.actorEmail!
                  : 'Unknown email',
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: const TextStyle(fontWeight: FontWeight.w800),
            ),
            Tooltip(
              message: log.actorUid ?? '',
              child: Text(
                log.actorUid == null ? '—' : truncateMiddle(log.actorUid!),
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: Theme.of(context).textTheme.labelSmall?.copyWith(
                  fontFamily: 'monospace',
                  color: Theme.of(context).colorScheme.outline,
                ),
              ),
            ),
          ],
        ),
      ),
    ],
  );
}

class _TargetIdentity extends StatelessWidget {
  const _TargetIdentity({required this.log});

  final AuditLog log;

  @override
  Widget build(BuildContext context) => Column(
    crossAxisAlignment: CrossAxisAlignment.start,
    mainAxisAlignment: MainAxisAlignment.center,
    children: [
      Text(
        log.targetType?.trim().isNotEmpty == true
            ? log.targetType!
            : 'resource',
        style: const TextStyle(fontWeight: FontWeight.w800),
      ),
      const SizedBox(height: 3),
      Tooltip(
        message: log.targetId ?? '',
        child: Text(
          log.targetId == null ? '—' : truncateMiddle(log.targetId!, keep: 10),
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
          style: Theme.of(context).textTheme.labelSmall?.copyWith(
            fontFamily: 'monospace',
            color: Theme.of(context).colorScheme.onSurfaceVariant,
          ),
        ),
      ),
    ],
  );
}
