class RankedEntity {
  final String id;
  final String name;
  final int worksCount;
  final int oaWorksCount;
  final int citedByCount;
  final double? twoYearMeanCitedness;
  final int? hIndex;
  final int? i10Index;
  final int? firstPublicationYear;
  final int? lastPublicationYear;
  final String? publisher;
  final String? homepageUrl;
  final String? issnL;
  final Map<int, int> countsByYear;
  final List<RankedEntity> topics;

  const RankedEntity({
    required this.id,
    required this.name,
    required this.worksCount,
    this.oaWorksCount = 0,
    this.citedByCount = 0,
    this.twoYearMeanCitedness,
    this.hIndex,
    this.i10Index,
    this.firstPublicationYear,
    this.lastPublicationYear,
    this.publisher,
    this.homepageUrl,
    this.issnL,
    this.countsByYear = const {},
    this.topics = const [],
  });

  /// OpenAlex group_by keys come as full URLs (e.g.
  /// `https://openalex.org/S137773608`).
  String get shortId {
    final trimmed = id.trim();
    if (trimmed.isEmpty) {
      return trimmed;
    }
    final segments = trimmed.split('/');
    return segments.isEmpty ? trimmed : segments.last;
  }

  factory RankedEntity.fromGroupByJson(Map<String, dynamic> json) {
    return RankedEntity(
      id: (json['key'] ?? '').toString(),
      name: (json['key_display_name'] ?? '').toString().trim(),
      worksCount: _asInt(json['count']) ?? 0,
    );
  }

  factory RankedEntity.fromSourceJson(Map<String, dynamic> json) {
    final summaryStats = json['summary_stats'];
    return RankedEntity(
      id: (json['id'] ?? '').toString(),
      name: (json['display_name'] ?? '').toString().trim(),
      worksCount: _asInt(json['works_count']) ?? 0,
      oaWorksCount: _asInt(json['oa_works_count']) ?? 0,
      citedByCount: _asInt(json['cited_by_count']) ?? 0,
      twoYearMeanCitedness: summaryStats is Map<String, dynamic>
          ? _asDouble(summaryStats['2yr_mean_citedness'])
          : null,
      hIndex: summaryStats is Map<String, dynamic>
          ? _asInt(summaryStats['h_index'])
          : null,
      i10Index: summaryStats is Map<String, dynamic>
          ? _asInt(summaryStats['i10_index'])
          : null,
      firstPublicationYear: _asInt(json['first_publication_year']),
      lastPublicationYear: _asInt(json['last_publication_year']),
      publisher: _emptyToNull(
        (json['host_organization_name'] ?? '').toString(),
      ),
      homepageUrl: _emptyToNull((json['homepage_url'] ?? '').toString()),
      issnL: _emptyToNull((json['issn_l'] ?? '').toString()),
      countsByYear: _countsByYear(json['counts_by_year']),
      topics: _topics(json['topics']),
    );
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

  static double? _asDouble(Object? value) {
    if (value is double) {
      return value;
    }
    if (value is num) {
      return value.toDouble();
    }
    if (value is String) {
      return double.tryParse(value);
    }
    return null;
  }

  static Map<int, int> _countsByYear(Object? value) {
    if (value is! List) {
      return const {};
    }

    final counts = <int, int>{};
    for (final item in value) {
      if (item is! Map<String, dynamic>) continue;
      final year = _asInt(item['year']);
      final worksCount = _asInt(item['works_count']);
      if (year != null && worksCount != null) {
        counts[year] = worksCount;
      }
    }
    return counts;
  }

  static List<RankedEntity> _topics(Object? value) {
    if (value is! List) {
      return const [];
    }

    return value
        .whereType<Map<String, dynamic>>()
        .map(
          (topic) => RankedEntity(
            id: (topic['id'] ?? '').toString(),
            name: (topic['display_name'] ?? '').toString().trim(),
            worksCount: _asInt(topic['count']) ?? 0,
          ),
        )
        .where((topic) => topic.id.isNotEmpty && topic.name.isNotEmpty)
        .toList(growable: false);
  }

  static String? _emptyToNull(String value) {
    final trimmed = value.trim();
    return trimmed.isEmpty ? null : trimmed;
  }
}
