import 'json_readers.dart';

final class AuditLog {
  const AuditLog({
    required this.id,
    required this.actorUid,
    required this.actorEmail,
    required this.action,
    required this.targetType,
    required this.targetId,
    required this.summary,
    required this.createdAt,
  });

  factory AuditLog.fromJson(JsonMap json) => AuditLog(
    id: readString(json, 'id'),
    actorUid: readNullableString(json, 'actorUid'),
    actorEmail: readNullableString(json, 'actorEmail'),
    action: readString(json, 'action', fallback: 'unknown'),
    targetType: readNullableString(json, 'targetType'),
    targetId: readNullableString(json, 'targetId'),
    summary: readNullableString(json, 'summary'),
    createdAt: readNullableString(json, 'createdAt'),
  );

  final String id;
  final String? actorUid;
  final String? actorEmail;
  final String action;
  final String? targetType;
  final String? targetId;
  final String? summary;
  final String? createdAt;
}

final class AuditLogPage {
  const AuditLogPage({required this.logs});

  factory AuditLogPage.fromJson(JsonMap json) =>
      AuditLogPage(logs: readObjectList(json, 'logs', AuditLog.fromJson));

  final List<AuditLog> logs;
}
