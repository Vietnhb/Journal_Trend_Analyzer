import 'package:flutter/foundation.dart';

import '../../core/errors/app_errors.dart';
import '../../data/models/publication.dart';
import '../../data/repositories/publication_repository.dart';

class PublicationProvider extends ChangeNotifier {
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
  PublicationAnalytics? _analytics;
  int _totalAvailable = 0;
  int _currentPage = 1;
  int _perPage = 50;

  String get query => _query;
  bool get isLoading => _isLoading;
  bool get hasSearched => _hasSearched;
  AppError? get error => _error;
  PublicationYearSort get yearSort => _yearSort;
  List<Publication> get publications => _publications;
  int get totalAvailable => _totalAvailable;
  int get currentPage => _currentPage;
  int get perPage => _perPage;
  int get totalPages {
    if (_totalAvailable == 0) {
      return 1;
    }
    return (_totalAvailable / _perPage).ceil();
  }

  bool get canGoPrevious => _currentPage > 1 && !_isLoading;
  bool get canGoNext => _currentPage < totalPages && !_isLoading;

  List<Publication> get analysisPublications {
    return _analysisPublications;
  }

  int get totalPublications {
    if (_totalAvailable > 0) {
      return _totalAvailable;
    }
    return _analytics?.totalCount ?? 0;
  }

  int get totalCitations {
    final analytics = _analytics;
    if (analytics != null) {
      return analytics.citationSampleTotal;
    }
    return analysisPublications.fold<int>(
      0,
      (total, publication) => total + publication.citationCount,
    );
  }

  double get averageCitations {
    final analytics = _analytics;
    if (analytics != null) {
      return analytics.averageCitationCount;
    }
    if (analysisPublications.isEmpty) {
      return 0;
    }
    return totalCitations / analysisPublications.length;
  }

  int? get mostActiveYear {
    final ranked = yearsByPublicationCount;
    if (ranked.isEmpty) {
      return null;
    }
    return ranked.first.key;
  }

  Publication? get mostInfluentialPaper {
    final analyticsPapers = _analytics?.topPapers;
    if (analyticsPapers != null && analyticsPapers.isNotEmpty) {
      return analyticsPapers.first;
    }
    return null;
  }

  String? get topJournal {
    final analyticsJournals = _analytics?.topJournals;
    if (analyticsJournals != null && analyticsJournals.isNotEmpty) {
      return analyticsJournals.first.label;
    }
    return null;
  }

  String? get topAuthor {
    final analyticsAuthors = _analytics?.topAuthors;
    if (analyticsAuthors != null && analyticsAuthors.isNotEmpty) {
      return analyticsAuthors.first.label;
    }
    return null;
  }

  Map<int, int> get publicationsByYear {
    final analyticsYears = _analytics?.publicationsByYear;
    if (analyticsYears != null && analyticsYears.isNotEmpty) {
      return analyticsYears;
    }
    final grouped = <int, int>{};
    for (final publication in _publications) {
      final year = publication.year;
      if (year == null) {
        continue;
      }
      grouped[year] = (grouped[year] ?? 0) + 1;
    }
    return grouped;
  }

  List<MapEntry<int, int>> get yearsByPublicationCount {
    final list = publicationsByYear.entries.toList();
    list.sort((a, b) {
      final countCompare = b.value.compareTo(a.value);
      if (countCompare != 0) {
        return countCompare;
      }
      return _compareYears(a.key, b.key);
    });
    return list;
  }

  List<Publication> get topPapers {
    final analyticsPapers = _analytics?.topPapers;
    if (analyticsPapers != null && analyticsPapers.isNotEmpty) {
      return analyticsPapers;
    }
    return const [];
  }

  List<MapEntry<String, int>> get topJournals {
    final analyticsJournals = _analytics?.topJournals;
    if (analyticsJournals != null && analyticsJournals.isNotEmpty) {
      return analyticsJournals
          .map((item) => MapEntry(item.label, item.count))
          .toList(growable: false);
    }
    return const [];
  }

  List<MapEntry<String, int>> get topAuthors {
    final analyticsAuthors = _analytics?.topAuthors;
    if (analyticsAuthors != null && analyticsAuthors.isNotEmpty) {
      return analyticsAuthors
          .map((item) => MapEntry(item.label, item.count))
          .toList(growable: false);
    }
    return const [];
  }

  Future<void> search(String query) async {
    final trimmed = query.trim();
    if (trimmed.isEmpty || _isLoading) {
      return;
    }

    _query = trimmed;
    _isLoading = true;
    _hasSearched = true;
    _error = null;
    _publications = const [];
    _analysisPublications = const [];
    _analytics = null;
    _totalAvailable = 0;
    _currentPage = 1;
    notifyListeners();

    try {
      final results = await Future.wait([
        _repository.searchPublicationsPage(
          trimmed,
          yearSort: _yearSort,
          page: 1,
        ),
        _repository.fetchAnalytics(trimmed),
      ]);
      final page = results[0] as PublicationSearchPage;
      final analytics = results[1] as PublicationAnalytics;
      _applySearchPage(page);
      _analytics = analytics;
    } on AppError catch (error) {
      _error = error;
      _publications = const [];
      _analysisPublications = const [];
      _analytics = null;
      _totalAvailable = 0;
    } catch (error) {
      _error = AppError('Search failed.', details: error.toString());
      _publications = const [];
      _analysisPublications = const [];
      _analytics = null;
      _totalAvailable = 0;
    } finally {
      _isLoading = false;
      notifyListeners();
    }
  }

  Future<void> goToPage(int pageNumber, {bool force = false}) async {
    if (_query.isEmpty || _isLoading) {
      return;
    }

    final targetPage = pageNumber.clamp(1, totalPages);
    if (!force && targetPage == _currentPage) {
      return;
    }

    _isLoading = true;
    _error = null;
    notifyListeners();

    try {
      final page = await _repository.searchPublicationsPage(
        _query,
        yearSort: _yearSort,
        page: targetPage,
      );
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

  void clear() {
    _query = '';
    _isLoading = false;
    _hasSearched = false;
    _error = null;
    _yearSort = PublicationYearSort.descending;
    _publications = const [];
    _analysisPublications = const [];
    _analytics = null;
    _totalAvailable = 0;
    _currentPage = 1;
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

  void _applySearchPage(PublicationSearchPage page) {
    _publications = page.publications;
    _totalAvailable = page.totalCount;
    _currentPage = page.page;
    _perPage = page.perPage;
    _sortAnalysisPublications();
  }

  void _sortAnalysisPublications() {
    final sorted = _publications.toList();
    sorted.sort(_comparePublicationsByYear);
    _analysisPublications = sorted;
  }
}
