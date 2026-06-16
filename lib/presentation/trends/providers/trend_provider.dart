import 'package:flutter/foundation.dart';
import '../../../data/models/publication.dart';

class TrendProvider extends ChangeNotifier {
  List<Publication> _publications = [];
  bool _isLoading = false;

  List<Publication> get publications => _publications;
  bool get isLoading => _isLoading;

  // Key metrics
  Map<int, int> get publicationsByYear {
    final Map<int, int> grouped = {};
    for (var pub in _publications) {
      final year = pub.year;
      if (year == null) {
        continue;
      }
      grouped[year] = (grouped[year] ?? 0) + 1;
    }
    return grouped;
  }

  int get mostActiveYear {
    final grouped = publicationsByYear;
    if (grouped.isEmpty) return 0;

    int maxYear = 0;
    int maxCount = -1;

    grouped.forEach((year, count) {
      if (count > maxCount) {
        maxCount = count;
        maxYear = year;
      }
    });
    return maxYear;
  }

  List<MapEntry<int, int>> get rankedYears {
    final grouped = publicationsByYear;
    final list = grouped.entries.toList();
    // Sort descending by count, then descending by year
    list.sort((a, b) {
      int countCompare = b.value.compareTo(a.value);
      if (countCompare != 0) return countCompare;
      return b.key.compareTo(a.key);
    });
    return list;
  }

  // Temporary function to load dummy data for testing
  void loadDummyData() {
    _isLoading = true;
    notifyListeners();

    // Simulate network delay
    Future.delayed(const Duration(seconds: 1), () {
      _publications = [
        Publication.dummy(2018),
        Publication.dummy(2019),
        Publication.dummy(2019),
        Publication.dummy(2020),
        Publication.dummy(2020),
        Publication.dummy(2020),
        Publication.dummy(2021),
        Publication.dummy(2021),
        Publication.dummy(2021),
        Publication.dummy(2021),
        Publication.dummy(2022),
        Publication.dummy(2022),
        Publication.dummy(2022),
        Publication.dummy(2022),
        Publication.dummy(2022),
        Publication.dummy(2023),
        Publication.dummy(2023),
        Publication.dummy(2023),
        Publication.dummy(2024),
      ];
      _isLoading = false;
      notifyListeners();
    });
  }
}
