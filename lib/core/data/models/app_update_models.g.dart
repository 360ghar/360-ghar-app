// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'app_update_models.dart';

// **************************************************************************
// JsonSerializableGenerator
// **************************************************************************

AppVersionCheckResponse _$AppVersionCheckResponseFromJson(Map<String, dynamic> json) {
  $checkKeys(json, requiredKeys: const ['update_available']);
  return AppVersionCheckResponse(
    updateAvailable: json['update_available'] as bool,
    isMandatory: json['is_mandatory'] as bool? ?? false,
    latestVersion: json['latest_version'] as String?,
    downloadUrl: json['download_url'] as String?,
    releaseNotes: json['release_notes'] as String?,
    minSupportedVersion: json['min_supported_version'] as String?,
  );
}

Map<String, dynamic> _$AppVersionCheckResponseToJson(AppVersionCheckResponse instance) =>
    <String, dynamic>{
      'update_available': instance.updateAvailable,
      'is_mandatory': instance.isMandatory,
      'latest_version': instance.latestVersion,
      'download_url': instance.downloadUrl,
      'release_notes': instance.releaseNotes,
      'min_supported_version': instance.minSupportedVersion,
    };

AppVersionInfo _$AppVersionInfoFromJson(Map<String, dynamic> json) => AppVersionInfo(
  version: json['version'] as String,
  buildNumber: (json['build_number'] as num?)?.toInt(),
);

Map<String, dynamic> _$AppVersionInfoToJson(AppVersionInfo instance) => <String, dynamic>{
  'version': instance.version,
  'build_number': instance.buildNumber,
};
