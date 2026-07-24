import 'package:firebase_app_check/firebase_app_check.dart';
import 'package:firebase_auth/firebase_auth.dart';

import 'analytics_token_store.dart';

const appCheckSiteKey = String.fromEnvironment(
  'APP_CHECK_SITE_KEY',
  defaultValue: String.fromEnvironment('FIREBASE_APP_CHECK_SITE_KEY'),
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
        message: 'Bạn cần đăng nhập để kết nối Google Analytics.',
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
    return 'Cửa sổ đăng nhập đã đóng trước khi hoàn tất.';
  }
  if (code.contains('popup-blocked')) {
    return 'Trình duyệt đang chặn cửa sổ đăng nhập. Hãy cho phép popup rồi thử lại.';
  }
  if (code.contains('unauthorized-domain')) {
    return 'Tên miền này chưa được thêm vào Authorized domains của Firebase Auth.';
  }
  if (code.contains('network-request-failed')) {
    return 'Không thể kết nối Firebase Auth. Hãy kiểm tra mạng và thử lại.';
  }
  if (code.contains('user-disabled')) {
    return 'Tài khoản này đã bị vô hiệu hóa.';
  }
  return 'Không thể đăng nhập bằng Google. Vui lòng kiểm tra cấu hình Firebase.';
}
