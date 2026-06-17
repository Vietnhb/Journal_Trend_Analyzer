import 'package:flutter/foundation.dart';

import '../../core/errors/app_errors.dart';
import '../../data/models/publication.dart';
import '../../data/repositories/publication_repository.dart';

class PublicationProvider extends ChangeNotifier {
  static const int _maxDirectPage = 200;

  final PublicationRepository _repository;

  PublicationProvider({PublicationRepository? repository})
    : _repository = repository ?? PublicationRepository();

  String _query = '';
  bool _isLoading = false;
  bool _hasSearched = false;
  AppError? _error;
  PublicationYearSort _yearSort = PublicationYearSort.descending;
  List<Publication> _publications = const [];
  List<Publication> _analysisPublications = const [];
  List<String> _recentSearches = const [];
  int _totalAvailable = 0;
  int _currentPage = 1;
  int _perPage = 50;
  bool _isDarkMode = false;
  bool _filterFuturePublicationMetadata = true;

  bool _isLoadingAnalytics = false;
  AppError? _analyticsError;
  Map<int, int> _analyticsPublicationsByYear = const {};
  List<Publication> _topPapersData = const [];
  List<RankedEntity> _topJournalsData = const [];
  List<RankedEntity> _topAuthorsData = const [];
  int? _averageCitations;

  String get query => _query;
  bool get isLoading => _isLoading;
  bool get hasSearched => _hasSearched;
  AppError? get error => _error;
  PublicationYearSort get yearSort => _yearSort;
  List<Publication> get publications => _publications;
  List<Publication> get analysisPublications => _analysisPublications;
  List<String> get recentSearches => _recentSearches;
  int get totalAvailable => _totalAvailable;
  int get currentPage => _currentPage;
  int get perPage => _perPage;
  bool get isDarkMode => _isDarkMode;
  bool get filterFuturePublicationMetadata => _filterFuturePublicationMetadata;
  bool get isLoadingAnalytics => _isLoadingAnalytics;
  AppError? get analyticsError => _analyticsError;

  int get totalPages {
    if (_totalAvailable <= 0) {
      return 1;
    }
    return (_totalAvailable / _perPage).ceil();
  }

  bool get canGoPrevious => _currentPage > 1 && !_isLoading;
  bool get canGoNext => _currentPage < totalPages && !_isLoading;

  int get totalPublications {
    return _totalAvailable > 0 ? _totalAvailable : _publications.length;
  }

  int? get avgCitationCount => _averageCitations;

  int? get mostActiveYear {
    final ranked = yearsByPublicationCount;
    return ranked.isEmpty ? null : ranked.first.key;
  }

  Publication? get mostInfluentialPaper {
    final papers = topPapers;
    return papers.isEmpty ? null : papers.first;
  }

  String? get topJournal {
    return _topJournalsData.isEmpty ? null : _topJournalsData.first.name;
  }

  String? get topAuthor {
    return _topAuthorsData.isEmpty ? null : _topAuthorsData.first.name;
  }

  Map<int, int> get publicationsByYear {
    if (!_filterFuturePublicationMetadata) {
      return _analyticsPublicationsByYear;
    }

    final currentYear = DateTime.now().year;
    return Map<int, int>.fromEntries(
      _analyticsPublicationsByYear.entries.where(
        (entry) => entry.key <= currentYear,
      ),
    );
  }

  List<MapEntry<int, int>> get yearsByPublicationCount {
    final list = publicationsByYear.entries.toList();
    list.sort((a, b) {
      final countCompare = b.value.compareTo(a.value);
      return countCompare != 0 ? countCompare : _compareYears(a.key, b.key);
    });
    return list;
  }

  List<Publication> get topPapers {
    return _topPapersData.take(5).toList(growable: false);
  }

  List<RankedEntity> get topJournals {
    return _topJournalsData.take(5).toList(growable: false);
  }

