// test/features/auth/presentation/views/login_view_test.dart

import 'package:flutter/material.dart';

import 'package:flutter_test/flutter_test.dart';
import 'package:get/get.dart';

import 'package:ghar360/core/controllers/auth_controller.dart';
import 'package:ghar360/features/auth/data/models/identifier_status.dart';
import 'package:ghar360/features/auth/presentation/controllers/login_controller.dart';
import 'package:ghar360/features/auth/presentation/views/login_view.dart';
import '../../../../helpers/getx_test_binding.dart';
import '../../../../helpers/mocks.dart';
import '../../../../helpers/pump_app.dart';

// ---------------------------------------------------------------------------
// Stub controllers — lightweight implementations that avoid calling
// Get.find for AuthRepository / production dependencies in onInit.
// ---------------------------------------------------------------------------

class _StubAuthController extends GetxServiceMock implements AuthController {
  @override
  final RxBool isAuthResolving = false.obs;
}

class _StubLoginController extends GetxServiceMock implements LoginController {
  _StubLoginController({LoginStep initialStep = LoginStep.password}) {
    step.value = initialStep;
  }

  @override
  final GlobalKey<FormState> passwordFormKey = GlobalKey<FormState>();

  @override
  final TextEditingController passwordController = TextEditingController();

  @override
  final TextEditingController otpController = TextEditingController();

  @override
  final RxBool isLoading = false.obs;

  @override
  final RxBool isPasswordVisible = false.obs;

  @override
  final RxString errorMessage = ''.obs;

  @override
  final Rx<LoginStep> step = LoginStep.password.obs;

  @override
  final RxString identifier = '+919876543210'.obs;

  @override
  final Rx<IdentifierChannel> channel = IdentifierChannel.phone.obs;

  @override
  final RxBool canResendOtp = false.obs;

  @override
  final RxInt otpCountdown = 0.obs;

  bool signInCalled = false;
  bool verifyOtpCalled = false;
  bool resendOtpCalled = false;

  @override
  bool get isEmail => channel.value == IdentifierChannel.email;

  @override
  String get maskedIdentifier => identifier.value;

  @override
  void togglePasswordVisibility() => isPasswordVisible.value = !isPasswordVisible.value;

  @override
  Future<void> signIn() async {
    signInCalled = true;
  }

  @override
  Future<void> verifyOtp([String? code]) async {
    verifyOtpCalled = true;
  }

  @override
  Future<void> resendOtp() async {
    resendOtpCalled = true;
  }
}

// ---------------------------------------------------------------------------
// Tests
// ---------------------------------------------------------------------------

