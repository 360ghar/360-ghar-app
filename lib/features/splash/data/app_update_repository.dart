import 'package:flutter/foundation.dart';

import 'package:get/get.dart';

import 'package:ghar360/core/data/models/app_update_models.dart';
import 'package:ghar360/core/firebase/firebase_initializer.dart';
import 'package:ghar360/core/firebase/remote_config_service.dart';
import 'package:ghar360/core/utils/debug_logger.dart';

/// Repository for checking app updates using Firebase Remote Config.
///
/// This approach allows you to control app updates from Firebase Console
/// without deploying backend changes. Simply update the Remote Config values
/// when you publish a new version to Play Store / App Store.
class AppUpdateRepository extends GetxService {
  /// Checks for app updates using Firebase Remote Config.
  ///
  /// Compares the current app version against the latest version configured
  /// in Remote Config. Returns update availability and whether it's mandatory.
  Future<AppVersionCheckResponse> checkForUpdates(AppVersionCheckRequest request) async {
    try {
      if (!FirebaseInitializer.isFirebaseReady) {
        DebugLogger.debug('Skipping app update check: Firebase/Remote Config disabled');
        return const AppVersionCheckResponse(updateAvailable: false, isMandatory: false);
      }

      // Force-fetch the latest Remote Config to get real-time version info
      await RemoteConfigService.forceFetch();

      // Get platform-specific version info
      final isAndroid = request.platform == 'android';
      final latestVersion = isAndroid
          ? RemoteConfigService.androidLatestVersion
          : RemoteConfigService.iosLatestVersion;
      final minVersion = isAndroid
          ? RemoteConfigService.androidMinVersion
          : RemoteConfigService.iosMinVersion;
      final forceUpdate = isAndroid
          ? RemoteConfigService.androidForceUpdate
          : RemoteConfigService.iosForceUpdate;
      final updateUrl = isAndroid
          ? RemoteConfigService.androidUpdateUrl
          : RemoteConfigService.iosUpdateUrl;
      final releaseNotes = isAndroid
          ? RemoteConfigService.androidReleaseNotes
          : RemoteConfigService.iosReleaseNotes;

      // Compare versions
      final currentVersion = request.currentVersion;
      final updateAvailable = _isVersionNewer(latestVersion, currentVersion);
      final isMandatory = forceUpdate || _isVersionNewer(minVersion, currentVersion);

      DebugLogger.info(
        'App update check: current=$currentVersion, latest=$latestVersion, '
        'min=$minVersion, updateAvailable=$updateAvailable, mandatory=$isMandatory',
      );

      return AppVersionCheckResponse(
        updateAvailable: updateAvailable,
        isMandatory: isMandatory,
        latestVersion: latestVersion,
        downloadUrl: updateUrl,
        releaseNotes: releaseNotes.isNotEmpty ? releaseNotes : null,
        minSupportedVersion: minVersion,
      );
    } catch (e, stackTrace) {
      DebugLogger.warning('Failed to check for app updates via Remote Config', e, stackTrace);
      // Return no update available on error to prevent blocking users
      return const AppVersionCheckResponse(updateAvailable: false, isMandatory: false);
    }
  }

  /// Test-only exposure of version comparison.
  @visibleForTesting
  bool isVersionNewerForTest(String newer, String older) => _isVersionNewer(newer, older);

  /// Compares two semantic version strings.
  /// Returns true if [newer] is a higher version than [older].
  ///
  /// Supports versions like "1.0.0", "1.2.3", "2.0.0+10"
  bool _isVersionNewer(String newer, String older) {
    try {
      // Strip build metadata (e.g., "1.0.0+10" -> "1.0.0")
      final cleanNewer = newer.split('+').first.trim();
      final cleanOlder = older.split('+').first.trim();

      final newerParts = cleanNewer.split('.').map((e) => int.tryParse(e) ?? 0).toList();
      final olderParts = cleanOlder.split('.').map((e) => int.tryParse(e) ?? 0).toList();

      // Pad to equal length
      while (newerParts.length < 3) {
        newerParts.add(0);
      }
      while (olderParts.length < 3) {
        olderParts.add(0);
      }

      // Compare major.minor.patch
      for (int i = 0; i < 3; i++) {
        if (newerParts[i] > olderParts[i]) return true;
        if (newerParts[i] < olderParts[i]) return false;
      }
      return false; // Versions are equal
    } catch (e) {
      DebugLogger.warning('Version comparison failed: $newer vs $older', e);
      return false;
    }
  }
}
