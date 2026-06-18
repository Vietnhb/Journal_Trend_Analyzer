import 'package:flutter/foundation.dart';

import '../../core/errors/app_errors.dart';
import '../../data/repositories/journal_repository.dart';

class JournalProvider extends ChangeNotifier {
  final JournalRepository _repository;

  JournalProvider({JournalRepository? repository})
    : _repository = repository ?? JournalRepository();

  String _query = '';
  String _selectedKeyword = '';
  bool _isLoading = false;
  bool _hasSearched = false;
  AppError? _error;
  PublicationYearSort _yearSort = PublicationYearSort.descending;
  PublicationListSort _publicationSort = PublicationListSort.newest;
  List<String> _recentSearches = const [];
  List<OpenAlexTopic> _topicSuggestions = const [];
  OpenAlexTopic? _selectedTopic;

  List<RankedEntity> _journals = const [];
  RankedEntity? _selectedJournal;
  bool _isLoadingJournals = false;
  AppError? _journalError;

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
  int _perPage = 50;
  int? _loadingPage;

  bool _isDarkMode = false;
  bool _filterFutureSourceYears = true;

  String get query => _query;
  String get selectedKeyword => _selectedKeyword;
  bool get isLoading => _isLoading;
  bool get hasSearched => _hasSearched;
  AppError? get error => _error;
  PublicationYearSort get yearSort => _yearSort;
  PublicationListSort get publicationSort => _publicationSort;
  List<String> get recentSearches => _recentSearches;
  List<OpenAlexTopic> get topicSuggestions => _topicSuggestions;
  OpenAlexTopic? get selectedTopic => _selectedTopic;

  List<RankedEntity> get journals => _journals;
  RankedEntity? get selectedJournal => _selectedJournal;
  bool get isLoadingJournals => _isLoadingJournals;
  AppError? get journalError => _journalError;

  bool get isLoadingAnalytics => _isLoadingAnalytics;
  AppError? get analyticsError => _analyticsError;
  List<Publication> get topPapers => List.unmodifiable(_topPapers);
  List<RankedEntity> get topAuthors => List.unmodifiable(_topAuthors);

  bool get isLoadingJournalPublications => _isLoadingJournalPublications;
  AppError? get journalPublicationError => _journalPublicationError;
  List<Publication> get journalPublications => _journalPublications;
  int get journalTotalAvailable => _journalPublicationTotal;
  int get currentPage => _currentPage;
  int? get loadingPage => _loadingPage;
  int get perPage => _perPage;
  int get totalPages {
    if (_journalPublicationTotal <= 0) return 1;
    return (_journalPublicationTotal / _perPage).ceil();
  }

  int get directPageLimit => totalPages < 200 ? totalPages : 200;

  bool get canGoPrevious =>
      _canNavigateTo(_currentPage - 1) && !_isLoadingJournalPublications;
  bool get canGoNext =>
      _canNavigateTo(_currentPage + 1) && !_isLoadingJournalPublications;

  bool get isDarkMode => _isDarkMode;
  bool get filterFutureSourceYears => _filterFutureSourceYears;

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

    _query = trimmed;
    _selectedKeyword = trimmed;
    _rememberSearch(trimmed);
    _isLoading = true;
    _isLoadingJournals = true;
    _isLoadingAnalytics = true;
    _hasSearched = true;
    _error = null;
    _journalError = null;
    _analyticsError = null;
    _topicSuggestions = const [];
    _selectedTopic = null;
    _selectedJournal = null;
    _journals = const [];
    _clearKeywordAnalytics();
    _clearJournalPublications();
    notifyListeners();