void main() {
  late _StubAuthController authController;

  setUp(() {
    GetxTestBinding.init();
    authController = _StubAuthController();
    GetxTestBinding.bind().register<AuthController>(authController);
  });

  tearDown(() => GetxTestBinding.reset());

  Future<void> pumpLoginView(WidgetTester tester, _StubLoginController controller) async {
    Get.put<LoginController>(controller);
    await tester.pumpApp(const LoginView());
    await tester.pump();
  }

  group('LoginView — password step', () {
    testWidgets('renders screen with password field and submit button', (tester) async {
      final controller = _StubLoginController();
      await pumpLoginView(tester, controller);

      expect(find.bySemanticsLabel('qa.auth.login.screen'), findsOneWidget);
      expect(find.byKey(const ValueKey('qa.auth.login.password_input')), findsOneWidget);
      expect(find.byKey(const ValueKey('qa.auth.login.submit')), findsOneWidget);
      expect(find.byKey(const ValueKey('qa.auth.login.forgot_password')), findsOneWidget);
    });

    testWidgets('displays the identifier in the banner', (tester) async {
      final controller = _StubLoginController();
      controller.identifier.value = 'test@example.com';
      controller.channel.value = IdentifierChannel.email;
      await pumpLoginView(tester, controller);

      expect(find.text('test@example.com'), findsOneWidget);
      expect(find.text('email_address'.tr), findsOneWidget);
    });

    testWidgets('tapping password visibility toggle updates obscure state', (tester) async {
      final controller = _StubLoginController();
      await pumpLoginView(tester, controller);

      expect(controller.isPasswordVisible.value, isFalse);

      await tester.tap(find.byKey(const ValueKey('qa.auth.login.password_input')).at(0));
      await tester.pump();

      final visibilityIcon = find.descendant(
        of: find.byKey(const ValueKey('qa.auth.login.password_input')),
        matching: find.byIcon(Icons.visibility),
      );
      await tester.tap(visibilityIcon, warnIfMissed: false);
      await tester.pump();

      expect(controller.isPasswordVisible.value, isTrue);
    });

    testWidgets('shows loading spinner on submit button when isLoading', (tester) async {
      final controller = _StubLoginController();
      controller.isLoading.value = true;
      await pumpLoginView(tester, controller);

      // The submit button should show a CircularProgressIndicator while loading.
      final submitArea = find.ancestor(
        of: find.byKey(const ValueKey('qa.auth.login.submit')),
        matching: find.byType(SizedBox),
      );
      expect(
        find.descendant(of: submitArea, matching: find.byType(CircularProgressIndicator)),
        findsOneWidget,
      );
    });

    testWidgets('tapping submit calls signIn', (tester) async {
      final controller = _StubLoginController();
      await pumpLoginView(tester, controller);

      await tester.tap(find.byKey(const ValueKey('qa.auth.login.submit')));
      await tester.pump();

      expect(controller.signInCalled, isTrue);
    });

    testWidgets('shows inline error message when errorMessage is set', (tester) async {
      final controller = _StubLoginController();
      controller.errorMessage.value = 'Invalid credentials';
      await pumpLoginView(tester, controller);

      expect(find.text('Invalid credentials'), findsOneWidget);
    });
  });

  group('LoginView — OTP step', () {
    testWidgets('renders OTP input and verify button when step is otp', (tester) async {
      final controller = _StubLoginController(initialStep: LoginStep.otp);
      controller.canResendOtp.value = true;
      await pumpLoginView(tester, controller);

      expect(find.byKey(const ValueKey('qa.auth.login.verify_otp')), findsOneWidget);
      // OtpInputField uses ValueKey(semanticsLabel) internally.
      expect(find.byKey(const ValueKey('qa.auth.login.otp_input')), findsOneWidget);
      expect(find.text('resend_code'.tr), findsOneWidget);
    });

    testWidgets('shows countdown text when resend is not allowed', (tester) async {
      final controller = _StubLoginController(initialStep: LoginStep.otp);
      controller.canResendOtp.value = false;
      controller.otpCountdown.value = 25;
      await pumpLoginView(tester, controller);

      expect(find.textContaining('resend_in'.tr), findsOneWidget);
    });

    testWidgets('tapping verify OTP button calls verifyOtp', (tester) async {
      final controller = _StubLoginController(initialStep: LoginStep.otp);
      await pumpLoginView(tester, controller);

      await tester.tap(find.byKey(const ValueKey('qa.auth.login.verify_otp')));
      await tester.pump();

      expect(controller.verifyOtpCalled, isTrue);
    });
  });

  group('LoginView — auth resolving overlay', () {
    testWidgets('shows resolving overlay when isAuthResolving is true', (tester) async {
      final controller = _StubLoginController();
      authController.isAuthResolving.value = true;
      await pumpLoginView(tester, controller);

      // The overlay renders a 'loading' text label that only appears in the
      // resolving overlay (the navigator always has one ModalBarrier).
      expect(find.text('loading'.tr), findsOneWidget);
    });

    testWidgets('does not show overlay when isAuthResolving is false', (tester) async {
      final controller = _StubLoginController();
      await pumpLoginView(tester, controller);

      expect(find.text('loading'.tr), findsNothing);
    });
  });
}
