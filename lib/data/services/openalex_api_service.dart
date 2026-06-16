import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:http/http.dart' as http;

import '../../core/errors/app_errors.dart';
import '../models/publication.dart';

enum PublicationYearSort {
  descending,
  ascending;

  String get apiSort {
    return switch (this) {
      PublicationYearSort.descending => 'publication_year:desc',
      PublicationYearSort.ascending => 'publication_year:asc',
    };
  }
}

class PublicationSearchPage {
  final List<Publication> publications;
  final int totalCount;
  final int page;
  final int perPage;

  const PublicationSearchPage({
    required this.publications,
    required this.totalCount,
    required this.page,
    required this.perPage,
  });
}

class OpenAlexApiService {
  static final Uri _baseUri = Uri.parse('https://api.openalex.org');
  static const int defaultPerPage = 50;
  static const Duration defaultTimeout = Duration(seconds: 30);

  final http.Client _client;
  final Duration timeout;

  OpenAlexApiService({http.Client? client, this.timeout = defaultTimeout})
    : _client = client ?? http.Client();

  Future<PublicationSearchPage> searchWorksPage({
    required String topic,
    PublicationYearSort yearSort = PublicationYearSort.descending,
    int page = 1,
    int perPage = defaultPerPage,
  }) async {
    final trimmedTopic = topic.trim();
    if (trimmedTopic.isEmpty) {
      throw AppError('Please enter a topic to search.');
    }

    final safePage = page < 1 ? 1 : page;
    final safePerPage = perPage.clamp(1, defaultPerPage);
    final uri = _baseUri.replace(
      path: '/works',
      queryParameters: {
        'search': trimmedTopic,
        'per-page': safePerPage.toString(),
        'page': safePage.toString(),
        'sort': yearSort.apiSort,
        'mailto': 'vietnhbse183457@fpt.edu.vn',
      },
    );

    try {
      final response = await _client.get(uri).timeout(timeout);
      return _parseSearchPage(response, page: safePage, perPage: safePerPage);
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

  PublicationSearchPage _parseSearchPage(
    http.Response response, {
    required int page,
    required int perPage,
  }) {
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

    final meta = decoded['meta'];
    final totalCount = meta is Map<String, dynamic>
        ? _asInt(meta['count']) ?? 0
        : 0;

    return PublicationSearchPage(
      publications: results
          .whereType<Map<String, dynamic>>()
          .map(Publication.fromOpenAlexJson)
          .toList(growable: false),
      totalCount: totalCount,
      page: page,
      perPage: perPage,
    );
  }

  static int? _asInt(Object? value) {
    if (value is int) {
      return value;
    }
    if (value is num) {
      return value.toInt();
    }
    return null;
  }

  Future<Map<int, int>> getPublicationsByYear(String topic) async {
    final trimmedTopic = topic.trim();
    if (trimmedTopic.isEmpty) {
      throw AppError('Please enter a topic to search.');
    }

    final uri = _baseUri.replace(
      path: '/works',
      queryParameters: {
        'search': trimmedTopic,
        'group_by': 'publication_year',
        'mailto': 'vietnhbse183457@fpt.edu.vn',
      },
    );

    try {
      final response = await _client.get(uri).timeout(timeout);
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

      final groupByList = decoded['group_by'];
      if (groupByList is! List) {
        return {};
      }

      final map = <int, int>{};
      for (final item in groupByList) {
        if (item is! Map<String, dynamic>) continue;
        final yearStr = item['key'];
        final count = item['count'];
        final year = int.tryParse(yearStr.toString());
        if (year != null && count is int) {
          // OpenAlex returns 'unknown' sometimes, ignore invalid years
          if (year <= DateTime.now().year) {
            map[year] = count;
          }
        }
      }
      return map;
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

  Future<List<Publication>> getTopPapers(String topic) async {
    final trimmedTopic = topic.trim();
    if (trimmedTopic.isEmpty) return [];

    final uri = _baseUri.replace(
      path: '/works',
      queryParameters: {
        'search': trimmedTopic,
        'per-page': '50',
        'page': '1',
        'sort': 'cited_by_count:desc',
        'mailto': 'vietnhbse183457@fpt.edu.vn',
      },
    );

    try {
      final response = await _client.get(uri).timeout(timeout);
      if (response.statusCode < 200 || response.statusCode >= 300) {
        throw AppError(
          'OpenAlex request failed.',
          details: 'HTTP ${response.statusCode}: ${response.reasonPhrase ?? ''}',
        );
      }

      final decoded = jsonDecode(response.body);
      final results = decoded['results'];
      if (results is! List) return [];

      return results
          .whereType<Map<String, dynamic>>()
          .map(Publication.fromOpenAlexJson)
          .toList(growable: false);
    } catch (error) {
      throw AppError('Failed to fetch top papers.', details: error.toString());
    }
  }

  void dispose() {
    _client.close();
  }
}
