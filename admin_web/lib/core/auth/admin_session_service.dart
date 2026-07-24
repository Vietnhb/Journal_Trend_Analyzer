import 'package:firebase_auth/firebase_auth.dart';

import '../api/admin_api.dart';
import '../api/api_exception.dart';
import '../models/admin_identity.dart';
import 'admin_auth_service.dart';

final class AdminSession {
  const AdminSession({required this.firebaseUser, required this.identity});

  final User firebaseUser;
  final AdminIdentity identity;
}

final class AdminSessionService {
  const AdminSessionService({
    required AdminAuthService auth,
    required AdminApi api,
  }) : _auth = auth,
       _api = api;

  final AdminAuthService _auth;
  final AdminApi _api;

  Stream<User?> get authStateChanges => _auth.authStateChanges;

  Future<AdminSession?> restore() async {
    final user = _auth.currentUser;
    if (user == null) return null;
    final analyticsToken = await _auth.analyticsAccessToken();
    if (analyticsToken == null) {
      await _auth.signOut();
      return null;
    }
    return _verify(user);
  }

  Future<AdminSession> signInWithGoogle() async {
    final credential = await _auth.signInWithGoogle();
    final user = credential.user;
    if (user == null) {
      throw const AdminAuthException(
        code: 'missing_user',
        message: 'Firebase không trả về tài khoản sau khi đăng nhập.',
      );
    }
    final analyticsToken = await _auth.analyticsAccessToken();
    if (analyticsToken == null) {
      await _auth.signOut();
      throw const AdminAuthException(
        code: 'analytics_oauth_required',
        message:
            'Đăng nhập chưa cấp quyền đọc Google Analytics. Hãy thử lại và chọn Cho phép.',
      );
    }
    return _verify(user);
  }

  Future<AdminSession> refresh() async {
    final user = _auth.currentUser;
    if (user == null) {
      throw const ApiException(
        status: 401,
        code: 'auth_required',
        message: 'Bạn cần đăng nhập để tiếp tục.',
      );
    }
    await user.getIdToken(true);
    return _verify(user);
  }

  Future<void> signOut() => _auth.signOut();

  Future<AdminSession> _verify(User user) async {
    try {
      final identity = await _api.getMe();
      if (!identity.isAdmin) {
        await _auth.signOut();
        throw const ApiException(
          status: 403,
          code: 'admin_required',
          message: 'Tài khoản không có quyền quản trị.',
        );
      }
      return AdminSession(firebaseUser: user, identity: identity);
    } on ApiException catch (error) {
      if (error.isUnauthorized || error.isForbidden) {
        await _auth.signOut();
      }
      rethrow;
    }
  }
}
