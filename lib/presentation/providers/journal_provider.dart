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
  List<String> _recentSearches = const [];
  List<OpenAlexTopic> _topicSuggestions = const [];
  @Deprecated('Use selectedKeyword instead')
  OpenAlexTopic? _selectedTopic;
  List<RankedEntity> _journals = const [];
  RankedEntity? _selectedJournal;
  bool _isDarkMode = false;
  bool _filterFutureSourceYears = true;
  bool _isLoadingJournals = false;
  bool _isLoadingAnalytics = false;
  AppError? _journalError;
  AppError? _analyticsError;
  List<Publication> _journalPublications = const [];
  List<Publication> _topPapers = const [];
  List<RankedEntity> _topAuthors = const [];
  Map<int, int> _journalPublicationsByYear = const {};
  int? _journalAverageCitations;
  int _journalPublicationTotal = 0;
  int _currentPage = 1;
  int _perPage = 50;

  String get query => _query;
  String get selectedKeyword => _selectedKeyword;
  bool get isLoading => _isLoading;
  bool get hasSearched => _hasSearched;
  AppError? get error => _error;
  PublicationYearSort get yearSort => _yearSort;
  List<String> get recentSearches => _recentSearches;
  List<OpenAlexTopic> get topicSuggestions => _topicSuggestions;
  @Deprecated('Use selectedKeyword instead')
  OpenAlexTopic? get selectedTopic => _selectedTopic;
  List<RankedEntity> get journals => _journals;
  RankedEntity? get selectedJournal => _selectedJournal;
  bool get isDarkMode => _isDarkMode;
  bool get filterFutureSourceYears => _filterFutureSourceYears;
  bool get isLoadingJournals => _isLoadingJournals;
  bool get isLoadingAnalytics => _isLoadingAnalytics;
  AppError? get journalError => _journalError;
  AppError? get analyticsError => _analyticsError;
  List<Publication> get journalPublications => _journalPublications;
  List<Publication> get topPapers =>
      _topPapers.take(50).toList(growable: false);
  List<RankedEntity> get topAuthors =>
      _topAuthors.take(50).toList(growable: false);

  int get totalAvailable => _journalPublicationTotal;
  int get currentPage => _currentPage;
  int get perPage => _perPage;
  int get totalPages {
    if (_journalPublicationTotal <= 0) return 1;
    return (_journalPublicationTotal / _perPage).ceil();
  }

  bool get canGoPrevious => _currentPage > 1 && !_isLoadingAnalytics;
  bool get canGoNext => _currentPage < totalPages && !_isLoadingAnalytics;

  int get totalWorks {
    return _journalPublicationTotal > 0
        ? _journalPublicationTotal
        : _selectedJournal?.worksCount ?? 0;
  }

  int? get avgCitationCount {
    return _journalAverageCitations;
  }

  int? get mostActiveYear {
    final ranked = yearsByWorkCount;
    return ranked.isEmpty ? null : ranked.first.key;
  }

  String? get topJournal => _journals.isEmpty ? null : _journals.first.name;
  String? get topAuthor => _topAuthors.isEmpty ? null : _topAuthors.first.name;

  Publication? get mostInfluentialPaper {
    return _topPapers.isEmpty ? null : _topPapers.first;
  }

  Map<int, int> get sourceWorksByYear {
    final counts = _journalPublicationsByYear;
    if (!_filterFutureSourceYears) {
      return counts;
    }

    final currentYear = DateTime.now().year;
    return Map<int, int>.fromEntries(
      counts.entries.where((entry) => entry.key <= currentYear),
    );
  }

  List<MapEntry<int, int>> get yearsByWorkCount {
    final list = sourceWorksByYear.entries.toList();
    list.sort((a, b) {
      final countCompare = b.value.compareTo(a.value);
      return countCompare != 0 ? countCompare : _compareYears(a.key, b.key);
    });
    return list;
  }

  /// Search and analyze keyword directly.
  /// This is the main entry point - no topic selection required.
  Future<void> analyzeKeyword(String keyword) async {
    final trimmed = keyword.trim();
    if (trimmed.isEmpty || _isLoading) {
      return;
    }

    _query = trimmed;
    _selectedKeyword = trimmed;
    _rememberSearch(trimmed);
    _isLoading = true;
    _isLoadingJournals = true;
    _hasSearched = true;
    _error = null;
    _journalError = null;
    _analyticsError = null;
    _topicSuggestions = const [];
    _selectedTopic = null;
    _selectedJournal = null;
    _journals = const [];
    _clearAnalytics();
    notifyListeners();

    try {
      // Load both journals and keyword-level analytics in parallel
      final results = await Future.wait([
        _repository.getTopJournalsByKeyword(trimmed, limit: 50),
        _repository.getTopPapersByKeyword(
          trimmed,
          excludeFuturePublications: _filterFutureSourceYears,
        ),
        _repository.getTopAuthorsByKeyword(
          trimmed,
          limit: 50,
          excludeFuturePublications: _filterFutureSourceYears,
        ),
        _repository.getPublicationTrendByKeyword(
          trimmed,
          excludeFuturePublications: _filterFutureSourceYears,
        ),
        _repository.getAverageCitationsByKeyword(
          trimmed,
          excludeFuturePublications: _filterFutureSourceYears,
        ),
        _repository.getPublicationsByKeyword(
          trimmed,
          yearSort: _yearSort,
          page: 1,
          excludeFuturePublications: _filterFutureSourceYears,
        ),
      ]);

      _journals = results[0] as List<RankedEntity>;
      _topPapers = results[1] as List<Publication>;
      _topAuthors = results[2] as List<RankedEntity>;
      _journalPublicationsByYear = results[3] as Map<int, int>;
      _journalAverageCitations = results[4] as int?;
      _applyPublicationPage(results[5] as PublicationSearchPage);
    } on AppError catch (error) {
      _error = error;
      _journalError = error;
      _journals = const [];
      _clearAnalytics();
    } catch (error) {
      _error = AppError('Keyword analysis failed.', details: error.toString());
      _journalError = _error;
      _journals = const [];
      _clearAnalytics();
    } finally {
      _isLoading = false;
      _isLoadingJournals = false;
      notifyListeners();
    }
  }

  @Deprecated('Use analyzeKeyword instead')
  Future<void> search(String query) async {
    final trimmed = query.trim();
    if (trimmed.isEmpty) {
      return;
    }

    _query = trimmed;
    _rememberSearch(trimmed);
    _isLoading = true;
    _hasSearched = true;
    _error = null;
    _journalError = null;
    _analyticsError = null;
    _topicSuggestions = const [];
    _selectedTopic = null;
    _selectedJournal = null;
    _journals = const [];
    _clearAnalytics();
    notifyListeners();

    try {
      _topicSuggestions = await _repository.searchTopics(trimmed);
    } on AppError catch (error) {
      _error = error;
      _topicSuggestions = const [];
    } catch (error) {
      _error = AppError('Topic search failed.', details: error.toString());
      _topicSuggestions = const [];
    } finally {
      _isLoading = false;
      notifyListeners();
    }
  }

  @Deprecated('Topic selection is optional. Use analyzeKeyword for main flow.')
  Future<void> selectTopic(OpenAlexTopic topic) async {
    _selectedTopic = topic;
    _selectedJournal = null;
    _journals = const [];
    _journalError = null;
    _analyticsError = null;
    _isLoadingJournals = true;
    _clearAnalytics();
    notifyListeners();

    try {
      _journals = await _repository.getTopJournalsByTopicId(topic.id);
    } on AppError catch (error) {
      _journalError = error;
      _journals = const [];
    } catch (error) {
      _journalError = AppError(
        'Could not load top journals.',
        details: error.toString(),
      );
      _journals = const [];
    } finally {
      _isLoadingJournals = false;
      notifyListeners();
    }
  }

  /// Select journal for drill-down analysis (optional).
  /// Filters all analytics by the selected journal.
  Future<void> selectJournal(RankedEntity journal) async {
    if (_selectedKeyword.isEmpty) return;
    _selectedJournal = journal;
    _analyticsError = null;
    notifyListeners();
    await _loadJournalDrillDown(journal);
  }

  /// Clear journal selection and return to keyword-level analytics.
  Future<void> clearJournalSelection() async {
    if (_selectedKeyword.isEmpty) return;
    _selectedJournal = null;
    _analyticsError = null;
    _isLoadingAnalytics = true;
    notifyListeners();

    try {
      // Reload keyword-level analytics
      final results = await Future.wait([
        _repository.getTopPapersByKeyword(
          _selectedKeyword,
          excludeFuturePublications: _filterFutureSourceYears,
        ),
        _repository.getTopAuthorsByKeyword(
          _selectedKeyword,
          limit: 50,
          excludeFuturePublications: _filterFutureSourceYears,
        ),
        _repository.getPublicationTrendByKeyword(
          _selectedKeyword,
          excludeFuturePublications: _filterFutureSourceYears,
        ),
        _repository.getAverageCitationsByKeyword(
          _selectedKeyword,
          excludeFuturePublications: _filterFutureSourceYears,
        ),
        _repository.getPublicationsByKeyword(
          _selectedKeyword,
          yearSort: _yearSort,
          page: 1,
          excludeFuturePublications: _filterFutureSourceYears,
        ),
      ]);

      _topPapers = results[0] as List<Publication>;
      _topAuthors = results[1] as List<RankedEntity>;
      _journalPublicationsByYear = results[2] as Map<int, int>;
      _journalAverageCitations = results[3] as int?;
      _applyPublicationPage(results[4] as PublicationSearchPage);
    } on AppError catch (error) {
      _analyticsError = error;
    } catch (error) {
      _analyticsError = AppError(
        'Could not reload analytics.',
        details: error.toString(),
      );
    } finally {
      _isLoadingAnalytics = false;
      notifyListeners();
    }
  }

  Future<void> _loadJournalDrillDown(RankedEntity journal) async {
    if (_selectedKeyword.isEmpty) return;

    _isLoadingAnalytics = true;
    _analyticsError = null;
    _clearAnalytics(keepSelected: true);
    notifyListeners();

    try {
      final results = await Future.wait([
        _getJournalSourceDetailOrNull(journal),
        _repository.getTopPapersByKeyword(
          _selectedKeyword,
          sourceId: journal.id,
          excludeFuturePublications: false,
        ),
        _repository.getTopAuthorsByKeyword(
          _selectedKeyword,
          sourceId: journal.id,
          limit: 50,
          excludeFuturePublications: false,
        ),
        _repository.getPublicationTrendByKeyword(
          _selectedKeyword,
          sourceId: journal.id,
          excludeFuturePublications: false,
        ),
        _repository.getAverageCitationsByKeyword(
          _selectedKeyword,
          sourceId: journal.id,
          excludeFuturePublications: false,
        ),
        _repository.getPublicationsByKeyword(
          _selectedKeyword,
          sourceId: journal.id,
          yearSort: _yearSort,
          page: 1,
          excludeFuturePublications: false,
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

      _topPapers = results[1] as List<Publication>;
      _topAuthors = results[2] as List<RankedEntity>;
      _journalPublicationsByYear = results[3] as Map<int, int>;
      _journalAverageCitations = results[4] as int?;
      _applyPublicationPage(results[5] as PublicationSearchPage);
    } on AppError catch (error) {
      _analyticsError = error;
      _clearAnalytics(keepSelected: true);
    } catch (error) {
      _analyticsError = AppError(
        'Journal drill-down failed.',
        details: error.toString(),
      );
      _clearAnalytics(keepSelected: true);
    } finally {
      _isLoadingAnalytics = false;
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

  Future<void> goToPage(int pageNumber, {bool force = false}) async {
    if (_selectedKeyword.isEmpty || _isLoadingAnalytics) return;
    final targetPage = pageNumber.clamp(1, totalPages).toInt();
    if (!force && targetPage == _currentPage) return;

    _isLoadingAnalytics = true;
    _analyticsError = null;
    notifyListeners();

    try {
      final page = await _repository.getPublicationsByKeyword(
        _selectedKeyword,
        sourceId: _selectedJournal?.id,
        yearSort: _yearSort,
        page: targetPage,
        excludeFuturePublications: _selectedJournal == null
            ? _filterFutureSourceYears
            : false,
      );
      _applyPublicationPage(page);
    } on AppError catch (error) {
      _analyticsError = error;
    } catch (error) {
      _analyticsError = AppError(
        'Could not load publications.',
        details: error.toString(),
      );
    } finally {
      _isLoadingAnalytics = false;
      notifyListeners();
    }
  }

  Future<void> setYearSort(PublicationYearSort yearSort) async {
    if (_yearSort == yearSort) {
      return;
    }
    _yearSort = yearSort;
    if (_selectedKeyword.isNotEmpty) {
      await goToPage(1, force: true);
      return;
    }
    notifyListeners();
  }

  void setDarkMode(bool enabled) {
    if (_isDarkMode == enabled) {
      return;
    }
    _isDarkMode = enabled;
    notifyListeners();
  }

  Future<void> setFilterFutureSourceYears(bool enabled) async {
    if (_filterFutureSourceYears == enabled) {
      return;
    }
    _filterFutureSourceYears = enabled;
    notifyListeners();
    if (_selectedKeyword.isNotEmpty) {
      // Reload analytics with new filter
      if (_selectedJournal != null) {
        await _loadJournalDrillDown(_selectedJournal!);
      } else {
        await analyzeKeyword(_selectedKeyword);
      }
    }
  }

  void clear() {
    _query = '';
    _selectedKeyword = '';
    _isLoading = false;
    _hasSearched = false;
    _error = null;
    _yearSort = PublicationYearSort.descending;
    _recentSearches = const [];
    _topicSuggestions = const [];
    _selectedTopic = null;
    _journals = const [];
    _selectedJournal = null;
    _isLoadingJournals = false;
    _journalError = null;
    _analyticsError = null;
    _isLoadingAnalytics = false;
    _clearAnalytics();
    notifyListeners();
  }

  @override
  void dispose() {
    _repository.dispose();
    super.dispose();
  }

  int _compareYears(int a, int b) {
    return switch (_yearSort) {
      PublicationYearSort.descending => b.compareTo(a),
      PublicationYearSort.ascending => a.compareTo(b),
    };
  }

  void _rememberSearch(String query) {
    final updated = [
      query,
      ..._recentSearches.where(
        (item) => item.toLowerCase() != query.toLowerCase(),
      ),
    ];
    _recentSearches = updated.take(6).toList(growable: false);
  }

  void _applyPublicationPage(PublicationSearchPage page) {
    _journalPublications = page.publications;
    _journalPublicationTotal = page.totalCount;
    _currentPage = page.page;
    _perPage = page.perPage;
  }

  void _clearAnalytics({bool keepSelected = false}) {
    _journalPublications = const [];
    _topPapers = const [];
    _topAuthors = const [];
    _journalPublicationsByYear = const {};
    _journalAverageCitations = null;
    _journalPublicationTotal = keepSelected
        ? _selectedJournal?.worksCount ?? 0
        : 0;
    _currentPage = 1;
    _perPage = 50;
  }
}
