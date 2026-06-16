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

class GroupStat {
  final String key;
  final String label;
  final int count;

  const GroupStat({
    required this.key,
    required this.label,
    required this.count,
  });
}

class PublicationAnalytics {
  final int totalCount;
  final int citationSampleTotal;
  final int citationSampleSize;
  final Map<int, int> publicationsByYear;
  final List<GroupStat> topJournals;
  final List<GroupStat> topAuthors;
  final List<Publication> topPapers;

  const PublicationAnalytics({
    required this.totalCount,
    required this.citationSampleTotal,
    required this.citationSampleSize,
    required this.publicationsByYear,
    required this.topJournals,
    required this.topAuthors,
    required this.topPapers,
  });

  double get averageCitationCount {
    if (citationSampleSize == 0) {
      return 0;
    }
    return citationSampleTotal / citationSampleSize;
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

  final http.Client _client;
  final Duration timeout;

  OpenAlexApiService({
    http.Client? client,
    this.timeout = const Duration(seconds: 15),
  }) : _client = client ?? http.Client();

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

    try {
      final safePerPage = perPage.clamp(1, defaultPerPage);
      final safePage = page < 1 ? 1 : page;
      final uri = _baseUri.replace(
        path: '/works',
        queryParameters: {
          'search': trimmedTopic,
          'per-page': safePerPage.toString(),
          'page': safePage.toString(),
          'sort': yearSort.apiSort,
        },
      );

      final response = await _client.get(uri).timeout(timeout);
      return _handleSearchResponse(
        response,
        page: safePage,
        perPage: safePerPage,
      );
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

  Future<PublicationAnalytics> fetchAnalytics({required String topic}) async {
    final trimmedTopic = topic.trim();
    if (trimmedTopic.isEmpty) {
      throw AppError('Please enter a topic to search.');
    }

    try {
      final results = await Future.wait<Object>([
        _fetchGroupStats(trimmedTopic, 'publication_year'),
        _fetchGroupStats(trimmedTopic, 'primary_location.source.id'),
        _fetchGroupStats(trimmedTopic, 'authorships.author.id'),
        _fetchTopPapers(trimmedTopic),
        _fetchCitationSample(trimmedTopic),
      ]);
      final years = results[0] as List<GroupStat>;
      final journals = results[1] as List<GroupStat>;
      final authors = results[2] as List<GroupStat>;
      final topPapers = results[3] as List<Publication>;
      final citationSample = results[4] as List<Publication>;
      final citationSampleTotal = citationSample.fold<int>(
        0,
        (total, publication) => total + publication.citationCount,
      );

      final publicationsByYear = <int, int>{};
      for (final year in years) {
        final parsedYear = int.tryParse(year.key);
        if (parsedYear != null) {
          publicationsByYear[parsedYear] = year.count;
        }
      }

      return PublicationAnalytics(
        totalCount: years.fold<int>(0, (total, item) => total + item.count),
        citationSampleTotal: citationSampleTotal,
        citationSampleSize: citationSample.length,
        publicationsByYear: publicationsByYear,
        topJournals: journals.take(5).toList(growable: false),
        topAuthors: authors.take(5).toList(growable: false),
        topPapers: topPapers,
      );
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

  PublicationSearchPage _handleSearchResponse(
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

    final publications = results
        .whereType<Map<String, dynamic>>()
        .map(Publication.fromOpenAlexJson)
        .toList(growable: false);

    return PublicationSearchPage(
      publications: publications,
      totalCount: totalCount,
      page: page,
      perPage: perPage,
    );
  }

  Future<List<GroupStat>> _fetchGroupStats(String topic, String groupBy) async {
    final uri = _baseUri.replace(
      path: '/works',
      queryParameters: {'search': topic, 'group_by': groupBy},
    );
    final response = await _client.get(uri).timeout(timeout);
    final decoded = _decodeObject(response);
    final groups = decoded['group_by'];
    if (groups is! List) {
      throw const FormatException('Expected "group_by" to be a list.');
    }
    return groups
        .whereType<Map<String, dynamic>>()
        .map(
          (item) => GroupStat(
            key: _asString(item['key']) ?? '',
            label:
                _asString(item['key_display_name']) ??
                _asString(item['key']) ??
                'Unknown',
            count: _asInt(item['count']) ?? 0,
          ),
        )
        .where((item) => item.key.isNotEmpty && item.count > 0)
        .toList(growable: false);
  }

  Future<List<Publication>> _fetchTopPapers(String topic) async {
    final uri = _baseUri.replace(
      path: '/works',
      queryParameters: {
        'search': topic,
        'per-page': '5',
        'sort': 'cited_by_count:desc',
      },
    );
    final response = await _client.get(uri).timeout(timeout);
    return _handleSearchResponse(response, page: 1, perPage: 5).publications;
  }

  Future<List<Publication>> _fetchCitationSample(String topic) async {
    final uri = _baseUri.replace(
      path: '/works',
      queryParameters: {'search': topic, 'per-page': '200'},
    );
    final response = await _client.get(uri).timeout(timeout);
    return _handleSearchResponse(response, page: 1, perPage: 200).publications;
  }

  Map<String, dynamic> _decodeObject(http.Response response) {
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
    return decoded;
  }

  static String? _asString(Object? value) {
    return value is String && value.isNotEmpty ? value : null;
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

  void dispose() {
    _client.close();
  }
}
