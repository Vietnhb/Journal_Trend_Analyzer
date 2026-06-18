import '../models/publication.dart';
import '../models/openalex_topic.dart';
import '../models/ranked_entity.dart';
import '../services/openalex_api_service.dart';

export '../models/publication.dart' show Publication;
export '../models/openalex_topic.dart' show OpenAlexTopic;
export '../models/ranked_entity.dart' show RankedEntity;
export '../services/openalex_api_service.dart'
    show PublicationListSort, PublicationSearchPage, PublicationYearSort;

class JournalRepository {
  final OpenAlexApiService _apiService;

  JournalRepository({OpenAlexApiService? apiService})
    : _apiService = apiService ?? OpenAlexApiService();

  // ============ Keyword-based Methods (Primary) ============

  /// Get top journals by keyword search.
  /// Returns journals with the most articles related to the keyword.
  Future<List<RankedEntity>> getTopJournalsByKeyword(
    String keyword, {
    String? sourceId,
    int limit = 50,
    bool excludeFuturePublications = true,
  }) {
    return _apiService.getTopJournalsByKeyword(
      keyword,
      sourceId: sourceId,
      limit: limit,
      excludeFuturePublications: excludeFuturePublications,
    );
  }

  /// Get publications by keyword search.
  /// Optionally filter by sourceId for journal drill-down.
  Future<PublicationSearchPage> getPublicationsByKeyword(
    String keyword, {
    String? sourceId,
    String? authorId,
    PublicationYearSort yearSort = PublicationYearSort.descending,
    int page = 1,
    bool excludeFuturePublications = true,
    String? cursor,
    PublicationListSort? publicationSort,
    String? sortOverride,
  }) {
    return _apiService.getPublicationsByKeyword(
      keyword,
      sourceId: sourceId,
      authorId: authorId,
      yearSort: yearSort,
      page: page,
      excludeFuturePublications: excludeFuturePublications,
      cursor: cursor,
      publicationSort: publicationSort,
      sortOverride: sortOverride,
    );
  }

  /// Get top papers by keyword search, sorted by citation count.
  Future<List<Publication>> getTopPapersByKeyword(
    String keyword, {
    String? sourceId,
    String? authorId,
    bool excludeFuturePublications = true,
  }) {
    return _apiService.getTopPapersByKeyword(
      keyword,
      sourceId: sourceId,
      authorId: authorId,
      excludeFuturePublications: excludeFuturePublications,
    );
  }

  /// Get top authors by keyword search.
  Future<List<RankedEntity>> getTopAuthorsByKeyword(
    String keyword, {
    String? sourceId,
    int limit = 10,
    bool excludeFuturePublications = true,
  }) {
    return _apiService.getTopAuthorsByKeyword(
      keyword,
      sourceId: sourceId,
      limit: limit,
      excludeFuturePublications: excludeFuturePublications,
    );
  }

  /// Get publication trend by year for keyword search.
  Future<Map<int, int>> getPublicationTrendByKeyword(
    String keyword, {
    String? sourceId,
    String? authorId,
    bool excludeFuturePublications = true,
  }) {
    return _apiService.getPublicationTrendByKeyword(
      keyword,
      sourceId: sourceId,
      authorId: authorId,
      excludeFuturePublications: excludeFuturePublications,
    );
  }

  /// Get average citations for keyword search.
  Future<int?> getAverageCitationsByKeyword(
    String keyword, {
    String? sourceId,
    String? authorId,
    bool excludeFuturePublications = true,
  }) {
    return _apiService.getAverageCitationsByKeyword(
      keyword,
      sourceId: sourceId,
      authorId: authorId,
      excludeFuturePublications: excludeFuturePublications,
    );
  }

  // ============ Common Methods ============

  /// Search for OpenAlex topics (optional, for advanced filtering).
  Future<List<OpenAlexTopic>> searchTopics(String keyword, {int limit = 10}) {
    return _apiService.searchTopics(keyword, limit: limit);
  }

  /// Get detailed journal/source metadata.
  Future<RankedEntity> getJournalSourceDetail(String sourceId) {
    return _apiService.getJournalSourceDetail(sourceId);
  }

  // ============ Deprecated Topic-based Methods ============

  @Deprecated('Use getTopJournalsByKeyword instead')
  Future<List<RankedEntity>> getTopJournalsByTopicId(
    String topicId, {
    int limit = 50,
  }) {
    return _apiService.getTopJournalsByTopicId(topicId, limit: limit);
  }

  @Deprecated('Use getPublicationsByKeyword instead')
  Future<PublicationSearchPage> getJournalPublicationsByTopicId(
    String topicId, {
    required String sourceId,
    PublicationYearSort yearSort = PublicationYearSort.descending,
    int page = 1,
    bool excludeFuturePublications = true,
  }) {
    return _apiService.getJournalPublicationsByTopicId(
      topicId,
      sourceId: sourceId,
      yearSort: yearSort,
      page: page,
      excludeFuturePublications: excludeFuturePublications,
    );
  }

  @Deprecated('Use getTopPapersByKeyword instead')
  Future<List<Publication>> getJournalTopPapersByTopicId(
    String topicId, {
    required String sourceId,
    bool excludeFuturePublications = true,
  }) {
    return _apiService.getJournalTopPapersByTopicId(
      topicId,
      sourceId: sourceId,
      excludeFuturePublications: excludeFuturePublications,
    );
  }

  @Deprecated('Use getTopAuthorsByKeyword instead')
  Future<List<RankedEntity>> getJournalTopAuthorsByTopicId(
    String topicId, {
    required String sourceId,
    int limit = 10,
    bool excludeFuturePublications = true,
  }) {
    return _apiService.getJournalTopAuthorsByTopicId(
      topicId,
      sourceId: sourceId,
      limit: limit,
      excludeFuturePublications: excludeFuturePublications,
    );
  }

  @Deprecated('Use getPublicationTrendByKeyword instead')
  Future<Map<int, int>> getJournalPublicationsByYearByTopicId(
    String topicId, {
    required String sourceId,
    bool excludeFuturePublications = true,
  }) {
    return _apiService.getJournalPublicationsByYearByTopicId(
      topicId,
      sourceId: sourceId,
      excludeFuturePublications: excludeFuturePublications,
    );
  }

  @Deprecated('Use getAverageCitationsByKeyword instead')
  Future<int?> getJournalAverageCitationsByTopicId(
    String topicId, {
    required String sourceId,
    bool excludeFuturePublications = true,
  }) {
    return _apiService.getJournalAverageCitationsByTopicId(
      topicId,
      sourceId: sourceId,
      excludeFuturePublications: excludeFuturePublications,
    );
  }

  void dispose() {
    _apiService.dispose();
  }
}
