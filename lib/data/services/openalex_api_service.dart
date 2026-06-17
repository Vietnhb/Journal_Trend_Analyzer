import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:http/http.dart' as http;

import '../../core/errors/app_errors.dart';
import '../models/ranked_entity.dart';

enum PublicationYearSort { descending, ascending }

class OpenAlexApiService {
  static final Uri _baseUri = Uri.parse('https://api.openalex.org');
  static const Duration defaultTimeout = Duration(seconds: 30);
  static const String _contactEmail = 'vietnhbse183457@fpt.edu.vn';

  final http.Client _client;
  final Duration timeout;

  OpenAlexApiService({http.Client? client, this.timeout = defaultTimeout})
    : _client = client ?? http.Client();

  Future<List<RankedEntity>> getTopJournalsByTopic(
    String topic, {
    int limit = 25,
  }) async {
    final trimmedTopic = topic.trim();
    if (trimmedTopic.isEmpty) {
      return const [];
    }

    final safeLimit = limit.clamp(1, 200).toInt();
    final uri = _sourceUri({
      'search': trimmedTopic,
      'filter': 'type:journal',
      'sort': 'works_count:desc',
      'per-page': safeLimit.toString(),
      'mailto': _contactEmail,
    });

    try {
      final response = await _client.get(uri).timeout(timeout);
      if (response.statusCode < 200 || response.statusCode >= 300) {
        throw AppError(
          'OpenAlex request failed.',
          details:
              'HTTP ${response.statusCode}: ${response.reasonPhrase ?? ''}',
        );
      }

      final decoded = jsonDecode(response.body);
      if (decoded is! Map<String, dynamic>) {
        throw const FormatException('Expected a JSON object.');
      }

      final results = decoded['results'];
      if (results is! List) {
        return const [];
      }

      final journals = <RankedEntity>[];
      for (final item in results) {
        if (item is! Map<String, dynamic>) continue;
        if (item['type'] != 'journal') continue;
        final journal = RankedEntity.fromSourceJson(item);
        if (journal.id.isEmpty || journal.name.isEmpty) continue;
        journals.add(journal);
      }
      return journals;
    } on TimeoutException {
      throw AppError(
        'Request timed out.',
        details: 'OpenAlex did not respond within ${timeout.inSeconds}s.',
      );
    } on SocketException {
      throw AppError(
        'No internet connection.',
        details: 'Please check your network and try again.',
      );
    } on FormatException catch (error) {
      throw AppError('Invalid response from OpenAlex.', details: error.message);
    } on http.ClientException catch (error) {
      throw AppError('Could not connect to OpenAlex.', details: error.message);
    }
  }

  Uri _sourceUri(Map<String, String> queryParameters) {
    return _baseUri.replace(path: '/sources', queryParameters: queryParameters);
  }

  void dispose() {
    _client.close();
  }
}
