import 'json_readers.dart';

final class RemoteConfigData {
  const RemoteConfigData({
    required this.etag,
    required this.version,
    required this.parameters,
    required this.allParameters,
  });

  factory RemoteConfigData.fromJson(JsonMap json) => RemoteConfigData(
    etag: readString(json, 'etag'),
    version: RemoteConfigVersion.fromJson(
      readJsonMap(json['version'] ?? const <String, Object?>{}),
    ),
    parameters: RemoteConfigLimits.fromJson(
      readJsonMap(json['parameters'] ?? const <String, Object?>{}),
    ),
    allParameters: readObjectList(
      json,
      'allParameters',
      RemoteConfigParameter.fromJson,
    ),
  );

  final String etag;
  final RemoteConfigVersion version;
  final RemoteConfigLimits parameters;
  final List<RemoteConfigParameter> allParameters;
}

final class RemoteConfigLimits {
  const RemoteConfigLimits({
    required this.maxJournals,
    required this.maxKeywords,
  });

  factory RemoteConfigLimits.fromJson(JsonMap json) => RemoteConfigLimits(
    maxJournals: readNullableInt(json, 'maxJournals'),
    maxKeywords: readNullableInt(json, 'maxKeywords'),
  );

  final int? maxJournals;
  final int? maxKeywords;
}

final class RemoteConfigParameter {
  const RemoteConfigParameter({
    required this.key,
    required this.value,
    required this.description,
    required this.valueType,
    required this.group,
  });

  factory RemoteConfigParameter.fromJson(JsonMap json) => RemoteConfigParameter(
    key: readString(json, 'key'),
    value: readNullableString(json, 'value'),
    description: readNullableString(json, 'description'),
    valueType: readNullableString(json, 'valueType'),
    group: readNullableString(json, 'group'),
  );

  final String key;
  final String? value;
  final String? description;
  final String? valueType;
  final String? group;
}

final class RemoteConfigVersion {
  const RemoteConfigVersion({
    required this.versionNumber,
    required this.updatedAt,
    required this.description,
    required this.updateOrigin,
    required this.updateType,
    required this.updatedBy,
    required this.rollbackSource,
  });

  factory RemoteConfigVersion.fromJson(JsonMap json) => RemoteConfigVersion(
    versionNumber: readNullableString(json, 'versionNumber'),
    updatedAt: readNullableString(json, 'updatedAt'),
    description: readNullableString(json, 'description'),
    updateOrigin: readNullableString(json, 'updateOrigin'),
    updateType: readNullableString(json, 'updateType'),
    updatedBy: readNullableString(json, 'updatedBy'),
    rollbackSource: readNullableString(json, 'rollbackSource'),
  );

  final String? versionNumber;
  final String? updatedAt;
  final String? description;
  final String? updateOrigin;
  final String? updateType;
  final String? updatedBy;
  final String? rollbackSource;
}

final class RemoteConfigVersionPage {
  const RemoteConfigVersionPage({
    required this.versions,
    required this.nextPageToken,
  });

  factory RemoteConfigVersionPage.fromJson(JsonMap json) =>
      RemoteConfigVersionPage(
        versions: readObjectList(
          json,
          'versions',
          RemoteConfigVersion.fromJson,
        ),
        nextPageToken: readNullableString(json, 'nextPageToken'),
      );

  final List<RemoteConfigVersion> versions;
  final String? nextPageToken;
}

final class RemoteConfigUpdate {
  const RemoteConfigUpdate({
    required this.maxJournals,
    required this.maxKeywords,
    required this.expectedEtag,
    required this.description,
  });

  final int maxJournals;
  final int maxKeywords;
  final String expectedEtag;
  final String description;

  JsonMap toJson() => {
    'maxJournals': maxJournals,
    'maxKeywords': maxKeywords,
    'expectedEtag': expectedEtag,
    'description': description,
  };
}
