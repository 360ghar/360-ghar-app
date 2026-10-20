import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:ghar360/core/bootstrap/provider_policy.dart';
import 'package:ghar360/core/data/models/app_update_models.dart';
import 'package:ghar360/core/data/models/wire_enums.dart';
import 'package:ghar360/core/providers/app_database_provider.dart';
import 'package:ghar360/core/providers/network_providers.dart';
import 'package:ghar360/core/utils/app_exceptions.dart';
import 'package:ghar360/core/utils/debug_logger.dart';
import 'package:ghar360/features/splash/data/app_update_platform.dart';
import 'package:ghar360/features/splash/data/app_update_repository.dart';

enum AppUpdateAction { update, remindLater }

final appUpdateRepositoryProvider = Provider<AppUpdateRepository>(
  (ref) => AppUpdateRepository(apiClient: ref.watch(apiClientProvider)),
  retry: noProviderRetry,
);
final appUpdatePlatformProvider = Provider<AppUpdatePlatform>(
  (ref) => const AppUpdatePlatform(),
  retry: noProviderRetry,
);
final appUpdateClockProvider = Provider<DateTime Function()>(
  (ref) => DateTime.now,
  retry: noProviderRetry,
);

class AppUpdateState {
  const AppUpdateState({
    this.version,
    this.prompt,
    this.check = const AsyncData(null),
    this.action = const AsyncData(null),
    this.actionErrorKey,
  });
  final AppVersionInfo? version;
  final AppVersionCheckResponse? prompt;
  final AsyncValue<void> check;
  final AsyncValue<void> action;
  final String? actionErrorKey;
  AppUpdateState copyWith({
    AppVersionInfo? version,
    AppVersionCheckResponse? prompt,
    bool clearPrompt = false,
    AsyncValue<void>? check,
    AsyncValue<void>? action,
    String? actionErrorKey,
  }) => AppUpdateState(
    version: version ?? this.version,
    prompt: clearPrompt ? null : prompt ?? this.prompt,
    check: check ?? this.check,
    action: action ?? this.action,
    actionErrorKey: actionErrorKey,
  );
}

final appUpdateProvider = NotifierProvider<AppUpdateController, AppUpdateState>(
  AppUpdateController.new,
  retry: noProviderRetry,
);

class AppUpdateController extends Notifier<AppUpdateState> {
  static const skippedVersionKey = 'skipped_app_version';
  static const _checkThrottle = Duration(minutes: 5);
  static const _postActionCooldown = Duration(minutes: 30);
  DateTime? _lastCheck;
  DateTime? _lastAction;
  int _generation = 0;
  Future<AppVersionInfo?>? _versionRequest;
  @override
  AppUpdateState build() {
    ref.watch(appDatabaseProvider);
    ref.watch(appUpdateRepositoryProvider);
    ref.watch(appUpdatePlatformProvider);
    ++_generation;
    _versionRequest = null;
    ref.onDispose(() => ++_generation);
    return const AppUpdateState();
  }

  Future<AppVersionInfo?> getVersionInfo({bool forceRefresh = false}) {
    if (!forceRefresh && state.version != null) return Future.value(state.version);
    if (_versionRequest != null) return _versionRequest!;
    final generation = _generation;
    final request = _loadVersion(generation);
    _versionRequest = request;
    request.then((_) {
      if (identical(_versionRequest, request)) _versionRequest = null;
    });
    return request;
  }

  Future<AppVersionInfo?> _loadVersion(int generation) async {
    try {
      final version = await ref
          .read(appUpdatePlatformProvider)
          .versionInfo()
          .timeout(const Duration(seconds: 10));
      if (!ref.mounted || generation != _generation) return null;
      state = state.copyWith(version: version);
      return version;
    } catch (error, stack) {
      if (ref.mounted && generation == _generation) {
        state = state.copyWith(check: AsyncError(error, stack));
        return state.version;
      }
      return null;
    }
  }

  String? get currentVersion => state.version?.version;
  int? get currentBuildNumber => state.version?.buildNumber;

