// test/features/auth/presentation/views/set_password_view_test.dart

import 'package:flutter/material.dart';

import 'package:flutter_test/flutter_test.dart';
import 'package:get/get.dart';

import 'package:ghar360/core/controllers/auth_controller.dart';
import 'package:ghar360/features/auth/presentation/controllers/set_password_controller.dart';
import 'package:ghar360/features/auth/presentation/views/set_password_view.dart';
import '../../../../helpers/getx_test_binding.dart';
import '../../../../helpers/mocks.dart';
import '../../../../helpers/pump_app.dart';

// ---------------------------------------------------------------------------
// Stub controllers
// ---------------------------------------------------------------------------

class _StubAuthController extends GetxServiceMock implements AuthController {
  @override
  final RxBool isAuthResolving = false.obs;
}

class _StubSetPasswordController extends GetxServiceMock implements SetPasswordController {
  @override
  final GlobalKey<FormState> formKey = GlobalKey<FormState>();

  @override
  final TextEditingController passwordController = TextEditingController();

  @override
  final TextEditingController confirmPasswordController = TextEditingController();

  @override
  final RxBool isLoading = false.obs;

  @override
  final RxBool isPasswordVisible = false.obs;

  @override
  final RxBool isConfirmPasswordVisible = false.obs;

  @override
  final RxString errorMessage = ''.obs;

  @override
  final RxInt passwordStrength = 0.obs;

  @override
  String get maskedIdentifier => 'test@example.com';

  bool submitCalled = false;

  @override
  void togglePasswordVisibility() => isPasswordVisible.value = !isPasswordVisible.value;

  @override
  void toggleConfirmPasswordVisibility() =>
      isConfirmPasswordVisible.value = !isConfirmPasswordVisible.value;

  @override
  Future<void> submit() async {
    submitCalled = true;
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

  Future<void> pumpView(WidgetTester tester, _StubSetPasswordController controller) async {
    Get.put<SetPasswordController>(controller);
    await tester.pumpApp(const SetPasswordView());
    await tester.pump();
  }

  group('SetPasswordView', () {
    testWidgets('renders password, confirm, and submit fields', (tester) async {
      final controller = _StubSetPasswordController();
      await pumpView(tester, controller);

      expect(find.bySemanticsLabel('qa.auth.set_password.screen'), findsOneWidget);
      expect(find.byKey(const ValueKey('qa.auth.set_password.password_input')), findsOneWidget);
      expect(
        find.byKey(const ValueKey('qa.auth.set_password.confirm_password_input')),
        findsOneWidget,
      );
      expect(find.byKey(const ValueKey('qa.auth.set_password.submit')), findsOneWidget);
    });

    testWidgets('shows account hint with masked identifier', (tester) async {
      final controller = _StubSetPasswordController();
      await pumpView(tester, controller);

      expect(
        find.textContaining(
          'set_password_for_account'.trParams({'identifier': 'test@example.com'}),
        ),
        findsOneWidget,
      );
    });

    testWidgets('tapping submit calls submit', (tester) async {
      final controller = _StubSetPasswordController();
      await pumpView(tester, controller);

      await tester.tap(find.byKey(const ValueKey('qa.auth.set_password.submit')));
      await tester.pump();

      expect(controller.submitCalled, isTrue);
    });

    testWidgets('toggles password visibility', (tester) async {
      final controller = _StubSetPasswordController();
      await pumpView(tester, controller);

      expect(controller.isPasswordVisible.value, isFalse);

      final visibilityIcon = find.descendant(
        of: find.byKey(const ValueKey('qa.auth.set_password.password_input')),
        matching: find.byIcon(Icons.visibility),
      );
      await tester.tap(visibilityIcon, warnIfMissed: false);
      await tester.pump();

      expect(controller.isPasswordVisible.value, isTrue);
    });

    testWidgets('shows loading spinner on submit when isLoading', (tester) async {
      final controller = _StubSetPasswordController();
      controller.isLoading.value = true;
      await pumpView(tester, controller);

      final buttonArea = find.ancestor(
        of: find.byKey(const ValueKey('qa.auth.set_password.submit')),
        matching: find.byType(SizedBox),
      );
      expect(
        find.descendant(of: buttonArea, matching: find.byType(CircularProgressIndicator)),
        findsOneWidget,
      );
    });

    testWidgets('shows password strength bar when strength > 0', (tester) async {
      final controller = _StubSetPasswordController();
      controller.passwordStrength.value = 3;
      await pumpView(tester, controller);

      expect(find.text('password_strength_strong'.tr), findsOneWidget);
    });

    testWidgets('shows inline error message when errorMessage is set', (tester) async {
      final controller = _StubSetPasswordController();
      controller.errorMessage.value = 'Set password failed';
      await pumpView(tester, controller);

      expect(find.text('Set password failed'), findsOneWidget);
    });

    testWidgets('shows resolving overlay when isAuthResolving is true', (tester) async {
      final controller = _StubSetPasswordController();
      authController.isAuthResolving.value = true;
      await pumpView(tester, controller);

      // The overlay renders a CircularProgressIndicator; the main form also
      // has one when loading, so verify via the overlay's ModalBarrier count.
      // Navigator always has 1 ModalBarrier; the overlay adds a second.
      expect(find.byType(ModalBarrier), findsNWidgets(2));
    });

    testWidgets('does not show overlay when isAuthResolving is false', (tester) async {
      final controller = _StubSetPasswordController();
      await pumpView(tester, controller);

      expect(find.byType(ModalBarrier), findsOneWidget);
    });
  });
}
