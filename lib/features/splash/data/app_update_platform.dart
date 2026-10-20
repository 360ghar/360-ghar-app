import 'package:flutter/foundation.dart';

import 'package:in_app_update/in_app_update.dart';
import 'package:package_info_plus/package_info_plus.dart';
import 'package:url_launcher/url_launcher.dart';

import 'package:ghar360/core/data/models/app_update_models.dart';
import 'package:ghar360/core/utils/debug_logger.dart';

enum NativeUpdateResult { handled, notOnStore, unsupported }

/// The native plugin boundary. State and dialogs are owned by the provider/UI.
class AppUpdatePlatform {
  const AppUpdatePlatform();
  String get platform => kIsWeb
      ? 'web'
      : switch (defaultTargetPlatform) {
          TargetPlatform.android => 'android',
          TargetPlatform.iOS => 'ios',
          _ => 'unsupported',
        };
  Future<AppVersionInfo> versionInfo() async {
    final package = await PackageInfo.fromPlatform();
    return AppVersionInfo(version: package.version, buildNumber: int.tryParse(package.buildNumber));
  }

  Future<bool> openStore(Uri uri) => launchUrl(uri, mode: LaunchMode.externalApplication);
  Future<NativeUpdateResult> tryAndroidUpdate(bool mandatory) async {
    try {
      final info = await InAppUpdate.checkForUpdate();
      if (info.updateAvailability != UpdateAvailability.updateAvailable) {
        return NativeUpdateResult.notOnStore;
      }
      if (mandatory && info.immediateUpdateAllowed) {
        final result = await InAppUpdate.performImmediateUpdate();
        return result != AppUpdateResult.inAppUpdateFailed
            ? NativeUpdateResult.handled
            : NativeUpdateResult.unsupported;
      }
      if (info.flexibleUpdateAllowed) {
        final result = await InAppUpdate.startFlexibleUpdate();
        if (result == AppUpdateResult.userDeniedUpdate) return NativeUpdateResult.handled;
        if (result != AppUpdateResult.success) return NativeUpdateResult.unsupported;
        await InAppUpdate.completeFlexibleUpdate();
        return NativeUpdateResult.handled;
      }
      return NativeUpdateResult.unsupported;
    } catch (error, stack) {
      DebugLogger.warning('Native app update unavailable', error.runtimeType, stack);
      return NativeUpdateResult.unsupported;
    }
  }
}
