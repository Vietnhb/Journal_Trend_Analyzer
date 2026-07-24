import 'json_readers.dart';

final class SessionRevokeResult {
  const SessionRevokeResult({required this.uid, required this.revoked});

  factory SessionRevokeResult.fromJson(JsonMap json) => SessionRevokeResult(
    uid: readString(json, 'uid'),
    revoked: readBool(json, 'revoked'),
  );

  final String uid;
  final bool revoked;
}

final class UserDeleteResult {
  const UserDeleteResult({required this.uid, required this.deleted});

  factory UserDeleteResult.fromJson(JsonMap json) => UserDeleteResult(
    uid: readString(json, 'uid'),
    deleted: readBool(json, 'deleted'),
  );

  final String uid;
  final bool deleted;
}
