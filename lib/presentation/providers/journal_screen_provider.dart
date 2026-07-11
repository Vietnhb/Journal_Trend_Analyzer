import 'dart:async';

import 'package:flutter/foundation.dart';

import '../../core/constants/app_limits.dart';
import '../../core/errors/app_errors.dart';
import '../../data/repositories/journal_repository.dart';
import '../../data/services/firebase_service.dart';

class JournalSearchProvider extends ChangeNotifier {
  final JournalRepository _repository;
  int resultLimit;

  JournalSearchProvider({
    this.resultLimit = AppLimits.topJournalResults,
    JournalRepository? repository,
  }) : _repository = repository ?? JournalRepository();

  String query = '';
  bool isSearching = false;
  AppError? error;
  List<JournalProfile> results = const [];

  Future<void> search(String value) async {
    final normalized = value.trim();
    if (normalized.isEmpty || isSearching) return;

    query = normalized;
    isSearching = true;
    error = null;
    results = const [];
    notifyListeners();

    try {
      results = await _repository.searchJournals(
        normalized,
        limit: resultLimit,
      );
    } on AppError catch (caught) {
      error = caught;
    } catch (caught) {
      error = AppError(
        'Could not search journals.',
        details: caught.toString(),
      );
    } finally {
      isSearching = false;
      notifyListeners();
    }
  }

  void clear() {
    query = '';
    isSearching = false;
    error = null;
    results = const [];
    notifyListeners();
  }

  @override
  void dispose() {
    _repository.dispose();
    super.dispose();
  }
}

class JournalDetailProvider extends ChangeNotifier {
  final JournalRepository _repository;

  JournalDetailProvider(
    JournalProfile initialProfile, {
    JournalRepository? repository,
  }) : profile = initialProfile,
       _repository = repository ?? JournalRepository() {
    unawaited(
      FirebaseService.instance.logEvent(
        'view_journal',
        parameters: {'journal_name': initialProfile.name},
      ),
    );
  }

  JournalProfile profile;
  List<Publication> relatedPublications = const [];
  bool isLoading = true;
  AppError? error;

  double? get averageCitations => profile.worksCount == 0
      ? null
      : profile.citedByCount / profile.worksCount;

  Future<void> load() async {
    isLoading = true;
    error = null;
    notifyListeners();

    try {
      final loadedProfile = await _repository.getJournalProfile(profile.id);
      final loadedPublications = await _repository.getPublicationsBySource(
        loadedProfile.id,
      );
      profile = loadedProfile;
      relatedPublications = loadedPublications;
    } on AppError catch (caught) {
      error = caught;
    } catch (caught) {
      error = AppError(
        'Could not load journal analysis.',
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
