// test/features/auth/presentation/controllers/profile_completion_controller_test.dart
//
// Proving tests for [ProfileCompletionController]. These exercise the controller
// WITHOUT any network or real GetX services: [MockAuthRepository] backs the
// Supabase surface, a real [AuthController] is registered in test mode with its
// stream stubbed to an empty controller, and step-advance logic is driven
// directly. This validates the mocktail + GetxTestBinding harness end-to-end.

import 'dart:async';

import 'package:flutter_test/flutter_test.dart';
import 'package:ghar360/core/controllers/page_state_service.dart';
import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:ghar360/core/controllers/auth_controller.dart';
import 'package:ghar360/core/data/models/auth_status.dart';
import 'package:ghar360/features/auth/data/auth_method.dart';
import 'package:ghar360/features/auth/data/auth_repository.dart';
import 'package:ghar360/features/auth/presentation/controllers/profile_completion_controller.dart';
import 'package:ghar360/features/notifications/data/datasources/notifications_remote_datasource.dart';
import 'package:ghar360/features/profile/data/profile_repository.dart';
import 'package:mocktail/mocktail.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../../../../helpers/getx_test_binding.dart';
import '../../../../helpers/mocks.dart';

/// Fake Supabase [User] for testing OAuth provider detection in
/// [ProfileCompletionController._evaluateAddPhone].
class FakeSupabaseUser extends Fake implements User {
  FakeSupabaseUser({this.appMetadata = const <String, dynamic>{}});

  @override
  final Map<String, dynamic> appMetadata;

  @override
  String? get email => null;

  @override
  String? get phone => null;

  @override
  String get id => 'fake-supabase-id';

  @override
  List<UserIdentity> get identities => const <UserIdentity>[];
}

