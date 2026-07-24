import 'analytics.dart';
import 'json_readers.dart';

final class CrashData {
  const CrashData({
    required this.status,
    required this.reason,
    required this.summary,
    required this.crashFree,
    required this.releases,
    required this.issues,
    required this.daily,
  });

  factory CrashData.fromJson(JsonMap json) => CrashData(
    status: IntegrationStatus.parse(json['status']),
    reason: readNullableString(json, 'reason'),
    summary: CrashSummary.fromJson(
      readJsonMap(json['summary'] ?? const <String, Object?>{}),
    ),
    crashFree: CrashFree.fromJson(
      readJsonMap(json['crashFree'] ?? const <String, Object?>{}),
    ),
    releases: _strings(json['releases']),
    issues: readObjectList(json, 'issues', CrashIssue.fromJson),
    daily: readObjectList(json, 'daily', CrashDaily.fromJson),
  );

  final IntegrationStatus status;
  final String? reason;
  final CrashSummary summary;
  final CrashFree crashFree;
  final List<String> releases;
  final List<CrashIssue> issues;
  final List<CrashDaily> daily;
}

final class CrashFree {
  const CrashFree({
    required this.available,
    required this.usersPercent,
    required this.sessionsPercent,
    required this.totalUsers,
    required this.totalSessions,
  });

  factory CrashFree.fromJson(JsonMap json) => CrashFree(
    available: readBool(json, 'available'),
    usersPercent: json['usersPercent'] == null
        ? null
        : readDouble(json, 'usersPercent'),
    sessionsPercent: json['sessionsPercent'] == null
        ? null
        : readDouble(json, 'sessionsPercent'),
    totalUsers: readInt(json, 'totalUsers'),
    totalSessions: readInt(json, 'totalSessions'),
  );

  final bool available;
  final double? usersPercent;
  final double? sessionsPercent;
  final int totalUsers;
  final int totalSessions;
}

final class CrashSummary {
  const CrashSummary({
    required this.events,
    required this.fatal,
    required this.nonFatal,
    required this.affectedUsers,
  });

  factory CrashSummary.fromJson(JsonMap json) => CrashSummary(
    events: readInt(json, 'events'),
    fatal: readInt(json, 'fatal'),
    nonFatal: readInt(json, 'nonFatal'),
    affectedUsers: readInt(json, 'affectedUsers'),
  );

  final int events;
  final int fatal;
  final int nonFatal;
  final int affectedUsers;
}

final class CrashIssue {
  const CrashIssue({
    required this.issueId,
    required this.errorType,
    required this.events,
    required this.affectedUsers,
    required this.variants,
    required this.firstSeen,
    required this.lastSeen,
    required this.title,
    required this.subtitle,
    required this.versions,
    required this.trend,
    required this.users,
    required this.latest,
  });

  factory CrashIssue.fromJson(JsonMap json) => CrashIssue(
    issueId: readString(json, 'issueId', fallback: 'unknown'),
    errorType: readNullableString(json, 'errorType'),
    events: readInt(json, 'events'),
    affectedUsers: readInt(json, 'affectedUsers'),
    variants: readInt(json, 'variants'),
    firstSeen: readNullableString(json, 'firstSeen'),
    lastSeen: readNullableString(json, 'lastSeen'),
    title: readNullableString(json, 'title'),
    subtitle: readNullableString(json, 'subtitle'),
    versions: _strings(json['versions']),
    trend: readObjectList(json, 'trend', CrashIssueTrend.fromJson),
    users: readObjectList(json, 'users', CrashIssueUser.fromJson),
    latest: CrashIssueLatest.fromJson(
      readJsonMap(json['latest'] ?? const <String, Object?>{}),
    ),
  );

  final String issueId;
  final String? errorType;
  final int events;
  final int affectedUsers;
  final int variants;
  final String? firstSeen;
  final String? lastSeen;
  final String? title;
  final String? subtitle;
  final List<String> versions;
  final List<CrashIssueTrend> trend;
  final List<CrashIssueUser> users;
  final CrashIssueLatest latest;
}

final class CrashIssueTrend {
  const CrashIssueTrend({required this.date, required this.events});

  factory CrashIssueTrend.fromJson(JsonMap json) => CrashIssueTrend(
    date: readString(json, 'date', fallback: ''),
    events: readInt(json, 'events'),
  );

  final String date;
  final int events;
}

final class CrashIssueUser {
  const CrashIssueUser({
    required this.installationId,
    required this.userId,
    required this.name,
    required this.email,
    required this.events,
    required this.firstSeen,
    required this.lastSeen,
    required this.device,
    required this.operatingSystem,
  });

  factory CrashIssueUser.fromJson(JsonMap json) => CrashIssueUser(
    installationId: readString(json, 'installationId', fallback: 'unknown'),
    userId: readNullableString(json, 'userId'),
    name: readNullableString(json, 'name'),
    email: readNullableString(json, 'email'),
    events: readInt(json, 'events'),
    firstSeen: readNullableString(json, 'firstSeen'),
    lastSeen: readNullableString(json, 'lastSeen'),
    device: CrashDevice.fromJson(
      readJsonMap(json['device'] ?? const <String, Object?>{}),
    ),
    operatingSystem: CrashOperatingSystem.fromJson(
      readJsonMap(json['operatingSystem'] ?? const <String, Object?>{}),
    ),
  );

