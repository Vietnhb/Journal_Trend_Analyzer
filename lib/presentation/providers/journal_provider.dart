import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../../core/constants/app_limits.dart';
import '../../core/errors/app_errors.dart';
import '../../data/models/dashboard_report_data.dart';
import '../../data/repositories/journal_repository.dart';
import '../../data/services/firebase_service.dart';

class JournalProvider extends ChangeNotifier {
  static const _recentSearchesKey = 'recent_searches';
  static const _maxRecentSearches = 10;

  final JournalRepository _repository;

  JournalProvider({JournalRepository? repository})
    : _repository = repository ?? JournalRepository() {
    unawaited(_loadRecentSearches());
  }

  String _selectedKeyword = '';
  String _topicSearchQuery = '';
  bool _isLoading = false;
  AppError? _error;
  PublicationListSort _publicationSort = PublicationListSort.newest;
  List<String> _recentSearches = const [];
  List<RankedEntity> _trendingKeywords = const [];
  bool _isLoadingTrendingKeywords = false;
  AppError? _trendingKeywordError;

  List<RankedEntity> _journals = const [];

  bool _isLoadingAnalytics = false;
  AppError? _analyticsError;
  List<Publication> _topPapers = const [];
  List<RankedEntity> _topAuthors = const [];
  Map<int, int> _publicationsByYear = const {};
  int? _averageCitations;
  int _keywordPublicationTotal = 0;

  bool _isLoadingJournalPublications = false;
  AppError? _journalPublicationError;
  List<Publication> _journalPublications = const [];
  int _journalPublicationTotal = 0;
  int _currentPage = 1;
  int _perPage = AppLimits.publicationPageSize;
  int? _loadingPage;

  bool _isDarkMode = false;
  bool _filterFutureSourceYears = true;
  bool _isDisposed = false;

  String get selectedKeyword => _selectedKeyword;
  String get topicSearchQuery => _topicSearchQuery;

  bool get isLoading => _isLoading;
  AppError? get error => _error;
  PublicationListSort get publicationSort => _publicationSort;
  List<String> get recentSearches => _recentSearches;
  List<RankedEntity> get trendingKeywords => _trendingKeywords;
  bool get isLoadingTrendingKeywords => _isLoadingTrendingKeywords;
  AppError? get trendingKeywordError => _trendingKeywordError;

  List<RankedEntity> get journals => _journals;

  bool get isLoadingAnalytics => _isLoadingAnalytics;
  AppError? get analyticsError => _analyticsError;
  List<RankedEntity> get keywordAnalyticsTopAuthors =>
      List.unmodifiable(_topAuthors.take(AppLimits.keywordAnalyticsCardLimit));

  bool get isLoadingJournalPublications => _isLoadingJournalPublications;
  AppError? get journalPublicationError => _journalPublicationError;
  List<Publication> get journalPublications => _journalPublications;
  int get journalTotalAvailable => _journalPublicationTotal;
  int get currentPage => _currentPage;
  int? get loadingPage => _loadingPage;
  int get totalPages {
    if (_journalPublicationTotal <= 0) return 1;
    return (_journalPublicationTotal / _perPage).ceil();
  }

  int get directPageLimit => totalPages < AppLimits.directPageNavigationLimit
      ? totalPages
      : AppLimits.directPageNavigationLimit;

  bool get canGoPrevious =>
      _canNavigateTo(_currentPage - 1) && !_isLoadingJournalPublications;
  bool get canGoNext =>
      _canNavigateTo(_currentPage + 1) && !_isLoadingJournalPublications;

  bool get isDarkMode => _isDarkMode;
  bool get filterFutureSourceYears => _filterFutureSourceYears;
  bool get hasDashboard => _selectedKeyword.isNotEmpty;

  DashboardReportData? get dashboardReportData {
    if (!hasDashboard) return null;
    return DashboardReportData(
      topic: _selectedKeyword,
      totalPublications: totalWorks,
      averageCitations: avgCitationCount,
      mostActiveYear: mostActiveYear,
      topJournal: topJournal,
      topAuthor: topAuthor,
      mostInfluentialPublication: mostInfluentialPaper,
      publicationsByYear: sourceWorksByYear,
      journals: List.unmodifiable(_journals.take(AppLimits.topJournalResults)),
      publications: List.unmodifiable(_journalPublications),
    );
  }