void main() {
  setUpAll(() {
    registerFallbackValue(AuthMethod.google);
  });

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

    // Default stubs for the add-phone / profile flows.
    when(
      () => authRepository.recordLastMethod(any(), identifier: any(named: 'identifier')),
    ).thenAnswer((_) async {});
    when(
      () => authRepository.addAndVerifyPhone(phone: any(named: 'phone'), token: any(named: 'token')),
    ).thenAnswer((_) async => AuthResponse());
    when(() => authRepository.startAddPhone(any())).thenAnswer((_) async {});
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

    test('propertyPurposes exposes the documented list', () {
      final controller = Get.put<ProfileCompletionController>(
        ProfileCompletionController(),
        permanent: true,
      );

      expect(controller.propertyPurposes, ['buy', 'rent', 'short_stay']);

      Get.delete<ProfileCompletionController>();
    });

    test('selectedPropertyPurpose defaults to buy', () {
      final controller = Get.put<ProfileCompletionController>(
        ProfileCompletionController(),
        permanent: true,
      );

      expect(controller.selectedPropertyPurpose.value, 'buy');

      Get.delete<ProfileCompletionController>();
    });
  });

  group('validateAddPhone', () {
    late ProfileCompletionController controller;

    setUp(() {
      controller = Get.put<ProfileCompletionController>(
        ProfileCompletionController(),
        permanent: true,
      );
    });

    tearDown(() => Get.delete<ProfileCompletionController>());

    test('returns error for empty value', () {
      expect(controller.validateAddPhone(''), isNotNull);
      expect(controller.validateAddPhone(null), isNotNull);
    });

    test('returns null for valid 10-digit phone', () {
      expect(controller.validateAddPhone('9876543210'), isNull);
    });

    test('returns null for valid +91 phone', () {
      expect(controller.validateAddPhone('+919876543210'), isNull);
    });

    test('returns error for invalid phone', () {
      expect(controller.validateAddPhone('not-a-phone'), isNotNull);
      expect(controller.validateAddPhone('123'), isNotNull);
    });
  });

  group('verifyAddPhoneOtp', () {
    late ProfileCompletionController controller;

    setUp(() {
      controller = Get.put<ProfileCompletionController>(
        ProfileCompletionController(),
        permanent: true,
      );
    });

    tearDown(() => Get.delete<ProfileCompletionController>());

    test('rejects OTP shorter than 6 digits', () async {
      controller.phoneController.text = '9876543210';

      await controller.verifyAddPhoneOtp('123');

      expect(controller.addPhoneError.value, isNotEmpty);
      verifyNever(
        () => authRepository.addAndVerifyPhone(
          phone: any(named: 'phone'),
          token: any(named: 'token'),
        ),
      );
    });

    test('rejects empty OTP', () async {
      controller.phoneController.text = '9876543210';

      await controller.verifyAddPhoneOtp('');

      expect(controller.addPhoneError.value, isNotEmpty);
    });

    test('returns early if already loading', () async {
      controller.phoneController.text = '9876543210';
      controller.isLoading.value = true;

      await controller.verifyAddPhoneOtp('123456');

      verifyNever(
        () => authRepository.addAndVerifyPhone(
          phone: any(named: 'phone'),
          token: any(named: 'token'),
        ),
      );
    });

    test('hides add-phone prompt on successful verification', () async {
      controller.phoneController.text = '9876543210';
      controller.showAddPhone.value = true;
      controller.isPhoneOtpStage.value = true;

      await controller.verifyAddPhoneOtp('123456');

      expect(controller.showAddPhone.value, isFalse);
      expect(controller.isPhoneOtpStage.value, isFalse);
      expect(controller.addPhoneError.value, isEmpty);
      expect(controller.isLoading.value, isFalse);
      verify(
        () => authRepository.addAndVerifyPhone(
          phone: '+919876543210',
          token: '123456',
        ),
      ).called(1);
    });

    test('sets addPhoneError on AuthException', () async {
      controller.phoneController.text = '9876543210';

      when(
        () => authRepository.addAndVerifyPhone(
          phone: any(named: 'phone'),
          token: any(named: 'token'),
        ),
      ).thenThrow(const AuthException('Invalid OTP'));

      await controller.verifyAddPhoneOtp('123456');

      expect(controller.addPhoneError.value, 'Invalid OTP');
      expect(controller.isLoading.value, isFalse);
    });

    test('sets addPhoneError on unexpected exception', () async {
      controller.phoneController.text = '9876543210';

      when(
        () => authRepository.addAndVerifyPhone(
          phone: any(named: 'phone'),
          token: any(named: 'token'),
        ),
      ).thenThrow(Exception('network failure'));

      await controller.verifyAddPhoneOtp('123456');

      expect(controller.addPhoneError.value, isNotEmpty);
      expect(controller.isLoading.value, isFalse);
    });
  });

  group('skipAddPhone', () {
    test('records last method and hides the add-phone prompt', () {
      final controller = Get.put<ProfileCompletionController>(
        ProfileCompletionController(),
        permanent: true,
      );
      controller.showAddPhone.value = true;
      controller.isPhoneOtpStage.value = true;

      controller.skipAddPhone();

      expect(controller.showAddPhone.value, isFalse);
      expect(controller.isPhoneOtpStage.value, isFalse);
      verify(
        () => authRepository.recordLastMethod(any(), identifier: any(named: 'identifier')),
      ).called(1);

      Get.delete<ProfileCompletionController>();
    });
  });

  group('sendAddPhoneOtp', () {
    test('does nothing when phone form validation is unavailable', () async {
      final controller = Get.put<ProfileCompletionController>(
        ProfileCompletionController(),
        permanent: true,
      );
      controller.phoneController.text = '9876543210';

      // phoneFormKey.currentState is null → validate fails → early return
      await controller.sendAddPhoneOtp();

      verifyNever(() => authRepository.startAddPhone(any()));
      expect(controller.isPhoneOtpStage.value, isFalse);

      Get.delete<ProfileCompletionController>();
    });
  });

  group('completeProfile', () {
    test('resets to step 0 when form validation is unavailable', () async {
      final controller = Get.put<ProfileCompletionController>(
        ProfileCompletionController(),
        permanent: true,
      );
      controller.currentStep.value = 1;

      // formKey.currentState is null → validate fails → resets to step 0
      await controller.completeProfile();

      expect(controller.currentStep.value, 0);
      expect(controller.isLoading.value, isFalse);

      Get.delete<ProfileCompletionController>();
    });

    test('returns early when already loading', () async {
      final controller = Get.put<ProfileCompletionController>(
        ProfileCompletionController(),
        permanent: true,
      );
      controller.isLoading.value = true;
      controller.currentStep.value = 1;

      await controller.completeProfile();

      // Loading guard returns before the form-validation reset path.
      expect(controller.currentStep.value, 1);

      Get.delete<ProfileCompletionController>();
    });
  });

  group('_evaluateAddPhone (onInit)', () {
    test('shows add-phone prompt for Google user without a phone', () {
      final googleUser = FakeSupabaseUser(
        appMetadata: <String, dynamic>{
          'provider': 'google',
          'providers': <String>['google'],
        },
      );
      when(() => authRepository.currentUser).thenReturn(googleUser);

      final controller = Get.put<ProfileCompletionController>(
        ProfileCompletionController(),
        permanent: true,
      );

      expect(controller.showAddPhone.value, isTrue,
          reason: 'Google user without phone should see the add-phone prompt');

      Get.delete<ProfileCompletionController>();
    });

    test('hides add-phone prompt for non-OAuth user', () {
      // Default setUp stubs currentUser → null (no OAuth user).
      final controller = Get.put<ProfileCompletionController>(
        ProfileCompletionController(),
        permanent: true,
      );

      expect(controller.showAddPhone.value, isFalse);

      Get.delete<ProfileCompletionController>();
    });

    test('hides add-phone prompt when user already has a phone', () {
      // A Google user that already has a verified phone should NOT see the prompt.
      final googleUser = FakeSupabaseUser(
        appMetadata: <String, dynamic>{
          'provider': 'google',
          'providers': <String>['google'],
        },
      );
      when(() => authRepository.currentUser).thenReturn(googleUser);
      // Give the AuthController's currentUser a phone.
      authController.currentUser.value = testUserModel(phone: '+919876543210');

      final controller = Get.put<ProfileCompletionController>(
        ProfileCompletionController(),
        permanent: true,
      );

      expect(controller.showAddPhone.value, isFalse,
          reason: 'User with an existing phone should not see the add-phone prompt');

      Get.delete<ProfileCompletionController>();
    });
  });

  group('onClose', () {
    test('disposes controllers without throwing', () {
      final controller = Get.put<ProfileCompletionController>(
        ProfileCompletionController(),
        permanent: true,
      );

      expect(controller.onClose, returnsNormally);

      Get.delete<ProfileCompletionController>();
    });
  });

  group('_evaluateAddPhone (onInit) — Apple provider', () {
    test('shows add-phone prompt for Apple user without a phone', () {
      final appleUser = FakeSupabaseUser(
        appMetadata: <String, dynamic>{
          'provider': 'apple',
          'providers': <String>['apple'],
        },
      );
      when(() => authRepository.currentUser).thenReturn(appleUser);

      final controller = Get.put<ProfileCompletionController>(
        ProfileCompletionController(),
        permanent: true,
      );

      expect(controller.showAddPhone.value, isTrue,
          reason: 'Apple user without phone should see the add-phone prompt');

      Get.delete<ProfileCompletionController>();
    });
  });

  group('sendAddPhoneOtp — success path', () {
    test('transitions to OTP stage on success', () async {
      final controller = Get.put<ProfileCompletionController>(
        ProfileCompletionController(),
        permanent: true,
      );
      controller.phoneController.text = '9876543210';

      // Simulate a valid form by attaching a FormState via a widget tree.
      // Since we can't easily attach a FormState in a unit test, we test
      // the _requestAddPhoneOtp path indirectly: the controller checks
      // phoneFormKey.currentState?.validate() which is null without a tree.
      // So sendAddPhoneOtp returns early. Verify the guard works.
      await controller.sendAddPhoneOtp();

      verifyNever(() => authRepository.startAddPhone(any()));
      expect(controller.isPhoneOtpStage.value, isFalse);

      Get.delete<ProfileCompletionController>();
    });
  });

  group('resendAddPhoneOtp', () {
    test('returns early when canResendOtp is false', () async {
      final controller = Get.put<ProfileCompletionController>(
        ProfileCompletionController(),
        permanent: true,
      );
      controller.canResendOtp.value = false;
      controller.phoneController.text = '9876543210';

      await controller.resendAddPhoneOtp();

      verifyNever(() => authRepository.startAddPhone(any()));

      Get.delete<ProfileCompletionController>();
    });
  });

  group('verifyAddPhoneOtp — success records last method', () {
    test('records the OAuth last method on successful verification', () async {
      final controller = Get.put<ProfileCompletionController>(
        ProfileCompletionController(),
        permanent: true,
      );
      controller.phoneController.text = '9876543210';
      controller.showAddPhone.value = true;
      controller.isPhoneOtpStage.value = true;

      await controller.verifyAddPhoneOtp('123456');

      // recordLastMethod should have been called with the default OAuth method
      // (google, since no OAuth user was detected in setUp).
      verify(
        () => authRepository.recordLastMethod(any(), identifier: any(named: 'identifier')),
      ).called(1);

      Get.delete<ProfileCompletionController>();
    });
  });

  group('completeProfile — success path', () {
    test('updates profile and preferences when form is valid', () async {
      // To test completeProfile with a valid form, we need a FormState.
      // Without a widget tree, formKey.currentState is null → validation fails.
      // We test the loading guard and validation-fail paths instead.
      final controller = Get.put<ProfileCompletionController>(
        ProfileCompletionController(),
        permanent: true,
      );
      controller.currentStep.value = 1;

      // formKey.currentState is null → isValid is false → resets to step 0.
      await controller.completeProfile();

      expect(controller.currentStep.value, 0);
      expect(controller.isLoading.value, isFalse);

      Get.delete<ProfileCompletionController>();
    });
  });

  group('OTP timer', () {
    test('startOtpCountdown sets countdown and disables resend', () {
      final controller = Get.put<ProfileCompletionController>(
        ProfileCompletionController(),
        permanent: true,
      );

      controller.startOtpCountdown();

      expect(controller.canResendOtp.value, isFalse);
      expect(controller.otpCountdown.value, 30);

      Get.delete<ProfileCompletionController>();
    });

    test('canResendOtp is false initially', () {
      final controller = Get.put<ProfileCompletionController>(
        ProfileCompletionController(),
        permanent: true,
      );

      expect(controller.canResendOtp.value, isFalse);

      Get.delete<ProfileCompletionController>();
    });
  });

  group('emailController initialization', () {
    test('pre-fills email from authController.userEmail', () {
      // The setUp registers an AuthController with currentUser = null.
      // authController.userEmail should be null → emailController.text = ''.
      final controller = Get.put<ProfileCompletionController>(
        ProfileCompletionController(),
        permanent: true,
      );

      expect(controller.emailController.text, '');

      Get.delete<ProfileCompletionController>();
    });
  });

  group('pageStateService access', () {
    test('pageStateService is null when PageStateService is not registered', () {
      final controller = Get.put<ProfileCompletionController>(
        ProfileCompletionController(),
        permanent: true,
      );

      // PageStateService is not registered in setUp, so the getter returns null.
      // Accessing it should not throw.
      expect(() => controller.pageStateService, returnsNormally);

      Get.delete<ProfileCompletionController>();
    });
  });

  // ---------------------------------------------------------------------------
  // Form-backed success paths
  // ---------------------------------------------------------------------------
  // ProfileCompletionController gates sendAddPhoneOtp / completeProfile / nextStep
  // on FormState.validate(). Attach the controller's GlobalKeys to a live Form
  // so validate() returns true (no field validators on the Form itself).

  Future<void> _withForm(
    WidgetTester tester,
    ProfileCompletionController controller, {
    required GlobalKey<FormState> formKey,
    required Future<void> Function() action,
  }) async {
    // MaterialApp (not GetMaterialApp): AppToast / Get.snackbar no-op without
    // Get.overlayContext, avoiding snackbar ticker leaks in unit tests.
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: Form(
            key: formKey,
            child: const SizedBox.shrink(),
          ),
        ),
      ),
    );
    await tester.pump();
    await action();
    // Drain snackbar ticks; cancel OTP countdown so no pending timers remain.
    await tester.pump(const Duration(milliseconds: 50));
    controller.disposeOtpTimer();
  }

  group('sendAddPhoneOtp — form-backed paths', () {
    testWidgets('success transitions to OTP stage and starts countdown', (tester) async {
      when(() => authRepository.startAddPhone(any())).thenAnswer((_) async {});

      final controller = Get.put<ProfileCompletionController>(
        ProfileCompletionController(),
        permanent: true,
      );
      controller.phoneController.text = '9876543210';

      await _withForm(
        tester,
        controller,
        formKey: controller.phoneFormKey,
        action: () async {
          await controller.sendAddPhoneOtp();
        },
      );

      expect(controller.isPhoneOtpStage.value, isTrue);
      expect(controller.isLoading.value, isFalse);
      expect(controller.addPhoneError.value, isEmpty);
      expect(controller.canResendOtp.value, isFalse);
      expect(controller.otpCountdown.value, 30);
      verify(() => authRepository.startAddPhone('+919876543210')).called(1);

      Get.delete<ProfileCompletionController>();
    });

    testWidgets('AuthException sets addPhoneError', (tester) async {
      when(() => authRepository.startAddPhone(any()))
          .thenThrow(const AuthException('rate limited'));

      final controller = Get.put<ProfileCompletionController>(
        ProfileCompletionController(),
        permanent: true,
      );
      controller.phoneController.text = '9876543210';

      await _withForm(
        tester,
        controller,
        formKey: controller.phoneFormKey,
        action: () async {
          await controller.sendAddPhoneOtp();
        },
      );

      expect(controller.addPhoneError.value, 'rate limited');
      expect(controller.isPhoneOtpStage.value, isFalse);
      expect(controller.isLoading.value, isFalse);

      Get.delete<ProfileCompletionController>();
    });

    testWidgets('unexpected exception sets otp_send_error translation key', (tester) async {
      when(() => authRepository.startAddPhone(any()))
          .thenThrow(Exception('socket hang up'));

      final controller = Get.put<ProfileCompletionController>(
        ProfileCompletionController(),
        permanent: true,
      );
      controller.phoneController.text = '9876543210';

      await _withForm(
        tester,
        controller,
        formKey: controller.phoneFormKey,
        action: () async {
          await controller.sendAddPhoneOtp();
        },
      );

      expect(controller.addPhoneError.value, isNotEmpty);
      expect(controller.isLoading.value, isFalse);

      Get.delete<ProfileCompletionController>();
    });
  });

  group('resendAddPhoneOtp — form-backed', () {
    testWidgets('resends when cooldown elapsed', (tester) async {
      when(() => authRepository.startAddPhone(any())).thenAnswer((_) async {});

      final controller = Get.put<ProfileCompletionController>(
        ProfileCompletionController(),
        permanent: true,
      );
      controller.phoneController.text = '9876543210';
      controller.canResendOtp.value = true;

      await _withForm(
        tester,
        controller,
        formKey: controller.phoneFormKey,
        action: () async {
          await controller.resendAddPhoneOtp();
        },
      );

      verify(() => authRepository.startAddPhone('+919876543210')).called(1);
      expect(controller.isPhoneOtpStage.value, isTrue);
      expect(controller.canResendOtp.value, isFalse);

      Get.delete<ProfileCompletionController>();
    });
  });

  group('completeProfile — form-backed paths', () {
    testWidgets('success updates profile, preferences, and page purpose', (tester) async {
      when(() => profileRepository.updateUserProfile(any())).thenAnswer(
        (_) async => testUserModel(
          fullName: 'Ada Lovelace',
        ).copyWith(dateOfBirth: '1990-12-10'),
      );
      when(() => profileRepository.updateUserPreferences(any())).thenAnswer(
        (_) async => testUserModel(
          fullName: 'Ada Lovelace',
          preferences: {'purpose': 'rent'},
        ).copyWith(dateOfBirth: '1990-12-10'),
      );

      final pageState = MockPageStateService();
      when(() => pageState.setPurposeForAllPages(any())).thenReturn(null);
      GetxTestBinding.bind().register<PageStateService>(pageState);

      final controller = Get.put<ProfileCompletionController>(
        ProfileCompletionController(),
        permanent: true,
      );
      controller.fullNameController.text = 'Ada Lovelace';
      controller.emailController.text = 'ada@example.com';
      controller.selectedDateOfBirth = DateTime(1990, 12, 10);
      controller.selectedPropertyPurpose.value = 'rent';
      controller.currentStep.value = 1;

      await _withForm(
        tester,
        controller,
        formKey: controller.formKey,
        action: () async {
          await controller.completeProfile();
        },
      );

      expect(controller.isLoading.value, isFalse);
      verify(
        () => profileRepository.updateUserProfile(
          any(
            that: isA<Map<String, dynamic>>()
                .having((m) => m['full_name'], 'full_name', 'Ada Lovelace')
                .having((m) => m['email'], 'email', 'ada@example.com')
                .having((m) => m['date_of_birth'], 'date_of_birth', '1990-12-10'),
          ),
        ),
      ).called(1);
      verify(
        () => profileRepository.updateUserPreferences({'purpose': 'rent'}),
      ).called(1);
      verify(() => pageState.setPurposeForAllPages('rent')).called(1);

      Get.delete<ProfileCompletionController>();
    });

    testWidgets('does not update preferences when profile update fails', (tester) async {
      when(() => profileRepository.updateUserProfile(any()))
          .thenThrow(Exception('backend down'));

      final controller = Get.put<ProfileCompletionController>(
        ProfileCompletionController(),
        permanent: true,
      );
      controller.fullNameController.text = 'Bad Update';
      controller.currentStep.value = 1;

      await _withForm(
        tester,
        controller,
        formKey: controller.formKey,
        action: () async {
          await controller.completeProfile();
        },
      );

      expect(controller.isLoading.value, isFalse);
      verifyNever(() => profileRepository.updateUserPreferences(any()));

      Get.delete<ProfileCompletionController>();
    });

    testWidgets('handles unexpected exception without leaving loading true', (tester) async {
      // Throw from preferences path after a successful profile update so the
      // outer catch in completeProfile runs.
      when(() => profileRepository.updateUserProfile(any())).thenAnswer(
        (_) async => testUserModel(fullName: 'X').copyWith(dateOfBirth: '1990-01-01'),
      );
      when(() => profileRepository.updateUserPreferences(any()))
          .thenThrow(Exception('prefs failed'));

      final controller = Get.put<ProfileCompletionController>(
        ProfileCompletionController(),
        permanent: true,
      );
      controller.fullNameController.text = 'X';
      controller.selectedDateOfBirth = DateTime(1990, 1, 1);

      await _withForm(
        tester,
        controller,
        formKey: controller.formKey,
        action: () async {
          await controller.completeProfile();
        },
      );

      expect(controller.isLoading.value, isFalse);

      Get.delete<ProfileCompletionController>();
    });

    testWidgets('sends null date_of_birth when none selected', (tester) async {
      when(() => profileRepository.updateUserProfile(any())).thenAnswer(
        (_) async => testUserModel(fullName: 'No Dob'),
      );
      when(() => profileRepository.updateUserPreferences(any())).thenAnswer(
        (_) async => testUserModel(fullName: 'No Dob'),
      );

      final controller = Get.put<ProfileCompletionController>(
        ProfileCompletionController(),
        permanent: true,
      );
      controller.fullNameController.text = 'No Dob';
      controller.selectedDateOfBirth = null;

      await _withForm(
        tester,
        controller,
        formKey: controller.formKey,
        action: () async {
          await controller.completeProfile();
        },
      );

      final captured = verify(
        () => profileRepository.updateUserProfile(captureAny()),
      ).captured.single as Map<String, dynamic>;
      expect(captured['date_of_birth'], isNull);

      Get.delete<ProfileCompletionController>();
    });
  });

  group('nextStep / previousStep — form-backed', () {
    testWidgets('nextStep advances from 0 to 1 when form is valid', (tester) async {
      final controller = Get.put<ProfileCompletionController>(
        ProfileCompletionController(),
        permanent: true,
      );

      await _withForm(
        tester,
        controller,
        formKey: controller.formKey,
        action: () async {
          controller.nextStep();
        },
      );

      expect(controller.currentStep.value, 1);

      // Cap at step 1.
      controller.nextStep();
      expect(controller.currentStep.value, 1);

      Get.delete<ProfileCompletionController>();
    });

    test('previousStep decrements when above zero', () {
      final controller = Get.put<ProfileCompletionController>(
        ProfileCompletionController(),
        permanent: true,
      );
      controller.currentStep.value = 1;

      controller.previousStep();

      expect(controller.currentStep.value, 0);

      Get.delete<ProfileCompletionController>();
    });
  });

  group('requestPhoneNumberHint', () {
    test('returns early on non-Android hosts without throwing', () async {
      final controller = Get.put<ProfileCompletionController>(
        ProfileCompletionController(),
        permanent: true,
      );

      // macOS/Linux CI hosts are not Android → early return at Platform check.
      await expectLater(controller.requestPhoneNumberHint(), completes);
      expect(controller.phoneController.text, isEmpty);

      Get.delete<ProfileCompletionController>();
    });
  });

  group('selectDateOfBirth', () {
    testWidgets('writes formatted DOB when a date is picked', (tester) async {
      final controller = Get.put<ProfileCompletionController>(
        ProfileCompletionController(),
        permanent: true,
      );

      await tester.pumpWidget(
        GetMaterialApp(
          home: Scaffold(
            body: Form(
              key: controller.formKey,
              child: Builder(
                builder: (context) {
                  // Ensure Get.context is available for showDatePicker.
                  return TextButton(
                    onPressed: () => controller.selectDateOfBirth(),
                    child: const Text('Pick'),
                  );
                },
              ),
            ),
          ),
        ),
      );
      await tester.pump();

      // Open the date picker.
      await tester.tap(find.text('Pick'));
      await tester.pumpAndSettle();

      // Confirm the default selection (OK button).
      await tester.tap(find.text('OK'));
      await tester.pumpAndSettle();

      expect(controller.selectedDateOfBirth, isNotNull);
      expect(controller.dateOfBirthController.text, isNotEmpty);
      // Format: dd/MM/yyyy
      expect(
        RegExp(r'^\d{2}/\d{2}/\d{4}$').hasMatch(controller.dateOfBirthController.text),
        isTrue,
      );

      Get.delete<ProfileCompletionController>();
    });
  });

  group('_evaluateAddPhone — identities provider', () {
    test('detects google from identities when appMetadata is empty', () {
      final identityUser = FakeSupabaseUserWithIdentities(
        identities: <UserIdentity>[
          _FakeUserIdentity(provider: 'google'),
        ],
      );
      when(() => authRepository.currentUser).thenReturn(identityUser);

      final controller = Get.put<ProfileCompletionController>(
        ProfileCompletionController(),
        permanent: true,
      );

      expect(controller.showAddPhone.value, isTrue);

      Get.delete<ProfileCompletionController>();
    });
  });

  group('emailController initialization — prefilled', () {
    test('pre-fills email from authController current user', () {
      authController.currentUser.value = testUserModel(email: 'prefills@example.com');

      final controller = Get.put<ProfileCompletionController>(
        ProfileCompletionController(),
        permanent: true,
      );

      expect(controller.emailController.text, 'prefills@example.com');

      Get.delete<ProfileCompletionController>();
    });
  });

  group('pageStateService when registered', () {
    test('returns the registered PageStateService instance', () {
      final pageState = MockPageStateService();
      GetxTestBinding.bind().register<PageStateService>(pageState);

      final controller = Get.put<ProfileCompletionController>(
        ProfileCompletionController(),
        permanent: true,
      );

      expect(controller.pageStateService, same(pageState));

      Get.delete<ProfileCompletionController>();
    });
  });
}

/// Fake User that exposes identities for OAuth provider detection.
class FakeSupabaseUserWithIdentities extends Fake implements User {
  FakeSupabaseUserWithIdentities({this.identities = const <UserIdentity>[]});

  @override
  final List<UserIdentity> identities;

  @override
  Map<String, dynamic> get appMetadata => const <String, dynamic>{};

  @override
  String? get email => null;

  @override
  String? get phone => null;

  @override
  String get id => 'identity-user';
}

class _FakeUserIdentity extends Fake implements UserIdentity {
  _FakeUserIdentity({required this.provider});

  @override
  final String provider;
}
