import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:http/http.dart' as http;

import '../../core/errors/app_errors.dart';
import '../models/openalex_topic.dart';
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
  final String? nextCursor;

  const PublicationSearchPage({
    required this.publications,
    required this.totalCount,
    required this.page,
    required this.perPage,
    this.nextCursor,
  });
}

class OpenAlexApiService {
  static final Uri _baseUri = Uri.parse('https://api.openalex.org');
  static const Duration defaultTimeout = Duration(seconds: 30);
  static const String _contactEmail = 'vietnhbse183457@fpt.edu.vn';

  final http.Client _client;
  final Duration timeout;

  OpenAlexApiService({http.Client? client, this.timeout = defaultTimeout})
    : _client = client ?? http.Client();

  Future<List<OpenAlexTopic>> searchTopics(
    String keyword, {
    int limit = 50,
  }) async {
    final trimmedKeyword = keyword.trim();
    if (trimmedKeyword.isEmpty) return const [];

    final safeLimit = limit.clamp(1, 50).toInt();
    final uri = _openAlexUri('/topics', {
      'search': trimmedKeyword,
      'per-page': safeLimit.toString(),
      'mailto': _contactEmail,
    });

    final decoded = await _getJsonObject(uri);
    final results = decoded['results'];
    if (results is! List) return const [];

    return results
        .whereType<Map<String, dynamic>>()
        .map(OpenAlexTopic.fromJson)
        .where((topic) => topic.id.isNotEmpty && topic.name.isNotEmpty)
        .toList(growable: false);
  }

