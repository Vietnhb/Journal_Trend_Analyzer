import 'dart:async';

import 'package:flutter/foundation.dart';

import '../../core/errors/app_errors.dart';
import '../../data/repositories/journal_repository.dart';
import '../../data/services/firebase_service.dart';

enum AnalyticsEntityType { journal, author }

class EntityAnalyticsProvider extends ChangeNotifier {
  final JournalRepository _repository;
  final AnalyticsEntityType type;
  final RankedEntity entity;
  final String keyword;
  final bool excludeFuturePublications;

  EntityAnalyticsProvider({
    required this.type,
    required this.entity,
    required this.keyword,
    required this.excludeFuturePublications,
    JournalRepository? repository,
  }) : _repository = repository ?? JournalRepository() {
    if (type == AnalyticsEntityType.journal) {
      unawaited(
        FirebaseService.instance.logEvent(
          'view_journal',
          parameters: {'journal_name': entity.name},
        ),
      );
    }
  }

  bool isLoading = true;
  AppError? error;
  List<Publication> publications = const [];
  Map<int, int> publicationsByYear = const {};
  int totalPublications = 0;
  int totalCitations = 0;
  int? averageCitations;

  String? get sourceId =>
      type == AnalyticsEntityType.journal ? entity.id : null;
  String? get authorId => type == AnalyticsEntityType.author ? entity.id : null;

  Future<void> load() async {
    isLoading = true;
    error = null;
    notifyListeners();
    try {
      final page = await _repository.getPublicationsByKeyword(
        keyword,
        sourceId: sourceId,
        authorId: authorId,
        page: 1,
        excludeFuturePublications: excludeFuturePublications,
        sortOverride: 'cited_by_count:desc',
      );
      final trend = await _repository.getPublicationTrendByKeyword(
        keyword,
        sourceId: sourceId,
        authorId: authorId,
        excludeFuturePublications: excludeFuturePublications,
      );
      final stats = await _repository.getCitationStatsByKeyword(
        keyword,
        sourceId: sourceId,
        authorId: authorId,
        excludeFuturePublications: excludeFuturePublications,
      );
      publications = page.publications;
      totalPublications = page.totalCount;
      publicationsByYear = trend;
      totalCitations = stats.totalCitations;
      averageCitations = stats.averageCitations;
    } on AppError catch (caught) {
      error = caught;
    } catch (caught) {
      error = AppError(
        'Could not load filtered analytics.',
        details: caught.toString(),
      );
    } finally {
      isLoading = false;
      notifyListeners();
    }
  }

  @override
  void dispose() {
    _repository.dispose();
    super.dispose();
  }
}
