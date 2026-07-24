import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
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
      builder: (dialogContext) => AlertDialog(
        title: const Text('Chỉnh sửa người dùng'),
        content: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 460),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Text(user.email ?? user.uid),
              const SizedBox(height: 18),
              TextField(
                controller: controller,
                autofocus: true,
                maxLength: 256,
                decoration: const InputDecoration(
                  labelText: 'Tên hiển thị',
                  helperText: 'Để trống nếu muốn xóa tên hiển thị.',
                ),
                onSubmitted: (text) => Navigator.pop(dialogContext, text),
              ),
            ],
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(dialogContext),
            child: const Text('Hủy'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(dialogContext, controller.text),
            child: const Text('Lưu thay đổi'),
          ),
        ],
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
    }, 'Đã cập nhật hồ sơ người dùng.');
  }

  Future<void> _action(AdminUser user, _UserAction action) async {
    final self = user.uid == widget.currentUid;
    if (self && action != _UserAction.revoke) {
      showAppMessage(
        context,
        'Bạn không thể thực hiện thao tác này trên chính mình.',
        error: true,
      );
      return;
    }
    final target = user.email ?? user.uid;
    final config = switch (action) {
      _UserAction.toggleRole => (
        title: user.isAdmin ? 'Thu hồi quyền Admin?' : 'Cấp quyền Admin?',
        description: user.isAdmin
            ? 'Tài khoản sẽ mất quyền truy cập trang quản trị và các phiên hiện có bị thu hồi.'
            : 'Tài khoản sẽ được phép thực hiện mọi thao tác quản trị đặc quyền.',
        label: user.isAdmin ? 'Thu hồi quyền' : 'Cấp quyền',
        danger: user.isAdmin,
      ),
      _UserAction.toggleStatus => (
        title: user.disabled ? 'Mở khóa tài khoản?' : 'Khóa tài khoản?',
        description: user.disabled
            ? 'Người dùng có thể đăng nhập lại sau khi tài khoản được mở khóa.'
            : 'Người dùng sẽ không thể tạo phiên đăng nhập Firebase mới.',
        label: user.disabled ? 'Mở khóa' : 'Khóa tài khoản',
        danger: !user.disabled,
      ),
      _UserAction.revoke => (
        title: 'Thu hồi mọi phiên đăng nhập?',
        description:
            'Refresh token hiện có sẽ bị vô hiệu hóa. Người dùng cần đăng nhập lại.',
        label: 'Thu hồi phiên',
        danger: true,
      ),
      _UserAction.delete => (
        title: 'Xóa vĩnh viễn tài khoản?',
        description:
            'Tài khoản Firebase Auth sẽ bị xóa. Báo cáo trong Storage không tự động bị xóa theo.',
        label: 'Xóa tài khoản',
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
          user.isAdmin ? 'Đã thu hồi quyền Admin.' : 'Đã cấp quyền Admin.',
        );
      case _UserAction.toggleStatus:
        await _run(
          user.uid,
          () => widget.api.updateUser(
            user.uid,
            UserUpdate(disabled: !user.disabled),
          ),
          user.disabled ? 'Đã mở khóa tài khoản.' : 'Đã khóa tài khoản.',
        );
      case _UserAction.revoke:
        await _run(
          user.uid,
          () => widget.api.revokeUserSessions(user.uid),
          'Đã thu hồi các phiên đăng nhập.',
        );
      case _UserAction.delete:
        await _run(
          user.uid,
          () => widget.api.deleteUser(user.uid),
          'Đã xóa tài khoản Firebase Auth.',
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
        title: 'Quản lý người dùng',
        description:
            'Tra cứu chính xác theo email, số điện thoại hoặc UID, quản lý trạng thái tài khoản và custom claim Admin.',
        actions: [
          OutlinedButton.icon(
            onPressed: _refresh,
            icon: const Icon(Icons.refresh_rounded),
            label: const Text('Làm mới'),
          ),
        ],
      ),
      SectionCard(
        padding: EdgeInsets.zero,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Padding(
              padding: const EdgeInsets.all(20),
              child: LayoutBuilder(
                builder: (context, constraints) {
                  final search = TextField(
                    controller: _searchController,
                    decoration: InputDecoration(
                      prefixIcon: const Icon(Icons.search_rounded),
                      hintText: 'Email, số điện thoại +84… hoặc UID…',
                      suffixIcon: _searchController.text.isEmpty
                          ? null
                          : IconButton(
                              tooltip: 'Xóa từ khóa',
                              onPressed: () {
                                _searchController.clear();
                                setState(() {});
                              },
                              icon: const Icon(Icons.close_rounded),
                            ),
                    ),
                    onChanged: (_) => setState(() {}),
                    onSubmitted: (_) => _search(),
                  );
                  final button = FilledButton.icon(
                    onPressed: _search,
                    icon: const Icon(Icons.search_rounded),
                    label: const Text('Tìm kiếm'),
                  );
                  if (constraints.maxWidth < 620) {
                    return Column(
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [search, const SizedBox(height: 10), button],
                    );
                  }
                  return Row(
                    children: [
                      Expanded(child: search),
                      const SizedBox(width: 10),
                      button,
                      const SizedBox(width: 14),
                      const StatusPill(
                        'Role từ custom claims',
                        tone: StatusTone.purple,
                        icon: Icons.key_rounded,
                      ),
                    ],
                  );
                },
              ),
            ),
            const Divider(height: 1),
            FutureBuilder<UserPage>(
              future: _future,
              builder: (context, snapshot) {
                if (snapshot.connectionState != ConnectionState.done) {
                  return const LoadingPanel();
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
                        ? 'Chưa có người dùng'
                        : 'Không tìm thấy tài khoản',
                    description: _query.isEmpty
                        ? 'Tài khoản sẽ xuất hiện sau lần đăng nhập Firebase đầu tiên.'
                        : 'Không có email, số điện thoại hoặc UID khớp “$_query”.',
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
                    if (_page > 0 || data.nextPageToken != null)
                      Padding(
                        padding: const EdgeInsets.all(18),
                        child: Row(
                          mainAxisAlignment: MainAxisAlignment.end,
                          children: [
                            OutlinedButton.icon(
                              onPressed: _page == 0 || _busyUid != null
                                  ? null
                                  : () => setState(() {
                                      _page--;
                                      _load();
                                    }),
                              icon: const Icon(Icons.chevron_left_rounded),
                              label: const Text('Trước'),
                            ),
                            Padding(
                              padding: const EdgeInsets.symmetric(
                                horizontal: 16,
                              ),
                              child: Text('Trang ${_page + 1}'),
                            ),
                            OutlinedButton.icon(
                              onPressed:
                                  data.nextPageToken == null || _busyUid != null
                                  ? null
                                  : () => setState(() {
                                      if (_tokens.length == _page + 1) {
                                        _tokens.add(data.nextPageToken);
                                      } else {
                                        _tokens[_page + 1] = data.nextPageToken;
                                      }
                                      _page++;
                                      _load();
                                    }),
                              iconAlignment: IconAlignment.end,
                              icon: const Icon(Icons.chevron_right_rounded),
                              label: const Text('Sau'),
                            ),
                          ],
                        ),
                      ),
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

enum _UserAction { toggleRole, toggleStatus, revoke, delete }

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
  Widget build(BuildContext context) => SingleChildScrollView(
    scrollDirection: Axis.horizontal,
    child: DataTable(
      columns: const [
        DataColumn(label: Text('NGƯỜI DÙNG')),
        DataColumn(label: Text('UID')),
        DataColumn(label: Text('VAI TRÒ')),
        DataColumn(label: Text('TRẠNG THÁI')),
        DataColumn(label: Text('PROVIDER')),
        DataColumn(label: Text('NGÀY TẠO')),
        DataColumn(label: Text('ĐĂNG NHẬP GẦN NHẤT')),
        DataColumn(label: Text('')),
      ],
      rows: [
        for (final user in users)
          DataRow(
            cells: [
              DataCell(SizedBox(width: 260, child: _UserIdentity(user: user))),
              DataCell(_UidValue(uid: user.uid)),
              DataCell(
                user.isAdmin
                    ? const StatusPill(
                        'Admin',
                        tone: StatusTone.purple,
                        icon: Icons.shield_outlined,
                      )
                    : const StatusPill('User'),
              ),
              DataCell(
                StatusPill(
                  user.disabled ? 'Đã khóa' : 'Hoạt động',
                  tone: user.disabled ? StatusTone.danger : StatusTone.success,
                ),
              ),
              DataCell(
                SizedBox(
                  width: 120,
                  child: Text(
                    user.providers.isEmpty ? '—' : user.providers.join(', '),
                  ),
                ),
              ),
              DataCell(
                SizedBox(
                  width: 150,
                  child: Text(formatDateTime(user.createdAt)),
                ),
              ),
              DataCell(
                SizedBox(
                  width: 150,
                  child: Text(formatDateTime(user.lastSignInAt)),
                ),
              ),
              DataCell(
                _UserMenu(
                  user: user,
                  isSelf: user.uid == currentUid,
                  busy: busyUid == user.uid,
                  onEdit: onEdit,
                  onAction: onAction,
                ),
              ),
            ],
          ),
      ],
    ),
  );
}

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
  Widget build(BuildContext context) => ListView.separated(
    padding: const EdgeInsets.all(16),
    shrinkWrap: true,
    physics: const NeverScrollableScrollPhysics(),
    itemCount: users.length,
    separatorBuilder: (_, _) => const SizedBox(height: 10),
    itemBuilder: (context, index) {
      final user = users[index];
      return DecoratedBox(
        decoration: BoxDecoration(
          border: Border.all(color: Theme.of(context).dividerColor),
          borderRadius: BorderRadius.circular(14),
        ),
        child: Padding(
          padding: const EdgeInsets.all(15),
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
              const SizedBox(height: 13),
              Wrap(
                spacing: 7,
                runSpacing: 7,
                children: [
                  StatusPill(
                    user.isAdmin ? 'Admin' : 'User',
                    tone: user.isAdmin ? StatusTone.purple : StatusTone.neutral,
                  ),
                  StatusPill(
                    user.disabled ? 'Đã khóa' : 'Hoạt động',
                    tone: user.disabled
                        ? StatusTone.danger
                        : StatusTone.success,
                  ),
                  StatusPill(
                    user.emailVerified ? 'Đã xác minh' : 'Chưa xác minh',
                  ),
                ],
              ),
              const SizedBox(height: 11),
              _CardDetail(
                label: 'UID',
                child: _UidValue(uid: user.uid),
              ),
              const SizedBox(height: 7),
              _CardDetail(
                label: 'Ngày tạo',
                child: Text(formatDateTime(user.createdAt)),
              ),
              const SizedBox(height: 7),
              Text(
                'Đăng nhập gần nhất: ${formatDateTime(user.lastSignInAt)}',
                style: Theme.of(context).textTheme.bodySmall,
              ),
            ],
          ),
        ),
      );
    },
  );
}

class _UserIdentity extends StatelessWidget {
  const _UserIdentity({required this.user});
  final AdminUser user;

  @override
  Widget build(BuildContext context) => Row(
    children: [
      CircleAvatar(
        radius: 20,
        backgroundColor: Theme.of(context).colorScheme.primaryContainer,
        backgroundImage: user.photoUrl == null
            ? null
            : NetworkImage(user.photoUrl!),
        child: user.photoUrl == null
            ? Text(
                initials(user.displayName, user.email),
                style: const TextStyle(fontWeight: FontWeight.w900),
              )
            : null,
      ),
      const SizedBox(width: 11),
      Expanded(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              user.displayName?.trim().isNotEmpty == true
                  ? user.displayName!
                  : 'Chưa đặt tên',
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: const TextStyle(fontWeight: FontWeight.w800),
            ),
            Text(
              user.email ??
                  user.phoneNumber ??
                  'Không có email hoặc số điện thoại',
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: TextStyle(
                color: Theme.of(context).colorScheme.onSurfaceVariant,
                fontSize: 12,
              ),
            ),
          ],
        ),
      ),
    ],
  );
}

