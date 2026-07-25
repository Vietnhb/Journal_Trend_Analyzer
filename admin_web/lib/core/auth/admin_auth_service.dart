import 'package:firebase_app_check/firebase_app_check.dart';
import 'package:firebase_auth/firebase_auth.dart';

import 'analytics_token_store.dart';

// App Check keys are injected by the deployment build, never read at runtime.
// ignore: do_not_use_environment
const _legacyAppCheckSiteKey = String.fromEnvironment(
  'FIREBASE_APP_CHECK_SITE_KEY',
);
// ignore: do_not_use_environment
const appCheckSiteKey = String.fromEnvironment(
  'APP_CHECK_SITE_KEY',
  defaultValue: _legacyAppCheckSiteKey,
);
const firebaseAppCheckSiteKey = appCheckSiteKey;
const firebaseAppCheckConfigured = appCheckSiteKey != '';

final class AdminAuthService {
  AdminAuthService({
    FirebaseAuth? firebaseAuth,
    FirebaseAppCheck? firebaseAppCheck,
    this.appCheckEnabled = firebaseAppCheckConfigured,
  }) : _auth = firebaseAuth ?? FirebaseAuth.instance,
       _appCheck = firebaseAppCheck ?? FirebaseAppCheck.instance {
    _restoreAnalyticsToken();
  }

  final FirebaseAuth _auth;
  final FirebaseAppCheck _appCheck;
  final bool appCheckEnabled;
  String? _analyticsAccessToken;
  DateTime? _analyticsAccessTokenExpiresAt;

  static const _analyticsTokenKey = 'admin.analytics.access_token';
  static const _analyticsTokenExpiryKey = 'admin.analytics.access_token_expiry';

  User? get currentUser => _auth.currentUser;

  Stream<User?> get authStateChanges => _auth.authStateChanges();

  Stream<User?> get idTokenChanges => _auth.idTokenChanges();

  Future<UserCredential> signInWithGoogle() async {
    final provider = GoogleAuthProvider()
      ..addScope('https://www.googleapis.com/auth/analytics.readonly')
      ..setCustomParameters(const {'prompt': 'select_account'});
    try {
      final result = await _auth.signInWithPopup(provider);
      _captureAnalyticsToken(result);
      return result;
    } on FirebaseAuthException catch (error) {
      throw AdminAuthException(
        code: error.code,
        message: friendlyFirebaseAuthMessage(error.code),
        cause: error,
      );
    }
  }

  Future<String?> analyticsAccessToken({bool interactive = false}) async {
    if (_analyticsAccessTokenExpiresAt?.isBefore(DateTime.now()) == true) {
      _clearAnalyticsToken();
    }
    final cached = _analyticsAccessToken;
    if (cached != null && cached.isNotEmpty) return cached;
    if (!interactive) return null;

    final user = _auth.currentUser;
    if (user == null) {
      throw const AdminAuthException(
        code: 'auth_required',
        message: 'Sign in to connect Google Analytics.',
      );
    }
    final provider = GoogleAuthProvider()
      ..addScope('https://www.googleapis.com/auth/analytics.readonly')
      ..setCustomParameters(const {'prompt': 'consent'});
    try {
      final result = await user.reauthenticateWithPopup(provider);
      _captureAnalyticsToken(result);
      return _analyticsAccessToken;
    } on FirebaseAuthException catch (error) {
      throw AdminAuthException(
        code: error.code,
        message: friendlyFirebaseAuthMessage(error.code),
        cause: error,
      );
    }
  }

  void _captureAnalyticsToken(UserCredential result) {
    final credential = result.credential;
    if (credential is OAuthCredential) {
      final token = credential.accessToken?.trim();
      if (token != null && token.isNotEmpty) {
        final expiresAt = DateTime.now().add(const Duration(minutes: 50));
        _analyticsAccessToken = token;
        _analyticsAccessTokenExpiresAt = expiresAt;
        writeSessionValue(_analyticsTokenKey, token);
        writeSessionValue(
          _analyticsTokenExpiryKey,
          expiresAt.toUtc().toIso8601String(),
        );
      }
    }
  }

  void _restoreAnalyticsToken() {
    final token = readSessionValue(_analyticsTokenKey)?.trim();
    final expiresAt = DateTime.tryParse(
      readSessionValue(_analyticsTokenExpiryKey) ?? '',
    );
    if (token == null ||
        token.isEmpty ||
        expiresAt == null ||
        expiresAt.isBefore(DateTime.now())) {
      _clearAnalyticsToken();
      return;
    }
    _analyticsAccessToken = token;
    _analyticsAccessTokenExpiresAt = expiresAt;
  }

  void _clearAnalyticsToken() {
    _analyticsAccessToken = null;
    _analyticsAccessTokenExpiresAt = null;
    removeSessionValue(_analyticsTokenKey);
    removeSessionValue(_analyticsTokenExpiryKey);
  }

  Future<void> signOut() async {
    _clearAnalyticsToken();
    await _auth.signOut();
  }

  Future<String?> idToken({bool forceRefresh = false}) =>
      _auth.currentUser?.getIdToken(forceRefresh) ?? Future.value();

  Future<String?> appCheckToken({bool forceRefresh = false}) {
    if (!appCheckEnabled) return Future.value();
    return _appCheck.getToken(forceRefresh);
  }
}

final class AdminAuthException implements Exception {
  const AdminAuthException({
    required this.code,
    required this.message,
    this.cause,
  });

  final String code;
  final String message;
  final Object? cause;

  String get userMessage => message;

  @override
  String toString() => 'AdminAuthException(code: $code, message: $message)';
}

String friendlyFirebaseAuthMessage(String code) {
  if (code.contains('popup-closed-by-user')) {
    return 'The sign-in window was closed before authentication completed.';
  }
  if (code.contains('popup-blocked')) {
    return 'Your browser blocked the sign-in window. Allow pop-ups and try again.';
  }
  if (code.contains('unauthorized-domain')) {
    return 'This domain is not listed in Firebase Auth Authorized domains.';
  }
  if (code.contains('network-request-failed')) {
    return 'Unable to reach Firebase Auth. Check your network and try again.';
  }
  if (code.contains('user-disabled')) {
    return 'This account has been disabled.';
  }
  return 'Unable to sign in with Google. Check the Firebase configuration.';
}
