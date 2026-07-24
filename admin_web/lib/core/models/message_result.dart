import 'json_readers.dart';

final class TestMessage {
  const TestMessage({
    required this.target,
    required this.title,
    required this.body,
    this.data = const {},
  });

  final String target;
  final String title;
  final String body;
  final Map<String, String> data;

  JsonMap toJson() => {
    'target': target,
    'title': title,
    'body': body,
    'data': data,
  };
}

final class BroadcastMessage {
  const BroadcastMessage({
    required this.title,
    required this.body,
    this.data = const {},
  });

  final String title;
  final String body;
  final Map<String, String> data;

  JsonMap toJson() => {'title': title, 'body': body, 'data': data};
}

final class MessageResult {
  const MessageResult({
    required this.messageId,
    required this.targetFingerprint,
    required this.topic,
  });

  factory MessageResult.fromJson(JsonMap json) => MessageResult(
    messageId: readNullableString(json, 'messageId'),
    targetFingerprint: readNullableString(json, 'targetFingerprint'),
    topic: readNullableString(json, 'topic'),
  );

  final String? messageId;
  final String? targetFingerprint;
  final String? topic;
}

bool isFirebaseInstallationId(String value) =>
    RegExp(r'^[A-Za-z0-9_-]{22}$').hasMatch(value);
