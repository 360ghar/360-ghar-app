// test/features/splash/data/app_update_repository_test.dart
//
// Unit tests for [AppUpdateRepository]. When Firebase is not ready the
// repository must short-circuit without throwing.

import 'package:flutter_test/flutter_test.dart';

import 'package:ghar360/core/data/models/app_update_models.dart';
import 'package:ghar360/core/firebase/firebase_initializer.dart';
import 'package:ghar360/core/firebase/firebase_runtime_state.dart';
import 'package:ghar360/features/splash/data/app_update_repository.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  late AppUpdateRepository repository;

  setUp(() {
    repository = AppUpdateRepository();
  });

  group('AppUpdateRepository.checkForUpdates', () {
    test('returns no update when Firebase is not ready', () async {
      // Default test process: FirebaseRuntimeState is not ready.
      expect(FirebaseInitializer.isFirebaseReady, isFalse);
      expect(FirebaseRuntimeState.isReady, isFalse);

      final response = await repository.checkForUpdates(
        const AppVersionCheckRequest(app: 'user', platform: 'android', currentVersion: '1.0.0'),
      );

      expect(response.updateAvailable, isFalse);
      expect(response.isMandatory, isFalse);
      expect(response.latestVersion, isNull);
    });

    test('returns no update for iOS platform when Firebase is not ready', () async {
      final response = await repository.checkForUpdates(
        const AppVersionCheckRequest(
          app: 'user',
          platform: 'ios',
          currentVersion: '2.3.4',
          buildNumber: 99,
        ),
      );

      expect(response.updateAvailable, isFalse);
      expect(response.isMandatory, isFalse);
    });

    test('does not throw for empty current version when Firebase disabled', () async {
      final response = await repository.checkForUpdates(
        const AppVersionCheckRequest(app: 'user', platform: 'android', currentVersion: ''),
      );
      expect(response.updateAvailable, isFalse);
    });
  });

  group('AppUpdateRepository.isVersionNewerForTest', () {
    test('detects newer major/minor/patch', () {
      expect(repository.isVersionNewerForTest('2.0.0', '1.9.9'), isTrue);
      expect(repository.isVersionNewerForTest('1.2.0', '1.1.9'), isTrue);
      expect(repository.isVersionNewerForTest('1.0.2', '1.0.1'), isTrue);
    });

    test('returns false when versions are equal', () {
      expect(repository.isVersionNewerForTest('1.0.0', '1.0.0'), isFalse);
    });

    test('returns false when candidate is older', () {
      expect(repository.isVersionNewerForTest('1.0.0', '1.0.1'), isFalse);
      expect(repository.isVersionNewerForTest('1.0.0', '2.0.0'), isFalse);
    });

    test('strips build metadata before comparison', () {
      expect(repository.isVersionNewerForTest('1.0.1+20', '1.0.0+10'), isTrue);
      expect(repository.isVersionNewerForTest('1.0.0+99', '1.0.0+1'), isFalse);
    });

    test('pads short versions to major.minor.patch', () {
      expect(repository.isVersionNewerForTest('2', '1.9.9'), isTrue);
      expect(repository.isVersionNewerForTest('1.1', '1.0.9'), isTrue);
    });

    test('treats non-numeric segments as zero', () {
      expect(repository.isVersionNewerForTest('1.0.1', '1.0.beta'), isTrue);
      expect(repository.isVersionNewerForTest('1.0.0', '1.0.0'), isFalse);
    });
  });
}
