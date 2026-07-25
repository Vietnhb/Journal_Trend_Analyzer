import 'package:flutter/material.dart';

import 'core/core.dart';
import 'features/auth/auth_gate.dart';
import 'theme/app_theme.dart';
import 'utils/ui_format.dart';

class JournalAdminApp extends StatefulWidget {
  const JournalAdminApp({required this.appCheckEnabled, super.key});

  final bool appCheckEnabled;

  @override
  State<JournalAdminApp> createState() => _JournalAdminAppState();
}

class _JournalAdminAppState extends State<JournalAdminApp> {
  ThemeMode _themeMode = ThemeMode.system;
  late final AdminAuthService _auth;
  late final ApiClient _client;
  late final AdminApi _api;
  late final AdminSessionService _sessions;

  @override
  void initState() {
    super.initState();
    _auth = AdminAuthService(appCheckEnabled: widget.appCheckEnabled);
    _client = ApiClient(
      idTokenProvider: _auth.idToken,
      appCheckTokenProvider: widget.appCheckEnabled
          ? _auth.appCheckToken
          : null,
    );
    _api = AdminApi(
      _client,
      analyticsTokenProvider: _auth.analyticsAccessToken,
    );
    _sessions = AdminSessionService(auth: _auth, api: _api);
  }

  @override
  void dispose() {
    _client.close();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => MaterialApp(
    title: 'Journal Trend Observatory',
    debugShowCheckedModeBanner: false,
    theme: AppTheme.light(),
    darkTheme: AppTheme.dark(),
    themeMode: _themeMode,
    home: AuthGate(
      api: _api,
      sessions: _sessions,
      themeMode: _themeMode,
      onToggleTheme: () => setState(() {
        final platformBrightness =
            WidgetsBinding.instance.platformDispatcher.platformBrightness;
        final currentlyDark =
            _themeMode == ThemeMode.dark ||
            (_themeMode == ThemeMode.system &&
                platformBrightness == Brightness.dark);
        _themeMode = currentlyDark ? ThemeMode.light : ThemeMode.dark;
      }),
    ),
  );
}

class AdminBootstrapFailure extends StatelessWidget {
  const AdminBootstrapFailure({required this.error, super.key});

  final Object error;

  @override
  Widget build(BuildContext context) => MaterialApp(
    title: 'Journal Trend Observatory',
    debugShowCheckedModeBanner: false,
    theme: AppTheme.light(),
    darkTheme: AppTheme.dark(),
    home: Scaffold(
      body: Center(
        child: Card(
          margin: const EdgeInsets.all(24),
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 560),
            child: Padding(
              padding: const EdgeInsets.all(28),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  const Icon(
                    Icons.cloud_off_rounded,
                    size: 52,
                    color: AppTheme.danger,
                  ),
                  const SizedBox(height: 18),
                  Text(
                    'Unable to initialize Firebase',
                    style: Theme.of(context).textTheme.headlineSmall?.copyWith(
                      fontWeight: FontWeight.w900,
                    ),
                  ),
                  const SizedBox(height: 10),
                  const Text(
                    'Check your network connection, Web App configuration, and authorized domains in Firebase Console.',
                    textAlign: TextAlign.center,
                  ),
                  const SizedBox(height: 14),
                  SelectableText(
                    errorText(error),
                    textAlign: TextAlign.center,
                    style: TextStyle(
                      color: Theme.of(context).colorScheme.onSurfaceVariant,
                      fontFamily: 'monospace',
                      fontSize: 12,
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    ),
  );
}
