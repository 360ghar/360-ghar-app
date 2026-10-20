import 'dart:async';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_riverpod/misc.dart';
import 'package:ghar360/core/controllers/app_update_controller.dart';
import 'package:ghar360/core/data/models/app_update_models.dart';
import 'package:ghar360/core/providers/app_database_provider.dart';
import 'package:ghar360/core/storage/app_database.dart';
import 'package:ghar360/features/splash/data/app_update_platform.dart';
import 'package:ghar360/features/splash/data/app_update_repository.dart';
import 'package:mocktail/mocktail.dart';

const updateAvailable = AppVersionCheckResponse(
  updateAvailable: true,
  isMandatory: false,
  latestVersion: '2.0.0',
  downloadUrl: 'https://store.test/update',
);

class UpdateTestDatabase extends Fake implements AppDatabase {
  final values = <String, Object?>{};
  Object? writeError;
  Future<void> Function()? beforeWrite;
  int writes = 0;
  @override
  T? readPreference<T>(String key) => values[key] as T?;
  @override
  Future<void> writePreference(String key, Object? value) async {
    writes++;
    await beforeWrite?.call();
    if (writeError != null) throw writeError!;
    values[key] = value;
  }
}

class UpdateTestRepository extends Fake implements AppUpdateRepository {
  final requests = <AppVersionCheckRequest>[];
  Future<AppVersionCheckResponse> Function() response = () async =>
      const AppVersionCheckResponse(updateAvailable: false, isMandatory: false);
  @override
  Future<AppVersionCheckResponse> checkForUpdates(AppVersionCheckRequest request) {
    requests.add(request);
    return response();
  }
}

class UpdateTestPlatform extends AppUpdatePlatform {
  @override
  String platform = 'ios';
  int versionCalls = 0;
  int nativeCalls = 0;
  final opened = <Uri>[];
  bool? lastMandatory;
  Future<AppVersionInfo> Function() version = () async =>
      const AppVersionInfo(version: '1.2.3', buildNumber: 42);
  Future<NativeUpdateResult> Function() native = () async => NativeUpdateResult.unsupported;
  Future<bool> Function() launch = () async => true;
  @override
  Future<AppVersionInfo> versionInfo() {
    versionCalls++;
    return version();
  }

  @override
  Future<NativeUpdateResult> tryAndroidUpdate(bool mandatory) {
    nativeCalls++;
    lastMandatory = mandatory;
    return native();
  }

  @override
  Future<bool> openStore(Uri uri) {
    opened.add(uri);
    return launch();
  }
}

class UpdateTestHarness {
  UpdateTestHarness() {
    overrides = [
      appUpdateRepositoryProvider.overrideWithValue(repository),
      appUpdatePlatformProvider.overrideWithValue(platform),
      appDatabaseProvider.overrideWithValue(database),
      appUpdateClockProvider.overrideWithValue(() => now),
    ];
    container = ProviderContainer(overrides: overrides, retry: (_, _) => null);
  }
  final repository = UpdateTestRepository();
  final platform = UpdateTestPlatform();
  final database = UpdateTestDatabase();
  var now = DateTime(2026);
  late final List<Override> overrides;
  late final ProviderContainer container;
  AppUpdateController get controller => container.read(appUpdateProvider.notifier);
  AppUpdateState get state => container.read(appUpdateProvider);
  void dispose() => container.dispose();
}
