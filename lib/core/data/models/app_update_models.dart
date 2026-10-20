// lib/core/data/models/app_update_models.dart

import 'package:json_annotation/json_annotation.dart';

import 'package:ghar360/core/data/models/wire_enums.dart';

part 'app_update_models.g.dart';

/// Body of `POST /api/v1/versions/check` (`AppVersionCheckRequest`). `app` and `platform` are
/// enum values, `current_version` is 1 to 20 characters and `build_number` is a number, left out
/// when the build number is unknown.
class AppVersionCheckRequest {
  const AppVersionCheckRequest({
    required this.app,
    required this.platform,
    required this.currentVersion,
    this.buildNumber,
  });

  /// `current_version` is 1 to 20 characters.
  static const maxVersionLength = 20;

  final AppKey app;
  final DevicePlatform platform;
  final String currentVersion;
  final int? buildNumber;

  Map<String, dynamic> toJson() {
    final version = currentVersion.trim();
    if (version.isEmpty || version.length > maxVersionLength) {
      throw const FormatException('current_version must be 1 to 20 characters');
    }
    return {
      'app': app.wire,
      'platform': platform.wire,
      'current_version': version,
      'build_number': ?buildNumber,
    };
  }
}

@JsonSerializable(fieldRename: FieldRename.snake)
class AppVersionCheckResponse {
  const AppVersionCheckResponse({
    required this.updateAvailable,
    required this.isMandatory,
    this.latestVersion,
    this.downloadUrl,
    this.releaseNotes,
    this.minSupportedVersion,
  });

  @JsonKey(required: true)
  final bool updateAvailable;
  @JsonKey(defaultValue: false)
  final bool isMandatory;
  final String? latestVersion;
  final String? downloadUrl;
  final String? releaseNotes;
  final String? minSupportedVersion;

  factory AppVersionCheckResponse.fromJson(Map<String, dynamic> json) =>
      _$AppVersionCheckResponseFromJson(json);

  Map<String, dynamic> toJson() => _$AppVersionCheckResponseToJson(this);

  bool get hasDownloadUrl => (downloadUrl ?? '').isNotEmpty;

  AppVersionCheckResponse copyWith({
    bool? updateAvailable,
    bool? isMandatory,
    String? latestVersion,
    String? downloadUrl,
    String? releaseNotes,
    String? minSupportedVersion,
  }) {
    return AppVersionCheckResponse(
      updateAvailable: updateAvailable ?? this.updateAvailable,
      isMandatory: isMandatory ?? this.isMandatory,
      latestVersion: latestVersion ?? this.latestVersion,
      downloadUrl: downloadUrl ?? this.downloadUrl,
      releaseNotes: releaseNotes ?? this.releaseNotes,
      minSupportedVersion: minSupportedVersion ?? this.minSupportedVersion,
    );
  }
}

@JsonSerializable(fieldRename: FieldRename.snake)
class AppVersionInfo {
  const AppVersionInfo({required this.version, this.buildNumber});

  final String version;
  final int? buildNumber;

  factory AppVersionInfo.fromJson(Map<String, dynamic> json) => _$AppVersionInfoFromJson(json);

  Map<String, dynamic> toJson() => _$AppVersionInfoToJson(this);
}