  final String installationId;
  final String? userId;
  final String? name;
  final String? email;
  final int events;
  final String? firstSeen;
  final String? lastSeen;
  final CrashDevice device;
  final CrashOperatingSystem operatingSystem;
}

final class CrashIssueLatest {
  const CrashIssueLatest({
    required this.eventId,
    required this.occurredAt,
    required this.file,
    required this.line,
    required this.symbol,
    required this.device,
    required this.operatingSystem,
    required this.memoryUsed,
    required this.memoryFree,
    required this.storageUsed,
    required this.storageFree,
    required this.exceptionType,
    required this.exceptionMessage,
    required this.frames,
    required this.customKeys,
    required this.logs,
  });

  factory CrashIssueLatest.fromJson(JsonMap json) => CrashIssueLatest(
    eventId: readNullableString(json, 'eventId'),
    occurredAt: readNullableString(json, 'occurredAt'),
    file: readNullableString(json, 'file'),
    line: readInt(json, 'line'),
    symbol: readNullableString(json, 'symbol'),
    device: CrashDevice.fromJson(
      readJsonMap(json['device'] ?? const <String, Object?>{}),
    ),
    operatingSystem: CrashOperatingSystem.fromJson(
      readJsonMap(json['operatingSystem'] ?? const <String, Object?>{}),
    ),
    memoryUsed: readInt(json, 'memoryUsed'),
    memoryFree: readInt(json, 'memoryFree'),
    storageUsed: readInt(json, 'storageUsed'),
    storageFree: readInt(json, 'storageFree'),
    exceptionType: readNullableString(json, 'exceptionType'),
    exceptionMessage: readNullableString(json, 'exceptionMessage'),
    frames: readObjectList(json, 'frames', CrashFrame.fromJson),
    customKeys: readObjectList(json, 'customKeys', CrashKeyValue.fromJson),
    logs: readObjectList(json, 'logs', CrashLog.fromJson),
  );

  final String? eventId;
  final String? occurredAt;
  final String? file;
  final int line;
  final String? symbol;
  final CrashDevice device;
  final CrashOperatingSystem operatingSystem;
  final int memoryUsed;
  final int memoryFree;
  final int storageUsed;
  final int storageFree;
  final String? exceptionType;
  final String? exceptionMessage;
  final List<CrashFrame> frames;
  final List<CrashKeyValue> customKeys;
  final List<CrashLog> logs;
}

final class CrashDevice {
  const CrashDevice({this.manufacturer, this.model, this.architecture});
  factory CrashDevice.fromJson(JsonMap json) => CrashDevice(
    manufacturer: readNullableString(json, 'manufacturer'),
    model: readNullableString(json, 'model'),
    architecture: readNullableString(json, 'architecture'),
  );
  final String? manufacturer;
  final String? model;
  final String? architecture;
}

final class CrashOperatingSystem {
  const CrashOperatingSystem({this.name, this.version, this.deviceType});
  factory CrashOperatingSystem.fromJson(JsonMap json) => CrashOperatingSystem(
    name: readNullableString(json, 'name'),
    version: readNullableString(json, 'version'),
    deviceType: readNullableString(json, 'deviceType'),
  );
  final String? name;
  final String? version;
  final String? deviceType;
}

final class CrashFrame {
  const CrashFrame({
    this.symbol,
    this.file,
    required this.line,
    this.library,
    this.owner,
    required this.blamed,
  });
  factory CrashFrame.fromJson(JsonMap json) => CrashFrame(
    symbol: readNullableString(json, 'symbol'),
    file: readNullableString(json, 'file'),
    line: readInt(json, 'line'),
    library: readNullableString(json, 'library'),
    owner: readNullableString(json, 'owner'),
    blamed: readBool(json, 'blamed'),
  );
  final String? symbol;
  final String? file;
  final int line;
  final String? library;
  final String? owner;
  final bool blamed;
}

final class CrashKeyValue {
  const CrashKeyValue({this.key, this.value});
  factory CrashKeyValue.fromJson(JsonMap json) => CrashKeyValue(
    key: readNullableString(json, 'key'),
    value: readNullableString(json, 'value'),
  );
  final String? key;
  final String? value;
}

final class CrashLog {
  const CrashLog({this.timestamp, this.message});
  factory CrashLog.fromJson(JsonMap json) => CrashLog(
    timestamp: readNullableString(json, 'timestamp'),
    message: readNullableString(json, 'message'),
  );
  final String? timestamp;
  final String? message;
}

final class CrashDaily {
  const CrashDaily({
    required this.date,
    required this.fatal,
    required this.nonFatal,
  });

  factory CrashDaily.fromJson(JsonMap json) => CrashDaily(
    date: readString(json, 'date'),
    fatal: readInt(json, 'fatal'),
    nonFatal: readInt(json, 'nonFatal'),
  );

  final String date;
  final int fatal;
  final int nonFatal;
}

List<String> _strings(Object? value) => value is List
    ? value.whereType<String>().toList(growable: false)
    : const [];