    try {
      await _loadKeywordAnalytics(trimmed, includeJournals: true);
    } on AppError catch (error) {
      _error = error;
      _journalError = error;
      _analyticsError = error;
    } catch (error) {
      final appError = AppError(
        'Keyword analysis failed.',
        details: error.toString(),
      );
      _error = appError;
      _journalError = appError;
      _analyticsError = appError;
    } finally {
      _isLoading = false;
      _isLoadingJournals = false;
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
      await _loadKeywordAnalytics(_selectedKeyword, includeJournals: true);
    } on AppError catch (error) {
      _analyticsError = error;
    } catch (error) {
      _analyticsError = AppError(
        'Could not refresh keyword analytics.',
        details: error.toString(),
      );
    } finally {
      _isLoadingAnalytics = false;
      notifyListeners();
    }
  }

  Future<void> _loadKeywordAnalytics(
    String keyword, {
    required bool includeJournals,
  }) async {
    final initialRequests = <Future<Object?>>[
      if (includeJournals)
        _repository.getTopJournalsByKeyword(
          keyword,
          limit: 50,
          excludeFuturePublications: _filterFutureSourceYears,
        ),
      _repository.getPublicationsByKeyword(
        keyword,
        page: 1,
        excludeFuturePublications: _filterFutureSourceYears,
        publicationSort: _publicationSort,
      ),
    ];
    final initial = await Future.wait(initialRequests);
    var resultIndex = 0;
    if (includeJournals) {
      _journals = initial[resultIndex++] as List<RankedEntity>;
    }
    final countPage = initial[resultIndex] as PublicationSearchPage;
    _keywordPublicationTotal = countPage.totalCount;
    _applyJournalPublicationPage(countPage);
    notifyListeners();

    await Future<void>.delayed(const Duration(milliseconds: 180));
    final rankings = await Future.wait([
      _repository.getTopPapersByKeyword(
        keyword,
        excludeFuturePublications: _filterFutureSourceYears,
      ),
      _repository.getTopAuthorsByKeyword(
        keyword,
        limit: 50,
        excludeFuturePublications: _filterFutureSourceYears,
      ),
    ]);
    _topPapers = rankings[0] as List<Publication>;
    _topAuthors = rankings[1] as List<RankedEntity>;
    notifyListeners();

    await Future<void>.delayed(const Duration(milliseconds: 180));
    final trends = await Future.wait([
      _repository.getPublicationTrendByKeyword(
        keyword,
        excludeFuturePublications: _filterFutureSourceYears,
      ),
      _repository.getAverageCitationsByKeyword(
        keyword,
        excludeFuturePublications: _filterFutureSourceYears,
      ),
    ]);
    _publicationsByYear = trends[0] as Map<int, int>;
    _averageCitations = trends[1] as int?;
  }

  Future<void> selectJournal(RankedEntity journal) async {
    if (_selectedKeyword.isEmpty || _isLoadingJournalPublications) return;
    _selectedJournal = journal;
    _journalPublicationError = null;
    _isLoadingJournalPublications = true;
    _clearJournalPublications(keepSelectedCount: true);
    notifyListeners();

    try {
      final results = await Future.wait([
        _getJournalSourceDetailOrNull(journal),
        _repository.getPublicationsByKeyword(
          _selectedKeyword,
          sourceId: journal.id,
          yearSort: _yearSort,
          page: 1,
          excludeFuturePublications: _filterFutureSourceYears,
          cursor: '*',
        ),
      ]);

      final sourceDetail = results[0] as RankedEntity?;
      if (sourceDetail != null) {
        _selectedJournal = journal.mergeSourceMetadata(sourceDetail);
        _journals = _journals
            .map(
              (item) => item.id == journal.id
                  ? item.mergeSourceMetadata(sourceDetail)
                  : item,
            )
            .toList(growable: false);
      }
      _applyJournalPublicationPage(results[1] as PublicationSearchPage);
    } on AppError catch (error) {
      _journalPublicationError = error;
    } catch (error) {
      _journalPublicationError = AppError(
        'Could not load journal publications.',
        details: error.toString(),
      );
    } finally {
      _isLoadingJournalPublications = false;
      notifyListeners();
    }
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
        yearSort: _yearSort,
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

  Future<void> goToFirstPage() => goToPage(1);

  Future<void> goToLastPage() => goToPage(totalPages);

  bool _canNavigateTo(int page) {
    if (page < 1 || page > totalPages) return false;
    return page <= directPageLimit || totalPages - page + 1 <= directPageLimit;
  }

  Future<void> setYearSort(PublicationYearSort yearSort) async {
    if (_yearSort == yearSort) return;
    _yearSort = yearSort;
    if (_selectedKeyword.isNotEmpty) {
      await goToPage(1, force: true);
    } else {
      notifyListeners();
    }
  }

  Future<void> setPublicationSort(PublicationListSort sort) async {
    if (_publicationSort == sort) return;
    _publicationSort = sort;
    _yearSort = switch (sort) {
      PublicationListSort.oldest => PublicationYearSort.ascending,
      _ => PublicationYearSort.descending,
    };
    if (_selectedKeyword.isNotEmpty) {
      await goToPage(1, force: true);
    } else {
      notifyListeners();
    }
  }

  void clearJournalSelection() {
    _selectedJournal = null;
    _clearJournalPublications();
    notifyListeners();
  }

  @Deprecated('Use analyzeKeyword instead')
  Future<void> search(String query) async {
    final trimmed = query.trim();
    if (trimmed.isEmpty) return;
    _query = trimmed;
    _rememberSearch(trimmed);
    _isLoading = true;
    _hasSearched = true;
    _error = null;
    _topicSuggestions = const [];
    notifyListeners();
    try {
      _topicSuggestions = await _repository.searchTopics(trimmed);
    } on AppError catch (error) {
      _error = error;
    } finally {
      _isLoading = false;
      notifyListeners();
    }
  }

  @Deprecated('Topic selection is optional. Use analyzeKeyword for main flow.')
  Future<void> selectTopic(OpenAlexTopic topic) async {
    _selectedTopic = topic;
    _isLoadingJournals = true;
    _journalError = null;
    notifyListeners();
    try {
      _journals = await _repository.getTopJournalsByTopicId(topic.id);
    } on AppError catch (error) {
      _journalError = error;
    } finally {
      _isLoadingJournals = false;
      notifyListeners();
    }
  }

  Future<RankedEntity?> _getJournalSourceDetailOrNull(
    RankedEntity journal,
  ) async {
    try {
      return await _repository.getJournalSourceDetail(journal.id);
    } catch (_) {
      return null;
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
    _query = '';
    _selectedKeyword = '';
    _isLoading = false;
    _hasSearched = false;
    _error = null;
    _yearSort = PublicationYearSort.descending;
    _publicationSort = PublicationListSort.newest;
    _recentSearches = const [];
    _topicSuggestions = const [];
    _selectedTopic = null;
    _journals = const [];
    _selectedJournal = null;
    _isLoadingJournals = false;
    _journalError = null;
    _isLoadingAnalytics = false;
    _analyticsError = null;
    _isLoadingJournalPublications = false;
    _journalPublicationError = null;
    _clearKeywordAnalytics();
    _clearJournalPublications();
    notifyListeners();
  }

  void _rememberSearch(String query) {
    final updated = [
      query,
      ..._recentSearches.where(
        (item) => item.toLowerCase() != query.toLowerCase(),
      ),
    ];
    _recentSearches = List.unmodifiable(updated);
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

  void _clearJournalPublications({bool keepSelectedCount = false}) {
    _journalPublications = const [];
    _journalPublicationTotal = keepSelectedCount
        ? _selectedJournal?.worksCount ?? 0
        : 0;
    _currentPage = 1;
    _perPage = 50;
    _loadingPage = null;
  }

  @override
  void dispose() {
    _repository.dispose();
    super.dispose();
  }
}
