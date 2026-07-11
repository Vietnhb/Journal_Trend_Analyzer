import '../../core/constants/app_text_sanitizer.dart';

class Publication {
  final String id;
  final String title;
  final String? titleMarkup;
  final int? year;
  final String? publicationDate;
  final int citationCount;
  final String journalName;
  final List<String> authors;
  final String? doi;
  final String? url;
  final String? abstractText;
  final String? abstractMarkup;

  const Publication({
    required this.id,
    required this.title,
    this.titleMarkup,
    required this.year,
    this.publicationDate,
    required this.citationCount,
    required this.journalName,
    required this.authors,
    this.doi,
    this.url,
    this.abstractText,
    this.abstractMarkup,
  });

  factory Publication.fromOpenAlexJson(Map<String, dynamic> json) {
    final rawTitle = _emptyToNull(
      _asString(json['title']) ?? _asString(json['display_name']),
    );
    final rawAbstract = _emptyToNull(
      _abstractFromInvertedIndex(json['abstract_inverted_index']),
    );
    return Publication(
      id: _asString(json['id']) ?? '',
      title: AppTextSanitizer.clean(rawTitle, fallback: 'Untitled publication'),
      titleMarkup: rawTitle,
      year: _asInt(json['publication_year']),
      publicationDate: _emptyToNull(_asString(json['publication_date'])),
      citationCount: _asInt(json['cited_by_count']) ?? 0,
      journalName: _extractJournalName(json),
      authors: _extractAuthors(json),
      doi: _emptyToNull(_asString(json['doi'])),
      url: _extractUrl(json),
      abstractText: AppTextSanitizer.cleanNullable(rawAbstract),
      abstractMarkup: rawAbstract,
    );
  }

  factory Publication.fromBookmarkJson(Map<String, dynamic> json) {
    return Publication(
      id: _asString(json['id']) ?? '',
      title: AppTextSanitizer.clean(
        _asString(json['title']),
        fallback: 'Untitled publication',
      ),
      titleMarkup: _emptyToNull(_asString(json['titleMarkup'])),
      year: _asInt(json['year']),
      publicationDate: _emptyToNull(_asString(json['publicationDate'])),
      citationCount: _asInt(json['citationCount']) ?? 0,
      journalName: AppTextSanitizer.clean(
        _asString(json['journalName']),
        fallback: 'Unknown journal',
      ),
      authors: _asStringList(json['authors']),
      doi: _emptyToNull(_asString(json['doi'])),
      url: _emptyToNull(_asString(json['url'])),
      abstractText: AppTextSanitizer.cleanNullable(json['abstractText']),
      abstractMarkup: _emptyToNull(_asString(json['abstractMarkup'])),
    );
  }

  Map<String, dynamic> toBookmarkJson() {
    return {
      'id': id,
      'title': title,
      'titleMarkup': titleMarkup,
      'year': year,
      'publicationDate': publicationDate,
      'citationCount': citationCount,
      'journalName': journalName,
      'authors': authors,
      'doi': doi,
      'url': url,
      'abstractText': abstractText,
      'abstractMarkup': abstractMarkup,
    };
  }

  static String? _extractUrl(Map<String, dynamic> json) {
    final landingPage = _asString(
      (json['primary_location'] as Map?)?['landing_page_url'],
    );
    if (landingPage != null && landingPage.trim().isNotEmpty) {
      return landingPage.trim();
    }
    return _emptyToNull(_asString(json['doi']));
  }

  static String _extractJournalName(Map<String, dynamic> json) {
    final primaryLocation = json['primary_location'];
    if (primaryLocation is Map<String, dynamic>) {
      final source = primaryLocation['source'];
      if (source is Map<String, dynamic>) {
        final name = AppTextSanitizer.cleanNullable(source['display_name']);
        if (name != null) return name;
      }
    }
    return 'Unknown journal';
  }

  static List<String> _extractAuthors(Map<String, dynamic> json) {
    final authorships = json['authorships'];
    if (authorships is! List) return const [];

    return authorships
        .map((authorship) {
          if (authorship is! Map<String, dynamic>) return null;
          final author = authorship['author'];
          if (author is! Map<String, dynamic>) return null;
          return AppTextSanitizer.cleanNullable(author['display_name']);
        })
        .whereType<String>()
        .toList(growable: false);
  }

  static String? _abstractFromInvertedIndex(Object? value) {
    if (value is! Map<String, dynamic>) return null;

    final wordsByPosition = <int, String>{};
    for (final entry in value.entries) {
      final positions = entry.value;
      if (positions is! List) continue;
      for (final position in positions) {
        final index = _asInt(position);
        if (index != null) {
          wordsByPosition[index] = entry.key;
        }
      }
    }

    final orderedPositions = wordsByPosition.keys.toList()..sort();
    return orderedPositions.map((index) => wordsByPosition[index]).join(' ');
  }

  static String? _asString(Object? value) {
    return value is String ? value : null;
  }

  static List<String> _asStringList(Object? value) {
    if (value is! List) return const [];
    return value
        .map((item) => item.toString().trim())
        .where((item) => item.isNotEmpty)
        .toList(growable: false);
  }

  static int? _asInt(Object? value) {
    if (value is int) return value;
    if (value is num) return value.toInt();
    if (value is String) return int.tryParse(value);
    return null;
  }

  static String? _emptyToNull(String? value) {
    final trimmed = value?.trim();
    return trimmed == null || trimmed.isEmpty ? null : trimmed;
  }
}
