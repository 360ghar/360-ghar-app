import 'dart:convert';
import 'dart:io';

import 'package:flutter/foundation.dart';

import 'package:path/path.dart' as path;
import 'package:path_provider/path_provider.dart';

import 'package:ghar360/core/data/models/unified_filter_model.dart';
import 'package:ghar360/core/storage/storage_failure.dart';

typedef LegacyStorageReader = Future<Map<String, Object?>> Function();

/// Reads the former GetStorage container without initializing or modifying it.
/// GetStorage 2.1.1 used JSON in the application documents directory.
///
/// A container that cannot be parsed in either file is `LEGACY_STORAGE_CORRUPT`: nothing can be
/// imported, and the caller opens with defaults. A file that cannot be read (permission, disk) is
/// `LEGACY_STORAGE_UNREADABLE`: a later attempt can succeed, so the caller must not give up.
Future<Map<String, Object?>> readLegacyStorage({String? directory}) async {
  // Web has no documents directory, so there is no GetStorage file to import.
  if (kIsWeb) return {};
  final root = directory ?? (await getApplicationDocumentsDirectory()).path;
  Object? failure;
  var unreadable = false;
  for (final name in ['GetStorage.gs', 'GetStorage.bak']) {
    final file = File(path.join(root, name));
    try {
      if (!await file.exists()) continue;
      final text = await file.readAsString();
      if (text.trim().isEmpty) {
        throw const FormatException('Empty legacy container');
      }
      final decoded = jsonDecode(text);
      if (decoded is! Map<String, dynamic>) {
        throw const FormatException('Invalid legacy container');
      }
      return decoded;
    } catch (error) {
      failure = error;
      if (error is! FormatException) unreadable = true;
    }
  }
  if (failure != null) {
    throw StorageFailure(
      'read legacy storage',
      cause: failure,
      code: unreadable ? legacyStorageUnreadable : legacyStorageCorrupt,
    );
  }
  return {};
}

const legacyStorageCorrupt = 'LEGACY_STORAGE_CORRUPT';
const legacyStorageUnreadable = 'LEGACY_STORAGE_UNREADABLE';

/// Only device preferences are imported. Never infer ownership of server data.
Map<String, Object?> legacyPreferences(Map<String, Object?> source) {
  final result = <String, Object?>{};
  const booleanKeys = {
    'has_seen_onboarding',
    'pushNotifications',
    'emailNotifications',
    'similarProperties',
    'consent_analytics',
    'consent_performance',
  };
  for (final key in booleanKeys) {
    if (source[key] is bool) result[key] = source[key];
  }
  const themes = ['light', 'dark', 'system'];
  final theme = source['themeMode'];
  if (theme is String && themes.contains(theme)) result['themeMode'] = theme;
  if (theme is int && theme >= 0 && theme < themes.length) {
    result['themeMode'] = themes[theme];
  }
  final language = source['language_code'];
  if (language == 'en' || language == 'hi') {
    result['language_code'] = language;
    result['country_code'] = language == 'hi' ? 'IN' : 'US';
  }
  final purpose = source['global_purpose'];
  if (const ['buy', 'rent', 'short_stay'].contains(purpose)) {
    result['global_purpose'] = purpose;
  }
  final types = source['global_property_types'];
  if (types is List) {
    result['global_property_types'] = types.whereType<String>().where((s) => s.isNotEmpty).toList();
  }
  const checklistIds = {
    'title_deed',
    'sale_deed',
    'mother_deed',
    'encumbrance',
    'khata',
    'mutation',
    'society_noc',
    'bank_noc',
    'rera',
    'property_tax',
    'utility_bills',
    'maintenance_dues',
    'possession_letter',
    'occupancy_cert',
    'completion_cert',
  };
  final checklist = source['document_checklist'];
  if (checklist is Map) {
    result['document_checklist'] = {
      for (final id in checklistIds)
        if (checklist[id] is bool) id: checklist[id],
    };
  }
  // These are preferences only, not server data or credentials.
  for (final key in ['skipped_app_version', 'last_auth_method', 'last_auth_method_at']) {
    final value = source[key];
    if (value is String && value.length <= 128) result[key] = value;
  }
  final hint = source['last_auth_identifier_hint'];
  if (hint is String && hint.contains('*') && hint.length <= 256) {
    result['last_auth_identifier_hint'] = hint;
  }
  for (final page in ['explore', 'discover', 'likes']) {
    final raw = source['${page}_state'];
    if (raw is! Map) continue;
    final snapshot = <String, Object?>{'pageType': page};
    final filters = raw['filters'];
    if (filters is Map) {
      try {
        snapshot['filters'] = UnifiedFilterModel.fromJson(
          Map<String, dynamic>.from(filters),
        ).toJson();
      } catch (_) {
        // One corrupt filter must not prevent the other preferences migrating.
      }
    }
    final location = raw['selectedLocation'];
    if (location is Map) {
      final latitude = location['latitude'];
      final longitude = location['longitude'];
      if (latitude is num &&
          longitude is num &&
          latitude.isFinite &&
          longitude.isFinite &&
          latitude.abs() <= 90 &&
          longitude.abs() <= 180 &&
          location['name'] is String) {
        snapshot['selectedLocation'] = {
          'name': location['name'],
          'latitude': latitude,
          'longitude': longitude,
        };
        snapshot['locationSource'] = 'manual';
      }
    }
    if (page != 'discover' && raw['searchQuery'] is String) {
      snapshot['searchQuery'] = raw['searchQuery'];
    }
    final extra = raw['additionalData'];
    if (page == 'likes' &&
        extra is Map &&
        const ['liked', 'passed'].contains(extra['currentSegment'])) {
      snapshot['additionalData'] = {'currentSegment': extra['currentSegment']};
    }
    result['${page}_state'] = snapshot;
  }
  return result;
}
