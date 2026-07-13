// test/features/auth/presentation/controllers/set_password_controller_test.dart
//
// Tests for [SetPasswordController]: initial state, submit success/failure,
// togglePasswordVisibility, and passwordStrength updates.

import 'package:flutter_test/flutter_test.dart';
import 'package:get/get.dart';
import 'package:ghar360/core/controllers/auth_controller.dart';
import 'package:ghar360/features/auth/data/auth_repository.dart';
import 'package:ghar360/features/auth/presentation/controllers/set_password_controller.dart';
import 'package:mocktail/mocktail.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../../../../helpers/getx_test_binding.dart';
import '../../../../helpers/mocks.dart';

void main() {
  late MockAuthRepository authRepository;
  late MockAuthController authController;

  setUp(() {
    GetxTestBinding.init();

    authRepository = MockAuthRepository();
    authController = MockAuthController();

    GetxTestBinding.bind()
      ..register<AuthRepository>(authRepository)
      ..register<AuthController>(authController);
  });

  tearDown(() {
    GetxTestBinding.reset();
  });

  SetPasswordController createController({User? user}) {
    when(() => authRepository.currentUser).thenReturn(user);
    final controller = SetPasswordController();
    Get.put<SetPasswordController>(controller, permanent: true);
    return controller;
  }

  group('SetPasswordController', () {
    group('initial state', () {
      test('has expected defaults when currentUser is null', () {
        final controller = createController(user: null);

        expect(controller.isLoading.value, isFalse);
        expect(controller.isPasswordVisible.value, isFalse);
        expect(controller.isConfirmPasswordVisible.value, isFalse);
        expect(controller.errorMessage.value, isEmpty);
        expect(controller.passwordStrength.value, 0);
        expect(controller.maskedIdentifier, isEmpty);
      });

      test('detects email user and sets masked identifier', () {
        final user = FakeUser(email: 'test@example.com', phone: null);
        final controller = createController(user: user);

        // maskedIdentifier should mask the email
        expect(controller.maskedIdentifier, isNotEmpty);
        expect(controller.maskedIdentifier, contains('@'));
      });

      test('detects phone user when email is absent', () {
        final user = FakeUser(email: null, phone: '+919876543210');
        final controller = createController(user: user);

        expect(controller.maskedIdentifier, isNotEmpty);
        expect(controller.maskedIdentifier, contains('3210'));
      });
    });

    group('togglePasswordVisibility', () {
      test('toggles isPasswordVisible', () {
        final controller = createController();

        controller.togglePasswordVisibility();
        expect(controller.isPasswordVisible.value, isTrue);

        controller.togglePasswordVisibility();
        expect(controller.isPasswordVisible.value, isFalse);
      });

      test('toggles isConfirmPasswordVisible', () {
        final controller = createController();

        controller.toggleConfirmPasswordVisibility();
        expect(controller.isConfirmPasswordVisible.value, isTrue);

        controller.toggleConfirmPasswordVisibility();
        expect(controller.isConfirmPasswordVisible.value, isFalse);
      });
    });

    group('submit', () {
      test('does nothing when form validation is unavailable', () async {
        final controller = createController();
        controller.passwordController.text = 'StrongPass1!';

        // No form widget → formKey.currentState is null → validate fails
        await controller.submit();

        expect(controller.isLoading.value, isFalse);
        verifyNever(() => authController.completePasswordSetup(any()));
      });
    });

    group('passwordStrength', () {
      test('remains 0 for empty password', () {
        final controller = createController();
        controller.passwordController.text = '';
        expect(controller.passwordStrength.value, 0);
      });

      test('maps non-empty short password to strength 1', () {
        final controller = createController();

        // 'abcde' (< 6 chars): raw strength 0 → mapped to 1
        controller.passwordController.text = 'abcde';
        expect(controller.passwordStrength.value, 1);
      });

      test('increases for longer passwords', () {
        final controller = createController();

        // 'abcdefgh' (>= 8, no upper/digit/special): raw strength 2 → mapped to 1
        controller.passwordController.text = 'abcdefgh';
        expect(controller.passwordStrength.value, 1);
      });

      test('increases for passwords with mixed character classes', () {
        final controller = createController();

        // 'Abcdefgh1!' (10 chars, upper, digit, special): raw 5 → mapped to 3
        controller.passwordController.text = 'Abcdefgh1!';
        expect(controller.passwordStrength.value, 3);
      });

      test('max strength when all criteria met', () {
        final controller = createController();

        // 'Abcdef1!' (8 chars): raw 5 (len>=6, len>=8, upper, digit, special) → 3
        controller.passwordController.text = 'Abcdef1!';
        expect(controller.passwordStrength.value, 3);
      });
    });

    group('maskedIdentifier', () {
      test('returns empty string when user has no email or phone', () {
        final controller = createController(user: null);
        expect(controller.maskedIdentifier, isEmpty);
      });

      test('masks phone user keeping last 4 digits', () {
        final user = FakeUser(email: null, phone: '+919876543210');
        final controller = createController(user: user);

        expect(controller.maskedIdentifier, '+91 ******3210');
      });

      test('masks email user with first character and domain', () {
        final user = FakeUser(email: 'alice@gmail.com', phone: null);
        final controller = createController(user: user);

        expect(controller.maskedIdentifier, 'a***@gmail.com');
      });
    });

    group('passwordStrength additional cases', () {
      test('maps 6-char lowercase password to strength 1', () {
        final controller = createController();

        // 'abcdef' (>= 6, no upper/digit/special): raw 1 → mapped to 1
        controller.passwordController.text = 'abcdef';
        expect(controller.passwordStrength.value, 1);
      });

      test('maps digit-only password to strength 1', () {
        final controller = createController();

        // '123456' (>= 6, digit): raw 2 → mapped to 1
        controller.passwordController.text = '123456';
        expect(controller.passwordStrength.value, 1);
      });

      test('maps password with upper + digit + special to strength 3', () {
        final controller = createController();

        // 'Abc123!@' (8 chars, upper, digit, special): raw 5 → mapped to 3
        controller.passwordController.text = 'Abc123!@';
        expect(controller.passwordStrength.value, 3);
      });

      test('resets to 0 when password is cleared', () {
        final controller = createController();

        controller.passwordController.text = 'StrongPass1!';
        expect(controller.passwordStrength.value, 3);

        controller.passwordController.text = '';
        expect(controller.passwordStrength.value, 0);
      });
    });

    group('submit', () {
      test('does nothing when form validation is unavailable', () async {
        final controller = createController();
        controller.passwordController.text = 'StrongPass1!';

        // No form widget → formKey.currentState is null → validate fails
        await controller.submit();

        expect(controller.isLoading.value, isFalse);
        verifyNever(() => authController.completePasswordSetup(any()));
      });

      test('returns early when already loading even if form is valid', () async {
        final controller = createController();
        controller.isLoading.value = true;

        await controller.submit();

        verifyNever(() => authController.completePasswordSetup(any()));
      });
    });

    group('onClose', () {
      test('disposes controllers without throwing', () {
        final controller = createController();

        expect(controller.onClose, returnsNormally);
      });
    });
  });
}

/// Minimal fake User for Supabase AuthResponse testing.
class FakeUser extends Fake implements User {
  @override
  final String? email;

  @override
  final String? phone;

  @override
  String get id => 'fake-user-id';

  FakeUser({this.email, this.phone});
}