  Future<void> checkForUpdates({bool force = false}) async {
    if (state.check.isLoading || state.action.isLoading || state.prompt != null) return;
    final platform = ref.read(appUpdatePlatformProvider);
    if (platform.platform != 'ios' && platform.platform != 'android') return;
    final now = ref.read(appUpdateClockProvider)();
    if (!force &&
        ((_lastCheck != null && now.difference(_lastCheck!) < _checkThrottle) ||
            (_lastAction != null && now.difference(_lastAction!) < _postActionCooldown))) {
      return;
    }
    final generation = _generation;
    _lastCheck = now;
    state = state.copyWith(check: const AsyncLoading());
    try {
      final version = await getVersionInfo();
      if (!ref.mounted || generation != _generation) return;
      if (version == null) return;
      final response = await ref
          .read(appUpdateRepositoryProvider)
          .checkForUpdates(
            AppVersionCheckRequest(
              app: AppKey.ghar,
              platform: platform.platform == 'ios' ? DevicePlatform.ios : DevicePlatform.android,
              currentVersion: version.version,
              buildNumber: version.buildNumber,
            ),
          );
      if (!ref.mounted || generation != _generation) return;
      if (!response.updateAvailable) {
        state = state.copyWith(check: const AsyncData(null));
        return;
      }
      final database = ref.read(appDatabaseProvider);
      Object? preferenceError;
      StackTrace? preferenceStack;
      if (response.isMandatory) {
        try {
          await database.writePreference(skippedVersionKey, null);
        } catch (error, stack) {
          preferenceError = error;
          preferenceStack = stack;
        }
      } else if (response.latestVersion != null &&
          database.readPreference<String>(skippedVersionKey) == response.latestVersion) {
        state = state.copyWith(check: const AsyncData(null));
        return;
      }
      if (!ref.mounted || generation != _generation) return;
      if (platform.platform == 'android') {
        final native = await platform.tryAndroidUpdate(response.isMandatory);
        if (!ref.mounted || generation != _generation) return;
        if (native != NativeUpdateResult.unsupported) {
          if (native == NativeUpdateResult.handled) {
            _lastAction = ref.read(appUpdateClockProvider)();
          }
          state = state.copyWith(check: const AsyncData(null));
          return;
        }
      }
      state = state.copyWith(
        prompt: response,
        check: const AsyncData(null),
        action: preferenceError == null
            ? const AsyncData(null)
            : AsyncError(preferenceError, preferenceStack!),
        actionErrorKey: preferenceError == null ? null : 'app_update_save_failed',
      );
    } catch (error, stack) {
      if (!ref.mounted || generation != _generation) return;
      DebugLogger.warning('App update check failed', error.runtimeType, stack);
      state = state.copyWith(check: AsyncError(error, stack));
    }
  }

  Future<bool> act(AppUpdateAction action) async {
    final prompt = state.prompt;
    if (prompt == null || state.action.isLoading) return false;
    if (action == AppUpdateAction.remindLater && prompt.isMandatory) return false;
    final generation = _generation;
    state = state.copyWith(action: const AsyncLoading());
    try {
      if (action == AppUpdateAction.remindLater) {
        if (prompt.latestVersion != null) {
          await ref
              .read(appDatabaseProvider)
              .writePreference(skippedVersionKey, prompt.latestVersion);
        }
      } else {
        final uri = Uri.tryParse(prompt.downloadUrl ?? '');
        if (uri == null ||
            !['https', 'http', 'market', 'itms-apps'].contains(uri.scheme) ||
            uri.host.isEmpty) {
          throw ValidationException('Update link unavailable');
        }
        if (!await ref
            .read(appUpdatePlatformProvider)
            .openStore(uri)
            .timeout(const Duration(seconds: 10))) {
          throw NetworkException('Store unavailable');
        }
      }
      if (!ref.mounted || generation != _generation) return false;
      _lastAction = ref.read(appUpdateClockProvider)();
      state = state.copyWith(clearPrompt: true, action: const AsyncData(null));
      return true;
    } catch (error, stack) {
      if (!ref.mounted || generation != _generation) return false;
      state = state.copyWith(
        action: AsyncError(error, stack),
        actionErrorKey: action == AppUpdateAction.update
            ? 'app_update_open_failed'
            : 'app_update_save_failed',
      );
      return false;
    }
  }
}
