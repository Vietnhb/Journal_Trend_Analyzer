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
  List<String> _recentSearches = const [];
  int _totalAvailable = 0;
  int _currentPage = 1;
  int _perPage = 50;

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
  bool get isLoadingAnalytics => false;
  AppError? get analyticsError => null;

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

  double? get averageCitationCount {
    if (_analysisPublications.isEmpty) {
      return null;
    }
    final total = _analysisPublications.fold<int>(
      0,
      (sum, publication) => sum + publication.citationCount,
    );
    return total / _analysisPublications.length;
  }

  int? get mostActiveYear {
    final ranked = yearsByPublicationCount;
    return ranked.isEmpty ? null : ranked.first.key;
  }

  Publication? get mostInfluentialPaper {
    final papers = topPapers;
    return papers.isEmpty ? null : papers.first;
  }

  String? get topJournal {
    final journals = topJournals;
    return journals.isEmpty ? null : journals.first.key;
  }

  String? get topAuthor {
    final authors = topAuthors;
    return authors.isEmpty ? null : authors.first.key;
  }

  Map<int, int> get publicationsByYear {
    final grouped = <int, int>{};
    for (final publication in _analysisPublications) {
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
      return countCompare != 0 ? countCompare : _compareYears(a.key, b.key);
    });
    return list;
  }

  List<Publication> get topPapers {
    final sorted = _analysisPublications.toList()
      ..sort((a, b) => b.citationCount.compareTo(a.citationCount));
    return sorted.take(5).toList(growable: false);
  }

  List<MapEntry<String, int>> get topJournals {
    return _rankByCount(
      _analysisPublications
          .map((publication) => publication.journalName)
          .where((journal) => journal.trim().isNotEmpty),
    );
  }

  List<MapEntry<String, int>> get topAuthors {
    return _rankByCount(
      _analysisPublications.expand((publication) => publication.authors),
    );
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
    _totalAvailable = 0;
    _currentPage = 1;
  }

  void _sortAnalysisPublications() {
    final sorted = _publications.where((publication) {
      final year = publication.year;
      return year == null || year <= DateTime.now().year;
    }).toList();
    sorted.sort(_comparePublicationsByYear);
    _analysisPublications = sorted;
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

  List<MapEntry<String, int>> _rankByCount(Iterable<String> values) {
    final counts = <String, int>{};
    for (final value in values) {
      final trimmed = value.trim();
      if (trimmed.isEmpty || trimmed == 'Unknown journal') {
        continue;
      }
      counts[trimmed] = (counts[trimmed] ?? 0) + 1;
    }
    final entries = counts.entries.toList()
      ..sort((a, b) => b.value.compareTo(a.value));
    return entries.take(5).toList(growable: false);
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