  /// Get top journals by keyword search.
  /// Returns journals with the most articles related to the keyword.
  Future<List<RankedEntity>> getTopJournalsByKeyword(
    String keyword, {
    String? sourceId,
    int limit = 50,
    bool excludeFuturePublications = true,
  }) async {
    final trimmedKeyword = keyword.trim();
    if (trimmedKeyword.isEmpty) return const [];

    final safeLimit = limit.clamp(1, 200).toInt();
    final filters = _keywordWorkFilters(trimmedKeyword, sourceId: sourceId);
    if (excludeFuturePublications) {
      filters.add('to_publication_date:${_currentPublicationDateFilter()}');
    }

    final uri = _openAlexUri('/works', {
      'search': trimmedKeyword,
      'filter': filters.join(','),
      'group_by': 'primary_location.source.id',
      'per-page': safeLimit.toString(),
      'mailto': _contactEmail,
    });

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

  @Deprecated('Use getTopJournalsByKeyword instead')
  Future<List<RankedEntity>> getTopJournalsByTopicId(
    String topicId, {
    int limit = 50,
  }) async {
    final topicFilterValue = _openAlexIdFilterValue(topicId);
    if (topicFilterValue.isEmpty) return const [];

    final safeLimit = limit.clamp(1, 200).toInt();
    final uri = _openAlexUri('/works', {
      'filter':
          'type:article,primary_location.source.type:journal,topics.id:$topicFilterValue',
      'group_by': 'primary_location.source.id',
      'per-page': safeLimit.toString(),
      'mailto': _contactEmail,
    });

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

  Future<RankedEntity> getJournalSourceDetail(String sourceId) async {
    final shortId = _openAlexIdFilterValue(sourceId);
    if (shortId.isEmpty) {
      throw AppError('Please select a journal first.');
    }

    final uri = _openAlexUri('/sources/$shortId', {'mailto': _contactEmail});
    final decoded = await _getJsonObject(uri);
    return RankedEntity.fromSourceJson(decoded);
  }

  /// Get publications by keyword search.
  /// Optionally filter by sourceId for journal drill-down.
  Future<PublicationSearchPage> getPublicationsByKeyword(
    String keyword, {
    String? sourceId,
    String? authorId,
    PublicationYearSort yearSort = PublicationYearSort.descending,
    int page = 1,
    int perPage = 50,
    bool excludeFuturePublications = true,
    String? sortOverride,
    String? cursor,
    PublicationListSort? publicationSort,
  }) async {
    final trimmedKeyword = keyword.trim();
    if (trimmedKeyword.isEmpty) {
      throw AppError('Please enter a keyword to search.');
    }

    final safePage = page < 1 ? 1 : page;
    final safePerPage = perPage.clamp(1, 50).toInt();
    final filters = _keywordWorkFilters(
      trimmedKeyword,
      sourceId: sourceId,
      authorId: authorId,
    );
    if (excludeFuturePublications) {
      filters.add('to_publication_date:${_currentPublicationDateFilter()}');
    }

    final queryParameters = <String, String>{
      'search': trimmedKeyword,
      'filter': filters.join(','),
      'sort': sortOverride ?? publicationSort?.apiSort ?? yearSort.apiSort,
      'per-page': safePerPage.toString(),
      'mailto': _contactEmail,
    };
    if (cursor == null) {
      queryParameters['page'] = safePage.toString();
    } else {
      queryParameters['cursor'] = cursor;
    }
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
    final nextCursor = meta is Map<String, dynamic>
        ? meta['next_cursor']?.toString()
        : null;

    return PublicationSearchPage(
      publications: results
          .whereType<Map<String, dynamic>>()
          .map(Publication.fromOpenAlexJson)
          .toList(growable: false),
      totalCount: totalCount,
      page: safePage,
      perPage: safePerPage,
      nextCursor: nextCursor == null || nextCursor.isEmpty ? null : nextCursor,
    );
  }

  @Deprecated('Use getPublicationsByKeyword instead')
  Future<PublicationSearchPage> getJournalPublicationsByTopicId(
    String topicId, {
    required String sourceId,
    PublicationYearSort yearSort = PublicationYearSort.descending,
    int page = 1,
    int perPage = 50,
    bool excludeFuturePublications = true,
    String? sortOverride,
  }) async {
    final topicFilterValue = _openAlexIdFilterValue(topicId);
    if (topicFilterValue.isEmpty) {
      throw AppError('Please select a topic first.');
    }

    final safePage = page < 1 ? 1 : page;
    final safePerPage = perPage.clamp(1, 50).toInt();
    final filters = _journalTopicWorkFilters(topicFilterValue, sourceId);
    if (excludeFuturePublications) {
      filters.add('to_publication_date:${_currentPublicationDateFilter()}');
    }

    final uri = _openAlexUri('/works', {
      'filter': filters.join(','),
      'sort': sortOverride ?? yearSort.apiSort,
      'page': safePage.toString(),
      'per-page': safePerPage.toString(),
      'mailto': _contactEmail,
    });

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

  /// Get top papers by keyword search.
  /// Sorted by citation count descending.
  Future<List<Publication>> getTopPapersByKeyword(
    String keyword, {
    String? sourceId,
    String? authorId,
    bool excludeFuturePublications = true,
  }) async {
    final page = await getPublicationsByKeyword(
      keyword,
      sourceId: sourceId,
      authorId: authorId,
      page: 1,
      perPage: 50,
      excludeFuturePublications: excludeFuturePublications,
      sortOverride: 'cited_by_count:desc',
    );
    return page.publications;
  }

  @Deprecated('Use getTopPapersByKeyword instead')
  Future<List<Publication>> getJournalTopPapersByTopicId(
    String topicId, {
    required String sourceId,
    bool excludeFuturePublications = true,
  }) async {
    final page = await getJournalPublicationsByTopicId(
      topicId,
      sourceId: sourceId,
      page: 1,
      perPage: 50,
      excludeFuturePublications: excludeFuturePublications,
      sortOverride: 'cited_by_count:desc',
    );
    return page.publications;
  }

  /// Get top authors by keyword search.
  Future<List<RankedEntity>> getTopAuthorsByKeyword(
    String keyword, {
    String? sourceId,
    int limit = 10,
    bool excludeFuturePublications = true,
  }) async {
    final trimmedKeyword = keyword.trim();
    if (trimmedKeyword.isEmpty) return const [];
    final filters = _keywordWorkFilters(trimmedKeyword, sourceId: sourceId);
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

  @Deprecated('Use getTopAuthorsByKeyword instead')
  Future<List<RankedEntity>> getJournalTopAuthorsByTopicId(
    String topicId, {
    required String sourceId,
    int limit = 10,
    bool excludeFuturePublications = true,
  }) async {
    final topicFilterValue = _openAlexIdFilterValue(topicId);
    if (topicFilterValue.isEmpty) return const [];
    final filters = _journalTopicWorkFilters(topicFilterValue, sourceId);
    if (excludeFuturePublications) {
      filters.add('to_publication_date:${_currentPublicationDateFilter()}');
    }
    return _getJournalRankedEntities(
      groupBy: 'authorships.author.id',
      filters: filters,
      limit: limit,
    );
  }

  /// Get publication trend by year for keyword search.
  Future<Map<int, int>> getPublicationTrendByKeyword(
    String keyword, {
    String? sourceId,
    String? authorId,
    bool excludeFuturePublications = true,
  }) async {
    final trimmedKeyword = keyword.trim();
    if (trimmedKeyword.isEmpty) return const {};
    final filters = _keywordWorkFilters(
      trimmedKeyword,
      sourceId: sourceId,
      authorId: authorId,
    );
    if (excludeFuturePublications) {
      filters.add('to_publication_date:${_currentPublicationDateFilter()}');
    }
    final groups = await _getRankedEntities(
      keyword: trimmedKeyword,
      groupBy: 'publication_year',
      filters: filters,
      limit: 200,
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

  @Deprecated('Use getPublicationTrendByKeyword instead')
  Future<Map<int, int>> getJournalPublicationsByYearByTopicId(
    String topicId, {
    required String sourceId,
    bool excludeFuturePublications = true,
  }) async {
    final topicFilterValue = _openAlexIdFilterValue(topicId);
    if (topicFilterValue.isEmpty) return const {};
    final filters = _journalTopicWorkFilters(topicFilterValue, sourceId);
    if (excludeFuturePublications) {
      filters.add('to_publication_date:${_currentPublicationDateFilter()}');
    }
    final groups = await _getJournalRankedEntities(
      groupBy: 'publication_year',
      filters: filters,
      limit: 200,
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

  /// Get average citations for keyword search.
  Future<int?> getAverageCitationsByKeyword(
    String keyword, {
    String? sourceId,
    String? authorId,
    bool excludeFuturePublications = true,
  }) async {
    final trimmedKeyword = keyword.trim();
    if (trimmedKeyword.isEmpty) return null;
    final filters = _keywordWorkFilters(
      trimmedKeyword,
      sourceId: sourceId,
      authorId: authorId,
    );
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
    return totalWorks == 0 ? null : totalCitations ~/ totalWorks;
  }

  Future<List<RankedEntity>> _getAllRankedEntities({
    required String keyword,
    required String groupBy,
    required List<String> filters,
  }) async {
    final entities = <RankedEntity>[];
    String? cursor = '*';

    while (cursor != null) {
      final uri = _openAlexUri('/works', {
        'search': keyword,
        'filter': filters.join(','),
        'group_by': groupBy,
        'per-page': '200',
        'cursor': cursor,
        'mailto': _contactEmail,
      });

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

  @Deprecated('Use getAverageCitationsByKeyword instead')
  Future<int?> getJournalAverageCitationsByTopicId(
    String topicId, {
    required String sourceId,
    bool excludeFuturePublications = true,
  }) async {
    final topicFilterValue = _openAlexIdFilterValue(topicId);
    if (topicFilterValue.isEmpty) return null;
    final filters = _journalTopicWorkFilters(topicFilterValue, sourceId);
    if (excludeFuturePublications) {
      filters.add('to_publication_date:${_currentPublicationDateFilter()}');
    }
    final groups = await _getJournalRankedEntities(
      groupBy: 'cited_by_count',
      filters: filters,
      limit: 200,
    );

    var totalCitations = 0;
    var totalWorks = 0;
    for (final group in groups) {
      final citations = int.tryParse(group.id);
      if (citations == null) continue;
      totalCitations += citations * group.worksCount;
      totalWorks += group.worksCount;
    }
    return totalWorks == 0 ? null : totalCitations ~/ totalWorks;
  }

  Future<List<RankedEntity>> _getRankedEntities({
    required String keyword,
    required String groupBy,
    required List<String> filters,
    int limit = 10,
  }) async {
    final uri = _openAlexUri('/works', {
      'search': keyword,
      'filter': filters.join(','),
      'group_by': groupBy,
      'per-page': '200',
      'mailto': _contactEmail,
    });

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

  Future<List<RankedEntity>> _getJournalRankedEntities({
    required String groupBy,
    required List<String> filters,
    int limit = 10,
  }) async {
    final uri = _openAlexUri('/works', {
      'filter': filters.join(','),
      'group_by': groupBy,
      'per-page': '200',
      'mailto': _contactEmail,
    });

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

  /// Build filters for keyword-based work queries.
  /// Base filters: type:article, primary_location.source.type:journal
  /// Optional: primary_location.source.id for journal drill-down
  List<String> _keywordWorkFilters(
    String keyword, {
    String? sourceId,
    String? authorId,
  }) {
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

  List<String> _journalTopicWorkFilters(String topicId, String sourceId) {
    final sourceFilterValue = _openAlexIdFilterValue(sourceId);
    if (sourceFilterValue.isEmpty) {
      throw AppError('Please select a journal first.');
    }
    return [
      'type:article',
      'primary_location.source.type:journal',
      'topics.id:$topicId',
      'primary_location.source.id:$sourceFilterValue',
    ];
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
    final now = DateTime.now();
    final month = now.month.toString().padLeft(2, '0');
    final day = now.day.toString().padLeft(2, '0');
    return '${now.year}-$month-$day';
  }

  void dispose() {
    _client.close();
  }
}
