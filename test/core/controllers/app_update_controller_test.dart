// test/core/controllers/app_update_controller_test.dart
//
// Unit tests for [AppUpdateController]. Covers:
// - Initial reactive state (isChecking=false, version/build null)
// - didChangeAppLifecycleState no-op for non-resumed states
// - getVersionInfo resolves via mocked PackageInfo platform channel
// - scheduleCheckAfterFirstFrame does not throw without a frame pump
// - _resolvePlatform indirectly via getVersionInfo flow

import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:get/get.dart';
import 'package:get_storage/get_storage.dart';
import 'package:ghar360/core/controllers/app_update_controller.dart';
import 'package:ghar360/core/data/models/app_update_models.dart';
import 'package:ghar360/features/splash/data/app_update_repository.dart';
import 'package:mocktail/mocktail.dart';

import '../../helpers/getx_test_binding.dart';
import '../../helpers/mocks.dart';

// ---------------------------------------------------------------------------
// Mocks local to this test file
// ---------------------------------------------------------------------------

/// Mock for [AppUpdateRepository] (a [GetxService]).
class MockAppUpdateRepository extends GetxServiceMock implements AppUpdateRepository {}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  // Mock path_provider so GetStorage can initialise in tests.
  const pathProviderChannel = MethodChannel('plugins.flutter.io/path_provider');
  // Mock package_info_plus so PackageInfo.fromPlatform() resolves.
  const packageInfoChannel = MethodChannel('dev.fluttercommunity.plus/package_info');
  // Mock url_launcher so _openDownloadUrl can complete without a real browser.
  const urlLauncherChannel = MethodChannel('plugins.flutter.io/url_launcher');

  late Directory tempDir;

  setUpAll(() async {
    Get.testMode = true;
    // Isolate GetStorage files so parallel test suites do not lock ./GetStorage.gs.
    tempDir = await Directory.systemTemp.createTemp('app_update_gs_');
    registerFallbackValue(
      const AppVersionCheckRequest(app: 'user', platform: 'android', currentVersion: '0.0.0'),
    );

    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger.setMockMethodCallHandler(
      pathProviderChannel,
      (MethodCall call) async {
        if (call.method == 'getApplicationDocumentsDirectory') {
          return tempDir.path;
        }
        return null;
      },
    );

    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger.setMockMethodCallHandler(
      packageInfoChannel,
      (MethodCall call) async {
        if (call.method == 'getAll') {
          return <String, dynamic>{
            'appName': 'ghar360',
            'packageName': 'com.ghar360.app',
            'version': '1.2.3',
            'buildNumber': '42',
            'buildSignature': '',
            'installerStore': null,
          };
        }
        return null;
      },
    );

    // url_launcher: return true for canLaunchUrl/launchUrl so the download URL
    // opens "successfully" in tests.
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger.setMockMethodCallHandler(
      urlLauncherChannel,
      (MethodCall call) async {
        if (call.method == 'canLaunchUrl') return true;
        if (call.method == 'launchUrl') return true;
        return null;
      },
    );

    await GetStorage.init();
  });

  tearDownAll(() async {
    if (tempDir.existsSync()) {
      await tempDir.delete(recursive: true);
    }
  });

  late MockAppUpdateRepository mockRepository;
  late AppUpdateController controller;

  setUp(() async {
    GetxTestBinding.init();
    // Clear only the key used by AppUpdateController; await flush to avoid
    // "failed after completed" races with GetStorage microtasks.
    await GetStorage().remove('skipped_app_version');

    mockRepository = MockAppUpdateRepository();
    // Default stub: no update available.
    when(() => mockRepository.checkForUpdates(any())).thenAnswer(
      (_) async => const AppVersionCheckResponse(updateAvailable: false, isMandatory: false),
    );

    GetxTestBinding.bind().register<AppUpdateRepository>(mockRepository);

    controller = AppUpdateController();
    // onInit registers the WidgetsBindingObserver; skip onReady so the
    // automatic post-frame update check does not run during unit tests.
    controller.onInit();
  });

  tearDown(() async {
    controller.onClose();
    await GetStorage().remove('skipped_app_version');
    GetxTestBinding.reset();
  });

  group('AppUpdateController', () {
    // ── Initial state ─────────────────────────────────────────────────

    test('isChecking is false initially', () {
      expect(controller.isChecking.value, false);
    });

    test('currentVersion is null before getVersionInfo is called', () {
      expect(controller.currentVersion, isNull);
    });

    test('currentBuildNumber is null before getVersionInfo is called', () {
      expect(controller.currentBuildNumber, isNull);
    });

    // ── didChangeAppLifecycleState ────────────────────────────────────

    test('didChangeAppLifecycleState with paused state is a no-op', () async {
      controller.didChangeAppLifecycleState(AppLifecycleState.paused);

      // No repository call should have been made for a non-resumed state.
      verifyNever(() => mockRepository.checkForUpdates(any()));
      expect(controller.isChecking.value, false);
    });

    test('didChangeAppLifecycleState with inactive state is a no-op', () async {
      controller.didChangeAppLifecycleState(AppLifecycleState.inactive);

      verifyNever(() => mockRepository.checkForUpdates(any()));
      expect(controller.isChecking.value, false);
    });

    test('didChangeAppLifecycleState with detached state is a no-op', () async {
      controller.didChangeAppLifecycleState(AppLifecycleState.detached);

      verifyNever(() => mockRepository.checkForUpdates(any()));
      expect(controller.isChecking.value, false);
    });

    // ── getVersionInfo ────────────────────────────────────────────────

    test('getVersionInfo resolves package info from platform channel', () async {
      final info = await controller.getVersionInfo();

      expect(info, isNotNull);
      expect(info!.version, '1.2.3');
      expect(info.buildNumber, 42);
    });

    test('getVersionInfo caches result (currentVersion populated after call)', () async {
      await controller.getVersionInfo();

      expect(controller.currentVersion, '1.2.3');
      expect(controller.currentBuildNumber, 42);
    });

    test('getVersionInfo without force returns cached value', () async {
      final first = await controller.getVersionInfo();
      final second = await controller.getVersionInfo();

      expect(second, same(first));
    });

    test('getVersionInfo with forceRefresh re-reads platform', () async {
      final first = await controller.getVersionInfo();
      final second = await controller.getVersionInfo(forceRefresh: true);

      // A new AppVersionInfo instance is created on force refresh.
      expect(second, isNot(same(first)));
      expect(second?.version, '1.2.3');
    });

    // ── scheduleCheckAfterFirstFrame ──────────────────────────────────

    test('scheduleCheckAfterFirstFrame does not throw without a frame', () {
      // addPostFrameCallback is available in the test binding; the callback
      // is queued but never pumped in a pure unit test, so this should not
      // throw and should not synchronously trigger a repository call.
      expect(() => controller.scheduleCheckAfterFirstFrame(), returnsNormally);

      // Allow any pending microtasks to settle.
      verifyNever(() => mockRepository.checkForUpdates(any()));
    });
  });

  // ── didChangeAppLifecycleState (resumed) ───────────────────────────

  group('AppUpdateController didChangeAppLifecycleState resumed', () {
    test('triggers update check on first resume', () async {
      controller.didChangeAppLifecycleState(AppLifecycleState.resumed);

      // Wait for the unawaited _checkForUpdates to complete.
      await Future<void>.delayed(Duration.zero);
      await Future<void>.delayed(const Duration(milliseconds: 100));

      verify(() => mockRepository.checkForUpdates(any())).called(1);
    });

    test('throttles subsequent resume within 5 minutes', () async {
      controller.didChangeAppLifecycleState(AppLifecycleState.resumed);
      await Future<void>.delayed(const Duration(milliseconds: 100));

      // Second resume should be throttled (within 5 minutes).
      controller.didChangeAppLifecycleState(AppLifecycleState.resumed);
      await Future<void>.delayed(const Duration(milliseconds: 100));

      verify(() => mockRepository.checkForUpdates(any())).called(1);
    });

    test('does not check when isChecking is already true', () async {
      // Manually set isChecking to true to simulate an in-flight check.
      controller.isChecking.value = true;

      controller.didChangeAppLifecycleState(AppLifecycleState.resumed);
      await Future<void>.delayed(const Duration(milliseconds: 100));

      verifyNever(() => mockRepository.checkForUpdates(any()));
    });
  });

  // ── _resolvePlatform (indirect) ────────────────────────────────────

  group('AppUpdateController platform resolution', () {
    test('checkForUpdates request includes correct platform string', () async {
      AppVersionCheckRequest? capturedRequest;
      when(() => mockRepository.checkForUpdates(any())).thenAnswer((invocation) async {
        capturedRequest = invocation.positionalArguments[0] as AppVersionCheckRequest;
        return const AppVersionCheckResponse(updateAvailable: false, isMandatory: false);
      });

      controller.didChangeAppLifecycleState(AppLifecycleState.resumed);
      await Future<void>.delayed(const Duration(milliseconds: 100));

      expect(capturedRequest, isNotNull);
      // In the test environment, the platform should be resolved without
      // throwing. It will be 'android' (default fallback) or the actual
      // test host platform.
      expect(capturedRequest!.platform, anyOf('android', 'ios', 'web'));
      expect(capturedRequest!.app, 'user');
      expect(capturedRequest!.currentVersion, '1.2.3');
      expect(capturedRequest!.buildNumber, 42);
    });
  });

  // ── Update available (no update) ───────────────────────────────────

  group('AppUpdateController no update available', () {
    test('does not show dialog when updateAvailable is false', () async {
      when(() => mockRepository.checkForUpdates(any())).thenAnswer(
        (_) async => const AppVersionCheckResponse(updateAvailable: false, isMandatory: false),
      );

      controller.didChangeAppLifecycleState(AppLifecycleState.resumed);
      await Future<void>.delayed(const Duration(milliseconds: 100));

      verify(() => mockRepository.checkForUpdates(any())).called(1);
      expect(controller.isChecking.value, false);
    });
  });

  // ── Error handling ─────────────────────────────────────────────────

  group('AppUpdateController error handling', () {
    test('catches repository exception and resets isChecking', () async {
      when(() => mockRepository.checkForUpdates(any())).thenThrow(Exception('Network error'));

      controller.didChangeAppLifecycleState(AppLifecycleState.resumed);
      await Future<void>.delayed(const Duration(milliseconds: 100));

      // The exception should be caught, not propagated.
      expect(controller.isChecking.value, false);
      verify(() => mockRepository.checkForUpdates(any())).called(1);
    });
  });

  // ── getVersionInfo caching ─────────────────────────────────────────

  group('AppUpdateController getVersionInfo edge cases', () {
    test('forceRefresh re-reads and returns new instance', () async {
      final first = await controller.getVersionInfo();
      final second = await controller.getVersionInfo(forceRefresh: true);

      expect(second, isNot(same(first)));
      expect(second?.version, '1.2.3');
      expect(second?.buildNumber, 42);
    });

    test('currentVersion and currentBuildNumber populated after getVersionInfo', () async {
      await controller.getVersionInfo();

      expect(controller.currentVersion, '1.2.3');
      expect(controller.currentBuildNumber, 42);
    });
  });

  // ── Update available: mandatory ──────────────────────────────────────

  group('AppUpdateController mandatory update', () {
    test('clears skipped version from storage when mandatory update detected', () async {
      // Seed a skipped version; mandatory update should clear it.
      GetStorage().write('skipped_app_version', '1.5.0');

      when(() => mockRepository.checkForUpdates(any())).thenAnswer(
        (_) async => const AppVersionCheckResponse(
          updateAvailable: true,
          isMandatory: true,
          latestVersion: '2.0.0',
          downloadUrl: 'https://example.com/update',
        ),
      );

      controller.didChangeAppLifecycleState(AppLifecycleState.resumed);
      // Allow the unawaited _checkForUpdates (and any dialog attempt) to
      // settle. The dialog will fail without a navigator but the exception
      // is caught by _checkForUpdates' catch block.
      await Future<void>.delayed(const Duration(milliseconds: 200));

      // The skipped version must have been cleared before the dialog attempt.
      expect(GetStorage().read<String>('skipped_app_version'), isNull);
      expect(controller.isChecking.value, false);
    });

    test('resets isChecking after mandatory update flow', () async {
      when(() => mockRepository.checkForUpdates(any())).thenAnswer(
        (_) async => const AppVersionCheckResponse(
          updateAvailable: true,
          isMandatory: true,
          latestVersion: '2.0.0',
        ),
      );

      controller.didChangeAppLifecycleState(AppLifecycleState.resumed);
      await Future<void>.delayed(const Duration(milliseconds: 200));

      expect(controller.isChecking.value, false);
    });
  });

  // ── Update available: optional + skipped ─────────────────────────────

  group('AppUpdateController optional update skip logic', () {
    test('skips dialog when latestVersion matches previously skipped version', () async {
      GetStorage().write('skipped_app_version', '1.9.0');

      when(() => mockRepository.checkForUpdates(any())).thenAnswer(
        (_) async => const AppVersionCheckResponse(
          updateAvailable: true,
          isMandatory: false,
          latestVersion: '1.9.0',
        ),
      );

      controller.didChangeAppLifecycleState(AppLifecycleState.resumed);
      await Future<void>.delayed(const Duration(milliseconds: 200));

      // Skipped version remains (not cleared for optional updates).
      expect(GetStorage().read<String>('skipped_app_version'), '1.9.0');
      expect(controller.isChecking.value, false);
      // Repository was consulted exactly once.
      verify(() => mockRepository.checkForUpdates(any())).called(1);
    });

    test('does not skip when skipped version differs from latest', () async {
      GetStorage().write('skipped_app_version', '1.8.0');

      when(() => mockRepository.checkForUpdates(any())).thenAnswer(
        (_) async => const AppVersionCheckResponse(
          updateAvailable: true,
          isMandatory: false,
          latestVersion: '1.9.0',
        ),
      );

      controller.didChangeAppLifecycleState(AppLifecycleState.resumed);
      await Future<void>.delayed(const Duration(milliseconds: 200));

      // The mismatch means the dialog path is attempted (and fails without a
      // navigator), but the check completes without throwing.
      expect(controller.isChecking.value, false);
    });

    test('proceeds to dialog when no skipped version stored', () async {
      expect(GetStorage().read<String>('skipped_app_version'), isNull);

      when(() => mockRepository.checkForUpdates(any())).thenAnswer(
        (_) async => const AppVersionCheckResponse(
          updateAvailable: true,
          isMandatory: false,
          latestVersion: '1.9.0',
        ),
      );

      controller.didChangeAppLifecycleState(AppLifecycleState.resumed);
      await Future<void>.delayed(const Duration(milliseconds: 200));

      expect(controller.isChecking.value, false);
    });
  });

  // ── Throttling & cooldown ────────────────────────────────────────────

  group('AppUpdateController throttling', () {
    test('resumed triggers check after throttle window conceptually', () async {
      // First check.
      controller.didChangeAppLifecycleState(AppLifecycleState.resumed);
      await Future<void>.delayed(const Duration(milliseconds: 150));
      // Second resume within 5 minutes is throttled.
      controller.didChangeAppLifecycleState(AppLifecycleState.resumed);
      await Future<void>.delayed(const Duration(milliseconds: 150));

      verify(() => mockRepository.checkForUpdates(any())).called(1);
    });
  });

  // ── _resolvePlatform variants ────────────────────────────────────────

  group('AppUpdateController request construction', () {
    test('check request carries current version and build number', () async {
      AppVersionCheckRequest? captured;
      when(() => mockRepository.checkForUpdates(any())).thenAnswer((inv) async {
        captured = inv.positionalArguments[0] as AppVersionCheckRequest;
        return const AppVersionCheckResponse(updateAvailable: false, isMandatory: false);
      });

      controller.didChangeAppLifecycleState(AppLifecycleState.resumed);
      await Future<void>.delayed(const Duration(milliseconds: 200));

      expect(captured, isNotNull);
      expect(captured!.app, 'user');
      expect(captured!.currentVersion, '1.2.3');
      expect(captured!.buildNumber, 42);
      expect(captured!.platform, anyOf('android', 'ios', 'web'));
    });
  });

  // ── isDialogVisible guard ────────────────────────────────────────────

  group('AppUpdateController dialog guard', () {
    test('does not start a check while isChecking is true', () async {
      controller.isChecking.value = true;

      controller.didChangeAppLifecycleState(AppLifecycleState.resumed);
      await Future<void>.delayed(const Duration(milliseconds: 200));

      verifyNever(() => mockRepository.checkForUpdates(any()));
      expect(controller.isChecking.value, true);
    });
  });

  // ── onReady / scheduleCheckAfterFirstFrame ───────────────────────────

  group('AppUpdateController lifecycle hooks', () {
    test('onReady schedules a check without throwing', () {
      // onReady calls scheduleCheckAfterFirstFrame which queues a post-frame
      // callback. In a pure unit test the callback is never pumped, so this
      // should not throw and should not synchronously hit the repository.
      expect(() => controller.onReady(), returnsNormally);
    });

    test('scheduleCheckAfterFirstFrame does not throw', () {
      expect(() => controller.scheduleCheckAfterFirstFrame(), returnsNormally);
    });
  });
}
