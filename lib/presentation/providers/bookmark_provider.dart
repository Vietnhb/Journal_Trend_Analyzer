import 'dart:convert';

import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../../data/models/bookmark.dart';
import '../../data/models/journal_profile.dart';
import '../../data/models/publication.dart';

class BookmarkProvider extends ChangeNotifier {
  static const _journalsKey = 'bookmarked_journals';
  static const _publicationsKey = 'bookmarked_publications';

  List<JournalBookmark> _journals = const [];
  List<PublicationBookmark> _publications = const [];
  bool _isLoading = true;

  BookmarkProvider() {
    _load();
  }

  bool get isLoading => _isLoading;
  List<JournalBookmark> get journals => _journals;
  List<PublicationBookmark> get publications => _publications;
  int get totalCount => _journals.length + _publications.length;

  bool isJournalBookmarked(String id) {
    return _journals.any((bookmark) => bookmark.id == id);
  }

  bool isPublicationBookmarked(String id) {
    return _publications.any((bookmark) => bookmark.publication.id == id);
  }

  Future<void> toggleJournal(JournalProfile profile) async {
    if (isJournalBookmarked(profile.id)) {
      _journals = _journals
          .where((bookmark) => bookmark.id != profile.id)
          .toList(growable: false);
    } else {
      _journals = [
        JournalBookmark.fromProfile(profile),
        ..._journals.where((bookmark) => bookmark.id != profile.id),
      ];
    }
    notifyListeners();
    await _saveJournals();
  }

  Future<void> updateJournalSnapshot(JournalProfile profile) async {
    final index = _journals.indexWhere((bookmark) => bookmark.id == profile.id);
    if (index < 0) return;

    final current = _journals[index];
    final updated = JournalBookmark.fromProfile(
      profile,
      savedAt: current.savedAt,
    );
    _journals = List.unmodifiable([
      ..._journals.take(index),
      updated,
      ..._journals.skip(index + 1),
    ]);
    notifyListeners();
    await _saveJournals();
  }

  Future<void> togglePublication(Publication publication) async {
    if (isPublicationBookmarked(publication.id)) {
      _publications = _publications
          .where((bookmark) => bookmark.publication.id != publication.id)
          .toList(growable: false);
    } else {
      _publications = [
        PublicationBookmark.fromPublication(publication),
        ..._publications.where(
          (bookmark) => bookmark.publication.id != publication.id,
        ),
      ];
    }
    notifyListeners();
    await _savePublications();
  }

  Future<void> removeJournal(String id) async {
    _journals = _journals
        .where((bookmark) => bookmark.id != id)
        .toList(growable: false);
    notifyListeners();
    await _saveJournals();
  }

  Future<void> removePublication(String id) async {
    _publications = _publications
        .where((bookmark) => bookmark.publication.id != id)
        .toList(growable: false);
    notifyListeners();
    await _savePublications();
  }

  Future<void> _load() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      _journals = _decodeList(
        prefs.getStringList(_journalsKey) ?? const [],
        JournalBookmark.fromJson,
      );
      _publications = _decodeList(
        prefs.getStringList(_publicationsKey) ?? const [],
        PublicationBookmark.fromJson,
      );
    } catch (error) {
      debugPrint('Could not load bookmarks: $error');
    } finally {
      _isLoading = false;
      notifyListeners();
    }
  }

  Future<void> _saveJournals() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setStringList(
      _journalsKey,
      _journals.map((bookmark) => jsonEncode(bookmark.toJson())).toList(),
    );
  }

  Future<void> _savePublications() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setStringList(
      _publicationsKey,
      _publications.map((bookmark) => jsonEncode(bookmark.toJson())).toList(),
    );
  }

  List<T> _decodeList<T>(
    List<String> values,
    T Function(Map<String, dynamic> json) fromJson,
  ) {
    final result = <T>[];
    for (final value in values) {
      try {
        final decoded = jsonDecode(value);
        if (decoded is Map<String, dynamic>) {
          result.add(fromJson(decoded));
        }
      } catch (error) {
        debugPrint('Could not decode bookmark: $error');
      }
    }
    return List.unmodifiable(result);
  }
}