class _UidValue extends StatelessWidget {
  const _UidValue({required this.uid});

  final String uid;

  Future<void> _copy(BuildContext context) async {
    await Clipboard.setData(ClipboardData(text: uid));
    if (context.mounted) showAppMessage(context, 'Đã sao chép UID.');
  }

  @override
  Widget build(BuildContext context) => Row(
    mainAxisSize: MainAxisSize.min,
    children: [
      Tooltip(
        message: uid,
        child: Text(
          truncateMiddle(uid, keep: 6),
          style: TextStyle(
            color: Theme.of(context).colorScheme.onSurfaceVariant,
            fontFamily: 'monospace',
            fontSize: 11,
          ),
        ),
      ),
      IconButton(
        tooltip: 'Sao chép UID',
        visualDensity: VisualDensity.compact,
        onPressed: () => _copy(context),
        icon: const Icon(Icons.copy_rounded, size: 17),
      ),
    ],
  );
}

class _CardDetail extends StatelessWidget {
  const _CardDetail({required this.label, required this.child});

  final String label;
  final Widget child;

  @override
  Widget build(BuildContext context) => Row(
    crossAxisAlignment: CrossAxisAlignment.center,
    children: [
      SizedBox(
        width: 72,
        child: Text(label, style: Theme.of(context).textTheme.bodySmall),
      ),
      Expanded(
        child: Align(alignment: Alignment.centerLeft, child: child),
      ),
    ],
  );
}

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
        child: SizedBox.square(
          dimension: 20,
          child: CircularProgressIndicator(strokeWidth: 2),
        ),
      );
    }
    return PopupMenuButton<String>(
      tooltip: 'Thao tác',
      onSelected: (value) {
        if (value == 'edit') return onEdit(user);
        final action = _UserAction.values.byName(value);
        onAction(user, action);
      },
      itemBuilder: (context) => [
        const PopupMenuItem(
          value: 'edit',
          child: ListTile(
            dense: true,
            leading: Icon(Icons.edit_outlined),
            title: Text('Sửa tên hiển thị'),
          ),
        ),
        PopupMenuItem(
          value: _UserAction.toggleStatus.name,
          enabled: !isSelf,
          child: ListTile(
            dense: true,
            leading: Icon(
              user.disabled
                  ? Icons.lock_open_rounded
                  : Icons.lock_outline_rounded,
            ),
            title: Text(user.disabled ? 'Mở khóa' : 'Khóa tài khoản'),
          ),
        ),
        PopupMenuItem(
          value: _UserAction.toggleRole.name,
          enabled: !isSelf,
          child: ListTile(
            dense: true,
            leading: Icon(
              user.isAdmin
                  ? Icons.shield_outlined
                  : Icons.add_moderator_outlined,
            ),
            title: Text(user.isAdmin ? 'Thu hồi Admin' : 'Cấp Admin'),
          ),
        ),
        PopupMenuItem(
          value: _UserAction.revoke.name,
          child: const ListTile(
            dense: true,
            leading: Icon(Icons.logout_rounded),
            title: Text('Thu hồi phiên'),
          ),
        ),
        PopupMenuItem(
          value: _UserAction.delete.name,
          enabled: !isSelf,
          child: const ListTile(
            dense: true,
            leading: Icon(Icons.delete_outline_rounded, color: AppTheme.danger),
            title: Text(
              'Xóa tài khoản',
              style: TextStyle(color: AppTheme.danger),
            ),
          ),
        ),
      ],
      icon: const Icon(Icons.more_horiz_rounded),
    );
  }
}
