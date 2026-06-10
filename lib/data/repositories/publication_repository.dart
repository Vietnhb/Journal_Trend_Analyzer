import '../models/publication.dart';
import '../services/openalex_api_service.dart';

class PublicationRepository {
  final OpenAlexApiService _apiService;

  PublicationRepository({OpenAlexApiService? apiService})
    : _apiService = apiService ?? OpenAlexApiService();

  Future<List<Publication>> searchPublications(String topic) {
    return _apiService.searchWorks(topic: topic);
  }

  void dispose() {
    _apiService.dispose();
  }
}
