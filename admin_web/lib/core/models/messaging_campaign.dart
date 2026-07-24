import 'json_readers.dart';

enum CampaignAudience {
  allUsers('all_users', 'Tất cả người dùng'),
  android('platform_android', 'Thiết bị Android'),
  ios('platform_ios', 'Thiết bị iOS'),
  vietnamese('language_vi', 'Ngôn ngữ Việt'),
  english('language_en', 'Ngôn ngữ Anh');

  const CampaignAudience(this.apiValue, this.label);

  final String apiValue;
  final String label;

  static CampaignAudience fromApi(String value) => values.firstWhere(
    (item) => item.apiValue == value,
    orElse: () => allUsers,
  );
}

enum CampaignStatus {
  scheduled,
  sending,
  sent,
  failed,
  canceled;

  static CampaignStatus fromApi(String value) =>
      values.firstWhere((item) => item.name == value, orElse: () => failed);
}

final class MessagingCampaign {
  const MessagingCampaign({
    required this.id,
    required this.name,
    required this.title,
    required this.body,
    required this.data,
    required this.audience,
    required this.status,
    required this.ttlSeconds,
    required this.sound,
    required this.scheduleAt,
    required this.createdAt,
    required this.sentAt,
    required this.canceledAt,
    required this.messageId,
    required this.errorCode,
    required this.createdByUid,
    required this.createdByEmail,
  });

  factory MessagingCampaign.fromJson(JsonMap json) => MessagingCampaign(
    id: readString(json, 'id'),
    name: readString(json, 'name'),
    title: readString(json, 'title'),
    body: readString(json, 'body'),
    data: _stringMap(json['data']),
    audience: CampaignAudience.fromApi(
      readString(json, 'audience', fallback: 'all_users'),
    ),
    status: CampaignStatus.fromApi(
      readString(json, 'status', fallback: 'failed'),
    ),
    ttlSeconds: readInt(json, 'ttlSeconds', fallback: 86400),
    sound: readBool(json, 'sound', fallback: true),
    scheduleAt: _date(json['scheduleAt']),
    createdAt: _date(json['createdAt']),
    sentAt: _date(json['sentAt']),
    canceledAt: _date(json['canceledAt']),
    messageId: readNullableString(json, 'messageId'),
    errorCode: readNullableString(json, 'errorCode'),
    createdByUid: readNullableString(json, 'createdByUid'),
    createdByEmail: readNullableString(json, 'createdByEmail'),
  );

  final String id;
  final String name;
  final String title;
  final String body;
  final Map<String, String> data;
  final CampaignAudience audience;
  final CampaignStatus status;
  final int ttlSeconds;
  final bool sound;
  final DateTime? scheduleAt;
  final DateTime? createdAt;
  final DateTime? sentAt;
  final DateTime? canceledAt;
  final String? messageId;
  final String? errorCode;
  final String? createdByUid;
  final String? createdByEmail;
}

final class CampaignDraft {
  const CampaignDraft({
    required this.name,
    required this.title,
    required this.body,
    required this.data,
    required this.audience,
    required this.scheduleAt,
    required this.ttlSeconds,
    required this.sound,
  });

  final String name;
  final String title;
  final String body;
  final Map<String, String> data;
  final CampaignAudience audience;
  final DateTime? scheduleAt;
  final int ttlSeconds;
  final bool sound;

  JsonMap toJson() => {
    'name': name,
    'title': title,
    'body': body,
    'data': data,
    'audience': audience.apiValue,
    'scheduleAt': scheduleAt?.toUtc().toIso8601String(),
    'ttlSeconds': ttlSeconds,
    'sound': sound,
  };
}

DateTime? _date(Object? value) {
  if (value is! String) return null;
  return DateTime.tryParse(value)?.toLocal();
}

Map<String, String> _stringMap(Object? value) {
  if (value is! Map) return const {};
  return {
    for (final entry in value.entries)
      if (entry.key is String && entry.value is String)
        entry.key as String: entry.value as String,
  };
}
