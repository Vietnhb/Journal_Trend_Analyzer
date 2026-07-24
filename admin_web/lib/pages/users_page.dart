import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:journal_trend_admin_web/core/core.dart';

import '../theme/app_theme.dart';
import '../utils/ui_format.dart';
import '../widgets/admin_widgets.dart';

class UsersPage extends StatefulWidget {
  const UsersPage({required this.api, required this.currentUid, super.key});

  final AdminApi api;
  final String currentUid;

  @override
  State<UsersPage> createState() => _UsersPageState();
}

class _UsersPageState extends State<UsersPage> {
  static const _pageSize = 20;
  final _searchController = TextEditingController();
  final List<String?> _tokens = [null];
  late Future<UserPage> _future;
  String _query = '';
  int _page = 0;
  String? _busyUid;

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
    _future = widget.api.listUsers(
      pageSize: _pageSize,
      pageToken: _tokens[_page],
      query: _query.isEmpty ? null : _query,
    );
  }

  void _refresh() => setState(_load);

  void _search() {
    final value = _searchController.text.trim();
    setState(() {
      _query = value;
      _page = 0;
      _tokens
        ..clear()
        ..add(null);
      _load();
    });
  }

  Future<void> _edit(AdminUser user) async {
    final controller = TextEditingController(text: user.displayName ?? '');
    final value = await showDialog<String>(
      context: context,
      builder: (dialogContext) => _EditUserDialog(
        user: user,
        controller: controller,
      ),
    );
    controller.dispose();
    if (value == null || !mounted) return;
    await _run(user.uid, () {
      final normalized = value.trim();
      return widget.api.updateUser(
        user.uid,
        normalized.isEmpty
            ? const UserUpdate(clearDisplayName: true)
            : UserUpdate(displayName: normalized),
      );
    }, 'Display name updated.');
  }

  Future<void> _action(AdminUser user, _UserAction action) async {
    final self = user.uid == widget.currentUid;
    if (self && action != _UserAction.revoke) {
      showAppMessage(
        context,
        'You cannot perform this action on your own account.',
        error: true,
      );
      return;
    }
    final target = user.email ?? user.uid;
    final config = switch (action) {
      _UserAction.toggleRole => (
        title: user.isAdmin ? 'Revoke Admin role?' : 'Grant Admin role?',
        description: user.isAdmin
            ? 'This account will lose admin access and all active sessions will be revoked.'
            : 'This account will be able to perform all privileged admin operations.',
        label: user.isAdmin ? 'Revoke role' : 'Grant role',
        danger: user.isAdmin,
      ),
      _UserAction.toggleStatus => (
        title: user.disabled ? 'Unblock account?' : 'Block account?',
        description: user.disabled
            ? 'The user will be able to sign in again after the account is unblocked.'
            : 'The user will not be able to create new Firebase sessions.',
        label: user.disabled ? 'Unblock' : 'Block account',
        danger: !user.disabled,
      ),
      _UserAction.revoke => (
        title: 'Revoke all sessions?',
        description:
            'All existing refresh tokens will be invalidated. The user will need to sign in again.',
        label: 'Revoke sessions',
        danger: true,
      ),
      _UserAction.delete => (
        title: 'Permanently delete account?',
        description:
            'The Firebase Auth account will be deleted. Reports in Storage are not automatically removed.',
        label: 'Delete account',
        danger: true,
      ),
    };
    final confirmed = await showTypedConfirmation(
      context: context,
      title: config.title,
      description: config.description,
      confirmationText: target,
      actionLabel: config.label,
      danger: config.danger,
    );
    if (!confirmed || !mounted) return;

    switch (action) {
      case _UserAction.toggleRole:
        await _run(
          user.uid,
          () => widget.api.setAdminRole(user.uid, isAdmin: !user.isAdmin),
          user.isAdmin ? 'Admin role revoked.' : 'Admin role granted.',
        );
      case _UserAction.toggleStatus:
        await _run(
          user.uid,
          () => widget.api.updateUser(
            user.uid,
            UserUpdate(disabled: !user.disabled),
          ),
          user.disabled ? 'Account unblocked.' : 'Account blocked.',
        );
      case _UserAction.revoke:
        await _run(
          user.uid,
          () => widget.api.revokeUserSessions(user.uid),
          'Sessions revoked.',
        );
      case _UserAction.delete:
        await _run(
          user.uid,
          () => widget.api.deleteUser(user.uid),
          'Firebase Auth account deleted.',
        );
    }
  }

  Future<void> _run(
    String uid,
    Future<Object?> Function() operation,
    String success,
  ) async {
    setState(() => _busyUid = uid);
    try {
      await operation();
      if (!mounted) return;
      showAppMessage(context, success);
      _refresh();
    } catch (error) {
      if (mounted) showAppMessage(context, errorText(error), error: true);
    } finally {
      if (mounted) setState(() => _busyUid = null);
    }
  }

  @override
  Widget build(BuildContext context) => PageBody(
    children: [
      PageHeading(
        eyebrow: 'Firebase Authentication',
        title: 'User Management',
        description:
            'Search by email or UID, manage account status and Admin custom claims.',
        actions: [
          OutlinedButton.icon(
            onPressed: _refresh,
            icon: const Icon(Icons.refresh_rounded, size: 16),
            label: const Text('Refresh'),
          ),
        ],
      ),
      SectionCard(
        padding: EdgeInsets.zero,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            // ── Search bar ─────────────────────────────────────────────────
            Padding(
              padding: const EdgeInsets.all(16),
              child: LayoutBuilder(
                builder: (context, constraints) {
                  final search = SearchField(
                    controller: _searchController,
                    hintText: 'Search by email or UID — press Enter ↵',
                    onSubmitted: _search,
                    onChanged: (_) => setState(() {}),
                  );
                  final button = FilledButton.icon(
                    onPressed: _search,
                    icon: const Icon(Icons.search_rounded, size: 16),
                    label: const Text('Search'),
                  );
                  final badge = const StatusPill(
                    'Role via custom claims',
                    tone: StatusTone.purple,
                    icon: Icons.key_rounded,
                  );
                  if (constraints.maxWidth < 620) {
                    return Column(
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [search, const SizedBox(height: 8), button],
                    );
                  }
                  return Row(
                    children: [
                      Expanded(child: search),
                      const SizedBox(width: 8),
                      button,
                      const SizedBox(width: 12),
                      badge,
                    ],
                  );
                },
              ),
            ),
            const Divider(height: 0.5),
            // ── User list ─────────────────────────────────────────────────
            FutureBuilder<UserPage>(
              future: _future,
              builder: (context, snapshot) {
                if (snapshot.connectionState != ConnectionState.done) {
                  return const LoadingPanel(rowCount: 8);
                }
                if (snapshot.hasError) {
                  return ErrorPanel(
                    message: errorText(snapshot.error!),
                    onRetry: _refresh,
                  );
                }
                final data = snapshot.requireData;
                if (data.users.isEmpty) {
                  return EmptyPanel(
                    title: _query.isEmpty
                        ? 'No users yet'
                        : 'No accounts found',
                    description: _query.isEmpty
                        ? 'Accounts will appear after the first Firebase sign-in.'
                        : 'No email or UID matching "$_query".',
                    icon: Icons.person_search_outlined,
                  );
                }
                return Column(
                  children: [
                    LayoutBuilder(
                      builder: (context, constraints) =>
                          constraints.maxWidth >= 1000
                          ? _UsersTable(
                              users: data.users,
                              currentUid: widget.currentUid,
                              busyUid: _busyUid,
                              onEdit: _edit,
                              onAction: _action,
                            )
                          : _UsersCards(
                              users: data.users,
                              currentUid: widget.currentUid,
                              busyUid: _busyUid,
                              onEdit: _edit,
                              onAction: _action,
                            ),
                    ),
                    if (_page > 0 || data.nextPageToken != null) ...[
                      const Divider(height: 0.5),
                      TablePagination(
                        page: _page,
                        hasPrevious: _page > 0,
                        hasNext: data.nextPageToken != null,
                        busy: _busyUid != null,
                        onPrevious: () => setState(() {
                          _page--;
                          _load();
                        }),
                        onNext: () => setState(() {
                          if (_tokens.length == _page + 1) {
                            _tokens.add(data.nextPageToken);
                          } else {
                            _tokens[_page + 1] = data.nextPageToken;
                          }
                          _page++;
                          _load();
                        }),
                      ),
                    ],
                  ],
                );
              },
            ),
          ],
        ),
      ),
    ],
  );
}