  int get totalWorks => _keywordPublicationTotal;
  int? get avgCitationCount => _averageCitations;

  int? get mostActiveYear {
    final ranked = yearsByWorkCount;
    return ranked.isEmpty ? null : ranked.first.key;
  }

  String? get topJournal => _journals.isEmpty ? null : _journals.first.name;
  String? get topAuthor => _topAuthors.isEmpty ? null : _topAuthors.first.name;
  Publication? get mostInfluentialPaper =>
      _topPapers.isEmpty ? null : _topPapers.first;

  Map<int, int> get sourceWorksByYear {
    if (!_filterFutureSourceYears) return _publicationsByYear;
    final currentYear = DateTime.now().year;
    return Map<int, int>.fromEntries(
      _publicationsByYear.entries.where((entry) => entry.key <= currentYear),
    );
  }

  List<MapEntry<int, int>> get yearsByWorkCount {
    final list = sourceWorksByYear.entries.toList();
    list.sort((a, b) {
      final countCompare = b.value.compareTo(a.value);
      return countCompare != 0 ? countCompare : b.key.compareTo(a.key);
    });
    return list;
  }

  Future<void> analyzeKeyword(String keyword) async {
    final trimmed = keyword.trim();
    if (trimmed.isEmpty || _isLoading) return;

    unawaited(
      FirebaseService.instance.logEvent(
        'search_topic',
        parameters: {'keyword': trimmed},
      ),
    );
    _rememberSearchInMemory(trimmed);
    _topicSearchQuery = trimmed;
    _selectedKeyword = trimmed;
    _isLoading = true;
    _isLoadingAnalytics = true;
    _error = null;
    _analyticsError = null;
    _journals = const [];
    _trendingKeywords = const [];
    _trendingKeywordError = null;
    _clearKeywordAnalytics();
    _clearJournalPublications();
    notifyListeners();
    await _saveRecentSearches();

    try {
      await _loadKeywordAnalytics(trimmed);
    } on AppError catch (error) {
      _error = error;
      _analyticsError = error;
    } catch (error) {
      final appError = AppError(
        'Topic analysis failed.',
        details: error.toString(),
      );
      _error = appError;
      _analyticsError = appError;
    } finally {
      _isLoading = false;
      _isLoadingAnalytics = false;
      notifyListeners();
    }
  }

  Future<void> refreshKeywordAnalytics() async {
    if (_selectedKeyword.isEmpty || _isLoadingAnalytics) return;
    _isLoadingAnalytics = true;
    _analyticsError = null;
    notifyListeners();

    try {
      await _loadKeywordAnalytics(_selectedKeyword);
    } on AppError catch (error) {
      _analyticsError = error;
    } catch (error) {
      _analyticsError = AppError(
        'Could not refresh topic analytics.',
        details: error.toString(),
      );
    } finally {
      _isLoadingAnalytics = false;
      notifyListeners();
    }
  }

  Future<void> loadTrendingKeywords({bool force = false}) async {
    if (_isLoadingTrendingKeywords) return;
    final keyword = _selectedKeyword;
    if (keyword.isEmpty) return;
    if (!force && _trendingKeywords.isNotEmpty) return;

    _isLoadingTrendingKeywords = true;
    _trendingKeywordError = null;
    notifyListeners();

    try {
      final keywords = await _repository.getKeywordsByKeyword(
        keyword,
        limit: AppLimits.trendingKeywordResults,
        excludeFuturePublications: _filterFutureSourceYears,
      );
      if (_isDisposed) return;
      _trendingKeywords = keywords;
    } on AppError catch (error) {
      if (_isDisposed) return;
      _trendingKeywordError = error;
    } catch (error) {
      if (_isDisposed) return;
      _trendingKeywordError = AppError(
        'Could not load keywords for the selected topic.',
        details: error.toString(),
      );
    } finally {
      if (!_isDisposed) {
        _isLoadingTrendingKeywords = false;
        notifyListeners();
      }
    }
  }

