import '../models/ranked_entity.dart';
import '../services/openalex_api_service.dart';

export '../models/ranked_entity.dart' show RankedEntity;
export '../services/openalex_api_service.dart' show PublicationYearSort;

class JournalRepository {
  final OpenAlexApiService _apiService;

  JournalRepository({OpenAlexApiService? apiService})
    : _apiService = apiService ?? OpenAlexApiService();

  Future<List<RankedEntity>> getTopJournalsByTopic(
    String topic, {
    int limit = 25,
  }) {
    return _apiService.getTopJournalsByTopic(topic, limit: limit);
  }

  void dispose() {
    _apiService.dispose();
  }
}
