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
  }) {
    return _apiService.searchWorksPage(
      topic: topic,
      yearSort: yearSort,
      page: page,
    );
  }

  Future<Map<int, int>> getPublicationsByYear(String topic) {
    return _apiService.getPublicationsByYear(topic);
  }

  Future<List<Publication>> getTopPapers(String topic) {
    return _apiService.getTopPapers(topic);
  }

  void dispose() {
    _apiService.dispose();
  }
}
