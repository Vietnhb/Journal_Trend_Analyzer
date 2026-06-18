import '../../core/constants/app_limits.dart';
import '../models/publication.dart';
import '../models/ranked_entity.dart';
import '../services/openalex_api_service.dart';

export '../models/publication.dart' show Publication;
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
    int limit = AppLimits.topJournalResults,
    bool excludeFuturePublications = true,
  }) {
    return _apiService.getTopJournalsByKeyword(
      keyword,
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
    int page = 1,
    bool excludeFuturePublications = true,
    PublicationListSort? publicationSort,
    String? sortOverride,
  }) {
    return _apiService.getPublicationsByKeyword(
      keyword,
      sourceId: sourceId,
      authorId: authorId,
      page: page,
      excludeFuturePublications: excludeFuturePublications,
      publicationSort: publicationSort,
      sortOverride: sortOverride,
    );
  }

  /// Get top papers by keyword search, sorted by citation count.
  Future<List<Publication>> getTopPapersByKeyword(
    String keyword, {
    bool excludeFuturePublications = true,
  }) {
    return _apiService.getTopPapersByKeyword(
      keyword,
      excludeFuturePublications: excludeFuturePublications,
    );
  }

  /// Get top authors by keyword search.
  Future<List<RankedEntity>> getTopAuthorsByKeyword(
    String keyword, {
    int limit = AppLimits.rankedEntityResults,
    bool excludeFuturePublications = true,
  }) {
    return _apiService.getTopAuthorsByKeyword(
      keyword,
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

  Future<List<RankedEntity>> getTrendingKeywords({
    int limit = AppLimits.trendingKeywordResults,
  }) {
    return _apiService.getTrendingKeywords(limit: limit);
  }

  void dispose() {
    _apiService.dispose();
  }
}
