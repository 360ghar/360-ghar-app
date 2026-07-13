// test/features/auth/presentation/controllers/phone_entry_controller_test.dart
//
// Tests for [PhoneEntryController]: validateIdentifier, checkAndNavigate,
// signInWithGoogle, and signInWithApple.

import 'package:flutter_test/flutter_test.dart';
import 'package:get/get.dart';
import 'package:ghar360/features/auth/data/auth_method.dart';
import 'package:ghar360/features/auth/data/auth_repository.dart';
import 'package:ghar360/features/auth/data/last_auth_method_store.dart';
import 'package:ghar360/features/auth/presentation/controllers/phone_entry_controller.dart';
import 'package:mocktail/mocktail.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../../../../helpers/getx_test_binding.dart';
import '../../../../helpers/mocks.dart';

class MockLastAuthMethodStore extends Mock implements LastAuthMethodStore {}

void main() {
  late MockAuthRepository authRepository;
  late MockLastAuthMethodStore lastAuthMethodStore;

  setUp(() {
    GetxTestBinding.init();

    authRepository = MockAuthRepository();
    lastAuthMethodStore = MockLastAuthMethodStore();
    when(() => lastAuthMethodStore.lastMethod).thenReturn(null);
    when(() => lastAuthMethodStore.lastIdentifierHint).thenReturn(null);
    when(() => authRepository.lastAuthMethodStore).thenReturn(lastAuthMethodStore);

    GetxTestBinding.bind().register<AuthRepository>(authRepository);
  });

  tearDown(() {
    GetxTestBinding.reset();
  });

  PhoneEntryController createController() {
    final controller = PhoneEntryController();
    Get.put<PhoneEntryController>(controller, permanent: true);
    return controller;
  }

  group('PhoneEntryController', () {
    test('initial state is idle with default values', () {
      final controller = createController();

      expect(controller.state.value, IdentifierEntryState.idle);
      expect(controller.isLoading.value, isFalse);
      expect(controller.isGoogleLoading.value, isFalse);
      expect(controller.isAppleLoading.value, isFalse);
      expect(controller.errorMessage.value, isEmpty);
      expect(controller.looksLikeEmail.value, isFalse);
      expect(controller.isIdentifierFocused.value, isFalse);
      expect(controller.validationShakeTrigger.value, 0);
    });

    test('isGoogleAvailable always returns true', () {
      final controller = createController();
      expect(controller.isGoogleAvailable, isTrue);
    });

    test('isAppleAvailable delegates to authRepository', () {
      when(() => authRepository.isAppleSignInSupported).thenReturn(true);
      final controller = createController();
      expect(controller.isAppleAvailable, isTrue);

      when(() => authRepository.isAppleSignInSupported).thenReturn(false);
      expect(controller.isAppleAvailable, isFalse);
    });

    group('validateIdentifier', () {
      late PhoneEntryController controller;

      setUp(() {
        controller = createController();
      });

      test('returns null for valid email', () {
        expect(controller.validateIdentifier('user@example.com'), isNull);
      });

      test('returns null for valid 10-digit phone', () {
        expect(controller.validateIdentifier('9876543210'), isNull);
      });

      test('returns null for valid +91 phone', () {
        expect(controller.validateIdentifier('+919876543210'), isNull);
      });

      test('returns error for empty string', () {
        expect(controller.validateIdentifier(''), isNotNull);
      });

      test('returns error for null', () {
        expect(controller.validateIdentifier(null), isNotNull);
      });

      test('returns error for invalid identifier', () {
        expect(controller.validateIdentifier('not-valid'), isNotNull);
      });
    });

    group('checkAndNavigate', () {
      test('increments validationShakeTrigger when form is unvalidated', () async {
        final controller = createController();

        // No form attached → currentState is null → validate() ?? false → false
        await controller.checkAndNavigate();

        expect(controller.validationShakeTrigger.value, 1);
        expect(controller.state.value, IdentifierEntryState.idle);
        expect(controller.isLoading.value, isFalse);
      });
    });

    group('signInWithGoogle', () {
      test('sets isGoogleLoading during the call', () async {
        final controller = createController();
        when(() => authRepository.signInWithGoogle()).thenAnswer((_) async {});

        // Start the flow; the future completes immediately (mock)
        final future = controller.signInWithGoogle();
        expect(controller.isGoogleLoading.value, isTrue);

        await future;
        expect(controller.isGoogleLoading.value, isFalse);
        expect(controller.errorMessage.value, isEmpty);
      });

      test('clears errorMessage on success', () async {
        final controller = createController();
        controller.errorMessage.value = 'previous error';
        when(() => authRepository.signInWithGoogle()).thenAnswer((_) async {});

        await controller.signInWithGoogle();

        expect(controller.errorMessage.value, isEmpty);
      });

      test('sets errorMessage on AuthException', () async {
        final controller = createController();
        when(
          () => authRepository.signInWithGoogle(),
        ).thenThrow(const AuthException('Google auth failed'));

        await controller.signInWithGoogle();

        expect(controller.errorMessage.value, 'Google auth failed');
        expect(controller.isGoogleLoading.value, isFalse);
      });

      test('silently handles cancel message', () async {
        final controller = createController();
        when(
          () => authRepository.signInWithGoogle(),
        ).thenThrow(const AuthException('Sign-in was cancelled'));

        await controller.signInWithGoogle();

        // Cancel message is not surfaced to the user
        expect(controller.errorMessage.value, isEmpty);
        expect(controller.isGoogleLoading.value, isFalse);
      });

      test('sets generic error on unexpected exception', () async {
        final controller = createController();
        when(() => authRepository.signInWithGoogle()).thenThrow(Exception('unexpected'));

        await controller.signInWithGoogle();

        expect(controller.errorMessage.value, isNotEmpty);
        expect(controller.isGoogleLoading.value, isFalse);
      });

      test('is idempotent — returns early if already loading', () async {
        final controller = createController();
        when(() => authRepository.signInWithGoogle()).thenAnswer((_) async {
          await Future<void>.delayed(const Duration(milliseconds: 50));
        });

        // Start first call
        final first = controller.signInWithGoogle();
        // Second call while first is in flight
        await controller.signInWithGoogle();

        await first;

        // signInWithGoogle was called only once
        verify(() => authRepository.signInWithGoogle()).called(1);
      });
    });

    group('signInWithApple', () {
      test('sets isAppleLoading during the call', () async {
        final controller = createController();
        when(() => authRepository.signInWithApple()).thenAnswer((_) async => AuthResponse());

        final future = controller.signInWithApple();
        expect(controller.isAppleLoading.value, isTrue);

        await future;
        expect(controller.isAppleLoading.value, isFalse);
        expect(controller.errorMessage.value, isEmpty);
      });

      test('sets errorMessage on AuthException', () async {
        final controller = createController();
        when(
          () => authRepository.signInWithApple(),
        ).thenThrow(const AuthException('Apple auth failed'));

        await controller.signInWithApple();

        expect(controller.errorMessage.value, 'Apple auth failed');
        expect(controller.isAppleLoading.value, isFalse);
      });

      test('silently handles cancel message', () async {
        final controller = createController();
        when(
          () => authRepository.signInWithApple(),
        ).thenThrow(const AuthException('Sign-in was cancelled'));

        await controller.signInWithApple();

        expect(controller.errorMessage.value, isEmpty);
      });

      test('sets generic error on unexpected exception', () async {
        final controller = createController();
        when(() => authRepository.signInWithApple()).thenThrow(Exception('unexpected'));

        await controller.signInWithApple();

        expect(controller.errorMessage.value, isNotEmpty);
        expect(controller.isAppleLoading.value, isFalse);
      });

      test('clears errorMessage on success', () async {
        final controller = createController();
        controller.errorMessage.value = 'previous error';
        when(() => authRepository.signInWithApple()).thenAnswer((_) async => AuthResponse());

        await controller.signInWithApple();

        expect(controller.errorMessage.value, isEmpty);
      });

      test('is idempotent — returns early if already loading', () async {
        final controller = createController();
        when(() => authRepository.signInWithApple()).thenAnswer((_) async {
          await Future<void>.delayed(const Duration(milliseconds: 50));
          return AuthResponse();
        });

        final first = controller.signInWithApple();
        await controller.signInWithApple();

        await first;

        verify(() => authRepository.signInWithApple()).called(1);
      });
    });

    group('onInit last-method hint', () {
      test('loads lastMethod and lastIdentifierHint from the store', () {
        when(() => lastAuthMethodStore.lastMethod).thenReturn(AuthMethod.google);
        when(() => lastAuthMethodStore.lastIdentifierHint).thenReturn('j***@gmail.com');

        final controller = createController();

        expect(controller.lastMethod.value, AuthMethod.google);
        expect(controller.lastIdentifierHint.value, 'j***@gmail.com');
      });
    });

    group('looksLikeEmail listener', () {
      test('updates to true when identifier text contains @', () {
        final controller = createController();

        expect(controller.looksLikeEmail.value, isFalse);

        controller.identifierController.text = 'user@example.com';

        expect(controller.looksLikeEmail.value, isTrue);
      });

      test('updates to false when identifier text is a phone', () {
        final controller = createController();
        controller.identifierController.text = 'user@example.com';

        expect(controller.looksLikeEmail.value, isTrue);

        controller.identifierController.text = '9876543210';

        expect(controller.looksLikeEmail.value, isFalse);
      });

      test('stays false for empty text', () {
        final controller = createController();

        controller.identifierController.text = '';

        expect(controller.looksLikeEmail.value, isFalse);
      });
    });

    group('isIdentifierFocused', () {
      test('starts unfocused and exposes a usable focus node', () {
        final controller = createController();

        expect(controller.isIdentifierFocused.value, isFalse);
        expect(controller.identifierFocusNode.hasFocus, isFalse);
      });
    });

    group('validateIdentifier additional cases', () {
      test('trims whitespace before validating email', () {
        final controller = createController();

        expect(controller.validateIdentifier('  user@example.com  '), isNull);
      });

      test('trims whitespace before validating phone', () {
        final controller = createController();

        expect(controller.validateIdentifier('  9876543210  '), isNull);
      });

      test('returns error for identifier with only spaces', () {
        final controller = createController();

        expect(controller.validateIdentifier('     '), isNotNull);
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
