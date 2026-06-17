import '../models/publication.dart';
import '../models/ranked_entity.dart';
import '../services/openalex_api_service.dart';

export '../models/ranked_entity.dart' show RankedEntity;
export '../services/openalex_api_service.dart'
    show PublicationSearchPage, PublicationYearSort;

class PublicationRepository {
  final OpenAlexApiService _apiService;

  PublicationRepository({OpenAlexApiService? apiService})
    : _apiService = apiService ?? OpenAlexApiService();

  Future<PublicationSearchPage> searchPublicationsPage(
    String topic, {
    PublicationYearSort yearSort = PublicationYearSort.descending,
    int page = 1,
    bool excludeFuturePublications = false,
  }) {
    return _apiService.searchWorksPage(
      topic: topic,
      yearSort: yearSort,
      page: page,
      excludeFuturePublications: excludeFuturePublications,
    );
  }

  Future<Map<int, int>> getPublicationsByYear(
    String topic, {
    bool excludeFuturePublications = false,
  }) {
    return _apiService.getPublicationsByYear(
      topic,
      excludeFuturePublications: excludeFuturePublications,
    );
  }

  Future<List<Publication>> getTopPapers(
    String topic, {
    bool excludeFuturePublications = false,
  }) {
    return _apiService.getTopPapers(
      topic,
      excludeFuturePublications: excludeFuturePublications,
    );
  }

  Future<List<RankedEntity>> getTopJournals(
    String topic, {
    int limit = 10,
    bool excludeFuturePublications = false,
  }) {
    return _apiService.getTopJournals(
      topic,
      limit: limit,
      excludeFuturePublications: excludeFuturePublications,
    );
  }

  Future<List<RankedEntity>> getTopAuthors(
    String topic, {
    int limit = 10,
    bool excludeFuturePublications = false,
  }) {
    return _apiService.getTopAuthors(
      topic,
      limit: limit,
      excludeFuturePublications: excludeFuturePublications,
    );
  }

  Future<int?> getAverageCitations(
    String topic, {
    bool excludeFuturePublications = false,
  }) {
    return _apiService.getAverageCitations(
      topic,
      excludeFuturePublications: excludeFuturePublications,
    );
  }

  Future<PublicationSearchPage> searchPublicationsByEntity(
    String topic, {
    String? sourceId,
    String? authorId,
    PublicationYearSort yearSort = PublicationYearSort.descending,
    int page = 1,
    bool excludeFuturePublications = false,
  }) {
    return _apiService.searchWorksByEntity(
      topic: topic,
      sourceId: sourceId,
      authorId: authorId,
      yearSort: yearSort,
      page: page,
      excludeFuturePublications: excludeFuturePublications,
    );
  }

  void dispose() {
    _apiService.dispose();
  }
}
