import 'dart:async';
import 'dart:convert';
import 'dart:typed_data';

import 'package:http/http.dart' as http;

import '../models/json_readers.dart';
import 'api_exception.dart';

typedef IdTokenProvider = Future<String?> Function({bool forceRefresh});
typedef AppCheckTokenProvider = Future<String?> Function({bool forceRefresh});
typedef ApiDecoder<T> = T Function(Object? data);

const configuredApiBaseUrl = String.fromEnvironment('API_BASE_URL');
const localEmulatorApiBaseUrl =
    'http://127.0.0.1:5001/'
    'journal-trend-analyzer/asia-southeast1/adminApi/api/v1';

final class ApiBytes {
  const ApiBytes({
    required this.bytes,
    required this.contentType,
    required this.contentDisposition,
    required this.contentLength,
  });

  final Uint8List bytes;
  final String? contentType;
  final String? contentDisposition;
  final int? contentLength;
}

final class ApiClient {
  ApiClient({
    required IdTokenProvider idTokenProvider,
    AppCheckTokenProvider? appCheckTokenProvider,
    Uri? baseUri,
    http.Client? httpClient,
    this.timeout = const Duration(seconds: 45),
  }) : _idTokenProvider = idTokenProvider,
       _appCheckTokenProvider = appCheckTokenProvider,
       baseUri = baseUri ?? resolveConfiguredApiBaseUri(),
       _httpClient = httpClient ?? http.Client(),
       _ownsHttpClient = httpClient == null;

  final IdTokenProvider _idTokenProvider;
  final AppCheckTokenProvider? _appCheckTokenProvider;
  final http.Client _httpClient;
  final bool _ownsHttpClient;
  final Uri baseUri;
  final Duration timeout;

  static Uri resolveConfiguredApiBaseUri({
    String configured = configuredApiBaseUrl,
    Uri? pageUri,
  }) {
    final currentPage = pageUri ?? Uri.base;
    var value = configured.trim();
    if (value.isEmpty) {
      value = currentPage.host == 'localhost' || currentPage.host == '127.0.0.1'
          ? localEmulatorApiBaseUrl
          : '/api/v1';
    }
    final parsed = Uri.tryParse(value);
    if (parsed == null) {
      throw ArgumentError.value(
        configured,
        'configured',
        'Invalid API base URL.',
      );
    }
    final resolved = parsed.hasScheme ? parsed : currentPage.resolveUri(parsed);
    if (!resolved.hasScheme || resolved.host.isEmpty) {
      throw ArgumentError.value(
        configured,
        'configured',
        'API base URL must resolve to an HTTP(S) URL.',
      );
    }
    if (resolved.scheme != 'http' && resolved.scheme != 'https') {
      throw ArgumentError.value(
        configured,
        'configured',
        'API base URL must use HTTP or HTTPS.',
      );
    }
    if (resolved.hasQuery || resolved.hasFragment) {
      throw ArgumentError.value(
        configured,
        'configured',
        'API base URL cannot contain a query or fragment.',
      );
    }
    return resolved;
  }

  Future<T> get<T>(
    String path,
    ApiDecoder<T> decode, {
    Map<String, Object?> query = const {},
    Map<String, String> headers = const {},
  }) => request('GET', path, decode, query: query, headers: headers);

  Future<T> post<T>(
    String path,
    Object? body,
    ApiDecoder<T> decode, {
    Map<String, Object?> query = const {},
  }) => request('POST', path, decode, query: query, body: body);

  Future<T> put<T>(
    String path,
    Object? body,
    ApiDecoder<T> decode, {
    Map<String, Object?> query = const {},
  }) => request('PUT', path, decode, query: query, body: body);

  Future<T> patch<T>(
    String path,
    Object? body,
    ApiDecoder<T> decode, {
    Map<String, Object?> query = const {},
  }) => request('PATCH', path, decode, query: query, body: body);

  Future<T> delete<T>(
    String path,
    Object? body,
    ApiDecoder<T> decode, {
    Map<String, Object?> query = const {},
  }) => request('DELETE', path, decode, query: query, body: body);

