// test/features/auth/presentation/controllers/profile_completion_controller_test.dart
//
// Proving tests for [ProfileCompletionController]. These exercise the controller
// WITHOUT any network or real GetX services: [MockAuthRepository] backs the
// Supabase surface, a real [AuthController] is registered in test mode with its
// stream stubbed to an empty controller, and step-advance logic is driven
// directly. This validates the mocktail + GetxTestBinding harness end-to-end.

import 'dart:async';

import 'package:flutter_test/flutter_test.dart';
import 'package:get/get.dart';
import 'package:ghar360/core/controllers/auth_controller.dart';
import 'package:ghar360/core/data/models/auth_status.dart';
import 'package:ghar360/features/auth/data/auth_repository.dart';
import 'package:ghar360/features/auth/presentation/controllers/profile_completion_controller.dart';
import 'package:ghar360/features/notifications/data/datasources/notifications_remote_datasource.dart';
import 'package:ghar360/features/profile/data/profile_repository.dart';
import 'package:mocktail/mocktail.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../../../../helpers/getx_test_binding.dart';
import '../../../../helpers/mocks.dart';

void main() {
  late MockAuthRepository authRepository;
  late MockProfileRepository profileRepository;
  late MockNotificationsRemoteDatasource notificationsDatasource;
  late AuthController authController;
  late StreamController<User?> authStateController;

  setUp(() {
    GetxTestBinding.init();

    authRepository = MockAuthRepository();
    profileRepository = MockProfileRepository();
    notificationsDatasource = MockNotificationsRemoteDatasource();
    // AuthController._initialize listens to this stream in onInit; provide a
    // quiet, never-emitting stream so no auth-state processing kicks off.
    authStateController = StreamController<User?>.broadcast();
    when(() => authRepository.onAuthStateChange).thenAnswer((_) => authStateController.stream);
    when(() => authRepository.currentUser).thenReturn(null);
    when(() => authRepository.currentSession).thenReturn(null);

    // Register every dependency the controllers look up via Get.find.
    // AuthController's field initializers resolve AuthRepository,
    // ProfileRepository, and NotificationsRemoteDatasource at construction.
    GetxTestBinding.bind()
      ..register<AuthRepository>(authRepository)
      ..register<ProfileRepository>(profileRepository)
      ..register<NotificationsRemoteDatasource>(notificationsDatasource);

    // AuthController is constructed here so its onInit runs against the mock
    // repository. It is registered so ProfileCompletionController can find it.
    authController = AuthController();
    Get.put<AuthController>(authController, permanent: true);
  });

  tearDown(() {
    // Close the stream first so the AuthController subscription cancels cleanly,
    // then tear down the whole GetX container.
    if (!authStateController.isClosed) {
      // Drain any pending events before closing.
      authStateController.close();
    }
    GetxTestBinding.reset();
  });

  group('ProfileCompletionController', () {
    test('initial reactive state is the documented default', () {
      final controller = Get.put<ProfileCompletionController>(
        ProfileCompletionController(),
        permanent: true,
      );

      // Constructed but not yet bootstrapped: no loading, step 0, default
      // purpose, add-phone prompt hidden.
      expect(controller.isLoading.value, isFalse);
      expect(controller.currentStep.value, 0);
      expect(controller.selectedPropertyPurpose.value, 'buy');
      expect(controller.showAddPhone.value, isFalse);
      expect(controller.isPhoneOtpStage.value, isFalse);

      Get.delete<ProfileCompletionController>();
    });

    test('nextStep does not advance currentStep when form validation is unavailable', () {
      final controller = Get.put<ProfileCompletionController>(
        ProfileCompletionController(),
        permanent: true,
      );

      // The form key is unattached (no widget tree), so currentState is null;
      // `formKey.currentState?.validate() ?? false` therefore returns false on
      // step 0, which would block the advance. Override by starting from a state
      // where validation has already passed: simulate a validated step 0 by
      // forcing the controller to step 0 with a valid form via the public API
      // is not possible without a tree — instead assert the clamp behaviour:
      // calling nextStep repeatedly never exceeds the max step (1).
      //
      // Start at step 0; because validation can't pass without a Form, we verify
      // the guard instead: currentStep stays 0 when validation is unavailable.
      controller.nextStep();
      expect(
        controller.currentStep.value,
        0,
        reason: 'nextStep must not advance when the form is unvalidated',
      );

      Get.delete<ProfileCompletionController>();
    });

    test('skipToHome flips the shared AuthController status to authenticated', () {
      // AuthController._initialize set the status to unauthenticated because
      // the repository's currentUser is null.
      expect(
        authController.authStatus.value,
        AuthStatus.unauthenticated,
        reason: 'precondition: AuthController starts unauthenticated',
      );

      final controller = Get.put<ProfileCompletionController>(
        ProfileCompletionController(),
        permanent: true,
      );

      controller.skipToHome();

      expect(
        authController.authStatus.value,
        AuthStatus.authenticated,
        reason: 'skipToHome must set AuthController to authenticated',
      );

      Get.delete<ProfileCompletionController>();
    });

    test('previousStep never drops currentStep below zero', () {
      final controller = Get.put<ProfileCompletionController>(
        ProfileCompletionController(),
        permanent: true,
      );

      expect(controller.currentStep.value, 0);

      controller.previousStep();
      controller.previousStep();

      expect(controller.currentStep.value, 0, reason: 'previousStep must clamp at 0');

      Get.delete<ProfileCompletionController>();
    });
  });
}
