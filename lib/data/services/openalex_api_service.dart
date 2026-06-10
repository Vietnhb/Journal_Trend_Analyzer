import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:http/http.dart' as http;

import '../../core/errors/app_errors.dart';
import '../models/publication.dart';

class OpenAlexApiService {
  static final Uri _baseUri = Uri.parse('https://api.openalex.org');

  final http.Client _client;
  final Duration timeout;

  OpenAlexApiService({
    http.Client? client,
    this.timeout = const Duration(seconds: 15),
  }) : _client = client ?? http.Client();

  Future<List<Publication>> searchWorks({
    required String topic,
    int perPage = 100,
  }) async {
    final trimmedTopic = topic.trim();
    if (trimmedTopic.isEmpty) {
      throw AppError('Please enter a topic to search.');
    }

    final uri = _baseUri.replace(
      path: '/works',
      queryParameters: {
        'search': trimmedTopic,
        'per-page': perPage.clamp(1, 200).toString(),
      },
    );

    try {
      final response = await _client.get(uri).timeout(timeout);
      return _handleSearchResponse(response);
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

  List<Publication> _handleSearchResponse(http.Response response) {
    if (response.statusCode < 200 || response.statusCode >= 300) {
      throw AppError(
        'OpenAlex request failed.',
        details: 'HTTP ${response.statusCode}: ${response.reasonPhrase ?? ''}',
      );
    }

    final decoded = jsonDecode(response.body);
    if (decoded is! Map<String, dynamic>) {
      throw const FormatException('Expected a JSON object.');
    }

    final results = decoded['results'];
    if (results is! List) {
      throw const FormatException('Expected "results" to be a list.');
    }

    return results
        .whereType<Map<String, dynamic>>()
        .map(Publication.fromOpenAlexJson)
        .toList(growable: false);
  }

  void dispose() {
    _client.close();
  }
}