// ─── Actions enum ─────────────────────────────────────────────────────────────

enum _UserAction { toggleRole, toggleStatus, revoke, delete }

// ─── Desktop table ────────────────────────────────────────────────────────────

class _UsersTable extends StatelessWidget {
  const _UsersTable({
    required this.users,
    required this.currentUid,
    required this.busyUid,
    required this.onEdit,
    required this.onAction,
  });

  final List<AdminUser> users;
  final String currentUid;
  final String? busyUid;
  final ValueChanged<AdminUser> onEdit;
  final void Function(AdminUser, _UserAction) onAction;

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final headerBg = isDark
        ? AppColors.darkSurfaceVariant
        : AppColors.lightSurfaceVariant;

    return SingleChildScrollView(
      scrollDirection: Axis.horizontal,
      child: ConstrainedBox(
        constraints: const BoxConstraints(minWidth: 800),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            // Custom header row
            DecoratedBox(
              decoration: BoxDecoration(color: headerBg),
              child: Padding(
                padding: const EdgeInsets.symmetric(
                  horizontal: 20,
                  vertical: 11,
                ),
                child: Row(
                  children: [
                    SizedBox(
                      width: 280,
                      child: _HeaderCell('USER'),
                    ),
                    SizedBox(width: 110, child: _HeaderCell('ROLE')),
                    SizedBox(width: 110, child: _HeaderCell('STATUS')),
                    SizedBox(width: 140, child: _HeaderCell('PROVIDER')),
                    Expanded(child: _HeaderCell('LAST SIGN-IN')),
                    const SizedBox(width: 64),
                  ],
                ),
              ),
            ),
            const Divider(height: 0.5),
            // Data rows
            for (var i = 0; i < users.length; i++) ...[
              _UserRow(
                user: users[i],
                isSelf: users[i].uid == currentUid,
                busy: busyUid == users[i].uid,
                onEdit: onEdit,
                onAction: onAction,
              ),
              if (i < users.length - 1)
                const Divider(height: 0.5, indent: 20, endIndent: 20),
            ],
          ],
        ),
      ),
    );
  }
}

