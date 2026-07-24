import 'json_readers.dart';

final class AdminUser {
  const AdminUser({
    required this.uid,
    required this.email,
    required this.phoneNumber,
    required this.displayName,
    required this.photoUrl,
    required this.disabled,
    required this.emailVerified,
    required this.isAdmin,
    required this.providers,
    required this.createdAt,
    required this.lastSignInAt,
    required this.lastRefreshAt,
  });

  factory AdminUser.fromJson(JsonMap json) => AdminUser(
    uid: readString(json, 'uid'),
    email: readNullableString(json, 'email'),
    phoneNumber: readNullableString(json, 'phoneNumber'),
    displayName: readNullableString(json, 'displayName'),
    photoUrl: readNullableString(json, 'photoURL'),
    disabled: readBool(json, 'disabled'),
    emailVerified: readBool(json, 'emailVerified'),
    isAdmin: readBool(json, 'admin'),
    providers:
        (json['providers'] is List ? json['providers']! as List : const [])
            .whereType<String>()
            .toList(growable: false),
    createdAt: readNullableString(json, 'createdAt'),
    lastSignInAt: readNullableString(json, 'lastSignInAt'),
    lastRefreshAt: readNullableString(json, 'lastRefreshAt'),
  );

  final String uid;
  final String? email;
  final String? phoneNumber;
  final String? displayName;
  final String? photoUrl;
  final bool disabled;
  final bool emailVerified;
  final bool isAdmin;
  final List<String> providers;
  final String? createdAt;
  final String? lastSignInAt;
  final String? lastRefreshAt;

  String get label => displayName?.trim().isNotEmpty == true
      ? displayName!.trim()
      : email ?? uid;
}

final class UserPage {
  const UserPage({required this.users, required this.nextPageToken});

  factory UserPage.fromJson(JsonMap json) => UserPage(
    users: readObjectList(json, 'users', AdminUser.fromJson),
    nextPageToken: readNullableString(json, 'nextPageToken'),
  );

  final List<AdminUser> users;
  final String? nextPageToken;
}

final class UserUpdate {
  const UserUpdate({
    this.displayName,
    this.clearDisplayName = false,
    this.email,
    this.emailVerified,
    this.disabled,
  }) : assert(
         displayName == null || !clearDisplayName,
         'displayName and clearDisplayName cannot both be set.',
       );

  final String? displayName;
  final bool clearDisplayName;
  final String? email;
  final bool? emailVerified;
  final bool? disabled;

  JsonMap toJson() {
    final result = <String, Object?>{};
    if (clearDisplayName) {
      result['displayName'] = null;
    } else if (displayName != null) {
      result['displayName'] = displayName;
    }
    if (email != null) result['email'] = email;
    if (emailVerified != null) result['emailVerified'] = emailVerified;
    if (disabled != null) result['disabled'] = disabled;
    if (result.isEmpty) {
      throw ArgumentError('At least one user field must be updated.');
    }
    return result;
  }
}
