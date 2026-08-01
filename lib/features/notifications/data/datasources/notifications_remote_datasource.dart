import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:ghar360/core/network/api_client.dart';
import 'package:ghar360/core/network/api_paths.dart';
import 'package:ghar360/core/utils/debug_logger.dart';
import 'package:package_info_plus/package_info_plus.dart';

/// Data source for notification-related API calls.
/// Handles device token registration with the backend.
class NotificationsRemoteDatasource {
  final ApiClient _apiClient;

  NotificationsRemoteDatasource(this._apiClient);

  /// Registers or updates an FCM device token with the backend.
  ///
  /// Endpoint: POST /api/v1/notifications/devices/register
  /// If the caller is authenticated, the token will be associated with the user.
  Future<bool> registerDeviceToken({required String token, String? userId}) async {
    final normalizedToken = token.trim();
    final normalizedUserId = userId?.trim();
    if (normalizedToken.isEmpty || normalizedUserId == null || normalizedUserId.isEmpty) {
      DebugLogger.warning('🔑 Skipping device token registration: missing token or user id');
      return false;
    }

    try {
      // Get app version and locale
      String appVersion = 'unknown';
      try {
        final packageInfo = await PackageInfo.fromPlatform();
        appVersion = '${packageInfo.version}+${packageInfo.buildNumber}';
      } catch (e) {
        DebugLogger.warning('Failed to get package info', e);
      }

      // Determine platform
      String platform = 'unknown';
      if (kIsWeb) {
        platform = 'web';
      } else if (Platform.isAndroid) {
        platform = 'android';
      } else if (Platform.isIOS) {
        platform = 'ios';
      } else if (Platform.isMacOS || Platform.isWindows || Platform.isLinux) {
        // Backend accepts android/ios/web only; map desktop clients to web.
        platform = 'web';
      }

      // Get locale
      final locale = Platform.localeName;

      final body = <String, dynamic>{
        'token': normalizedToken,
        'platform': platform,
        'app_version': appVersion,
        'locale': locale,
      };

      body['user_id'] = normalizedUserId;

      DebugLogger.info('🔑 Registering device token with backend...');
      DebugLogger.debug('🔑 Platform: $platform, Version: $appVersion, Locale: $locale');

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

  /// Unregisters a device token from the backend.
  /// Call this on logout to stop receiving notifications for the user.
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
        queryParams: {'token': normalizedToken},
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
