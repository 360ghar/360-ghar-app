// test/features/splash/presentation/bindings/splash_binding_test.dart
//
// Binding test for [SplashBinding]. Unlike most feature bindings, SplashBinding
// uses `Get.put` (eager construction) rather than `Get.lazyPut`, so the
// [SplashController] is instantiated immediately when `dependencies()` runs.
// SplashController's field initializers require an initialised [GetStorage]
// and its [GetTickerProviderStateMixin] requires a live Flutter binding, so
// the test harness mirrors the controller test setup: ensure the Flutter
// binding is initialised, mock the path_provider platform channel so GetStorage
// can initialise in a headless test environment, then verify the controller is
// registered in the GetX container.

import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:get/get.dart';
import 'package:get_storage/get_storage.dart';
import 'package:ghar360/features/splash/presentation/bindings/splash_binding.dart';
import 'package:ghar360/features/splash/presentation/controllers/splash_controller.dart';

import '../../../../helpers/getx_test_binding.dart';

void main() {
  // Required for GetTickerProviderStateMixin (AnimationController vsync) used by
  // SplashController, and for the mocked path_provider platform channel.
  TestWidgetsFlutterBinding.ensureInitialized();
  const channel = MethodChannel('plugins.flutter.io/path_provider');

  setUpAll(() {
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger.setMockMethodCallHandler(
      channel,
      (MethodCall methodCall) async {
        if (methodCall.method == 'getApplicationDocumentsDirectory') {
          return '.';
        }
        return null;
      },
    );
  });

  setUp(() async {
    GetxTestBinding.init();
    await GetStorage.init();
    GetStorage().erase();
  });

  tearDown(() {
    GetxTestBinding.reset();
  });

  test('SplashBinding registers SplashController', () {
    final binding = SplashBinding();
    binding.dependencies();

    expect(Get.isRegistered<SplashController>(), isTrue);
  });
}
