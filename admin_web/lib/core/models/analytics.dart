import 'json_readers.dart';

enum IntegrationStatus {
  ready,
  authorizationRequired,
  pending,
  unconfigured,
  error,
  unknown;

  static IntegrationStatus parse(Object? value) => switch (value) {
    'ready' => ready,
    'authorization_required' => authorizationRequired,
    'pending' => pending,
    'unconfigured' => unconfigured,
    'error' => error,
    _ => unknown,
  };
}

final class AnalyticsData {
  const AnalyticsData({
    required this.status,
    required this.reason,
    required this.summary,
    required this.events,
    required this.daily,
    required this.eventDaily,
  });

  factory AnalyticsData.fromJson(JsonMap json) => AnalyticsData(
    status: IntegrationStatus.parse(json['status']),
    reason: readNullableString(json, 'reason'),
    summary: AnalyticsSummary.fromJson(
      readJsonMap(json['summary'] ?? const <String, Object?>{}),
    ),
    events: readObjectList(json, 'events', AnalyticsEvent.fromJson),
    daily: readObjectList(json, 'daily', AnalyticsDaily.fromJson),
    eventDaily: readObjectList(
      json,
      'eventDaily',
      AnalyticsEventDaily.fromJson,
    ),
  );

  final IntegrationStatus status;
  final String? reason;
  final AnalyticsSummary summary;
  final List<AnalyticsEvent> events;
  final List<AnalyticsDaily> daily;
  final List<AnalyticsEventDaily> eventDaily;
}

final class AnalyticsSummary {
  const AnalyticsSummary({
    required this.activeUsers,
    required this.sessions,
    required this.eventCount,
  });

  factory AnalyticsSummary.fromJson(JsonMap json) => AnalyticsSummary(
    activeUsers: readInt(json, 'activeUsers'),
    sessions: readInt(json, 'sessions'),
    eventCount: readInt(json, 'eventCount'),
  );

  final int activeUsers;
  final int sessions;
  final int eventCount;
}

final class AnalyticsEvent {
  const AnalyticsEvent({
    required this.name,
    required this.count,
    required this.users,
    required this.countPerUser,
    required this.revenue,
  });

  factory AnalyticsEvent.fromJson(JsonMap json) => AnalyticsEvent(
    name: readString(json, 'name'),
    count: readInt(json, 'count'),
    users: readInt(json, 'users'),
    countPerUser: readDouble(json, 'countPerUser'),
    revenue: readDouble(json, 'revenue'),
  );

  final String name;
  final int count;
  final int users;
  final double countPerUser;
  final double revenue;
}

final class AnalyticsDaily {
  const AnalyticsDaily({required this.date, required this.count});

  factory AnalyticsDaily.fromJson(JsonMap json) => AnalyticsDaily(
    date: readString(json, 'date'),
    count: readInt(json, 'count'),
  );

  final String date;
  final int count;
}

final class AnalyticsEventDaily {
  const AnalyticsEventDaily({
    required this.date,
    required this.name,
    required this.count,
  });

  factory AnalyticsEventDaily.fromJson(JsonMap json) => AnalyticsEventDaily(
    date: readString(json, 'date'),
    name: readString(json, 'name'),
    count: readInt(json, 'count'),
  );

  final String date;
  final String name;
  final int count;
}
