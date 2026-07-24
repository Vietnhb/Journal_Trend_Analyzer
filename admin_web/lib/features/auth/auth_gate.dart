import 'package:flutter/material.dart';
import 'package:journal_trend_admin_web/core/core.dart';

import '../../shell/admin_shell.dart';
import '../../theme/app_theme.dart';
import '../../utils/ui_format.dart';

class AuthGate extends StatefulWidget {
  const AuthGate({
    required this.api,
    required this.sessions,
    required this.themeMode,
    required this.onToggleTheme,
    super.key,
  });

  final AdminApi api;
  final AdminSessionService sessions;
  final ThemeMode themeMode;
  final VoidCallback onToggleTheme;

  @override
  State<AuthGate> createState() => _AuthGateState();
}

class _AuthGateState extends State<AuthGate> {
  AdminSession? _session;
  Object? _error;
  bool _loading = true;

  @override
  void initState() {
    super.initState();
    _restore();
  }

  Future<void> _restore() async {
    setState(() {
      _loading = true;
      _error = null;
    });
    try {
      final session = await widget.sessions.restore();
      if (!mounted) return;
      setState(() => _session = session);
    } catch (error) {
      if (!mounted) return;
      setState(() => _error = error);
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  Future<void> _signIn() async {
    setState(() {
      _loading = true;
      _error = null;
    });
    try {
      final session = await widget.sessions.signInWithGoogle();
      if (!mounted) return;
      setState(() => _session = session);
    } catch (error) {
      if (!mounted) return;
      setState(() => _error = error);
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  Future<void> _signOut() async {
    await widget.sessions.signOut();
    if (mounted) {
      setState(() {
        _session = null;
        _error = null;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final session = _session;
    if (session != null) {
      return AdminShell(
        api: widget.api,
        session: session,
        onSignOut: _signOut,
        onToggleTheme: widget.onToggleTheme,
      );
    }
    return _LoginPage(
      loading: _loading,
      error: _error,
      onSignIn: _signIn,
      onToggleTheme: widget.onToggleTheme,
    );
  }
}

class _LoginPage extends StatelessWidget {
  const _LoginPage({
    required this.loading,
    required this.error,
    required this.onSignIn,
    required this.onToggleTheme,
  });

  final bool loading;
  final Object? error;
  final VoidCallback onSignIn;
  final VoidCallback onToggleTheme;

  @override
  Widget build(BuildContext context) => Scaffold(
    body: Stack(
      children: [
        Positioned.fill(
          child: DecoratedBox(
            decoration: BoxDecoration(
              gradient: LinearGradient(
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
                colors: Theme.of(context).brightness == Brightness.dark
                    ? const [Color(0xFF070B15), Color(0xFF111B31)]
                    : const [Color(0xFFF8FAFF), Color(0xFFEFF4FF)],
              ),
            ),
          ),
        ),
        Positioned(
          top: -100,
          right: -70,
          child: _Glow(color: AppTheme.brand.withValues(alpha: .16), size: 380),
        ),
        Positioned(
          bottom: -140,
          left: -90,
          child: _Glow(
            color: AppTheme.accent.withValues(alpha: .12),
            size: 420,
          ),
        ),
        SafeArea(
          child: Align(
            alignment: Alignment.topRight,
            child: Padding(
              padding: const EdgeInsets.all(18),
              child: IconButton.filledTonal(
                tooltip: 'Đổi giao diện sáng/tối',
                onPressed: onToggleTheme,
                icon: Icon(
                  Theme.of(context).brightness == Brightness.dark
                      ? Icons.light_mode_outlined
                      : Icons.dark_mode_outlined,
                ),
              ),
            ),
          ),
        ),
        Center(
          child: SingleChildScrollView(
            padding: const EdgeInsets.all(24),
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 1050),
              child: LayoutBuilder(
                builder: (context, constraints) {
                  final introduction = _LoginIntroduction();
                  final card = _SignInCard(
                    loading: loading,
                    error: error,
                    onSignIn: onSignIn,
                  );
                  if (constraints.maxWidth < 760) {
                    return Column(
                      children: [
                        introduction,
                        const SizedBox(height: 30),
                        card,
                      ],
                    );
                  }
                  return Row(
                    children: [
                      Expanded(flex: 6, child: introduction),
                      const SizedBox(width: 60),
                      Expanded(flex: 4, child: card),
                    ],
                  );
                },
              ),
            ),
          ),
        ),
      ],
    ),
  );
}

class _LoginIntroduction extends StatelessWidget {
  @override
  Widget build(BuildContext context) => Column(
    crossAxisAlignment: CrossAxisAlignment.start,
    children: [
      const _BrandMark(),
      const SizedBox(height: 30),
      Text(
        'Trang quản trị\nJournal Trend',
        style: Theme.of(context).textTheme.displaySmall?.copyWith(
          fontWeight: FontWeight.w900,
          letterSpacing: -1.4,
          height: 1.12,
        ),
      ),
      const SizedBox(height: 18),
      ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 570),
        child: Text(
          'Theo dõi người dùng, cấu hình và hoạt động của ứng dụng tại một nơi.',
          style: Theme.of(context).textTheme.titleMedium?.copyWith(
            color: Theme.of(context).colorScheme.onSurfaceVariant,
            fontWeight: FontWeight.w400,
            height: 1.55,
          ),
        ),
      ),
      const SizedBox(height: 28),
      const Wrap(
        spacing: 10,
        runSpacing: 10,
        children: [
          _FeatureChip(
            icon: Icons.people_alt_outlined,
            label: 'Authentication',
          ),
          _FeatureChip(icon: Icons.tune_rounded, label: 'Remote Config'),
          _FeatureChip(icon: Icons.cloud_outlined, label: 'Storage'),
          _FeatureChip(icon: Icons.query_stats_rounded, label: 'Analytics'),
          _FeatureChip(icon: Icons.bug_report_outlined, label: 'Crashlytics'),
        ],
      ),
    ],
  );
}

class _SignInCard extends StatelessWidget {
  const _SignInCard({
    required this.loading,
    required this.error,
    required this.onSignIn,
  });

  final bool loading;
  final Object? error;
  final VoidCallback onSignIn;

  @override
  Widget build(BuildContext context) => Card(
    child: Padding(
      padding: const EdgeInsets.all(30),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          CircleAvatar(
            radius: 25,
            backgroundColor: AppTheme.brand.withValues(alpha: .1),
            child: const Icon(
              Icons.admin_panel_settings_outlined,
              color: AppTheme.brand,
            ),
          ),
          const SizedBox(height: 20),
          Text(
            'Đăng nhập quản trị',
            textAlign: TextAlign.center,
            style: Theme.of(
              context,
            ).textTheme.headlineSmall?.copyWith(fontWeight: FontWeight.w900),
          ),
          const SizedBox(height: 8),
          Text(
            'Sử dụng tài khoản Google đã được cấp quyền quản trị.',
            textAlign: TextAlign.center,
            style: TextStyle(
              color: Theme.of(context).colorScheme.onSurfaceVariant,
              height: 1.45,
            ),
          ),
          if (error != null) ...[
            const SizedBox(height: 18),
            DecoratedBox(
              decoration: BoxDecoration(
                color: AppTheme.danger.withValues(alpha: .08),
                borderRadius: BorderRadius.circular(12),
                border: Border.all(
                  color: AppTheme.danger.withValues(alpha: .2),
                ),
              ),
              child: Padding(
                padding: const EdgeInsets.all(12),
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Icon(
                      Icons.error_outline_rounded,
                      color: AppTheme.danger,
                      size: 19,
                    ),
                    const SizedBox(width: 9),
                    Expanded(
                      child: Text(
                        _loginError(error!),
                        style: const TextStyle(
                          color: AppTheme.danger,
                          fontSize: 12,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ],
          const SizedBox(height: 24),
          FilledButton.icon(
            onPressed: loading ? null : onSignIn,
            icon: loading
                ? const SizedBox.square(
                    dimension: 18,
                    child: CircularProgressIndicator(strokeWidth: 2),
                  )
                : const Icon(Icons.login_rounded),
            label: Text(loading ? 'Đang đăng nhập…' : 'Đăng nhập với Google'),
          ),
          const SizedBox(height: 14),
          Text(
            _isLocalDevelopment
                ? 'Local dùng Functions Emulator tại cổng 5001. Cảnh báo COOP của Flutter dev server không làm hỏng đăng nhập.'
                : 'Phiên đăng nhập được xác thực qua Firebase.',
            textAlign: TextAlign.center,
            style: TextStyle(
              color: Theme.of(context).colorScheme.outline,
              fontSize: 11,
            ),
          ),
        ],
      ),
    ),
  );

  bool get _isLocalDevelopment =>
      Uri.base.host == 'localhost' || Uri.base.host == '127.0.0.1';

  String _loginError(Object error) {
    if (_isLocalDevelopment &&
        error is ApiException &&
        (error.code == 'network_error' || error.code == 'request_timeout')) {
      return 'Không kết nối được Functions Emulator tại 127.0.0.1:5001. '
          'Hãy chạy: npx firebase-tools emulators:start --only functions';
    }
    return errorText(error);
  }
}

class _FeatureChip extends StatelessWidget {
  const _FeatureChip({required this.icon, required this.label});
  final IconData icon;
  final String label;

  @override
  Widget build(BuildContext context) => Chip(
    avatar: Icon(icon, size: 17, color: Theme.of(context).colorScheme.primary),
    label: Text(label, style: const TextStyle(fontWeight: FontWeight.w700)),
  );
}

class _Glow extends StatelessWidget {
  const _Glow({required this.color, required this.size});
  final Color color;
  final double size;

  @override
  Widget build(BuildContext context) => Container(
    width: size,
    height: size,
    decoration: BoxDecoration(
      shape: BoxShape.circle,
      gradient: RadialGradient(colors: [color, color.withValues(alpha: 0)]),
    ),
  );
}

class _BrandMark extends StatelessWidget {
  const _BrandMark();

  @override
  Widget build(BuildContext context) => Row(
    mainAxisSize: MainAxisSize.min,
    children: [
      DecoratedBox(
        decoration: BoxDecoration(
          gradient: const LinearGradient(
            colors: [AppTheme.brand, AppTheme.accent],
          ),
          borderRadius: BorderRadius.circular(13),
        ),
        child: const Padding(
          padding: EdgeInsets.all(10),
          child: Icon(Icons.auto_graph_rounded, color: Colors.white, size: 23),
        ),
      ),
      const SizedBox(width: 12),
      Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'JOURNAL TREND',
            style: Theme.of(context).textTheme.titleSmall?.copyWith(
              fontWeight: FontWeight.w900,
              letterSpacing: .6,
            ),
          ),
          Text(
            'ADMIN CONSOLE',
            style: TextStyle(
              color: Theme.of(context).colorScheme.primary,
              fontSize: 10,
              fontWeight: FontWeight.w800,
              letterSpacing: 1.4,
            ),
          ),
        ],
      ),
    ],
  );
}
