class Publication {
  final String id;
  final String title;
  final int? year;
  final int citationCount;
  final String journalName;
  final List<String> authors;
  final String? doi;
  final String? abstractText;

  const Publication({
    required this.id,
    required this.title,
    required this.year,
    required this.citationCount,
    required this.journalName,
    required this.authors,
    this.doi,
    this.abstractText,
  });

  String get journal => journalName;

  factory Publication.dummy(int year) {
    return Publication(
      id: 'dummy_${year}_${DateTime.now().microsecondsSinceEpoch}',
      title: 'Sample Publication $year',
      year: year,
      citationCount: 10,
      journalName: 'Dummy Journal',
      authors: const ['Demo Author'],
    );
  }

  factory Publication.fromOpenAlexJson(Map<String, dynamic> json) {
    return Publication(
      id: _asString(json['id']) ?? '',
      title:
          _asString(json['title']) ??
          _asString(json['display_name']) ??
          'Untitled publication',
      year: _asInt(json['publication_year']),
      citationCount: _asInt(json['cited_by_count']) ?? 0,
      journalName: _extractJournalName(json),
      authors: _extractAuthors(json),
      doi: _emptyToNull(_asString(json['doi'])),
      abstractText: _emptyToNull(
        _abstractFromInvertedIndex(json['abstract_inverted_index']),
      ),
    );
  }

  static String _extractJournalName(Map<String, dynamic> json) {
    final primaryLocation = json['primary_location'];
    if (primaryLocation is Map<String, dynamic>) {
      final source = primaryLocation['source'];
      if (source is Map<String, dynamic>) {
        final name = _asString(source['display_name']);
        if (name != null && name.trim().isNotEmpty) {
          return name.trim();
        }
      }
    }

    final hostVenue = json['host_venue'];
    if (hostVenue is Map<String, dynamic>) {
      final name = _asString(hostVenue['display_name']);
      if (name != null && name.trim().isNotEmpty) {
        return name.trim();
      }
    }

    final locations = json['locations'];
    if (locations is List) {
      for (final location in locations) {
        if (location is! Map<String, dynamic>) {
          continue;
        }
        final source = location['source'];
        if (source is Map<String, dynamic>) {
          final name = _asString(source['display_name']);
          if (name != null && name.trim().isNotEmpty) {
            return name.trim();
          }
        }
      }
    }

    return 'Unknown journal';
  }

  static List<String> _extractAuthors(Map<String, dynamic> json) {
    final authorships = json['authorships'];
    if (authorships is! List) {
      return const [];
    }

    return authorships
        .map((authorship) {
          if (authorship is! Map<String, dynamic>) {
            return null;
          }
          final author = authorship['author'];
          if (author is! Map<String, dynamic>) {
            return null;
          }
          return _emptyToNull(_asString(author['display_name']));
        })
        .whereType<String>()
        .toList(growable: false);
  }

  static String? _abstractFromInvertedIndex(Object? value) {
    if (value is! Map<String, dynamic>) {
      return null;
    }

    final wordsByPosition = <int, String>{};
    for (final entry in value.entries) {
      final positions = entry.value;
      if (positions is! List) {
        continue;
      }

      for (final position in positions) {
        final index = _asInt(position);
        if (index != null) {
          wordsByPosition[index] = entry.key;
        }
      }
    }

    if (wordsByPosition.isEmpty) {
      return null;
    }

    final orderedPositions = wordsByPosition.keys.toList()..sort();
    return orderedPositions.map((index) => wordsByPosition[index]).join(' ');
  }

  static String? _asString(Object? value) {
    if (value is String) {
      return value;
    }
    return null;
  }

  static int? _asInt(Object? value) {
    if (value is int) {
      return value;
    }
    if (value is num) {
      return value.toInt();
    }
    if (value is String) {
      return int.tryParse(value);
    }
    return null;
  }

  static String? _emptyToNull(String? value) {
    final trimmed = value?.trim();
    if (trimmed == null || trimmed.isEmpty) {
      return null;
    }
    return trimmed;
  }
}
