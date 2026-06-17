import '../models/publication.dart';
import '../services/openalex_api_service.dart';

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

  void dispose() {
    _apiService.dispose();
  }
}