  Future<void> _loadKeywordAnalytics(String keyword) async {
    final journalsFuture = _repository.getTopJournalsByKeyword(
      keyword,
      limit: AppLimits.topJournalResults,
      excludeFuturePublications: _filterFutureSourceYears,
    );
    final publicationPageFuture = _repository.getPublicationsByKeyword(
      keyword,
      page: 1,
      excludeFuturePublications: _filterFutureSourceYears,
      publicationSort: _publicationSort,
    );
    final keywordsFuture = _repository.getKeywordsByKeyword(
      keyword,
      limit: AppLimits.trendingKeywordResults,
      excludeFuturePublications: _filterFutureSourceYears,
    );

    late List<RankedEntity> journals;
    late PublicationSearchPage countPage;
    late List<RankedEntity> keywords;
    await Future.wait<void>([
      journalsFuture.then((value) => journals = value),
      publicationPageFuture.then((value) => countPage = value),
      keywordsFuture.then((value) => keywords = value),
    ]);

    _journals = journals;
    _trendingKeywords = keywords;
    _trendingKeywordError = null;
    _keywordPublicationTotal = countPage.totalCount;
    _applyJournalPublicationPage(countPage);
    notifyListeners();

    await Future<void>.delayed(const Duration(milliseconds: 180));
    final topPapersFuture = _repository.getTopPapersByKeyword(
      keyword,
      excludeFuturePublications: _filterFutureSourceYears,
    );
    final topAuthorsFuture = _repository.getTopAuthorsByKeyword(
      keyword,
      limit: AppLimits.topAuthorResults,
      excludeFuturePublications: _filterFutureSourceYears,
    );

    late List<Publication> topPapers;
    late List<RankedEntity> topAuthors;
    await Future.wait<void>([
      topPapersFuture.then((value) => topPapers = value),
      topAuthorsFuture.then((value) => topAuthors = value),
    ]);

    _topPapers = topPapers;
    _topAuthors = topAuthors;
    notifyListeners();

    await Future<void>.delayed(const Duration(milliseconds: 180));
    final publicationTrendFuture = _repository.getPublicationTrendByKeyword(
      keyword,
      excludeFuturePublications: _filterFutureSourceYears,
    );
    final averageCitationsFuture = _repository.getAverageCitationsByKeyword(
      keyword,
      excludeFuturePublications: _filterFutureSourceYears,
    );

    late Map<int, int> publicationsByYear;
    int? averageCitations;
    await Future.wait<void>([
      publicationTrendFuture.then((value) => publicationsByYear = value),
      averageCitationsFuture.then((value) => averageCitations = value),
    ]);

    _publicationsByYear = publicationsByYear;
    _averageCitations = averageCitations;
  }

  Future<void> goToPage(int pageNumber, {bool force = false}) async {
    if (_selectedKeyword.isEmpty || _isLoadingJournalPublications) {
      return;
    }
    final targetPage = pageNumber.clamp(1, totalPages).toInt();
    if (!force && targetPage == _currentPage) return;
    if (!_canNavigateTo(targetPage)) return;

    _isLoadingJournalPublications = true;
    _loadingPage = targetPage;
    _journalPublicationError = null;
    notifyListeners();

    try {
      final reversePage = totalPages - targetPage + 1;
      final useReverseOrder = targetPage > directPageLimit;
      final apiPage = useReverseOrder ? reversePage : targetPage;
      final result = await _repository.getPublicationsByKeyword(
        _selectedKeyword,
        page: apiPage,
        excludeFuturePublications: _filterFutureSourceYears,
        publicationSort: _publicationSort,
        sortOverride: useReverseOrder ? _publicationSort.reverseApiSort : null,
      );
      final page = useReverseOrder
          ? PublicationSearchPage(
              publications: result.publications.reversed.toList(
                growable: false,
              ),
              totalCount: result.totalCount,
              page: targetPage,
              perPage: result.perPage,
            )
          : result;
      _applyJournalPublicationPage(page);
    } on AppError catch (error) {
      _journalPublicationError = error;
    } catch (error) {
      _journalPublicationError = AppError(
        'Could not load journal publications.',
        details: error.toString(),
      );
    } finally {
      _isLoadingJournalPublications = false;
      _loadingPage = null;
      notifyListeners();
    }
  }

