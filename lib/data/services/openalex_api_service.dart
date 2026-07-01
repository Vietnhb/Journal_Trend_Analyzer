import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:http/http.dart' as http;

import '../../core/constants/app_limits.dart';
import '../../core/errors/app_errors.dart';
import '../models/publication.dart';
import '../models/ranked_entity.dart';

enum PublicationYearSort { descending, ascending }

enum PublicationListSort {
  newest,
  oldest,
  mostCited;

  String get apiSort {
    return switch (this) {
      PublicationListSort.newest => 'publication_year:desc',
      PublicationListSort.oldest => 'publication_year:asc',
      PublicationListSort.mostCited => 'cited_by_count:desc',
    };
  }

  String get reverseApiSort {
    return switch (this) {
      PublicationListSort.newest => 'publication_year:asc',
      PublicationListSort.oldest => 'publication_year:desc',
      PublicationListSort.mostCited => 'cited_by_count:asc',
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

class CitationStats {
  final int totalCitations;
  final int totalWorks;

  const CitationStats({required this.totalCitations, required this.totalWorks});

  int? get averageCitations =>
      totalWorks == 0 ? null : totalCitations ~/ totalWorks;
}

class OpenAlexApiService {
  static final Uri _baseUri = Uri.parse('https://api.openalex.org');
  static const Duration defaultTimeout = Duration(seconds: 30);
  static const String _contactEmail = 'vietnhbse183457@fpt.edu.vn';

  final http.Client _client;
  final Duration timeout;

  OpenAlexApiService({http.Client? client, this.timeout = defaultTimeout})
    : _client = client ?? http.Client();

  Future<List<RankedEntity>> getKeywordsByKeyword(
    String keyword, {
    int limit = AppLimits.trendingKeywordResults,
    bool excludeFuturePublications = true,
  }) async {
    final trimmedKeyword = keyword.trim();
    if (trimmedKeyword.isEmpty) return const [];

    final filters = _keywordWorkFilters();
    if (excludeFuturePublications) {
      filters.add('to_publication_date:${_currentPublicationDateFilter()}');
    }

    return _getRankedEntities(
      keyword: trimmedKeyword,
      groupBy: 'keywords.id',
      filters: filters,
      limit: limit,
    );
  }

  Future<List<RankedEntity>> getTopJournalsByKeyword(
    String keyword, {
    int limit = AppLimits.topJournalResults,
    bool excludeFuturePublications = true,
  }) async {
    final trimmedKeyword = keyword.trim();
    if (trimmedKeyword.isEmpty) return const [];

    final safeLimit = limit.clamp(1, AppLimits.openAlexGroupPageSize).toInt();
    final filters = _keywordWorkFilters();
    if (excludeFuturePublications) {
      filters.add('to_publication_date:${_currentPublicationDateFilter()}');
    }

    final parameters = <String, String>{
      'search': trimmedKeyword,
      'filter': filters.join(','),
      'group_by': 'primary_location.source.id',
      'per-page': safeLimit.toString(),
      'mailto': _contactEmail,
    };
    final uri = _openAlexUri('/works', parameters);

    final decoded = await _getJsonObject(uri);
    final groups = decoded['group_by'];
    if (groups is! List) return const [];

    final journals = <RankedEntity>[];
    for (final item in groups) {
      if (item is! Map<String, dynamic>) continue;
      final journal = RankedEntity.fromGroupByJson(item);
      if (journal.id.isEmpty || journal.name.isEmpty) continue;
      journals.add(journal);
    }
    return journals;
  }

  Future<PublicationSearchPage> getPublicationsByKeyword(
    String keyword, {
    String? sourceId,
    String? authorId,
    int page = 1,
    int perPage = AppLimits.publicationPageSize,
    bool excludeFuturePublications = true,
    String? sortOverride,
    PublicationListSort? publicationSort,
  }) async {
    final trimmedKeyword = keyword.trim();
    if (trimmedKeyword.isEmpty) {
      throw AppError('Please enter a keyword to search.');
    }

    final safePage = page < 1 ? 1 : page;
    final safePerPage = perPage
        .clamp(1, AppLimits.openAlexListPageSize)
        .toInt();
    final filters = _keywordWorkFilters(sourceId: sourceId, authorId: authorId);
    if (excludeFuturePublications) {
      filters.add('to_publication_date:${_currentPublicationDateFilter()}');
    }

    final queryParameters = <String, String>{
      'search': trimmedKeyword,
      'filter': filters.join(','),
      'sort':
          sortOverride ??
          publicationSort?.apiSort ??
          PublicationListSort.newest.apiSort,
      'per-page': safePerPage.toString(),
      'mailto': _contactEmail,
      'page': safePage.toString(),
    };
    final uri = _openAlexUri('/works', queryParameters);

    final decoded = await _getJsonObject(uri);
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
      page: safePage,
      perPage: safePerPage,
    );
  }

  Future<List<Publication>> getTopPapersByKeyword(
    String keyword, {
    bool excludeFuturePublications = true,
  }) async {
    final page = await getPublicationsByKeyword(
      keyword,
      page: 1,
      perPage: AppLimits.topPaperResults,
      excludeFuturePublications: excludeFuturePublications,
      sortOverride: 'cited_by_count:desc',
    );
    return page.publications;
  }

  Future<List<RankedEntity>> getTopAuthorsByKeyword(
    String keyword, {
    int limit = AppLimits.rankedEntityResults,
    bool excludeFuturePublications = true,
  }) async {
    final trimmedKeyword = keyword.trim();
    if (trimmedKeyword.isEmpty) return const [];
    final filters = _keywordWorkFilters();
    if (excludeFuturePublications) {
      filters.add('to_publication_date:${_currentPublicationDateFilter()}');
    }
    return _getRankedEntities(
      keyword: trimmedKeyword,
      groupBy: 'authorships.author.id',
      filters: filters,
      limit: limit,
    );
  }

  Future<Map<int, int>> getPublicationTrendByKeyword(
    String keyword, {
    String? sourceId,
    String? authorId,
    bool excludeFuturePublications = true,
  }) async {
    final trimmedKeyword = keyword.trim();
    if (trimmedKeyword.isEmpty) return const {};
    final filters = _keywordWorkFilters(sourceId: sourceId, authorId: authorId);
    if (excludeFuturePublications) {
      filters.add('to_publication_date:${_currentPublicationDateFilter()}');
    }
    final groups = await _getRankedEntities(
      keyword: trimmedKeyword,
      groupBy: 'publication_year',
      filters: filters,
      limit: AppLimits.openAlexGroupPageSize,
    );

    final counts = <int, int>{};
    for (final group in groups) {
      final year = int.tryParse(group.id);
      if (year != null) {
        counts[year] = group.worksCount;
      }
    }
    return counts;
  }

  Future<int?> getAverageCitationsByKeyword(
    String keyword, {
    String? sourceId,
    String? authorId,
    bool excludeFuturePublications = true,
  }) async {
    final stats = await getCitationStatsByKeyword(
      keyword,
      sourceId: sourceId,
      authorId: authorId,
      excludeFuturePublications: excludeFuturePublications,
    );
    return stats.averageCitations;
  }

  Future<CitationStats> getCitationStatsByKeyword(
    String keyword, {
    String? sourceId,
    String? authorId,
    bool excludeFuturePublications = true,
  }) async {
    final trimmedKeyword = keyword.trim();
    if (trimmedKeyword.isEmpty) {
      return const CitationStats(totalCitations: 0, totalWorks: 0);
    }
    final filters = _keywordWorkFilters(sourceId: sourceId, authorId: authorId);
    if (excludeFuturePublications) {
      filters.add('to_publication_date:${_currentPublicationDateFilter()}');
    }
    final groups = await _getAllRankedEntities(
      keyword: trimmedKeyword,
      groupBy: 'cited_by_count',
      filters: filters,
    );

    var totalCitations = 0;
    var totalWorks = 0;
    for (final group in groups) {
      final citations = int.tryParse(group.id);
      if (citations == null) continue;
      totalCitations += citations * group.worksCount;
      totalWorks += group.worksCount;
    }
    return CitationStats(
      totalCitations: totalCitations,
      totalWorks: totalWorks,
    );
  }

  Future<List<RankedEntity>> _getAllRankedEntities({
    required String? keyword,
    required String groupBy,
    required List<String> filters,
  }) async {
    final entities = <RankedEntity>[];
    String? cursor = '*';

    while (cursor != null) {
      final parameters = <String, String>{
        'filter': filters.join(','),
        'group_by': groupBy,
        'per-page': AppLimits.openAlexGroupPageSize.toString(),
        'cursor': cursor,
        'mailto': _contactEmail,
      };
      if (keyword != null) parameters['search'] = keyword;
      final uri = _openAlexUri('/works', parameters);

      final decoded = await _getJsonObject(uri);
      final groupByList = decoded['group_by'];
      if (groupByList is List) {
        for (final item in groupByList) {
          if (item is! Map<String, dynamic>) continue;
          final entity = RankedEntity.fromGroupByJson(item);
          final key = entity.id.toLowerCase();
          if (entity.id.isEmpty || key == 'unknown' || key == '-111') {
            continue;
          }
          entities.add(entity);
        }
      }

      final meta = decoded['meta'];
      final nextCursor = meta is Map<String, dynamic>
          ? meta['next_cursor']?.toString()
          : null;
      cursor = nextCursor == null || nextCursor.isEmpty ? null : nextCursor;
      if (cursor != null) {
        await Future<void>.delayed(const Duration(milliseconds: 120));
      }
    }

    return entities;
  }

  Future<List<RankedEntity>> _getRankedEntities({
    required String? keyword,
    required String groupBy,
    required List<String> filters,
    int limit = AppLimits.rankedEntityResults,
  }) async {
    final parameters = <String, String>{
      'filter': filters.join(','),
      'group_by': groupBy,
      'per-page': AppLimits.openAlexGroupPageSize.toString(),
      'mailto': _contactEmail,
    };
    if (keyword != null) parameters['search'] = keyword;
    final uri = _openAlexUri('/works', parameters);

    final decoded = await _getJsonObject(uri);
    final groupByList = decoded['group_by'];
    if (groupByList is! List) return const [];

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
  }

  Future<Map<String, dynamic>> _getJsonObject(Uri uri) async {
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
      return decoded;
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

  Uri _openAlexUri(String path, Map<String, String> queryParameters) {
    final query = queryParameters.entries
        .map((entry) {
          final key = Uri.encodeQueryComponent(entry.key);
          if (entry.key == 'filter') {
            return '$key=${entry.value}';
          }
          return '$key=${Uri.encodeQueryComponent(entry.value)}';
        })
        .join('&');
    return _baseUri.replace(path: path, query: query);
  }

  List<String> _keywordWorkFilters({String? sourceId, String? authorId}) {
    final filters = ['type:article', 'primary_location.source.type:journal'];

    if (sourceId != null && sourceId.trim().isNotEmpty) {
      final sourceFilterValue = _openAlexIdFilterValue(sourceId);
      if (sourceFilterValue.isNotEmpty) {
        filters.add('primary_location.source.id:$sourceFilterValue');
      }
    }
    if (authorId != null && authorId.trim().isNotEmpty) {
      final authorFilterValue = _openAlexIdFilterValue(authorId);
      if (authorFilterValue.isNotEmpty) {
        filters.add('authorships.author.id:$authorFilterValue');
      }
    }

    return filters;
  }

  static String _openAlexIdFilterValue(String id) {
    final trimmed = id.trim();
    if (trimmed.isEmpty) return trimmed;
    final uri = Uri.tryParse(trimmed);
    if (uri != null && uri.pathSegments.isNotEmpty) {
      return uri.pathSegments.last;
    }
    return trimmed;
  }

  static int? _asInt(Object? value) {
    if (value is int) return value;
    if (value is num) return value.toInt();
    if (value is String) return int.tryParse(value);
    return null;
  }

  String _currentPublicationDateFilter() {
    return _formatDate(DateTime.now());
  }

  static String _formatDate(DateTime date) {
    final month = date.month.toString().padLeft(2, '0');
    final day = date.day.toString().padLeft(2, '0');
    return '${date.year}-$month-$day';
  }

  void dispose() {
    _client.close();
  }
}
