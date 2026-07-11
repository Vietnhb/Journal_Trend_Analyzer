import '../../core/constants/app_text_sanitizer.dart';

class JournalProfile {
  final String id;
  final String name;
  final String? issnL;
  final List<String> issn;
  final String? publisher;
  final String? countryCode;
  final String? homepageUrl;
  final String type;
  final int worksCount;
  final int citedByCount;
  final int oaWorksCount;
  final int? hIndex;
  final int? i10Index;
  final double? twoYearMeanCitedness;
  final int? firstPublicationYear;
  final int? lastPublicationYear;
  final bool isOpenAccess;
  final bool isInDoaj;
  final List<JournalTopic> topics;
  final Map<int, int> worksByYear;
  final Map<int, int> citationsByYear;

  const JournalProfile({
    required this.id,
    required this.name,
    required this.issnL,
    required this.issn,
    required this.publisher,
    required this.countryCode,
    required this.homepageUrl,
    required this.type,
    required this.worksCount,
    required this.citedByCount,
    required this.oaWorksCount,
    required this.hIndex,
    required this.i10Index,
    required this.twoYearMeanCitedness,
    required this.firstPublicationYear,
    required this.lastPublicationYear,
    required this.isOpenAccess,
    required this.isInDoaj,
    required this.topics,
    required this.worksByYear,
    required this.citationsByYear,
  });

  factory JournalProfile.fromOpenAlexJson(Map<String, dynamic> json) {
    final yearlyCounts = <int, int>{};
    final yearlyCitations = <int, int>{};
    final countsByYear = json['counts_by_year'];
    if (countsByYear is List) {
      for (final item in countsByYear) {
        if (item is! Map<String, dynamic>) continue;
        final year = _asInt(item['year']);
        if (year == null) continue;
        yearlyCounts[year] = _asInt(item['works_count']) ?? 0;
        yearlyCitations[year] = _asInt(item['cited_by_count']) ?? 0;
      }
    }

    final topicItems = json['topics'];
    final topics = <JournalTopic>[];
    if (topicItems is List) {
      for (final item in topicItems.take(10)) {
        if (item is Map<String, dynamic>) {
          topics.add(JournalTopic.fromOpenAlexJson(item));
        }
      }
    }

    final summaryStats = json['summary_stats'];
    return JournalProfile(
      id: (json['id'] ?? '').toString(),
      name: AppTextSanitizer.clean(json['display_name']),
      issnL: _asString(json['issn_l']),
      issn: _asStringList(json['issn']),
      publisher: _asString(json['host_organization_name']),
      countryCode: _asString(json['country_code']),
      homepageUrl: _asString(json['homepage_url']),
      type: _asString(json['type']) ?? 'journal',
      worksCount: _asInt(json['works_count']) ?? 0,
      citedByCount: _asInt(json['cited_by_count']) ?? 0,
      oaWorksCount: _asInt(json['oa_works_count']) ?? 0,
      hIndex: summaryStats is Map<String, dynamic>
          ? _asInt(summaryStats['h_index'])
          : null,
      i10Index: summaryStats is Map<String, dynamic>
          ? _asInt(summaryStats['i10_index'])
          : null,
      twoYearMeanCitedness: summaryStats is Map<String, dynamic>
          ? _asDouble(summaryStats['2yr_mean_citedness'])
          : null,
      firstPublicationYear: _asInt(json['first_publication_year']),
      lastPublicationYear: _asInt(json['last_publication_year']),
      isOpenAccess: json['is_oa'] == true,
      isInDoaj: json['is_in_doaj'] == true,
      topics: List.unmodifiable(topics),
      worksByYear: Map.unmodifiable(yearlyCounts),
      citationsByYear: Map.unmodifiable(yearlyCitations),
    );
  }

