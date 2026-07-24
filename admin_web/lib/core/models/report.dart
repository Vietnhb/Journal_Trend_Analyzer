import 'json_readers.dart';

final class StoredReport {
  const StoredReport({
    required this.path,
    required this.name,
    required this.ownerUid,
    required this.ownerEmail,
    required this.topic,
    required this.sizeBytes,
    required this.contentType,
    required this.generation,
    required this.createdAt,
    required this.updatedAt,
  });

  factory StoredReport.fromJson(JsonMap json) => StoredReport(
    path: readString(json, 'path'),
    name: readString(json, 'name'),
    ownerUid: readString(json, 'ownerUid'),
    ownerEmail: readNullableString(json, 'ownerEmail'),
    topic: readNullableString(json, 'topic'),
    sizeBytes: readInt(json, 'sizeBytes'),
    contentType: readNullableString(json, 'contentType'),
    generation: readString(json, 'generation'),
    createdAt: readNullableString(json, 'createdAt'),
    updatedAt: readNullableString(json, 'updatedAt'),
  );

  final String path;
  final String name;
  final String ownerUid;
  final String? ownerEmail;
  final String? topic;
  final int sizeBytes;
  final String? contentType;
  final String generation;
  final String? createdAt;
  final String? updatedAt;
}

final class ReportBulkDeleteResult {
  const ReportBulkDeleteResult({required this.deleted, required this.failed});

  factory ReportBulkDeleteResult.fromJson(JsonMap json) =>
      ReportBulkDeleteResult(
        deleted: readStringList(json, 'deleted'),
        failed: readObjectList(json, 'failed', ReportDeleteFailure.fromJson),
      );

  final List<String> deleted;
  final List<ReportDeleteFailure> failed;
}

final class ReportDeleteFailure {
  const ReportDeleteFailure({required this.path, required this.code});

  factory ReportDeleteFailure.fromJson(JsonMap json) => ReportDeleteFailure(
    path: readString(json, 'path'),
    code: readString(json, 'code'),
  );

  final String path;
  final String code;
}

final class ReportPage {
  const ReportPage({required this.reports, required this.nextPageToken});

  factory ReportPage.fromJson(JsonMap json) => ReportPage(
    reports: readObjectList(json, 'reports', StoredReport.fromJson),
    nextPageToken: readNullableString(json, 'nextPageToken'),
  );

  final List<StoredReport> reports;
  final String? nextPageToken;
}

final class ReportDeleteResult {
  const ReportDeleteResult({
    required this.path,
    required this.generation,
    required this.deleted,
  });

  factory ReportDeleteResult.fromJson(JsonMap json) => ReportDeleteResult(
    path: readString(json, 'path'),
    generation: readString(json, 'generation'),
    deleted: readBool(json, 'deleted'),
  );

  final String path;
  final String generation;
  final bool deleted;
}