class _HeaderCell extends StatelessWidget {
  const _HeaderCell(this.label);
  final String label;

  @override
  Widget build(BuildContext context) => Text(
    label,
    style: GoogleFonts.inter(
      fontSize: 10.5,
      fontWeight: FontWeight.w700,
      letterSpacing: 0.7,
      color: Theme.of(context).colorScheme.onSurfaceVariant,
    ),
  );
}

class _UserRow extends StatefulWidget {
  const _UserRow({
    required this.user,
    required this.isSelf,
    required this.busy,
    required this.onEdit,
    required this.onAction,
  });

  final AdminUser user;
  final bool isSelf;
  final bool busy;
  final ValueChanged<AdminUser> onEdit;
  final void Function(AdminUser, _UserAction) onAction;

  @override
  State<_UserRow> createState() => _UserRowState();
}

class _UserRowState extends State<_UserRow> {
  bool _hovered = false;

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final hoverBg = isDark
        ? Colors.white.withValues(alpha: .025)
        : Colors.black.withValues(alpha: .015);

    return MouseRegion(
      onEnter: (_) => setState(() => _hovered = true),
      onExit: (_) => setState(() => _hovered = false),
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 100),
        color: _hovered ? hoverBg : Colors.transparent,
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
          child: Row(
            children: [
              // Identity
              SizedBox(
                width: 280,
                child: _UserIdentity(user: widget.user),
              ),
              // Role
              SizedBox(
                width: 110,
                child: widget.user.isAdmin
                    ? const StatusPill(
                        'Admin',
                        tone: StatusTone.purple,
                        icon: Icons.shield_outlined,
                      )
                    : const StatusDot('User'),
              ),
              // Status
              SizedBox(
                width: 110,
                child: StatusDot(
                  widget.user.disabled ? 'Blocked' : 'Active',
                  tone: widget.user.disabled
                      ? StatusTone.danger
                      : StatusTone.success,
                ),
              ),
              // Provider
              SizedBox(
                width: 140,
                child: Text(
                  widget.user.providers.isEmpty
                      ? '—'
                      : widget.user.providers.join(', '),
                  style: GoogleFonts.inter(
                    fontSize: 12.5,
                    color: cs.onSurfaceVariant,
                  ),
                  overflow: TextOverflow.ellipsis,
                ),
              ),
              // Last sign-in
              Expanded(
                child: Text(
                  formatDateTime(widget.user.lastSignInAt),
                  style: GoogleFonts.inter(
                    fontSize: 12.5,
                    color: cs.onSurfaceVariant,
                  ),
                  overflow: TextOverflow.ellipsis,
                ),
              ),
              // Actions
              SizedBox(
                width: 64,
                child: _UserMenu(
                  user: widget.user,
                  isSelf: widget.isSelf,
                  busy: widget.busy,
                  onEdit: widget.onEdit,
                  onAction: widget.onAction,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

// ─── Mobile cards ─────────────────────────────────────────────────────────────

class _UsersCards extends StatelessWidget {
  const _UsersCards({
    required this.users,
    required this.currentUid,
    required this.busyUid,
    required this.onEdit,
    required this.onAction,
  });

  final List<AdminUser> users;
  final String currentUid;
  final String? busyUid;
  final ValueChanged<AdminUser> onEdit;
  final void Function(AdminUser, _UserAction) onAction;

  @override
  Widget build(BuildContext context) {
    final border = Theme.of(context).dividerColor;
    return ListView.separated(
      padding: const EdgeInsets.all(16),
      shrinkWrap: true,
      physics: const NeverScrollableScrollPhysics(),
      itemCount: users.length,
      separatorBuilder: (_, _) => const SizedBox(height: 8),
      itemBuilder: (context, index) {
        final user = users[index];
        return DecoratedBox(
          decoration: BoxDecoration(
            border: Border.all(color: border, width: 0.5),
            borderRadius: BorderRadius.circular(AppRadius.md),
          ),
          child: Padding(
            padding: const EdgeInsets.all(14),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Row(
                  children: [
                    Expanded(child: _UserIdentity(user: user)),
                    _UserMenu(
                      user: user,
                      isSelf: user.uid == currentUid,
                      busy: busyUid == user.uid,
                      onEdit: onEdit,
                      onAction: onAction,
                    ),
                  ],
                ),
                const SizedBox(height: 10),
                Wrap(
                  spacing: 6,
                  runSpacing: 6,
                  children: [
                    StatusPill(
                      user.isAdmin ? 'Admin' : 'User',
                      tone: user.isAdmin
                          ? StatusTone.purple
                          : StatusTone.neutral,
                      icon: user.isAdmin ? Icons.shield_outlined : null,
                    ),
                    StatusPill(
                      user.disabled ? 'Blocked' : 'Active',
                      tone: user.disabled
                          ? StatusTone.danger
                          : StatusTone.success,
                    ),
                    if (user.emailVerified)
                      const StatusPill(
                        'Verified',
                        tone: StatusTone.info,
                        icon: Icons.verified_outlined,
                      ),
                  ],
                ),
                const SizedBox(height: 8),
                Text(
                  'Last sign-in: ${formatDateTime(user.lastSignInAt)}',
                  style: Theme.of(context).textTheme.bodySmall?.copyWith(
                    color: Theme.of(context).colorScheme.onSurfaceVariant,
                  ),
                ),
              ],
            ),
          ),
        );
      },
    );
  }
}

// ─── UserIdentity ─────────────────────────────────────────────────────────────

class _UserIdentity extends StatelessWidget {
  const _UserIdentity({required this.user});
  final AdminUser user;

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;

    return Row(
      children: [
        Stack(
          clipBehavior: Clip.none,
          children: [
            CircleAvatar(
              radius: 18,
              backgroundColor: cs.primaryContainer,
              backgroundImage: user.photoUrl == null
                  ? null
                  : NetworkImage(user.photoUrl!),
              child: user.photoUrl == null
                  ? Text(
                      initials(user.displayName, user.email),
                      style: GoogleFonts.inter(
                        fontWeight: FontWeight.w800,
                        fontSize: 13,
                      ),
                    )
                  : null,
            ),
            if (user.emailVerified)
              Positioned(
                right: -2,
                bottom: -2,
                child: DecoratedBox(
                  decoration: BoxDecoration(
                    color: AppColors.brand,
                    shape: BoxShape.circle,
                    border: Border.all(color: cs.surface, width: 1.5),
                  ),
                  child: const Padding(
                    padding: EdgeInsets.all(1.5),
                    child: Icon(
                      Icons.check_rounded,
                      size: 8,
                      color: Colors.white,
                    ),
                  ),
                ),
              ),
          ],
        ),
        const SizedBox(width: 11),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                user.displayName?.trim().isNotEmpty == true
                    ? user.displayName!
                    : 'Unnamed',
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: GoogleFonts.inter(
                  fontSize: 13,
                  fontWeight: FontWeight.w600,
                  color: cs.onSurface,
                ),
              ),
              if (user.email != null)
                Text(
                  user.email!,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: GoogleFonts.inter(
                    color: cs.onSurfaceVariant,
                    fontSize: 11.5,
                  ),
                ),
              CopyableText(user.uid),
            ],
          ),
        ),
      ],
    );
  }
}

