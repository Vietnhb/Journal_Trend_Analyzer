import 'json_readers.dart';

final class AdminIdentity {
  const AdminIdentity({
    required this.uid,
    required this.email,
    required this.displayName,
    required this.photoUrl,
    required this.isAdmin,
  });

  factory AdminIdentity.fromJson(JsonMap json) => AdminIdentity(
    uid: readString(json, 'uid'),
    email: readNullableString(json, 'email'),
    displayName: readNullableString(json, 'displayName'),
    photoUrl: readNullableString(json, 'photoURL'),
    isAdmin: readBool(json, 'admin'),
  );

  final String uid;
  final String? email;
  final String? displayName;
  final String? photoUrl;
  final bool isAdmin;

  String get label => displayName?.trim().isNotEmpty == true
      ? displayName!.trim()
      : email ?? uid;
}
