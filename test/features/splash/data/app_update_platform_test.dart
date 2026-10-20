import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:ghar360/features/splash/data/app_update_platform.dart';
import 'package:package_info_plus/package_info_plus.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  const channel = MethodChannel('de.ffuf.in_app_update/methods');
  final messenger = TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger;
  const platform = AppUpdatePlatform();
  late List<String> calls;
  late Map<String, Object?> info;
  String? errorAt;
  String? errorCode;
  setUp(() {
    calls = [];
    errorAt = null;
    errorCode = null;
    info = {
      'updateAvailability': 2,
      'immediateAllowed': true,
      'flexibleAllowed': true,
      'installStatus': 0,
      'packageName': 'com.ghar360',
      'updatePriority': 1,
    };
    messenger.setMockMethodCallHandler(channel, (call) async {
      calls.add(call.method);
      if (call.method == errorAt) throw PlatformException(code: errorCode ?? 'NOT_SUPPORTED');
      return call.method == 'checkForUpdate' ? info : null;
    });
  });
  tearDown(() => messenger.setMockMethodCallHandler(channel, null));
  test('mandatory flow uses immediate update', () async {
    expect(await platform.tryAndroidUpdate(true), NativeUpdateResult.handled);
    expect(calls, ['checkForUpdate', 'performImmediateUpdate']);
  });
  test('optional flow starts and completes flexible update', () async {
    expect(await platform.tryAndroidUpdate(false), NativeUpdateResult.handled);
    expect(calls, ['checkForUpdate', 'startFlexibleUpdate', 'completeFlexibleUpdate']);
  });
  test('mandatory falls back to flexible when immediate unavailable', () async {
    info['immediateAllowed'] = false;
    expect(await platform.tryAndroidUpdate(true), NativeUpdateResult.handled);
    expect(calls, ['checkForUpdate', 'startFlexibleUpdate', 'completeFlexibleUpdate']);
  });
  test('no Play Store update suppresses custom prompt', () async {
    info['updateAvailability'] = 1;
    expect(await platform.tryAndroidUpdate(true), NativeUpdateResult.notOnStore);
    expect(calls, ['checkForUpdate']);
  });
  test('unavailable flows and platform errors allow custom fallback', () async {
    info['immediateAllowed'] = false;
    info['flexibleAllowed'] = false;
    expect(await platform.tryAndroidUpdate(true), NativeUpdateResult.unsupported);
    errorAt = 'checkForUpdate';
    expect(await platform.tryAndroidUpdate(false), NativeUpdateResult.unsupported);
  });
  for (final mandatory in [true, false]) {
    test('native cancellation does not open a second prompt for mandatory=$mandatory', () async {
      errorAt = mandatory ? 'performImmediateUpdate' : 'startFlexibleUpdate';
      errorCode = 'USER_DENIED_UPDATE';
      expect(await platform.tryAndroidUpdate(mandatory), NativeUpdateResult.handled);
      expect(calls, isNot(contains('completeFlexibleUpdate')));
    });
    test('native failed update permits fallback for mandatory=$mandatory', () async {
      errorAt = mandatory ? 'performImmediateUpdate' : 'startFlexibleUpdate';
      errorCode = 'IN_APP_UPDATE_FAILED';
      expect(await platform.tryAndroidUpdate(mandatory), NativeUpdateResult.unsupported);
      expect(calls, isNot(contains('completeFlexibleUpdate')));
    });
  }
  test('package version parses integer and missing build metadata', () async {
    for (final build in ['42', '']) {
      PackageInfo.setMockInitialValues(
        appName: '360Ghar',
        packageName: 'com.ghar360',
        version: '1.2.3',
        buildNumber: build,
        buildSignature: '',
      );
      final version = await platform.versionInfo();
      expect(version.version, '1.2.3');
      expect(version.buildNumber, build.isEmpty ? null : 42);
    }
  });
}
