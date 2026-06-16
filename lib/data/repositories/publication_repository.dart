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

  void dispose() {
    _apiService.dispose();
  }
}
