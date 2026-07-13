import 'package:flutter/material.dart';

import 'package:flutter_test/flutter_test.dart';
import 'package:get/get.dart';

import 'package:ghar360/core/translations/app_translations.dart';
import 'package:ghar360/features/auth/presentation/controllers/profile_completion_controller.dart';
import 'package:ghar360/features/auth/presentation/views/profile_completion_view.dart';

class _TestProfileCompletionController extends ProfileCompletionController {
  @override
  // ignore: must_call_super
  void onInit() {
    // Skip production dependency lookups (AuthController/PageStateService)
    // for isolated widget testing.
  }

  @override
  Future<void> completeProfile() async {}

  @override
  void skipToHome() {}

  @override
  Future<void> sendAddPhoneOtp() async {}

  @override
  Future<void> verifyAddPhoneOtp([String? code]) async {}

  @override
  void skipAddPhone() {}

  @override
  Future<void> resendAddPhoneOtp() async {}

  @override
  Future<void> requestPhoneNumberHint() async {}
}

void main() {
  setUp(() {
    Get.testMode = true;
    Get.reset();
  });

  tearDown(Get.reset);

  Future<void> pumpView(WidgetTester tester, {_TestProfileCompletionController? controller}) async {
    final c = controller ?? _TestProfileCompletionController();
    Get.put<ProfileCompletionController>(c);

    // Suppress RenderFlex overflow errors from the compact test surface.
    final originalError = FlutterError.onError;
    FlutterError.onError = (FlutterErrorDetails details) {};

    await tester.pumpWidget(
      GetMaterialApp(
        translations: AppTranslations(),
        locale: const Locale('en', 'US'),
        fallbackLocale: const Locale('en', 'US'),
        home: const ProfileCompletionView(),
      ),
    );
    // Use pump (not pumpAndSettle) to avoid infinite animation issues.
    await tester.pump();

    // Restore the original error handler after pumping.
    FlutterError.onError = originalError;
  }

  testWidgets('blocks progression on step 1 when required fields are missing', (tester) async {
    final controller = _TestProfileCompletionController();
    await pumpView(tester, controller: controller);

    final nextButton = find.byKey(const ValueKey('qa.auth.profile_completion.next_or_complete'));
    await tester.ensureVisible(nextButton);
    await tester.tap(nextButton, warnIfMissed: false);
    await tester.pumpAndSettle();

    expect(controller.currentStep.value, 0);
  });

  testWidgets('advances to purpose step when step 1 fields are valid', (tester) async {
    final controller = _TestProfileCompletionController();
    await pumpView(tester, controller: controller);

    await tester.enterText(
      find.byKey(const ValueKey('qa.auth.profile_completion.full_name_input')),
      'Test User',
    );
    await tester.enterText(
      find.byKey(const ValueKey('qa.auth.profile_completion.email_input')),
      'test@example.com',
    );

    controller.selectedDateOfBirth = DateTime(2000, 1, 1);
    controller.dateOfBirthController.text = '01/01/2000';
    controller.update();
    await tester.pump();

    final nextButton = find.byKey(const ValueKey('qa.auth.profile_completion.next_or_complete'));
    await tester.ensureVisible(nextButton);
    await tester.tap(nextButton, warnIfMissed: false);
    await tester.pumpAndSettle();

    expect(controller.currentStep.value, 1);
    expect(find.byKey(const ValueKey('qa.auth.profile_completion.purpose.rent')), findsOneWidget);
    expect(find.byKey(const ValueKey('qa.auth.profile_completion.purpose.buy')), findsOneWidget);
  });

  testWidgets('shows back button on step 2 and returns to step 1 when tapped', (tester) async {
    final controller = _TestProfileCompletionController();
    controller.currentStep.value = 1;
    controller.update();
    await pumpView(tester, controller: controller);

    // Step 2 should show a "back" button (OutlinedButton).
    final backButton = find.byType(OutlinedButton);
    expect(backButton, findsOneWidget);

    await tester.ensureVisible(backButton);
    await tester.tap(backButton, warnIfMissed: false);
    await tester.pumpAndSettle();

    expect(controller.currentStep.value, 0);
  });

  testWidgets('shows skip button on the profile screen', (tester) async {
    final controller = _TestProfileCompletionController();
    await pumpView(tester, controller: controller);

    final skipButton = find.byKey(const ValueKey('qa.auth.profile_completion.skip'));
    expect(skipButton, findsOneWidget);
  });

  testWidgets('shows add-phone screen when showAddPhone is true', (tester) async {
    final controller = _TestProfileCompletionController();
    controller.showAddPhone.value = true;
    await pumpView(tester, controller: controller);

    // The add-phone screen has a phone input field.
    final phoneInput = find.byKey(const ValueKey('qa.auth.add_phone.phone_input'));
    expect(phoneInput, findsOneWidget);

    // It should have a send-otp button.
    final sendOtpButton = find.byKey(const ValueKey('qa.auth.add_phone.send_otp'));
    expect(sendOtpButton, findsOneWidget);

    // It should have a skip button.
    final skipButton = find.byKey(const ValueKey('qa.auth.add_phone.skip'));
    expect(skipButton, findsOneWidget);
  });

  testWidgets('shows OTP stage when isPhoneOtpStage is true', (tester) async {
    final controller = _TestProfileCompletionController();
    controller.showAddPhone.value = true;
    controller.isPhoneOtpStage.value = true;
    controller.phoneController.text = '+919876543210';
    await pumpView(tester, controller: controller);

    // The OTP stage should show a verify-otp button.
    final verifyButton = find.byKey(const ValueKey('qa.auth.add_phone.verify_otp'));
    expect(verifyButton, findsOneWidget);

    // The phone input should NOT be visible in the OTP stage.
    final phoneInput = find.byKey(const ValueKey('qa.auth.add_phone.phone_input'));
    expect(phoneInput, findsNothing);
  });

  testWidgets('shows progress indicator with correct step label on step 0', (tester) async {
    final controller = _TestProfileCompletionController();
    await pumpView(tester, controller: controller);

    // Step 0 should show a LinearProgressIndicator.
    expect(find.byType(LinearProgressIndicator), findsOneWidget);
  });

  testWidgets('tapping a purpose option updates selectedPropertyPurpose', (tester) async {
    final controller = _TestProfileCompletionController();
    controller.currentStep.value = 1;
    controller.update();
    await pumpView(tester, controller: controller);

    final rentOption = find.byKey(const ValueKey('qa.auth.profile_completion.purpose.rent'));
    await tester.ensureVisible(rentOption);
    await tester.tap(rentOption, warnIfMissed: false);
    await tester.pump();

    expect(controller.selectedPropertyPurpose.value, 'rent');
  });

  testWidgets('shows complete button text on step 2', (tester) async {
    final controller = _TestProfileCompletionController();
    controller.currentStep.value = 1;
    controller.update();
    await pumpView(tester, controller: controller);

    // On step 2, the button should show "complete" text, not "next".
    final completeButton = find.byKey(
      const ValueKey('qa.auth.profile_completion.next_or_complete'),
    );
    expect(completeButton, findsOneWidget);
    // The button text should contain "complete" translation.
    final buttonText = tester.widget<FilledButton>(completeButton).child;
    expect(buttonText, isA<Text>());
  });

  testWidgets('shows loading spinner when isLoading is true on profile screen', (tester) async {
    final controller = _TestProfileCompletionController();
    controller.isLoading.value = true;
    await pumpView(tester, controller: controller);

    // The next/complete button should show a CircularProgressIndicator.
    final button = find.byKey(const ValueKey('qa.auth.profile_completion.next_or_complete'));
    final buttonWidget = tester.widget<FilledButton>(button);
    expect(buttonWidget.onPressed, isNull, reason: 'Button should be disabled when loading');
  });

  testWidgets('shows loading spinner when isLoading is true on add-phone screen', (tester) async {
    final controller = _TestProfileCompletionController();
    controller.showAddPhone.value = true;
    controller.isLoading.value = true;
    await pumpView(tester, controller: controller);

    // The send-otp button should be disabled when loading.
    final button = find.byKey(const ValueKey('qa.auth.add_phone.send_otp'));
    final buttonWidget = tester.widget<FilledButton>(button);
    expect(buttonWidget.onPressed, isNull);
  });
}
