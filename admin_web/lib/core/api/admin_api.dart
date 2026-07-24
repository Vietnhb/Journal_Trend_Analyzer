import '../models/models.dart';
import '../models/json_readers.dart';
import '../files/storage_file.dart';
import 'api_client.dart';
import 'api_exception.dart';

typedef AnalyticsTokenProvider = Future<String?> Function({bool interactive});

final class AdminApi {
  const AdminApi(this._client, {AnalyticsTokenProvider? analyticsTokenProvider})
    : _analyticsTokenProvider = analyticsTokenProvider;

  final ApiClient _client;
  final AnalyticsTokenProvider? _analyticsTokenProvider;

  Future<AdminIdentity> getMe() => _client.get(
    'me',
    (data) => AdminIdentity.fromJson(readJsonMap(data, context: 'me')),
  );

  Future<OverviewData> getOverview() => _client.get(
    'overview',
    (data) => OverviewData.fromJson(readJsonMap(data, context: 'overview')),
  );

  Future<UserPage> listUsers({
    int pageSize = 50,
    String? pageToken,
    String? query,
  }) {
    _requireRange(pageSize, 1, 100, 'pageSize');
    return _client.get(
      'users',
      (data) => UserPage.fromJson(readJsonMap(data, context: 'users')),
      query: {
        'pageSize': pageSize,
        'pageToken': pageToken,
        'query': query?.trim(),
      },
    );
  }

  Future<AdminUser> updateUser(String uid, UserUpdate update) => _client.patch(
    'users/${Uri.encodeComponent(_requiredText(uid, 'uid'))}',
    update.toJson(),
    (data) => AdminUser.fromJson(readJsonMap(data, context: 'updated user')),
  );

  Future<AdminUser> setAdminRole(String uid, {required bool isAdmin}) =>
      _client.put(
        'users/${Uri.encodeComponent(_requiredText(uid, 'uid'))}/role',
        {'admin': isAdmin},
        (data) =>
            AdminUser.fromJson(readJsonMap(data, context: 'updated user')),
      );

  Future<SessionRevokeResult> revokeUserSessions(String uid) => _client.post(
    'users/${Uri.encodeComponent(_requiredText(uid, 'uid'))}/revoke',
    const <String, Object?>{},
    (data) => SessionRevokeResult.fromJson(
      readJsonMap(data, context: 'session revoke result'),
    ),
  );

  Future<UserDeleteResult> deleteUser(String uid) => _client.delete(
    'users/${Uri.encodeComponent(_requiredText(uid, 'uid'))}',
    null,
    (data) => UserDeleteResult.fromJson(
      readJsonMap(data, context: 'user delete result'),
    ),
  );

  Future<RemoteConfigData> getRemoteConfig() => _client.get(
    'remote-config',
    (data) =>
        RemoteConfigData.fromJson(readJsonMap(data, context: 'Remote Config')),
  );

  Future<RemoteConfigData> updateRemoteConfig(RemoteConfigUpdate update) =>
      _client.put(
        'remote-config',
        update.toJson(),
        (data) => RemoteConfigData.fromJson(
          readJsonMap(data, context: 'Remote Config'),
        ),
      );

  Future<RemoteConfigVersionPage> listRemoteConfigVersions({
    int limit = 20,
    String? pageToken,
  }) {
    _requireRange(limit, 1, 100, 'limit');
    return _client.get(
      'remote-config/versions',
      (data) => RemoteConfigVersionPage.fromJson(
        readJsonMap(data, context: 'Remote Config versions'),
      ),
      query: {'limit': limit, 'pageToken': pageToken},
    );
  }

  Future<RemoteConfigData> rollbackRemoteConfig({
    required String versionNumber,
    required String expectedEtag,
  }) => _client.post(
    'remote-config/rollback',
    {
      'versionNumber': _requiredText(versionNumber, 'versionNumber'),
      'expectedEtag': _requiredText(expectedEtag, 'expectedEtag'),
    },
    (data) =>
        RemoteConfigData.fromJson(readJsonMap(data, context: 'Remote Config')),
  );

  Future<ReportPage> listReports({int pageSize = 50, String? pageToken}) {
    _requireRange(pageSize, 1, 100, 'pageSize');
    return _client.get(
      'reports',
      (data) => ReportPage.fromJson(readJsonMap(data, context: 'reports')),
      query: {'pageSize': pageSize, 'pageToken': pageToken},
    );
  }

  Future<ValidatedStorageFile> downloadReport(StoredReport report) async {
    final response = await _client.downloadBytes(
      'reports/download',
      query: {'path': _requiredText(report.path, 'path')},
    );
    if (response.contentLength != null &&
        response.contentLength != response.bytes.length) {
      throw ApiException(
        status: 502,
        code: 'incomplete_storage_download',
        message: 'Tệp tải về từ Storage không đầy đủ.',
      );
    }
    return ValidatedStorageFile.pdf(
      name: report.name,
      bytes: response.bytes,
      expectedSize: report.sizeBytes,
      responseContentType: response.contentType,
    );
  }

