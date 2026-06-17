class RankedEntity {
  final String id;
  final String name;
  final int worksCount;

  const RankedEntity({
    required this.id,
    required this.name,
    required this.worksCount,
  });

  /// OpenAlex group_by keys come as full URLs (e.g.
  /// `https://openalex.org/S137773608`); filters expect the short id segment.
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
}