  Future<T> request<T>(
    String method,
    String path,
    ApiDecoder<T> decode, {
    Map<String, Object?> query = const {},
    Object? body,
    Map<String, String> headers = const {},
  }) async {
    final encodedBody = body == null ? null : utf8.encode(jsonEncode(body));
    final response = await _executeWithTokenRetry(
      method: method,
      uri: _buildUri(path, query),
      bodyBytes: encodedBody,
      extraHeaders: headers,
    );

    if (!_isSuccess(response.statusCode)) {
      throw _errorFromResponse(response);
    }
    if (response.statusCode == 204 || response.bodyBytes.isEmpty) {
      return decode(null);
    }

    final Object? decoded;
    try {
      decoded = jsonDecode(utf8.decode(response.bodyBytes));
    } on FormatException catch (error) {
      throw ApiException(
        status: response.statusCode,
        code: 'invalid_response',
        message: 'Máy chủ trả về dữ liệu không hợp lệ.',
        cause: error,
      );
    }

    final envelope = _tryJsonMap(decoded);
    if (envelope == null || !envelope.containsKey('data')) {
      throw const ApiException(
        status: 502,
        code: 'invalid_response_envelope',
        message: 'Máy chủ trả về dữ liệu không đúng định dạng.',
      );
    }
    try {
      return decode(envelope['data']);
    } on FormatException catch (error) {
      throw ApiException(
        status: 502,
        code: 'invalid_response_data',
        message: 'Dữ liệu trả về từ máy chủ không đầy đủ.',
        requestId: _nullableText(envelope['requestId']),
        cause: error,
      );
    }
  }

  Future<ApiBytes> downloadBytes(
    String path, {
    Map<String, Object?> query = const {},
  }) async {
    final response = await _executeWithTokenRetry(
      method: 'GET',
      uri: _buildUri(path, query),
      bodyBytes: null,
      extraHeaders: const {'Accept': 'application/pdf'},
    );
    if (!_isSuccess(response.statusCode)) {
      throw _errorFromResponse(response);
    }
    return ApiBytes(
      bytes: response.bodyBytes,
      contentType: response.headers['content-type'],
      contentDisposition: response.headers['content-disposition'],
      contentLength: int.tryParse(response.headers['content-length'] ?? ''),
    );
  }

  Future<http.Response> _executeWithTokenRetry({
    required String method,
    required Uri uri,
    required List<int>? bodyBytes,
    required Map<String, String> extraHeaders,
  }) async {
    var response = await _send(
      method: method,
      uri: uri,
      bodyBytes: bodyBytes,
      extraHeaders: extraHeaders,
      forceRefresh: false,
    );
    if (response.statusCode == 401) {
      response = await _send(
        method: method,
        uri: uri,
        bodyBytes: bodyBytes,
        extraHeaders: extraHeaders,
        forceRefresh: true,
      );
    }
    return response;
  }

  Future<http.Response> _send({
    required String method,
    required Uri uri,
    required List<int>? bodyBytes,
    required Map<String, String> extraHeaders,
    required bool forceRefresh,
  }) async {
    final idToken = await _loadIdToken(forceRefresh);
    final appCheckToken = await _loadAppCheckToken(forceRefresh);
    final request = http.Request(method, uri)
      ..headers.addAll(extraHeaders)
      ..headers['Accept'] = extraHeaders['Accept'] ?? 'application/json'
      ..headers['Authorization'] = 'Bearer $idToken';
    if (appCheckToken != null && appCheckToken.isNotEmpty) {
      request.headers['X-Firebase-AppCheck'] = appCheckToken;
    }
    if (bodyBytes != null) {
      request
        ..headers['Content-Type'] = 'application/json; charset=utf-8'
        ..bodyBytes = bodyBytes;
    }

    try {
      final streamed = await _httpClient.send(request).timeout(timeout);
      return await http.Response.fromStream(streamed).timeout(timeout);
    } on TimeoutException catch (error) {
      throw ApiException(
        status: 0,
        code: 'request_timeout',
        message: 'Yêu cầu mất quá nhiều thời gian. Vui lòng thử lại.',
        cause: error,
      );
    } on http.ClientException catch (error) {
      throw ApiException(
        status: 0,
        code: 'network_error',
        message: 'Không thể kết nối tới máy chủ. Hãy kiểm tra mạng và thử lại.',
        cause: error,
      );
    }
  }

