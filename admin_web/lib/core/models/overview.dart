import 'json_readers.dart';

final class OverviewData {
  const OverviewData({
    required this.users,
    required this.reports,
    required this.remoteConfig,
  });

  factory OverviewData.fromJson(JsonMap json) => OverviewData(
    users: OverviewUsers.fromJson(
      readJsonMap(json['users'] ?? const <String, Object?>{}),
    ),
    reports: OverviewReports.fromJson(
      readJsonMap(json['reports'] ?? const <String, Object?>{}),
    ),
    remoteConfig: OverviewRemoteConfig.fromJson(
      readJsonMap(json['remoteConfig'] ?? const <String, Object?>{}),
    ),
  );

  final OverviewUsers users;
  final OverviewReports reports;
  final OverviewRemoteConfig remoteConfig;
}

final class OverviewUsers {
  const OverviewUsers({
    required this.total,
    required this.admins,
    required this.disabled,
    required this.newLast30Days,
  });

  factory OverviewUsers.fromJson(JsonMap json) => OverviewUsers(
    total: readInt(json, 'total'),
    admins: readInt(json, 'admins'),
    disabled: readInt(json, 'disabled'),
    newLast30Days: readInt(json, 'newLast30Days'),
  );

  final int total;
  final int admins;
  final int disabled;
  final int newLast30Days;
}

final class OverviewReports {
  const OverviewReports({required this.count, required this.totalBytes});

  factory OverviewReports.fromJson(JsonMap json) => OverviewReports(
    count: readInt(json, 'count'),
    totalBytes: readInt(json, 'totalBytes'),
  );

  final int count;
  final int totalBytes;
}

final class OverviewRemoteConfig {
  const OverviewRemoteConfig({
    required this.versionNumber,
    required this.updatedAt,
  });

  factory OverviewRemoteConfig.fromJson(JsonMap json) => OverviewRemoteConfig(
    versionNumber: readNullableString(json, 'versionNumber'),
    updatedAt: readNullableString(json, 'updatedAt'),
  );

  final String? versionNumber;
  final String? updatedAt;
}
