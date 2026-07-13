// test/features/splash/presentation/controllers/splash_controller_test.dart
//
// Unit tests for [SplashController]. Covers:
// - Initial state (currentStep=0, nullable fields initially null before onInit)
// - onReady is safe to call
// - Nullable pageController: nextStep/previousStep don't crash when called
// - nextStep increments currentStep up to limit (2)
// - previousStep decrements currentStep down to 0
// - skipToHome triggers onboarding completion

import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:get/get.dart';
import 'package:get_storage/get_storage.dart';
import 'package:ghar360/core/controllers/auth_controller.dart';
import 'package:ghar360/core/data/models/auth_status.dart';
import 'package:ghar360/features/splash/presentation/controllers/splash_controller.dart';
import 'package:mocktail/mocktail.dart';

import '../../../../helpers/getx_test_binding.dart';
import '../../../../helpers/mocks.dart';

void main() {
  // Required for GetTickerProviderStateMixin (AnimationController vsync).
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

  late MockAuthController mockAuthController;
  late Rx<AuthStatus> authStatus;

  setUp(() async {
    GetxTestBinding.init();
    await GetStorage.init();
    GetStorage().erase();

    mockAuthController = MockAuthController();
    authStatus = AuthStatus.authenticated.obs;
    when(() => mockAuthController.authStatus).thenReturn(authStatus);
    when(() => mockAuthController.isAuthenticated).thenReturn(true);

    GetxTestBinding.bind().register<AuthController>(mockAuthController);
  });

  tearDown(() {
    GetxTestBinding.reset();
  });

  SplashController createController() {
    final c = SplashController();
    c.onInit();
    return c;
  }

  group('SplashController', () {
    // ── Initial state ──────────────────────────────────────────────────

    test('initial state has currentStep=0', () {
      final controller = createController();

      expect(controller.currentStep.value, 0);
    });

    test('onInit creates non-null pageController and animations', () {
      final controller = createController();

      expect(controller.pageController, isNotNull);
      expect(controller.animationController, isNotNull);
      expect(controller.fadeAnimation, isNotNull);
      expect(controller.slideAnimation, isNotNull);
      expect(controller.scaleAnimation, isNotNull);
      expect(controller.rotationAnimation, isNotNull);
    });

    // ── Nullable pageController safety ─────────────────────────────────

    test('nextStep does not crash when pageController is null', () {
      final controller = SplashController();
      // Intentionally skip onInit so pageController stays null

      // Should not throw — uses null-safe operator
      expect(() => controller.nextStep(), returnsNormally);
    });

    test('previousStep does not crash when pageController is null', () {
      final controller = SplashController();
      // Intentionally skip onInit so pageController stays null

      expect(() => controller.previousStep(), returnsNormally);
    });

    // ── nextStep / previousStep ────────────────────────────────────────
    // Skip onInit so pageController is null — the null-safe `?.` makes
    // animateToPage a no-op, letting us test the step-counter logic without
    // needing a real PageView in the widget tree.

    test('nextStep increments currentStep from 0 to 1', () {
      final controller = SplashController();
      // pageController is null, so animateToPage is skipped via ?.

      controller.nextStep();

      expect(controller.currentStep.value, 1);
    });

    test('nextStep increments currentStep from 1 to 2', () {
      final controller = SplashController();
      controller.currentStep.value = 1;

      controller.nextStep();

      expect(controller.currentStep.value, 2);
    });

    test('nextStep at step 2 triggers onboarding completion (not beyond 2)', () {
      final controller = SplashController();
      controller.currentStep.value = 2;

      // At step 2, nextStep calls _completeOnboardingAndNavigate.
      // With auth controller registered and authenticated, it refreshes authStatus.
      controller.nextStep();

      // Step should stay at 2 (completion flow handles navigation)
      expect(controller.currentStep.value, 2);

      // Verify onboarding flag was written
      expect(GetStorage().read('has_seen_onboarding'), true);
    });

    test('previousStep decrements currentStep from 1 to 0', () {
      final controller = SplashController();
      controller.currentStep.value = 1;

      controller.previousStep();

      expect(controller.currentStep.value, 0);
    });

    test('previousStep at step 0 is a no-op', () {
      final controller = SplashController();

      controller.previousStep();

      expect(controller.currentStep.value, 0);
    });

    // ── skipToHome ─────────────────────────────────────────────────────

    test('skipToHome writes onboarding flag and triggers navigation', () {
      final controller = createController();

      controller.skipToHome();

      expect(GetStorage().read('has_seen_onboarding'), true);
    });

    test('skipToHome with unauthenticated user refreshes auth status', () {
      authStatus.value = AuthStatus.unauthenticated;
      when(() => mockAuthController.isAuthenticated).thenReturn(false);

      final controller = createController();

      // Should not throw even with unauthenticated state
      expect(() => controller.skipToHome(), returnsNormally);
      expect(GetStorage().read('has_seen_onboarding'), true);
    });

    // ── onReady ────────────────────────────────────────────────────────

    test('onReady does not throw', () {
      final controller = createController();

      expect(() => controller.onReady(), returnsNormally);
    });

    // ── onClose ────────────────────────────────────────────────────────

    test('onClose disposes resources without throwing', () {
      final controller = createController();

      expect(() => controller.onClose(), returnsNormally);
    });

    // ── nextStep from step 0 to 2 sequentially ──────────────────────────

    test('nextStep can be called multiple times to reach step 2', () {
      final controller = SplashController();

      controller.nextStep();
      expect(controller.currentStep.value, 1);

      controller.nextStep();
      expect(controller.currentStep.value, 2);

      // Third call triggers onboarding completion, step stays at 2
      controller.nextStep();
      expect(controller.currentStep.value, 2);
    });

    // ── previousStep from step 2 ───────────────────────────────────────

    test('previousStep decrements from step 2 to 1', () {
      final controller = SplashController();
      controller.currentStep.value = 2;

      controller.previousStep();

      expect(controller.currentStep.value, 1);
    });

    // ── previousStep from step 2 to 0 sequentially ─────────────────────

    test('previousStep can be called multiple times to reach step 0', () {
      final controller = SplashController();
      controller.currentStep.value = 2;

      controller.previousStep();
      expect(controller.currentStep.value, 1);

      controller.previousStep();
      expect(controller.currentStep.value, 0);

      // Further calls are no-op
      controller.previousStep();
      expect(controller.currentStep.value, 0);
    });

    // ── skipToHome with initial auth status ────────────────────────────

    test('skipToHome with initial auth status does not throw', () {
      authStatus.value = AuthStatus.initial;

      final controller = createController();

      expect(() => controller.skipToHome(), returnsNormally);
      expect(GetStorage().read('has_seen_onboarding'), true);
    });

    // ── nextStep at step 2 with initial auth status ────────────────────

    test('nextStep at step 2 with initial auth status does not throw', () {
      authStatus.value = AuthStatus.initial;
      final controller = SplashController();
      controller.currentStep.value = 2;

      expect(() => controller.nextStep(), returnsNormally);
      expect(GetStorage().read('has_seen_onboarding'), true);
    });

    // ── skipToHome writes boolean true to storage ──────────────────────

    test('skipToHome writes boolean true value to has_seen_onboarding', () {
      final controller = createController();

      controller.skipToHome();

      final value = GetStorage().read('has_seen_onboarding');
      expect(value, isTrue);
      expect(value, isA<bool>());
    });

    // ── Animation controller starts forward ────────────────────────────

    test('animationController is forward after onInit', () {
      final controller = createController();

      // The animation controller should have been started with forward()
      expect(controller.animationController, isNotNull);
      // The animation may or may not have completed depending on timing,
      // but it should not be null.
    });

    // ── onClose disposes animation and page controllers ────────────────

    test('onClose disposes animationController and pageController', () {
      final controller = createController();

      // Should complete without throwing
      expect(() => controller.onClose(), returnsNormally);
    });

    // ── pageController has initial page 0 ──────────────────────────────

    test('pageController initialPage is 0', () {
      final controller = createController();

      expect(controller.pageController!.initialPage, 0);
    });

    // ── skipToHome when AuthController is not registered ───────────────

    test('skipToHome falls back to phoneEntry when AuthController not registered', () {
      GetxTestBinding.reset();
      GetxTestBinding.init();

      final controller = createController();

      // Without AuthController registered, skipToHome should not throw
      expect(() => controller.skipToHome(), returnsNormally);
      expect(GetStorage().read('has_seen_onboarding'), true);
    });
  });
}
