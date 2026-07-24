import 'dart:convert';
import 'dart:typed_data';

import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:journal_trend_admin_web/core/core.dart';

void main() {
  group('ApiClient', () {
    test('uses the Functions Emulator on a Flutter localhost server', () {
      final uri = ApiClient.resolveConfiguredApiBaseUri(
        configured: '',
        pageUri: Uri.parse('http://localhost:57601/'),
      );

      expect(
        uri.toString(),
        'http://127.0.0.1:5001/'
        'journal-trend-analyzer/asia-southeast1/adminApi/api/v1',
      );
    });

    test('uses same-origin Hosting API outside local development', () {
      final uri = ApiClient.resolveConfiguredApiBaseUri(
        configured: '',
        pageUri: Uri.parse('https://journal-trend-analyzer.web.app/dashboard'),
      );

      expect(uri.toString(), 'https://journal-trend-analyzer.web.app/api/v1');
    });

    test('uses the Functions Emulator from the local Hosting Emulator', () {
      final uri = ApiClient.resolveConfiguredApiBaseUri(
        configured: '',
        pageUri: Uri.parse('http://localhost:5000/'),
      );

      expect(
        uri.toString(),
        'http://127.0.0.1:5001/'
        'journal-trend-analyzer/asia-southeast1/adminApi/api/v1',
      );
    });

    test(
      'adds auth headers, query values, and decodes the data envelope',
      () async {
        late http.Request captured;
        final idRefreshes = <bool>[];
        final appCheckRefreshes = <bool>[];
        final transport = MockClient((request) async {
          captured = request;
          return http.Response(
            jsonEncode({
              'data': {'value': 42},
              'requestId': 'request-123',
            }),
            200,
            headers: {'content-type': 'application/json'},
          );
        });
        final client = ApiClient(
          baseUri: Uri.parse('https://admin.example.test/api/v1'),
          httpClient: transport,
          idTokenProvider: ({bool forceRefresh = false}) async {
            idRefreshes.add(forceRefresh);
            return 'firebase-id-token';
          },
          appCheckTokenProvider: ({bool forceRefresh = false}) async {
            appCheckRefreshes.add(forceRefresh);
            return 'app-check-token';
          },
        );

        final result = await client.get<int>(
          'example',
          (data) => (data! as Map<String, Object?>)['value']! as int,
          query: {'query': 'email+tag@example.com', 'empty': null},
        );

        expect(result, 42);
        expect(captured.url.path, '/api/v1/example');
        expect(captured.url.queryParameters, {
          'query': 'email+tag@example.com',
        });
        expect(captured.headers['authorization'], 'Bearer firebase-id-token');
        expect(captured.headers['x-firebase-appcheck'], 'app-check-token');
        expect(idRefreshes, [false]);
        expect(appCheckRefreshes, [false]);
      },
    );

    test('retries a 401 exactly once with refreshed security tokens', () async {
      var requests = 0;
      final idRefreshes = <bool>[];
      final appCheckRefreshes = <bool>[];
      final transport = MockClient((request) async {
        requests++;
        if (requests == 1) {
          return http.Response(
            jsonEncode({
              'error': {'code': 'invalid_token', 'message': 'Expired'},
              'requestId': 'first-request',
            }),
            401,
          );
        }
        return http.Response(
          jsonEncode({
            'data': {'ok': true},
            'requestId': 'second-request',
          }),
          200,
        );
      });
      final client = ApiClient(
        baseUri: Uri.parse('https://admin.example.test/api/v1'),
        httpClient: transport,
        idTokenProvider: ({bool forceRefresh = false}) async {
          idRefreshes.add(forceRefresh);
          return forceRefresh ? 'fresh-id' : 'old-id';
        },
        appCheckTokenProvider: ({bool forceRefresh = false}) async {
          appCheckRefreshes.add(forceRefresh);
          return forceRefresh ? 'fresh-app-check' : 'old-app-check';
        },
      );

      final result = await client.get<bool>(
        'me',
        (data) => (data! as Map<String, Object?>)['ok']! as bool,
      );

      expect(result, isTrue);
      expect(requests, 2);
      expect(idRefreshes, [false, true]);
      expect(appCheckRefreshes, [false, true]);
    });

    test('keeps structured API error context', () async {
      final transport = MockClient(
        (request) async => http.Response(
          jsonEncode({
            'error': {
              'code': 'remote_config_conflict',
              'message': 'Remote Config changed.',
              'details': {'etag': 'new'},
            },
            'requestId': 'conflict-request',
          }),
          409,
        ),
      );
      final client = _client(transport);

      await expectLater(
        client.get<void>('remote-config', (_) {}),
        throwsA(
          isA<ApiException>()
              .having((error) => error.status, 'status', 409)
              .having((error) => error.code, 'code', 'remote_config_conflict')
              .having(
                (error) => error.requestId,
                'requestId',
                'conflict-request',
              )
              .having(
                (error) => error.userMessage,
                'userMessage',
                contains('conflict-request'),
              ),
        ),
      );
    });

    test('rejects a success response without the data envelope', () async {
      final transport = MockClient(
        (request) async => http.Response(jsonEncode({'value': 1}), 200),
      );
      final client = _client(transport);

      await expectLater(
        client.get<void>('overview', (_) {}),
        throwsA(
          isA<ApiException>().having(
            (error) => error.code,
            'code',
            'invalid_response_envelope',
          ),
        ),
      );
    });

    test('downloads bytes and returns relevant response metadata', () async {
      final transport = MockClient((request) async {
        expect(request.headers['accept'], 'application/pdf');
        return http.Response.bytes(
          Uint8List.fromList([0x25, 0x50, 0x44, 0x46]),
          200,
          headers: {
            'content-type': 'application/pdf',
            'content-disposition': 'inline; filename="report.pdf"',
          },
        );
      });
      final client = _client(transport);

      final result = await client.downloadBytes(
        'reports/download',
        query: {'path': 'report/user/analysis/report.pdf'},
      );

      expect(result.bytes, [0x25, 0x50, 0x44, 0x46]);
      expect(result.contentType, 'application/pdf');
      expect(result.contentDisposition, contains('report.pdf'));
      expect(result.contentLength, isNull);
    });

    test(
      'does not send a request when there is no Firebase ID token',
      () async {
        var sent = false;
        final transport = MockClient((request) async {
          sent = true;
          return http.Response('{}', 200);
        });
        final client = ApiClient(
          baseUri: Uri.parse('https://admin.example.test/api/v1'),
          httpClient: transport,
          idTokenProvider: ({bool forceRefresh = false}) async => null,
        );

        await expectLater(
          client.get<void>('me', (_) {}),
          throwsA(
            isA<ApiException>().having(
              (error) => error.code,
              'code',
              'auth_required',
            ),
          ),
        );
        expect(sent, isFalse);
      },
    );
  });
}

ApiClient _client(http.Client transport) => ApiClient(
  baseUri: Uri.parse('https://admin.example.test/api/v1'),
  httpClient: transport,
  idTokenProvider: ({bool forceRefresh = false}) async => 'id-token',
);