  Future<ReportDeleteResult> deleteReport({
    required String path,
    required String generation,
  }) => _client.delete(
    'reports',
    {
      'path': _requiredText(path, 'path'),
      'generation': _requiredText(generation, 'generation'),
    },
    (data) => ReportDeleteResult.fromJson(
      readJsonMap(data, context: 'report delete result'),
    ),
  );

  Future<void> authorizeAnalytics() async {
    final token = await _analyticsTokenProvider?.call(interactive: true);
    if (token == null || token.isEmpty) {
      throw const ApiException(
        status: 401,
        code: 'analytics_oauth_required',
        message: 'Không nhận được quyền truy cập Google Analytics.',
      );
    }
  }

  Future<AnalyticsData> getAnalytics({
    int days = 30,
    DateTime? start,
    DateTime? end,
  }) async {
    _requireDays(days);
    _requireDateRange(start, end);
    final token = await _analyticsTokenProvider?.call(interactive: false);
    return _client.get(
      'analytics',
      (data) => AnalyticsData.fromJson(readJsonMap(data, context: 'analytics')),
      query: {
        'days': days,
        'start': start?.toUtc().toIso8601String(),
        'end': end?.toUtc().toIso8601String(),
      },
      headers: token == null || token.isEmpty
          ? const {}
          : {'X-Google-Analytics-Token': token},
    );
  }

  Future<CrashData> getCrashes({
    int days = 30,
    DateTime? start,
    DateTime? end,
  }) {
    _requireDays(days);
    _requireDateRange(start, end);
    return _client.get(
      'crashes',
      (data) => CrashData.fromJson(readJsonMap(data, context: 'crashes')),
      query: {
        'days': days,
        'start': start?.toUtc().toIso8601String(),
        'end': end?.toUtc().toIso8601String(),
      },
    );
  }

  static void _requireDateRange(DateTime? start, DateTime? end) {
    if ((start == null) != (end == null)) {
      throw ArgumentError('start and end must be provided together.');
    }
    if (start != null && end != null) {
      if (!start.isBefore(end)) {
        throw ArgumentError('start must be before end.');
      }
      if (end.difference(start) > const Duration(days: 366)) {
        throw ArgumentError('Date range cannot exceed 366 days.');
      }
    }
  }

  Future<MessageResult> sendTestMessage(TestMessage message) => _client.post(
    'messages/test',
    message.toJson(),
    (data) =>
        MessageResult.fromJson(readJsonMap(data, context: 'message result')),
  );

  Future<MessageResult> sendBroadcastMessage(BroadcastMessage message) =>
      _client.post(
        'messages/broadcast',
        message.toJson(),
        (data) => MessageResult.fromJson(
          readJsonMap(data, context: 'message result'),
        ),
      );

  Future<List<MessagingCampaign>> listCampaigns({int limit = 50}) {
    _requireRange(limit, 1, 100, 'limit');
    return _client.get('campaigns', (data) {
      final json = readJsonMap(data, context: 'campaign page');
      return readJsonList(json['campaigns'], context: 'campaigns')
          .map(
            (item) => MessagingCampaign.fromJson(
              readJsonMap(item, context: 'campaign'),
            ),
          )
          .toList(growable: false);
    }, query: {'limit': limit});
  }

  Future<MessagingCampaign> createCampaign(CampaignDraft campaign) =>
      _client.post(
        'campaigns',
        campaign.toJson(),
        (data) => MessagingCampaign.fromJson(
          readJsonMap(data, context: 'created campaign'),
        ),
      );

  Future<MessagingCampaign> cancelCampaign(String campaignId) => _client.post(
    'campaigns/${Uri.encodeComponent(_requiredText(campaignId, 'campaignId'))}/cancel',
    const <String, Object?>{},
    (data) => MessagingCampaign.fromJson(
      readJsonMap(data, context: 'canceled campaign'),
    ),
  );

  Future<AuditLogPage> listAuditLogs({int limit = 50}) {
    _requireRange(limit, 1, 100, 'limit');
    return _client.get(
      'audit-logs',
      (data) => AuditLogPage.fromJson(readJsonMap(data, context: 'audit logs')),
      query: {'limit': limit},
    );
  }

  static String _requiredText(String value, String name) {
    final trimmed = value.trim();
    if (trimmed.isEmpty) {
      throw ArgumentError.value(value, name, '$name cannot be empty.');
    }
    return trimmed;
  }

  static void _requireRange(int value, int min, int max, String name) {
    if (value < min || value > max) {
      throw RangeError.range(value, min, max, name);
    }
  }

  static void _requireDays(int days) {
    if (days != 7 && days != 30 && days != 90) {
      throw ArgumentError.value(days, 'days', 'Must be 7, 30, or 90.');
    }
  }
}
