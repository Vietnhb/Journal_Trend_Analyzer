typedef JsonMap = Map<String, Object?>;

JsonMap readJsonMap(Object? value, {String context = 'response'}) {
  if (value is Map<String, Object?>) return value;
  if (value is Map) {
    return value.map((key, item) => MapEntry(key.toString(), item));
  }
  throw FormatException('Expected $context to be a JSON object.');
}

List<Object?> readJsonList(Object? value, {String context = 'value'}) {
  if (value is List<Object?>) return value;
  if (value is List) return value.cast<Object?>();
  throw FormatException('Expected $context to be a JSON array.');
}

String readString(JsonMap json, String key, {String? fallback}) {
  final value = json[key];
  if (value is String) return value;
  if (fallback != null) return fallback;
  throw FormatException('Expected "$key" to be a string.');
}

String? readNullableString(JsonMap json, String key) {
  final value = json[key];
  if (value == null) return null;
  if (value is String) return value;
  if (value is num) return value.toString();
  throw FormatException('Expected "$key" to be a string or null.');
}

bool readBool(JsonMap json, String key, {bool fallback = false}) {
  final value = json[key];
  return value is bool ? value : fallback;
}

num readNum(JsonMap json, String key, {num fallback = 0}) {
  final value = json[key];
  if (value is num && value.isFinite) return value;
  if (value is String) {
    final parsed = num.tryParse(value);
    if (parsed != null && parsed.isFinite) return parsed;
  }
  return fallback;
}

int readInt(JsonMap json, String key, {int fallback = 0}) {
  return readNum(json, key, fallback: fallback).toInt();
}

int? readNullableInt(JsonMap json, String key) {
  final value = json[key];
  if (value is num && value.isFinite) return value.toInt();
  if (value is String) return num.tryParse(value)?.toInt();
  return null;
}

double readDouble(JsonMap json, String key, {double fallback = 0}) {
  return readNum(json, key, fallback: fallback).toDouble();
}

List<T> readObjectList<T>(
  JsonMap json,
  String key,
  T Function(JsonMap json) decode,
) {
  final value = json[key];
  if (value == null) return const [];
  return readJsonList(value, context: '"$key"')
      .map((item) => decode(readJsonMap(item, context: 'an item in "$key"')))
      .toList(growable: false);
}
