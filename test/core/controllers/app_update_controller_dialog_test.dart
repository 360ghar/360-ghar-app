// test/core/controllers/app_update_controller_dialog_test.dart
//
// Widget tests for [AppUpdateController]'s update-dialog action flows. These
// exercise the private `_showUpdateDialog` → `_openDownloadUrl` and
// skipped-version persistence paths by pumping a real [GetMaterialApp] so
// `Get.dialog` can present the [AppUpdateDialog] and the test can tap its
// action buttons.
//
// Kept in a separate file from the unit tests so each widget test gets a
// pristine GetX container + navigator (no observer/route leakage from the
// unit-test controller).

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

class MockAppUpdateRepository extends GetxServiceMock implements AppUpdateRepository {}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  const pathProviderChannel = MethodChannel('plugins.flutter.io/path_provider');
  const packageInfoChannel = MethodChannel('dev.fluttercommunity.plus/package_info');
  const urlLauncherChannel = MethodChannel('plugins.flutter.io/url_launcher');

  setUpAll(() {
    Get.testMode = true;
    registerFallbackValue(
      const AppVersionCheckRequest(app: 'user', platform: 'android', currentVersion: '0.0.0'),
    );

    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger.setMockMethodCallHandler(
      pathProviderChannel,
      (MethodCall call) async {
        if (call.method == 'getApplicationDocumentsDirectory') return '.';
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

    // url_launcher: return true so _openDownloadUrl completes "successfully".
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger.setMockMethodCallHandler(
      urlLauncherChannel,
      (MethodCall call) async {
        if (call.method == 'canLaunchUrl') return true;
        if (call.method == 'launchUrl') return true;
        return null;
      },
    );
  });

  late MockAppUpdateRepository mockRepository;
  late AppUpdateController controller;

  setUp(() async {
    GetxTestBinding.init();
    await GetStorage.init();
    GetStorage().erase();

    mockRepository = MockAppUpdateRepository();
    when(() => mockRepository.checkForUpdates(any())).thenAnswer(
      (_) async => const AppVersionCheckResponse(updateAvailable: false, isMandatory: false),
    );
    GetxTestBinding.bind().register<AppUpdateRepository>(mockRepository);

    controller = AppUpdateController();
    controller.onInit();
  });

  tearDown(() {
    controller.onClose();
    GetxTestBinding.reset();
  });

  Future<void> pumpApp(WidgetTester tester) async {
    await tester.pumpWidget(const GetMaterialApp(home: Scaffold(body: SizedBox.shrink())));
  }

  group('AppUpdateController dialog actions', () {
    testWidgets('mandatory update: tapping Update opens download URL', (tester) async {
      when(() => mockRepository.checkForUpdates(any())).thenAnswer(
        (_) async => const AppVersionCheckResponse(
          updateAvailable: true,
          isMandatory: true,
          latestVersion: '2.0.0',
          downloadUrl: 'https://example.com/update',
        ),
      );

      await pumpApp(tester);

      controller.didChangeAppLifecycleState(AppLifecycleState.resumed);
      await tester.pump(const Duration(milliseconds: 50));
      await tester.pumpAndSettle(const Duration(milliseconds: 500));

      final updateButton = find.text('update_now'.tr);
      expect(updateButton, findsOneWidget);
      await tester.tap(updateButton);
      await tester.pumpAndSettle(const Duration(milliseconds: 500));

      expect(controller.isChecking.value, false);
    });

    testWidgets('optional update: tapping Not now stores skipped version', (tester) async {
      when(() => mockRepository.checkForUpdates(any())).thenAnswer(
        (_) async => const AppVersionCheckResponse(
          updateAvailable: true,
          isMandatory: false,
          latestVersion: '1.9.0',
          downloadUrl: 'https://example.com/update',
        ),
      );

      await pumpApp(tester);
      expect(GetStorage().read<String>('skipped_app_version'), isNull);

      controller.didChangeAppLifecycleState(AppLifecycleState.resumed);
      await tester.pump(const Duration(milliseconds: 50));
      await tester.pumpAndSettle(const Duration(milliseconds: 500));

      final notNowButton = find.text('not_now'.tr);
      expect(notNowButton, findsOneWidget);
      await tester.tap(notNowButton);
      await tester.pumpAndSettle(const Duration(milliseconds: 500));

      expect(GetStorage().read<String>('skipped_app_version'), '1.9.0');
      expect(controller.isChecking.value, false);
    });

    testWidgets('optional update: tapping Update opens download URL', (tester) async {
      when(() => mockRepository.checkForUpdates(any())).thenAnswer(
        (_) async => const AppVersionCheckResponse(
          updateAvailable: true,
          isMandatory: false,
          latestVersion: '1.9.0',
          downloadUrl: 'https://example.com/update',
        ),
      );

      await pumpApp(tester);

      controller.didChangeAppLifecycleState(AppLifecycleState.resumed);
      await tester.pump(const Duration(milliseconds: 50));
      await tester.pumpAndSettle(const Duration(milliseconds: 500));

      final updateButton = find.text('update'.tr);
      expect(updateButton, findsOneWidget);
      await tester.tap(updateButton);
      await tester.pumpAndSettle(const Duration(milliseconds: 500));

      expect(controller.isChecking.value, false);
    });

    testWidgets('optional update: dismissing dialog (null action) stores skipped version', (
      tester,
    ) async {
      when(() => mockRepository.checkForUpdates(any())).thenAnswer(
        (_) async => const AppVersionCheckResponse(
          updateAvailable: true,
          isMandatory: false,
          latestVersion: '1.9.0',
        ),
      );

      await pumpApp(tester);

      controller.didChangeAppLifecycleState(AppLifecycleState.resumed);
      await tester.pump(const Duration(milliseconds: 50));
      await tester.pumpAndSettle(const Duration(milliseconds: 500));

      // Dismiss via the barrier (optional dialog is dismissible).
      await tester.tapAt(const Offset(10, 10));
      await tester.pumpAndSettle(const Duration(milliseconds: 500));

      expect(GetStorage().read<String>('skipped_app_version'), '1.9.0');
    });
  });
}
