class OpenAlexTopic {
  final String id;
  final String name;
  final String? description;
  final String? domainName;
  final String? fieldName;
  final String? subfieldName;
  final int worksCount;

  const OpenAlexTopic({
    required this.id,
    required this.name,
    this.description,
    this.domainName,
    this.fieldName,
    this.subfieldName,
    this.worksCount = 0,
  });

  String get shortId {
    final trimmed = id.trim();
    if (trimmed.isEmpty) return trimmed;
    final uri = Uri.tryParse(trimmed);
    if (uri != null && uri.pathSegments.isNotEmpty) {
      return uri.pathSegments.last;
    }
    return trimmed;
  }

  factory OpenAlexTopic.fromJson(Map<String, dynamic> json) {
    return OpenAlexTopic(
      id: (json['id'] ?? '').toString(),
      name: (json['display_name'] ?? '').toString().trim(),
      description: _emptyToNull((json['description'] ?? '').toString()),
      domainName: _displayName(json['domain']),
      fieldName: _displayName(json['field']),
      subfieldName: _displayName(json['subfield']),
      worksCount: _asInt(json['works_count']) ?? 0,
    );
  }

  static String? _displayName(Object? value) {
    if (value is! Map<String, dynamic>) return null;
    return _emptyToNull((value['display_name'] ?? '').toString());
  }

  static int? _asInt(Object? value) {
    if (value is int) return value;
    if (value is num) return value.toInt();
    if (value is String) return int.tryParse(value);
    return null;
  }

  static String? _emptyToNull(String value) {
    final trimmed = value.trim();
    return trimmed.isEmpty ? null : trimmed;
  }
}
