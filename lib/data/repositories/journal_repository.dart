import '../../core/constants/app_limits.dart';
import '../models/publication.dart';
import '../models/ranked_entity.dart';
import '../services/openalex_api_service.dart';

export '../models/publication.dart' show Publication;
export '../models/ranked_entity.dart' show RankedEntity;
export '../services/openalex_api_service.dart'
    show
        CitationStats,
        PublicationListSort,
        PublicationSearchPage,
        PublicationYearSort;

class JournalRepository {
  final OpenAlexApiService _apiService;

  JournalRepository({OpenAlexApiService? apiService})
    : _apiService = apiService ?? OpenAlexApiService();

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

  Future<List<Publication>> getTopPapersByKeyword(
    String keyword, {
    bool excludeFuturePublications = true,
  }) {
    return _apiService.getTopPapersByKeyword(
      keyword,
      excludeFuturePublications: excludeFuturePublications,
    );
  }

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

  Future<CitationStats> getCitationStatsByKeyword(
    String keyword, {
    String? sourceId,
    String? authorId,
    bool excludeFuturePublications = true,
  }) {
    return _apiService.getCitationStatsByKeyword(
      keyword,
      sourceId: sourceId,
      authorId: authorId,
      excludeFuturePublications: excludeFuturePublications,
    );
  }

  Future<List<RankedEntity>> getKeywordsByKeyword(
    String keyword, {
    int limit = AppLimits.trendingKeywordResults,
    bool excludeFuturePublications = true,
  }) {
    return _apiService.getKeywordsByKeyword(
      keyword,
      limit: limit,
      excludeFuturePublications: excludeFuturePublications,
    );
  }

  void dispose() {
    _apiService.dispose();
  }
}
