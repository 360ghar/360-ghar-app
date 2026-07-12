// test/features/auth/presentation/views/forgot_password_view_test.dart

import 'package:flutter/material.dart';

import 'package:flutter_test/flutter_test.dart';
import 'package:get/get.dart';

import 'package:ghar360/features/auth/presentation/controllers/forgot_password_controller.dart';
import 'package:ghar360/features/auth/presentation/views/forgot_password_view.dart';
import '../../../../helpers/getx_test_binding.dart';
import '../../../../helpers/mocks.dart';
import '../../../../helpers/pump_app.dart';

// ---------------------------------------------------------------------------
// Stub controller
// ---------------------------------------------------------------------------

class _StubForgotPasswordController extends GetxServiceMock
    implements ForgotPasswordController {
  _StubForgotPasswordController({int initialStep = 0}) {
    currentStep.value = initialStep;
  }

  @override
  final GlobalKey<FormState> formKey = GlobalKey<FormState>();

  @override
  final TextEditingController identifierController = TextEditingController();

  @override
  final TextEditingController otpController = TextEditingController();

  @override
  final TextEditingController newPasswordController = TextEditingController();

  @override
  final TextEditingController confirmPasswordController = TextEditingController();

  @override
  final RxBool isLoading = false.obs;

  @override
  final RxBool isPasswordVisible = false.obs;

  @override
  final RxBool isConfirmPasswordVisible = false.obs;

  @override
  final RxInt currentStep = 0.obs;

  @override
  final RxString errorMessage = ''.obs;

  @override
  final RxBool looksLikeEmail = false.obs;

  @override
  final RxBool canResendOtp = false.obs;

  @override
  final RxInt otpCountdown = 0.obs;

  bool sendResetOtpCalled = false;
  bool verifyResetOtpCalled = false;
  bool updatePasswordCalled = false;

  @override
  bool get isEmail => looksLikeEmail.value;

  @override
  String get maskedIdentifier =>
      identifierController.text.isEmpty ? '' : identifierController.text;

  @override
  void togglePasswordVisibility() =>
      isPasswordVisible.value = !isPasswordVisible.value;

  @override
  void toggleConfirmPasswordVisibility() =>
      isConfirmPasswordVisible.value = !isConfirmPasswordVisible.value;

  @override
  String? validateIdentifier(String? value) {
    final raw = (value ?? '').trim();
    if (raw.isEmpty) return 'identifier_required'.tr;
    return null;
  }

  @override
  Future<void> sendResetOtp() async {
    sendResetOtpCalled = true;
  }

  @override
  Future<void> verifyResetOtp() async {
    verifyResetOtpCalled = true;
  }

  @override
  Future<void> updatePassword() async {
    updatePasswordCalled = true;
  }

  @override
  Future<void> resendOtp() async {}

  @override
  void goBackToStep(int step) {
    if (step >= 0 && step < currentStep.value) {
      currentStep.value = step;
    }
  }
}

// ---------------------------------------------------------------------------
// Tests
// ---------------------------------------------------------------------------

void main() {
  setUp(() {
    GetxTestBinding.init();
  });

  tearDown(() => GetxTestBinding.reset());

  Future<void> pumpView(WidgetTester tester, _StubForgotPasswordController controller) async {
    Get.put<ForgotPasswordController>(controller);
    await tester.pumpApp(const ForgotPasswordView());
    await tester.pump();
  }

  group('ForgotPasswordView — step 0 (identifier)', () {
    testWidgets('renders identifier input and send OTP button', (tester) async {
      final controller = _StubForgotPasswordController();
      await pumpView(tester, controller);

      expect(find.byKey(const ValueKey('qa.auth.forgot_password.screen')), findsOneWidget);
      expect(
        find.byKey(const ValueKey('qa.auth.forgot_password.identifier_input')),
        findsOneWidget,
      );
      expect(find.byKey(const ValueKey('qa.auth.forgot_password.send_otp')), findsOneWidget);
    });

    testWidgets('tapping send OTP calls sendResetOtp', (tester) async {
      final controller = _StubForgotPasswordController();
      await pumpView(tester, controller);

      await tester.tap(find.byKey(const ValueKey('qa.auth.forgot_password.send_otp')));
      await tester.pump();

      expect(controller.sendResetOtpCalled, isTrue);
    });

    testWidgets('shows loading spinner on send OTP when isLoading', (tester) async {
      final controller = _StubForgotPasswordController();
      controller.isLoading.value = true;
      await pumpView(tester, controller);

      final buttonArea = find.ancestor(
        of: find.byKey(const ValueKey('qa.auth.forgot_password.send_otp')),
        matching: find.byType(SizedBox),
      );
      expect(
        find.descendant(of: buttonArea, matching: find.byType(CircularProgressIndicator)),
        findsOneWidget,
      );
    });

    testWidgets('shows back to login link on step 0', (tester) async {
      final controller = _StubForgotPasswordController();
      await pumpView(tester, controller);

      expect(find.text('back_to_login'.tr), findsOneWidget);
    });
  });

  group('ForgotPasswordView — step 1 (OTP)', () {
    testWidgets('renders OTP input and verify button', (tester) async {
      final controller = _StubForgotPasswordController(initialStep: 1);
      controller.canResendOtp.value = true;
      await pumpView(tester, controller);

      expect(find.byKey(const ValueKey('qa.auth.forgot_password.otp_input')), findsOneWidget);
      expect(find.byKey(const ValueKey('qa.auth.forgot_password.verify_otp')), findsOneWidget);
      expect(find.text('resend_code'.tr), findsOneWidget);
    });

    testWidgets('tapping verify OTP calls verifyResetOtp', (tester) async {
      final controller = _StubForgotPasswordController(initialStep: 1);
      await pumpView(tester, controller);

      await tester.tap(find.byKey(const ValueKey('qa.auth.forgot_password.verify_otp')));
      await tester.pump();

      expect(controller.verifyResetOtpCalled, isTrue);
    });

    testWidgets('shows countdown when resend is not allowed', (tester) async {
      final controller = _StubForgotPasswordController(initialStep: 1);
      controller.canResendOtp.value = false;
      controller.otpCountdown.value = 15;
      await pumpView(tester, controller);

      expect(find.textContaining('resend_in'.tr), findsOneWidget);
    });
  });

  group('ForgotPasswordView — step 2 (new password)', () {
    testWidgets('renders new password, confirm, and update button', (tester) async {
      final controller = _StubForgotPasswordController(initialStep: 2);
      await pumpView(tester, controller);

      expect(
        find.byKey(const ValueKey('qa.auth.forgot_password.new_password_input')),
        findsOneWidget,
      );
      expect(
        find.byKey(const ValueKey('qa.auth.forgot_password.confirm_password_input')),
        findsOneWidget,
      );
      expect(
        find.byKey(const ValueKey('qa.auth.forgot_password.update_password')),
        findsOneWidget,
      );
    });

    testWidgets('tapping update password calls updatePassword', (tester) async {
      final controller = _StubForgotPasswordController(initialStep: 2);
      await pumpView(tester, controller);

      await tester.tap(find.byKey(const ValueKey('qa.auth.forgot_password.update_password')));
      await tester.pump();

      expect(controller.updatePasswordCalled, isTrue);
    });

    testWidgets('shows inline error message when errorMessage is set', (tester) async {
      final controller = _StubForgotPasswordController(initialStep: 2);
      controller.errorMessage.value = 'Passwords do not match';
      await pumpView(tester, controller);

      expect(find.text('Passwords do not match'), findsOneWidget);
    });
  });
}