  List<RankedEntity> get topAuthors {
    return _topAuthorsData.take(5).toList(growable: false);
  }

  Future<void> search(String query) async {
    final trimmed = query.trim();
    if (trimmed.isEmpty || _isLoading) {
      return;
    }

    final keepCurrent =
        _hasSearched &&
        trimmed.toLowerCase() == _query.toLowerCase() &&
        _publications.isNotEmpty;

    _query = trimmed;
    _rememberSearch(trimmed);
    _isLoading = true;
    _hasSearched = true;
    _error = null;
    if (!keepCurrent) {
      _clearResults();
    }
    notifyListeners();

    try {
      final page = await _repository.searchPublicationsPage(
        trimmed,
        yearSort: _yearSort,
        page: 1,
        excludeFuturePublications: _filterFuturePublicationMetadata,
      );
      _applySearchPage(page);
    } on AppError catch (error) {
      _error = error;
      if (!keepCurrent) {
        _clearResults();
      }
    } catch (error) {
      _error = AppError('Search failed.', details: error.toString());
      if (!keepCurrent) {
        _clearResults();
      }
    } finally {
      _isLoading = false;
      notifyListeners();
    }

    if (_error == null) {
      _loadAnalytics(trimmed);
    }
  }

  Future<void> _loadAnalytics(String query) async {
    _isLoadingAnalytics = true;
    _analyticsError = null;
    notifyListeners();

    try {
      final results = await Future.wait([
        _repository.getPublicationsByYear(
          query,
          excludeFuturePublications: _filterFuturePublicationMetadata,
        ),
        _repository.getTopPapers(
          query,
          excludeFuturePublications: _filterFuturePublicationMetadata,
        ),
        _repository.getTopJournals(
          query,
          excludeFuturePublications: _filterFuturePublicationMetadata,
        ),
        _repository.getTopAuthors(
          query,
          excludeFuturePublications: _filterFuturePublicationMetadata,
        ),
        _repository.getAverageCitations(
          query,
          excludeFuturePublications: _filterFuturePublicationMetadata,
        ),
      ]);
      _analyticsPublicationsByYear = results[0] as Map<int, int>;
      _topPapersData = results[1] as List<Publication>;
      _topJournalsData = results[2] as List<RankedEntity>;
      _topAuthorsData = results[3] as List<RankedEntity>;
      _averageCitations = results[4] as int?;
    } on AppError catch (error) {
      _analyticsError = error;
      _clearAnalytics();
    } catch (error) {
      _analyticsError = AppError(
        'Analytics failed.',
        details: error.toString(),
      );
      _clearAnalytics();
    } finally {
      _isLoadingAnalytics = false;
      notifyListeners();
    }
  }

  Future<PublicationSearchPage> loadEntityPublications({
    String? sourceId,
    String? authorId,
    int page = 1,
  }) {
    return _repository.searchPublicationsByEntity(
      _query,
      sourceId: sourceId,
      authorId: authorId,
      yearSort: _yearSort,
      page: page,
      excludeFuturePublications: _filterFuturePublicationMetadata,
    );
  }

  void _clearAnalytics() {
    _analyticsPublicationsByYear = const {};
    _topPapersData = const [];
    _topJournalsData = const [];
    _topAuthorsData = const [];
    _averageCitations = null;
  }

  Future<void> goToPage(int pageNumber, {bool force = false}) async {
    if (_query.isEmpty || _isLoading) {
      return;
    }

    final targetPage = pageNumber.clamp(1, totalPages).toInt();
    if (!force && targetPage == _currentPage) {
      return;
    }

    _isLoading = true;
    _error = null;
    notifyListeners();

    try {
      final page = await _loadRequestedPage(targetPage);
      _applySearchPage(page);
    } on AppError catch (error) {
      _error = error;
    } catch (error) {
      _error = AppError(
        'Could not load page $targetPage.',
        details: error.toString(),
      );
    } finally {
      _isLoading = false;
      notifyListeners();
    }
  }

