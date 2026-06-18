import '../../core/constants/app_text_sanitizer.dart';

class RankedEntity {
  final String id;
  final String name;
  final int worksCount;

  const RankedEntity({
    required this.id,
    required this.name,
    required this.worksCount,
  });

  factory RankedEntity.fromGroupByJson(Map<String, dynamic> json) {
    final key = (json['key'] ?? '').toString();
    final displayName = AppTextSanitizer.clean(json['key_display_name']);
    return RankedEntity(
      id: key,
      name: displayName.isEmpty ? key : displayName,
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
