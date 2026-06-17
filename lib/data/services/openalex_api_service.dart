import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:http/http.dart' as http;

import '../../core/errors/app_errors.dart';
import '../models/publication.dart';
import '../models/ranked_entity.dart';

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
  static const String _contactEmail = 'vietnhbse183457@fpt.edu.vn';

  final http.Client _client;
  final Duration timeout;

  OpenAlexApiService({http.Client? client, this.timeout = defaultTimeout})
    : _client = client ?? http.Client();

  Future<PublicationSearchPage> searchWorksPage({
    required String topic,
    PublicationYearSort yearSort = PublicationYearSort.descending,
    int page = 1,
    int perPage = defaultPerPage,
    bool excludeFuturePublications = false,
  }) async {
    final trimmedTopic = topic.trim();
    if (trimmedTopic.isEmpty) {
      throw AppError('Please enter a search term.');
    }

    final safePage = page < 1 ? 1 : page;
    final safePerPage = perPage.clamp(1, defaultPerPage);
    final queryParameters = {
      'search': trimmedTopic,
      'per-page': safePerPage.toString(),
      'page': safePage.toString(),
      'sort': yearSort.apiSort,
      'mailto': 'vietnhbse183457@fpt.edu.vn',
    };
    if (excludeFuturePublications) {
      queryParameters['filter'] =
          'to_publication_date:${_currentPublicationDateFilter()}';
    }

    final uri = _baseUri.replace(
      path: '/works',
      queryParameters: queryParameters,
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

  Future<Map<int, int>> getPublicationsByYear(
    String topic, {
    bool excludeFuturePublications = false,
  }) async {
    final trimmedTopic = topic.trim();
    if (trimmedTopic.isEmpty) {
      throw AppError('Please enter a search term.');
    }

    final queryParameters = {
      'search': trimmedTopic,
      'group_by': 'publication_year',
      'mailto': 'vietnhbse183457@fpt.edu.vn',
    };
    if (excludeFuturePublications) {
      queryParameters['filter'] =
          'to_publication_date:${_currentPublicationDateFilter()}';
    }

    final uri = _baseUri.replace(
      path: '/works',
      queryParameters: queryParameters,
    );

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
          map[year] = count;
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

  Future<List<Publication>> getTopPapers(
    String topic, {
    bool excludeFuturePublications = false,
  }) async {
    final trimmedTopic = topic.trim();
    if (trimmedTopic.isEmpty) return [];

    final queryParameters = {
      'search': trimmedTopic,
      'per-page': '50',
      'page': '1',
      'sort': 'cited_by_count:desc',
      'mailto': 'vietnhbse183457@fpt.edu.vn',
    };
    if (excludeFuturePublications) {
      queryParameters['filter'] =
          'to_publication_date:${_currentPublicationDateFilter()}';
    }

    final uri = _baseUri.replace(
      path: '/works',
      queryParameters: queryParameters,
    );

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

  /// Real-time ranking of journals with the most works for the topic, using
  /// OpenAlex `group_by` so counts reflect the whole topic (not a 50-paper sample).
  Future<List<RankedEntity>> getTopJournals(
    String topic, {
    int limit = 10,
    bool excludeFuturePublications = false,
  }) {
    return _getRankedEntities(
      topic,
      groupBy: 'primary_location.source.id',
      limit: limit,
      excludeFuturePublications: excludeFuturePublications,
    );
  }

  /// Real-time ranking of authors with the most works for the topic.
  Future<List<RankedEntity>> getTopAuthors(
    String topic, {
    int limit = 10,
    bool excludeFuturePublications = false,
  }) {
    return _getRankedEntities(
      topic,
      groupBy: 'authorships.author.id',
      limit: limit,
      excludeFuturePublications: excludeFuturePublications,
    );
  }

  Future<List<RankedEntity>> _getRankedEntities(
    String topic, {
    required String groupBy,
    int limit = 10,
    bool excludeFuturePublications = false,
  }) async {
    final trimmedTopic = topic.trim();
    if (trimmedTopic.isEmpty) {
      return const [];
    }

    final queryParameters = {
      'search': trimmedTopic,
      'group_by': groupBy,
      'per-page': '200',
      'mailto': _contactEmail,
    };
    if (excludeFuturePublications) {
      queryParameters['filter'] =
          'to_publication_date:${_currentPublicationDateFilter()}';
    }

    final uri = _baseUri.replace(
      path: '/works',
      queryParameters: queryParameters,
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
        return const [];
      }

      final entities = <RankedEntity>[];
      for (final item in groupByList) {
        if (item is! Map<String, dynamic>) continue;
        final entity = RankedEntity.fromGroupByJson(item);
        final key = entity.id.toLowerCase();
        if (entity.id.isEmpty || key == 'unknown' || entity.name.isEmpty) {
          continue;
        }
        entities.add(entity);
        if (entities.length >= limit) break;
      }
      return entities;
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

  /// Weighted average citation count across all works for the topic, computed
  /// from `group_by=cited_by_count`. This is a real-time topic-wide figure
  /// rather than an average over only the most-cited papers.
  Future<int?> getAverageCitations(
    String topic, {
    bool excludeFuturePublications = false,
  }) async {
    final trimmedTopic = topic.trim();
    if (trimmedTopic.isEmpty) {
      return null;
    }

    final queryParameters = {
      'search': trimmedTopic,
      'group_by': 'cited_by_count',
      'per-page': '200',
      'mailto': _contactEmail,
    };
    if (excludeFuturePublications) {
      queryParameters['filter'] =
          'to_publication_date:${_currentPublicationDateFilter()}';
    }

    final uri = _baseUri.replace(
      path: '/works',
      queryParameters: queryParameters,
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
      if (groupByList is! List || groupByList.isEmpty) {
        return null;
      }

      var totalCitations = 0;
      var totalWorks = 0;
      for (final item in groupByList) {
        if (item is! Map<String, dynamic>) continue;
        final citations = int.tryParse(item['key'].toString());
        final count = _asInt(item['count']);
        if (citations == null || count == null) continue;
        totalCitations += citations * count;
        totalWorks += count;
      }

      if (totalWorks == 0) {
        return null;
      }
      return totalCitations ~/ totalWorks;
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

  /// Works for the topic restricted to a specific journal (source) or author,
  /// used by the ranking drill-down detail screens.
  Future<PublicationSearchPage> searchWorksByEntity({
    required String topic,
    String? sourceId,
    String? authorId,
    PublicationYearSort yearSort = PublicationYearSort.descending,
    int page = 1,
    int perPage = defaultPerPage,
    bool excludeFuturePublications = false,
  }) async {
    final trimmedTopic = topic.trim();
    final safePage = page < 1 ? 1 : page;
    final safePerPage = perPage.clamp(1, defaultPerPage);

    final filters = <String>[];
    if (sourceId != null && sourceId.trim().isNotEmpty) {
      filters.add('primary_location.source.id:${_shortId(sourceId)}');
    }
    if (authorId != null && authorId.trim().isNotEmpty) {
      filters.add('authorships.author.id:${_shortId(authorId)}');
    }
    if (excludeFuturePublications) {
      filters.add('to_publication_date:${_currentPublicationDateFilter()}');
    }

    final queryParameters = {
      if (trimmedTopic.isNotEmpty) 'search': trimmedTopic,
      'per-page': safePerPage.toString(),
      'page': safePage.toString(),
      'sort': yearSort.apiSort,
      'mailto': _contactEmail,
    };
    if (filters.isNotEmpty) {
      queryParameters['filter'] = filters.join(',');
    }

    final uri = _baseUri.replace(
      path: '/works',
      queryParameters: queryParameters,
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

  void dispose() {
    _client.close();
  }

  static String _shortId(String id) {
    final trimmed = id.trim();
    if (trimmed.isEmpty) {
      return trimmed;
    }
    final segments = trimmed.split('/');
    return segments.isEmpty ? trimmed : segments.last;
  }

  String _currentPublicationDateFilter() {
    final now = DateTime.now();
    final month = now.month.toString().padLeft(2, '0');
    final day = now.day.toString().padLeft(2, '0');
    return '${now.year}-$month-$day';
  }
}