  Future<PublicationSearchPage> _loadRequestedPage(int targetPage) async {
    final reversePage = totalPages - targetPage + 1;
    final shouldLoadFromEnd =
        targetPage > _maxDirectPage && reversePage <= _maxDirectPage;

    if (shouldLoadFromEnd) {
      final page = await _repository.searchPublicationsPage(
        _query,
        yearSort: _reverseYearSort(_yearSort),
        page: reversePage,
        excludeFuturePublications: _filterFuturePublicationMetadata,
      );

      return PublicationSearchPage(
        publications: page.publications,
        totalCount: page.totalCount,
        page: targetPage,
        perPage: page.perPage,
      );
    }

    return await _repository.searchPublicationsPage(
      _query,
      yearSort: _yearSort,
      page: targetPage,
      excludeFuturePublications: _filterFuturePublicationMetadata,
    );
  }

  PublicationYearSort _reverseYearSort(PublicationYearSort yearSort) {
    return switch (yearSort) {
      PublicationYearSort.descending => PublicationYearSort.ascending,
      PublicationYearSort.ascending => PublicationYearSort.descending,
    };
  }

  Future<void> setYearSort(PublicationYearSort yearSort) async {
    if (_yearSort == yearSort) {
      return;
    }
    _yearSort = yearSort;
    if (_query.isEmpty || !_hasSearched) {
      _sortAnalysisPublications();
      notifyListeners();
      return;
    }
    await goToPage(1, force: true);
  }

  void setDarkMode(bool enabled) {
    if (_isDarkMode == enabled) {
      return;
    }
    _isDarkMode = enabled;
    notifyListeners();
  }

  Future<void> setFilterFuturePublicationMetadata(bool enabled) async {
    if (_filterFuturePublicationMetadata == enabled) {
      return;
    }
    _filterFuturePublicationMetadata = enabled;
    _sortAnalysisPublications();
    notifyListeners();
    if (_query.isNotEmpty && _hasSearched) {
      await goToPage(1, force: true);
      _loadAnalytics(_query);
    }
  }

  void clear() {
    _query = '';
    _isLoading = false;
    _hasSearched = false;
    _error = null;
    _yearSort = PublicationYearSort.descending;
    _clearResults();
    notifyListeners();
  }

  @override
  void dispose() {
    _repository.dispose();
    super.dispose();
  }

  void _applySearchPage(PublicationSearchPage page) {
    _publications = page.publications;
    _totalAvailable = page.totalCount;
    _currentPage = page.page;
    _perPage = page.perPage;
    _sortAnalysisPublications();
  }

  void _clearResults() {
    _publications = const [];
    _analysisPublications = const [];
    _clearAnalytics();
    _totalAvailable = 0;
    _currentPage = 1;
  }

  void _sortAnalysisPublications() {
    final sorted = _publications.where(_isPublicationCurrent).toList();
    sorted.sort(_comparePublicationsByYear);
    _analysisPublications = sorted;
  }

  bool _isPublicationCurrent(Publication publication) {
    if (!_filterFuturePublicationMetadata) {
      return true;
    }

    final publicationDate = publication.publicationDate;
    if (publicationDate != null) {
      final parsed = DateTime.tryParse(publicationDate);
      if (parsed != null) {
        final today = DateTime.now();
        final todayOnly = DateTime(today.year, today.month, today.day);
        final publishedDate = DateTime(parsed.year, parsed.month, parsed.day);
        return !publishedDate.isAfter(todayOnly);
      }
    }

    final year = publication.year;
    return year == null || year <= DateTime.now().year;
  }

  int _comparePublicationsByYear(Publication a, Publication b) {
    final aYear = a.year;
    final bYear = b.year;
    if (aYear == null && bYear == null) {
      return 0;
    }
    if (aYear == null) {
      return 1;
    }
    if (bYear == null) {
      return -1;
    }
    return _compareYears(aYear, bYear);
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
}
