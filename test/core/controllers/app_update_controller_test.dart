import 'dart:async';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:ghar360/core/controllers/app_update_controller.dart';
import 'package:ghar360/core/data/models/app_update_models.dart';
import 'package:ghar360/core/data/models/wire_enums.dart';
import 'package:ghar360/core/storage/app_database.dart';
import 'package:ghar360/core/utils/app_exceptions.dart';
import 'package:ghar360/features/splash/data/app_update_platform.dart';

import '../../helpers/app_update_test_harness.dart';

void main() {
  late UpdateTestHarness harness;
  setUp(() => harness = UpdateTestHarness());
  tearDown(() => harness.dispose());
  group('isVersionGreater', () {
    test('compares numerically and pads with zeros', () {
      expect(isVersionGreater('1.0.10', '1.0.9'), isTrue);
      expect(isVersionGreater('1.0.9', '1.0.9'), isFalse);
      expect(isVersionGreater('1.0.0', '1.0.9'), isFalse);
      expect(isVersionGreater('1.0', '1.0.0'), isFalse);
      expect(isVersionGreater('2.0.0+5', '1.9.9'), isTrue);
    });
    test('null or unparseable is false', () {
      expect(isVersionGreater(null, '1.0.0'), isFalse);
      expect(isVersionGreater('garbage', '1.0.0'), isFalse);
      expect(isVersionGreater('2.0.0', 'garbage'), isFalse);
    });
  });
  group('stale server response guard', () {
    const stale = AppVersionCheckResponse(
      updateAvailable: true,
      isMandatory: false,
      latestVersion: '1.0.0',
      downloadUrl: 'https://store.test/dead',
    );
    test('app review rejection: older latest_version never prompts', () async {
      harness.platform.version = () async =>
          const AppVersionInfo(version: '1.1.0', buildNumber: 18);
      harness.repository.response = () async => stale;
      await harness.controller.checkForUpdates();
      expect(harness.state.prompt, isNull);
      expect(harness.state.check.isLoading, isFalse);
      expect(harness.database.writes, 0);
    });
    test('mandatory with an older minimum and latest never prompts', () async {
      harness.repository.response = () async =>
          stale.copyWith(isMandatory: true, minSupportedVersion: '1.0.0');
      await harness.controller.checkForUpdates();
      expect(harness.state.prompt, isNull);
    });
    test('min supported above installed prompts even with a stale latest', () async {
      harness.repository.response = () async =>
          stale.copyWith(isMandatory: true, minSupportedVersion: '9.9.9');
      await harness.controller.checkForUpdates();
      expect(harness.state.prompt?.isMandatory, isTrue);
    });
  });
  test('initial state is idle with no cached version or prompt', () {
    expect(harness.state.check.isLoading, isFalse);
    expect(harness.state.action.isLoading, isFalse);
    expect(harness.state.prompt, isNull);
    expect(harness.controller.currentVersion, isNull);
    expect(harness.controller.currentBuildNumber, isNull);
  });
  test('getVersionInfo loads version/build, caches, coalesces, and force refreshes', () async {
    final results = await Future.wait([
      harness.controller.getVersionInfo(),
      harness.controller.getVersionInfo(),
    ]);
    expect(results.first?.version, '1.2.3');
    expect(results.last?.buildNumber, 42);
    expect(harness.controller.currentVersion, '1.2.3');
    expect(harness.controller.currentBuildNumber, 42);
    await harness.controller.getVersionInfo();
    expect(harness.platform.versionCalls, 1);
    harness.platform.version = () async => const AppVersionInfo(version: '1.2.4', buildNumber: 43);
    expect((await harness.controller.getVersionInfo(forceRefresh: true))?.buildNumber, 43);
    expect(harness.platform.versionCalls, 2);
  });
  test('version failure is recoverable and retains previous cached version', () async {
    harness.platform.version = () async => throw StateError('package failure');
    await harness.controller.checkForUpdates();
    expect(harness.state.check.hasError, isTrue);
    expect(harness.state.check.isLoading, isFalse);
    expect(harness.repository.requests, isEmpty);
    harness.platform.version = () async => const AppVersionInfo(version: '1');
    await harness.controller.checkForUpdates(force: true);
    harness.platform.version = () async => throw StateError('package failure');
    expect((await harness.controller.getVersionInfo(forceRefresh: true))?.version, '1');
  });
  test('checks carry package version and build with iOS/Android platform', () async {
    for (final platform in ['ios', 'android']) {
      harness.platform.platform = platform;
      await harness.controller.checkForUpdates(force: true);
      final request = harness.repository.requests.last;
      expect(request.platform.wire, platform);
      expect(request.currentVersion, '1.2.3');
      expect(request.buildNumber, 42);
      expect(request.app, AppKey.ghar);
    }
  });
  test('web and unsupported desktop skip native update checks', () async {
    for (final platform in ['web', 'unsupported']) {
      harness.platform.platform = platform;
      await harness.controller.checkForUpdates();
      expect(harness.repository.requests, isEmpty);
      expect(harness.platform.versionCalls, 0);
    }
  });
  test('first check runs, five-minute throttle expires, force bypasses throttle', () async {
    await harness.controller.checkForUpdates();
    await harness.controller.checkForUpdates();
    expect(harness.repository.requests, hasLength(1));
    harness.now = harness.now.add(const Duration(minutes: 5));
    await harness.controller.checkForUpdates();
    expect(harness.repository.requests, hasLength(2));
    await harness.controller.checkForUpdates(force: true);
    expect(harness.repository.requests, hasLength(3));
  });
  test('concurrent checks are suppressed even during package loading', () async {
    final package = Completer<AppVersionInfo>();
    harness.platform.version = () => package.future;
    final check = harness.controller.checkForUpdates();
    await harness.controller.checkForUpdates(force: true);
    expect(harness.platform.versionCalls, 1);
    expect(harness.state.check.isLoading, isTrue);
    package.complete(const AppVersionInfo(version: '1'));
    await check;
    expect(harness.repository.requests, hasLength(1));
    expect(harness.state.check.isLoading, isFalse);
  });
  test(
    'repository error remains distinct from no update and is throttled until explicit retry',
    () async {
      harness.repository.response = () async => throw NetworkException('offline');
      await harness.controller.checkForUpdates();
      expect(harness.state.check.error, isA<NetworkException>());
      expect(harness.state.prompt, isNull);
      await harness.controller.checkForUpdates();
      expect(harness.repository.requests, hasLength(1));
      harness.repository.response = () async => updateAvailable;
      await harness.controller.checkForUpdates(force: true);
      expect(harness.state.check.hasError, isFalse);
      expect(harness.state.prompt, updateAvailable);
      await harness.controller.checkForUpdates(force: true);
      expect(harness.repository.requests, hasLength(2));
    },
  );
  test('skipped optional version suppresses same version but not a newer one', () async {
    harness.database.values[AppUpdateController.skippedVersionKey] = '2.0.0';
    harness.repository.response = () async => updateAvailable;
    await harness.controller.checkForUpdates();
    expect(harness.state.prompt, isNull);
    harness.repository.response = () async => updateAvailable.copyWith(latestVersion: '2.1.0');
    await harness.controller.checkForUpdates(force: true);
    expect(harness.state.prompt?.latestVersion, '2.1.0');
  });
  test('mandatory update clears skipped version and cannot be dismissed', () async {
    harness.database.values[AppUpdateController.skippedVersionKey] = '2.0.0';
    harness.repository.response = () async => updateAvailable.copyWith(isMandatory: true);
    await harness.controller.checkForUpdates();
    expect(harness.database.values[AppUpdateController.skippedVersionKey], isNull);
    expect(harness.state.prompt?.isMandatory, isTrue);
    expect(await harness.controller.act(AppUpdateAction.remindLater), isFalse);
    expect(harness.state.prompt, isNotNull);
  });
  test('mandatory update still prompts if clearing skipped preference fails', () async {
    harness.database.writeError = StorageFailure('full');
    harness.repository.response = () async => updateAvailable.copyWith(isMandatory: true);
    await harness.controller.checkForUpdates();
    expect(harness.state.prompt?.isMandatory, isTrue);
    expect(harness.state.actionErrorKey, 'app_update_save_failed');
  });
  test('optional skip commits before prompt clears and duplicate actions are blocked', () async {
    harness.repository.response = () async => updateAvailable;
    await harness.controller.checkForUpdates();
    final write = Completer<void>();
    harness.database.beforeWrite = () => write.future;
    final action = harness.controller.act(AppUpdateAction.remindLater);
    expect(harness.state.action.isLoading, isTrue);
    expect(harness.state.prompt, isNotNull);
    expect(await harness.controller.act(AppUpdateAction.remindLater), isFalse);
    write.complete();
    expect(await action, isTrue);
    expect(harness.database.values[AppUpdateController.skippedVersionKey], '2.0.0');
    expect(harness.database.writes, 1);
    expect(harness.state.prompt, isNull);
  });
  test('skip write failure retains prompt with retry', () async {
    harness.repository.response = () async => updateAvailable;
    await harness.controller.checkForUpdates();
    harness.database.writeError = StorageFailure('full');
    expect(await harness.controller.act(AppUpdateAction.remindLater), isFalse);
    expect(harness.state.action.error, isA<StorageFailure>());
    expect(harness.state.prompt, isNotNull);
    harness.database.writeError = null;
    expect(await harness.controller.act(AppUpdateAction.remindLater), isTrue);
    expect(harness.state.action.hasError, isFalse);
  });
  test(
    'store failure retains prompt, successful retry opens URL and imposes 30-minute cooldown',
    () async {
      harness.repository.response = () async => updateAvailable;
      await harness.controller.checkForUpdates();
      harness.platform.launch = () async => false;
      expect(await harness.controller.act(AppUpdateAction.update), isFalse);
      expect(harness.state.actionErrorKey, 'app_update_open_failed');
      expect(harness.state.prompt, isNotNull);
      harness.platform.launch = () async => true;
      expect(await harness.controller.act(AppUpdateAction.update), isTrue);
      expect(harness.platform.opened.last.toString(), 'https://store.test/update');
      harness.now = harness.now.add(const Duration(minutes: 6));
      await harness.controller.checkForUpdates();
      expect(harness.repository.requests, hasLength(1));
      harness.now = harness.now.add(const Duration(minutes: 24));
      await harness.controller.checkForUpdates();
      expect(harness.repository.requests, hasLength(2));
    },
  );
  for (final url in ['', 'not a URL', 'javascript:alert(1)']) {
    test('invalid store URL $url stays recoverable without launching', () async {
      harness.repository.response = () async => updateAvailable.copyWith(downloadUrl: url);
      await harness.controller.checkForUpdates();
      expect(await harness.controller.act(AppUpdateAction.update), isFalse);
      expect(harness.platform.opened, isEmpty);
      expect(harness.state.prompt, isNotNull);
    });
  }
  for (final result in NativeUpdateResult.values) {
    test('native Android result $result controls custom prompt fallback', () async {
      harness.platform.platform = 'android';
      harness.platform.native = () async => result;
      harness.repository.response = () async => updateAvailable.copyWith(isMandatory: true);
      await harness.controller.checkForUpdates();
      expect(harness.platform.nativeCalls, 1);
      expect(harness.platform.lastMandatory, isTrue);
      expect(harness.state.check.isLoading, isFalse);
      expect(harness.state.prompt != null, result == NativeUpdateResult.unsupported);
    });
  }
  test('disposed provider rejects old check and never publishes a prompt', () async {
    final pending = Completer<AppVersionCheckResponse>();
    harness.repository.response = () => pending.future;
    final work = harness.controller.checkForUpdates();
    await Future<void>.delayed(Duration.zero);
    harness.dispose();
    pending.complete(updateAvailable);
    await work;
    expect(harness.platform.opened, isEmpty);
    expect(harness.database.writes, 0);
  });
  testWidgets('package and store plugin hangs expose bounded recovery', (tester) async {
    harness.platform.version = () => Completer<AppVersionInfo>().future;
    final check = harness.controller.checkForUpdates();
    await tester.pump(const Duration(seconds: 10));
    await check;
    expect(harness.state.check.error, isA<TimeoutException>());
    harness.platform.version = () async => const AppVersionInfo(version: '1');
    harness.repository.response = () async => updateAvailable;
    await harness.controller.checkForUpdates(force: true);
    harness.platform.launch = () => Completer<bool>().future;
    final action = harness.controller.act(AppUpdateAction.update);
    await tester.pump(const Duration(seconds: 10));
    expect(await action, isFalse);
    expect(harness.state.action.error, isA<TimeoutException>());
    expect(harness.state.prompt, isNotNull);
  });
}