// ─── UserMenu ─────────────────────────────────────────────────────────────────

class _UserMenu extends StatelessWidget {
  const _UserMenu({
    required this.user,
    required this.isSelf,
    required this.busy,
    required this.onEdit,
    required this.onAction,
  });

  final AdminUser user;
  final bool isSelf;
  final bool busy;
  final ValueChanged<AdminUser> onEdit;
  final void Function(AdminUser, _UserAction) onAction;

  @override
  Widget build(BuildContext context) {
    if (busy) {
      return const Padding(
        padding: EdgeInsets.all(10),
        child: InlineSpinner(),
      );
    }
    return PopupMenuButton<String>(
      tooltip: 'Actions',
      onSelected: (value) {
        if (value == 'edit') return onEdit(user);
        final action = _UserAction.values.byName(value);
        onAction(user, action);
      },
      offset: const Offset(0, 36),
      itemBuilder: (context) => [
        _menuItem(
          value: 'edit',
          icon: Icons.edit_outlined,
          label: 'Edit display name',
        ),
        _menuItem(
          value: _UserAction.toggleStatus.name,
          icon: user.disabled
              ? Icons.lock_open_rounded
              : Icons.lock_outline_rounded,
          label: user.disabled ? 'Unblock account' : 'Block account',
          enabled: !isSelf,
        ),
        _menuItem(
          value: _UserAction.toggleRole.name,
          icon: user.isAdmin
              ? Icons.shield_outlined
              : Icons.add_moderator_outlined,
          label: user.isAdmin ? 'Revoke Admin role' : 'Grant Admin role',
          enabled: !isSelf,
        ),
        _menuItem(
          value: _UserAction.revoke.name,
          icon: Icons.logout_rounded,
          label: 'Revoke sessions',
        ),
        const PopupMenuDivider(height: 0.5),
        _menuItem(
          value: _UserAction.delete.name,
          icon: Icons.delete_outline_rounded,
          label: 'Delete account',
          enabled: !isSelf,
          danger: true,
        ),
      ],
      icon: const Icon(Icons.more_horiz_rounded, size: 18),
      iconSize: 18,
    );
  }

