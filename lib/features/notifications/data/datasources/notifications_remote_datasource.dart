import 'package:flutter/foundation.dart';

import 'package:package_info_plus/package_info_plus.dart';

import 'package:ghar360/core/data/models/wire_enums.dart';
import 'package:ghar360/core/network/api_client.dart';
import 'package:ghar360/core/network/api_paths.dart';
import 'package:ghar360/core/utils/debug_logger.dart';

/// Data source for notification-related API calls.
/// Handles device token registration with the backend.
class NotificationsRemoteDatasource {
  final ApiClient _apiClient;

  NotificationsRemoteDatasource(this._apiClient);

  /// The device platform the backend accepts (`android`, `ios`, `web`), or null for a platform
  /// it does not know. Desktop builds report `web`.
  static DevicePlatform? get platform {
    if (kIsWeb) return DevicePlatform.web;
    return switch (defaultTargetPlatform) {
      TargetPlatform.android => DevicePlatform.android,
      TargetPlatform.iOS => DevicePlatform.ios,
      TargetPlatform.macOS || TargetPlatform.windows || TargetPlatform.linux => DevicePlatform.web,
      TargetPlatform.fuchsia => null,
    };
  }

  /// Registers or updates an FCM device token with the backend.
  ///
  /// Endpoint: `POST /api/v1/notifications/devices/register`, 201 with the registration. The
  /// body names the app (`app_key`: `ghar`) and never a user id: the bearer token says who the
  /// device belongs to.
  Future<bool> registerDeviceToken({required String token}) async {
    final normalizedToken = token.trim();
    if (normalizedToken.isEmpty) {
      DebugLogger.warning('🔑 Skipping device token registration: missing token');
      return false;
    }
    final devicePlatform = platform;
    if (devicePlatform == null) {
      DebugLogger.warning('🔑 Skipping device token registration: unsupported platform');
      return false;
    }

    try {
      // Get app version and locale
      String? appVersion;
      try {
        final packageInfo = await PackageInfo.fromPlatform();
        appVersion = '${packageInfo.version}+${packageInfo.buildNumber}';
      } catch (e, stack) {
        DebugLogger.warning('Failed to get package info', e, stack);
      }

      // dart:io Platform.localeName throws on web; the dispatcher works everywhere ("en_IN").
      final locale = PlatformDispatcher.instance.locale.toString();

      final body = <String, dynamic>{
        'token': normalizedToken,
        'platform': devicePlatform.wire,
        'app_key': AppKey.ghar.wire,
        // Backend limits: app_version 64 characters, locale 32.
        'app_version': ?(appVersion != null && appVersion.length <= 64 ? appVersion : null),
        'locale': ?(locale.length <= 32 ? locale : null),
      };

      DebugLogger.info('🔑 Registering device token with backend...');
      DebugLogger.debug('Notification registration platform: ${devicePlatform.wire}');

      final response = await _apiClient.post(ApiPaths.notificationsDeviceRegister, body: body);

      if (response.isSuccess) {
        DebugLogger.success('🔑 Device token registered successfully');
        return true;
      } else {
        DebugLogger.warning('🔑 Device token registration failed: ${response.statusCode}');
        return false;
      }
    } catch (e, st) {
      DebugLogger.warning('🔑 Failed to register device token', e, st);
      return false;
    }
  }

  /// Deactivates the caller's own device token. Call this on logout to stop pushes.
  ///
  /// Endpoint: `DELETE /api/v1/notifications/devices/unregister`, 204 with no body. The token
  /// goes in a JSON body, never in the URL, because URLs reach request logs.
  Future<bool> unregisterDeviceToken(String token) async {
    final normalizedToken = token.trim();
    if (normalizedToken.isEmpty) {
      DebugLogger.warning('🔑 Skipping device token unregistration: missing token');
      return false;
    }

    try {
      DebugLogger.info('🔑 Unregistering device token...');

      final response = await _apiClient.delete(
        ApiPaths.notificationsDeviceUnregister,
        body: {'token': normalizedToken},
      );

      if (response.isSuccess) {
        DebugLogger.success('🔑 Device token unregistered successfully');
        return true;
      } else {
        DebugLogger.warning('🔑 Device token unregistration failed: ${response.statusCode}');
        return false;
      }
    } catch (e, st) {
      DebugLogger.warning('🔑 Failed to unregister device token', e, st);
      return false;
    }
  }
}