  factory JournalProfile.fromBookmarkJson(Map<String, dynamic> json) {
    final topicsJson = json['topics'];
    return JournalProfile(
      id: (json['id'] ?? '').toString(),
      name: AppTextSanitizer.clean(json['name']),
      issnL: _asString(json['issnL']),
      issn: _asStringList(json['issn']),
      publisher: _asString(json['publisher']),
      countryCode: _asString(json['countryCode']),
      homepageUrl: _asString(json['homepageUrl']),
      type: _asString(json['type']) ?? 'journal',
      worksCount: _asInt(json['worksCount']) ?? 0,
      citedByCount: _asInt(json['citedByCount']) ?? 0,
      oaWorksCount: _asInt(json['oaWorksCount']) ?? 0,
      hIndex: _asInt(json['hIndex']),
      i10Index: _asInt(json['i10Index']),
      twoYearMeanCitedness: _asDouble(json['twoYearMeanCitedness']),
      firstPublicationYear: _asInt(json['firstPublicationYear']),
      lastPublicationYear: _asInt(json['lastPublicationYear']),
      isOpenAccess: json['isOpenAccess'] == true,
      isInDoaj: json['isInDoaj'] == true,
      topics: topicsJson is List
          ? List.unmodifiable(
              topicsJson.whereType<Map<String, dynamic>>().map(
                JournalTopic.fromBookmarkJson,
              ),
            )
          : const [],
      worksByYear: _asYearMap(json['worksByYear']),
      citationsByYear: _asYearMap(json['citationsByYear']),
    );
  }

  Map<String, dynamic> toBookmarkJson() => {
    'id': id,
    'name': name,
    'issnL': issnL,
    'issn': issn,
    'publisher': publisher,
    'countryCode': countryCode,
    'homepageUrl': homepageUrl,
    'type': type,
    'worksCount': worksCount,
    'citedByCount': citedByCount,
    'oaWorksCount': oaWorksCount,
    'hIndex': hIndex,
    'i10Index': i10Index,
    'twoYearMeanCitedness': twoYearMeanCitedness,
    'firstPublicationYear': firstPublicationYear,
    'lastPublicationYear': lastPublicationYear,
    'isOpenAccess': isOpenAccess,
    'isInDoaj': isInDoaj,
    'topics': topics.map((topic) => topic.toBookmarkJson()).toList(),
    'worksByYear': worksByYear.map((year, count) => MapEntry('$year', count)),
    'citationsByYear': citationsByYear.map(
      (year, count) => MapEntry('$year', count),
    ),
  };

  double get openAccessPercent =>
      worksCount == 0 ? 0 : (oaWorksCount / worksCount) * 100;

  static String? _asString(Object? value) {
    final text = value?.toString().trim();
    return text == null || text.isEmpty ? null : AppTextSanitizer.clean(text);
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

  static double? _asDouble(Object? value) {
    if (value is double) return value;
    if (value is num) return value.toDouble();
    if (value is String) return double.tryParse(value);
    return null;
  }

  static Map<int, int> _asYearMap(Object? value) {
    if (value is! Map) return const {};
    final result = <int, int>{};
    for (final entry in value.entries) {
      final year = _asInt(entry.key);
      final count = _asInt(entry.value);
      if (year != null && count != null) result[year] = count;
    }
    return Map.unmodifiable(result);
  }
}

class JournalTopic {
  final String name;
  final String? subfield;
  final String? field;
  final String? domain;
  final int count;

  const JournalTopic({
    required this.name,
    required this.subfield,
    required this.field,
    required this.domain,
    required this.count,
  });

  factory JournalTopic.fromOpenAlexJson(Map<String, dynamic> json) {
    return JournalTopic(
      name: AppTextSanitizer.clean(json['display_name']),
      subfield: _nestedDisplayName(json['subfield']),
      field: _nestedDisplayName(json['field']),
      domain: _nestedDisplayName(json['domain']),
      count: JournalProfile._asInt(json['count']) ?? 0,
    );
  }

  factory JournalTopic.fromBookmarkJson(Map<String, dynamic> json) {
    return JournalTopic(
      name: AppTextSanitizer.clean(json['name']),
      subfield: JournalProfile._asString(json['subfield']),
      field: JournalProfile._asString(json['field']),
      domain: JournalProfile._asString(json['domain']),
      count: JournalProfile._asInt(json['count']) ?? 0,
    );
  }

  Map<String, dynamic> toBookmarkJson() => {
    'name': name,
    'subfield': subfield,
    'field': field,
    'domain': domain,
    'count': count,
  };

  static String? _nestedDisplayName(Object? value) {
    if (value is! Map<String, dynamic>) return null;
    final text = value['display_name']?.toString().trim();
    return text == null || text.isEmpty ? null : AppTextSanitizer.clean(text);
  }
}
