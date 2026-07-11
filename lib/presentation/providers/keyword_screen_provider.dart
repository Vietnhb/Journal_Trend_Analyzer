import 'dart:async';

import 'package:flutter/foundation.dart';

import '../../core/constants/app_limits.dart';
import '../../core/errors/app_errors.dart';
import '../../data/repositories/journal_repository.dart';
import '../../data/services/firebase_service.dart';

class MonthlyKeywordsProvider extends ChangeNotifier {
  final JournalRepository _repository;
  int resultLimit;

  MonthlyKeywordsProvider({
    this.resultLimit = AppLimits.monthlyKeywordResults,
    JournalRepository? repository,
  }) : _repository = repository ?? JournalRepository();

  bool isLoading = true;
  AppError? error;
  List<RankedEntity> keywords = const [];

  Future<void> load() async {
    isLoading = true;
    error = null;
    notifyListeners();
    try {
      keywords = await _repository.getTopKeywordsInRecentMonth(
        limit: resultLimit,
      );
    } on AppError catch (caught) {
      error = caught;
    } catch (caught) {
      error = AppError(
        'Could not load monthly keyword rankings.',
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

class KeywordDetailProvider extends ChangeNotifier {
  final JournalRepository _repository;
  final String keyword;
  final bool excludeFuturePublications;
  final int maxJournals;

  KeywordDetailProvider({
    required this.keyword,
    required this.excludeFuturePublications,
    required this.maxJournals,
    JournalRepository? repository,
  }) : _repository = repository ?? JournalRepository() {
    unawaited(
      FirebaseService.instance.logEvent(
        'view_keyword',
        parameters: {'keyword': keyword},
      ),
    );
  }

  bool isLoading = true;
  AppError? error;
  List<RankedEntity> journals = const [];
  List<Publication> publications = const [];
  List<RankedEntity> authors = const [];
  Map<int, int> publicationsByYear = const {};

  Future<void> load() async {
    isLoading = true;
    error = null;
    notifyListeners();
    try {
      late List<RankedEntity> loadedJournals;
      late List<Publication> loadedPublications;
      late List<RankedEntity> loadedAuthors;
      late Map<int, int> loadedTrend;
      await Future.wait<void>([
        _repository
            .getTopJournalsByKeyword(
              keyword,
              limit: maxJournals,
              excludeFuturePublications: excludeFuturePublications,
            )
            .then((value) => loadedJournals = value),
        _repository
            .getTopPapersByKeyword(
              keyword,
              excludeFuturePublications: excludeFuturePublications,
            )
            .then((value) => loadedPublications = value),
        _repository
            .getTopAuthorsByKeyword(
              keyword,
              excludeFuturePublications: excludeFuturePublications,
            )
            .then((value) => loadedAuthors = value),
        _repository
            .getPublicationTrendByKeyword(
              keyword,
              excludeFuturePublications: excludeFuturePublications,
            )
            .then((value) => loadedTrend = value),
      ]);
      journals = loadedJournals;
      publications = loadedPublications;
      authors = loadedAuthors;
      publicationsByYear = loadedTrend;
    } on AppError catch (caught) {
      error = caught;
    } catch (caught) {
      error = AppError(
        'Could not load keyword analysis.',
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