  PopupMenuItem<String> _menuItem({
    required String value,
    required IconData icon,
    required String label,
    bool enabled = true,
    bool danger = false,
  }) => PopupMenuItem<String>(
    value: value,
    enabled: enabled,
    child: Opacity(
      opacity: enabled ? 1.0 : 0.4,
      child: Row(
        children: [
          Icon(
            icon,
            size: 16,
            color: danger ? AppColors.danger : null,
          ),
          const SizedBox(width: 10),
          Text(
            label,
            style: GoogleFonts.inter(
              fontSize: 13,
              fontWeight: FontWeight.w500,
              color: danger ? AppColors.danger : null,
            ),
          ),
        ],
      ),
    ),
  );
}

// ─── EditUserDialog ───────────────────────────────────────────────────────────

class _EditUserDialog extends StatelessWidget {
  const _EditUserDialog({required this.user, required this.controller});

  final AdminUser user;
  final TextEditingController controller;

  @override
  Widget build(BuildContext context) {
    final border = Theme.of(context).dividerColor;
    final cs = Theme.of(context).colorScheme;

    return Dialog(
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 480),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(24, 24, 24, 0),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'Edit user',
                    style: Theme.of(context).textTheme.titleLarge?.copyWith(
                      fontWeight: FontWeight.w700,
                      letterSpacing: -0.3,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    user.email ?? user.uid,
                    style: GoogleFonts.inter(
                      fontSize: 12.5,
                      color: cs.onSurfaceVariant,
                    ),
                  ),
                  const SizedBox(height: 20),
                  TextField(
                    controller: controller,
                    autofocus: true,
                    maxLength: 256,
                    decoration: const InputDecoration(
                      labelText: 'Display name',
                      helperText: 'Leave empty to clear the display name.',
                    ),
                    onSubmitted: (text) => Navigator.pop(context, text),
                  ),
                  const SizedBox(height: 24),
                ],
              ),
            ),
            Divider(height: 0.5, color: border),
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 14),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.end,
                children: [
                  TextButton(
                    onPressed: () => Navigator.pop(context),
                    child: const Text('Cancel'),
                  ),
                  const SizedBox(width: 8),
                  FilledButton(
                    onPressed: () => Navigator.pop(context, controller.text),
                    child: const Text('Save'),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}