  bool _canNavigateTo(int page) {
    if (page < 1 || page > totalPages) return false;
    return page <= directPageLimit || totalPages - page + 1 <= directPageLimit;
  }

  Future<void> setPublicationSort(PublicationListSort sort) async {
    if (_publicationSort == sort) return;
    _publicationSort = sort;
    if (_selectedKeyword.isNotEmpty) {
      await goToPage(1, force: true);
    } else {
      notifyListeners();
    }
  }

  void setDarkMode(bool enabled) {
    if (_isDarkMode == enabled) return;
    _isDarkMode = enabled;
    notifyListeners();
  }

  Future<void> setFilterFutureSourceYears(bool enabled) async {
    if (_filterFutureSourceYears == enabled) return;
    _filterFutureSourceYears = enabled;
    notifyListeners();
    if (_selectedKeyword.isEmpty) return;

    await refreshKeywordAnalytics();
  }

  void clear() {
    _selectedKeyword = '';
    _topicSearchQuery = '';
    _isLoading = false;
    _error = null;
    _publicationSort = PublicationListSort.newest;
    _journals = const [];
    _trendingKeywords = const [];
    _trendingKeywordError = null;
    _isLoadingAnalytics = false;
    _analyticsError = null;
    _isLoadingJournalPublications = false;
    _journalPublicationError = null;
    _clearKeywordAnalytics();
    _clearJournalPublications();
    notifyListeners();
  }

  Future<void> clearRecentSearches() async {
    if (_recentSearches.isEmpty) return;
    _recentSearches = const [];
    notifyListeners();
    await _saveRecentSearches();
  }

  void _rememberSearchInMemory(String query) {
    final updated = [
      query,
      ..._recentSearches.where(
        (item) => item.toLowerCase() != query.toLowerCase(),
      ),
    ].take(_maxRecentSearches);
    _recentSearches = List.unmodifiable(updated);
  }

  Future<void> _loadRecentSearches() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final stored = prefs.getStringList(_recentSearchesKey) ?? const [];
      final sanitized = _sanitizeRecentSearches(stored);
      if (_isDisposed) return;

      final merged = _mergeRecentSearches(_recentSearches, sanitized);
      if (listEquals(_recentSearches, merged)) return;

      _recentSearches = List.unmodifiable(merged);
      notifyListeners();
      if (!listEquals(sanitized, merged)) {
        await _saveRecentSearches();
      }
    } catch (error) {
      debugPrint('Could not load recent searches: $error');
    }
  }

  Future<void> _saveRecentSearches() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setStringList(_recentSearchesKey, _recentSearches);
    } catch (error) {
      debugPrint('Could not save recent searches: $error');
    }
  }

  List<String> _sanitizeRecentSearches(List<String> searches) {
    final result = <String>[];
    final seen = <String>{};
    for (final search in searches) {
      final trimmed = search.trim();
      final key = trimmed.toLowerCase();
      if (trimmed.isEmpty || seen.contains(key)) continue;
      result.add(trimmed);
      seen.add(key);
      if (result.length >= _maxRecentSearches) break;
    }
    return result;
  }

  List<String> _mergeRecentSearches(
    List<String> priority,
    List<String> fallback,
  ) {
    return _sanitizeRecentSearches([...priority, ...fallback]);
  }

  void _applyJournalPublicationPage(PublicationSearchPage page) {
    _journalPublications = page.publications;
    _journalPublicationTotal = page.totalCount;
    _currentPage = page.page;
    _perPage = page.perPage;
  }

  void _clearKeywordAnalytics() {
    _topPapers = const [];
    _topAuthors = const [];
    _publicationsByYear = const {};
    _averageCitations = null;
    _keywordPublicationTotal = 0;
  }

  void _clearJournalPublications() {
    _journalPublications = const [];
    _journalPublicationTotal = 0;
    _currentPage = 1;
    _perPage = AppLimits.publicationPageSize;
    _loadingPage = null;
  }

  @override
  void dispose() {
    _isDisposed = true;
    _repository.dispose();
    super.dispose();
  }
}
