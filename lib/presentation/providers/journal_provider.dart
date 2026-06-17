import 'package:flutter/foundation.dart';

import '../../core/errors/app_errors.dart';
import '../../data/repositories/journal_repository.dart';

class JournalProvider extends ChangeNotifier {
  final JournalRepository _repository;

  JournalProvider({JournalRepository? repository})
    : _repository = repository ?? JournalRepository();

  String _query = '';
  bool _isLoading = false;
  bool _hasSearched = false;
  AppError? _error;
  PublicationYearSort _yearSort = PublicationYearSort.descending;
  List<String> _recentSearches = const [];
  List<RankedEntity> _journals = const [];
  RankedEntity? _selectedJournal;
  bool _isDarkMode = false;
  bool _filterFutureSourceYears = true;
  bool _isLoadingJournals = false;
  AppError? _journalError;
  AppError? _analyticsError;

  String get query => _query;
  bool get isLoading => _isLoading;
  bool get hasSearched => _hasSearched;
  AppError? get error => _error;
  PublicationYearSort get yearSort => _yearSort;
  List<String> get recentSearches => _recentSearches;
  List<RankedEntity> get journals => _journals;
  RankedEntity? get selectedJournal => _selectedJournal;
  bool get isDarkMode => _isDarkMode;
  bool get filterFutureSourceYears => _filterFutureSourceYears;
  bool get isLoadingJournals => _isLoadingJournals;
  bool get isLoadingAnalytics => false;
  AppError? get journalError => _journalError;
  AppError? get analyticsError => _analyticsError;

  int get totalAvailable => _selectedJournal?.worksCount ?? 0;
  int get currentPage => 1;
  int get perPage => 50;
  int get totalPages => 1;
  bool get canGoPrevious => false;
  bool get canGoNext => false;

  int get totalWorks => _selectedJournal?.worksCount ?? 0;
  int? get avgCitationCount {
    final journal = _selectedJournal;
    if (journal == null || journal.worksCount == 0) {
      return null;
    }
    return journal.citedByCount ~/ journal.worksCount;
  }

  int? get mostActiveYear {
    final ranked = yearsByWorkCount;
    return ranked.isEmpty ? null : ranked.first.key;
  }

  String? get topJournal => _selectedJournal?.name;
  String? get topAuthor => null;

  Map<int, int> get sourceWorksByYear {
    final counts = _selectedJournal?.countsByYear ?? const <int, int>{};
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

  List<RankedEntity> get journalTopics {
    return (_selectedJournal?.topics ?? const []).take(10).toList();
  }

  Future<void> search(String query) async {
    final trimmed = query.trim();
    if (trimmed.isEmpty || _isLoading) {
      return;
    }

    _query = trimmed;
    _rememberSearch(trimmed);
    _isLoading = true;
    _isLoadingJournals = true;
    _hasSearched = true;
    _error = null;
    _journalError = null;
    _analyticsError = null;
    _selectedJournal = null;
    _journals = const [];
    notifyListeners();

    try {
      _journals = await _repository.getTopJournalsByTopic(trimmed, limit: 25);
    } on AppError catch (error) {
      _error = error;
      _journalError = error;
      _journals = const [];
    } catch (error) {
      _error = AppError('Search failed.', details: error.toString());
      _journalError = _error;
      _journals = const [];
    } finally {
      _isLoading = false;
      _isLoadingJournals = false;
      notifyListeners();
    }
  }

  Future<void> selectJournal(RankedEntity journal) async {
    _selectedJournal = journal;
    _analyticsError = null;
    notifyListeners();
  }

  Future<void> setYearSort(PublicationYearSort yearSort) async {
    if (_yearSort == yearSort) {
      return;
    }
    _yearSort = yearSort;
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
  }

  void clear() {
    _query = '';
    _isLoading = false;
    _hasSearched = false;
    _error = null;
    _yearSort = PublicationYearSort.descending;
    _recentSearches = const [];
    _journals = const [];
    _selectedJournal = null;
    _isLoadingJournals = false;
    _journalError = null;
    _analyticsError = null;
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
}