  Future<String> _loadIdToken(bool forceRefresh) async {
    try {
      final value = await _idTokenProvider(forceRefresh: forceRefresh);
      if (value != null && value.trim().isNotEmpty) return value.trim();
    } on ApiException {
      rethrow;
    } catch (error) {
      throw ApiException(
        status: 401,
        code: 'id_token_failed',
        message: 'Không thể xác thực phiên đăng nhập Firebase.',
        cause: error,
      );
    }
    throw const ApiException(
      status: 401,
      code: 'auth_required',
      message: 'Bạn cần đăng nhập để tiếp tục.',
    );
  }

  Future<String?> _loadAppCheckToken(bool forceRefresh) async {
    final provider = _appCheckTokenProvider;
    if (provider == null) return null;
    try {
      final value = await provider(forceRefresh: forceRefresh);
      final trimmed = value?.trim();
      return trimmed == null || trimmed.isEmpty ? null : trimmed;
    } catch (error) {
      throw ApiException(
        status: 401,
        code: 'app_check_token_failed',
        message: 'Không thể xác minh ứng dụng với Firebase App Check.',
        cause: error,
      );
    }
  }

  Uri _buildUri(String path, Map<String, Object?> query) {
    final cleanPath = path.trim().replaceFirst(RegExp(r'^/+'), '');
    if (cleanPath.isEmpty) {
      throw ArgumentError.value(path, 'path', 'API path is empty.');
    }
    final base = baseUri.toString().replaceFirst(RegExp(r'/+$'), '');
    var uri = Uri.parse('$base/$cleanPath');
    final values = <String, String>{};
    for (final entry in query.entries) {
      final value = entry.value;
      if (value != null && value.toString().isNotEmpty) {
        values[entry.key] = value.toString();
      }
    }
    if (values.isNotEmpty) uri = uri.replace(queryParameters: values);
    return uri;
  }

  ApiException _errorFromResponse(http.Response response) {
    JsonMap? payload;
    try {
      payload = _tryJsonMap(jsonDecode(utf8.decode(response.bodyBytes)));
    } on FormatException {
      payload = null;
    }
    final error = _tryJsonMap(payload?['error']);
    return ApiException(
      status: response.statusCode,
      code: _nullableText(error?['code']) ?? 'http_${response.statusCode}',
      message:
          _nullableText(error?['message']) ??
          _fallbackErrorMessage(response.statusCode),
      requestId: _nullableText(payload?['requestId']),
      details: error?['details'],
    );
  }

  static JsonMap? _tryJsonMap(Object? value) {
    if (value is Map<String, Object?>) return value;
    if (value is Map) {
      return value.map((key, item) => MapEntry(key.toString(), item));
    }
    return null;
  }

  static String? _nullableText(Object? value) =>
      value is String && value.isNotEmpty ? value : null;

  static bool _isSuccess(int status) => status >= 200 && status < 300;

  static String _fallbackErrorMessage(int status) => switch (status) {
    401 => 'Phiên đăng nhập đã hết hạn. Vui lòng đăng nhập lại.',
    403 => 'Tài khoản không có quyền quản trị.',
    404 => 'Không tìm thấy dữ liệu được yêu cầu.',
    409 => 'Dữ liệu đã thay đổi. Hãy tải lại và thử lại.',
    429 => 'Hệ thống đang quá tải. Vui lòng thử lại sau.',
    _ => 'Không thể hoàn tất yêu cầu. Vui lòng thử lại.',
  };

  void close() {
    if (_ownsHttpClient) _httpClient.close();
  }
}
