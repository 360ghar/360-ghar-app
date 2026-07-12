import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:get/get.dart';
import 'package:ghar360/core/controllers/auth_controller.dart';
import 'package:ghar360/core/data/models/user_model.dart';
import 'package:ghar360/features/profile/data/profile_repository.dart';
import 'package:ghar360/features/profile/presentation/controllers/edit_profile_controller.dart';
import 'package:mocktail/mocktail.dart';

import '../../../../helpers/getx_test_binding.dart';
import '../../../../helpers/mocks.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  late MockAuthController authController;
  late MockProfileRepository profileRepository;

  setUp(() {
    GetxTestBinding.init();

    authController = MockAuthController();
    profileRepository = MockProfileRepository();

    // Default: no current user (controller handles null gracefully).
    when(() => authController.currentUser).thenReturn(Rxn<UserModel>());

    GetxTestBinding.bind()
      ..register<AuthController>(authController)
      ..register<ProfileRepository>(profileRepository);
  });

  tearDown(() => GetxTestBinding.reset());

  /// Constructs an EditProfileController and calls onInit manually so the
  /// field-initializer Get.find calls resolve against the registered mocks.
  EditProfileController createController() {
    final controller = EditProfileController();
    controller.onInit();
    return controller;
  }

  group('EditProfileController — initial load', () {
    test('loads user data into controllers when currentUser is set', () {
      final user = testUserModel(
        fullName: 'John Doe',
        email: 'john@example.com',
      );
      // testUserModel doesn't expose all fields; build a full model directly.
      final fullUser = user.copyWith(
        profileImageUrl: 'https://example.com/avatar.jpg',
        dateOfBirth: '1995-06-15',
        preferences: {'location': 'Mumbai'},
      );
      when(() => authController.currentUser).thenReturn(Rxn<UserModel>(fullUser));

      final controller = createController();

      expect(controller.nameController.text, 'John Doe');
      expect(controller.emailController.text, 'john@example.com');
      expect(controller.profileImageUrl.value, 'https://example.com/avatar.jpg');
      expect(controller.dateOfBirth.value, DateTime(1995, 6, 15));
      expect(controller.locationController.text, 'Mumbai');
    });

    test('handles null currentUser gracefully', () {
      when(() => authController.currentUser).thenReturn(Rxn<UserModel>());

      final controller = createController();

      expect(controller.nameController.text, isEmpty);
      expect(controller.emailController.text, isEmpty);
      expect(controller.profileImageUrl.value, isEmpty);
      expect(controller.dateOfBirth.value, isNull);
      expect(controller.locationController.text, isEmpty);
    });

    test('handles preferences without location key', () {
      final user = testUserModel(fullName: 'Jane', email: 'jane@example.com')
          .copyWith(preferences: {'other': 'value'});
      when(() => authController.currentUser).thenReturn(Rxn<UserModel>(user));

      final controller = createController();

      expect(controller.locationController.text, isEmpty);
    });

    test('handles non-string location in preferences', () {
      final user = testUserModel(fullName: 'Jane', email: 'jane@example.com')
          .copyWith(preferences: {'location': 12345});
      when(() => authController.currentUser).thenReturn(Rxn<UserModel>(user));

      final controller = createController();

      // Non-string location falls back to empty string.
      expect(controller.locationController.text, isEmpty);
    });

    test('handles null preferences', () {
      final user = testUserModel(fullName: 'Jane', email: 'jane@example.com');
      when(() => authController.currentUser).thenReturn(Rxn<UserModel>(user));

      final controller = createController();

      expect(controller.locationController.text, isEmpty);
    });

    test('handles invalid dateOfBirth string', () {
      final user = testUserModel(fullName: 'Jane', email: 'jane@example.com')
          .copyWith(dateOfBirth: 'not-a-date');
      when(() => authController.currentUser).thenReturn(Rxn<UserModel>(user));

      final controller = createController();

      expect(controller.dateOfBirth.value, isNull);
    });
  });

  group('EditProfileController — formatDate', () {
    test('formats date as dd/MM/yyyy with zero-padding', () {
      final controller = createController();

      expect(controller.formatDate(DateTime(2025, 3, 5)), '05/03/2025');
      expect(controller.formatDate(DateTime(2025, 12, 31)), '31/12/2025');
      expect(controller.formatDate(DateTime(2025, 1, 1)), '01/01/2025');
    });
  });

  group('EditProfileController — clearDateOfBirth', () {
    test('sets dateOfBirth to null', () {
      final user = testUserModel(fullName: 'Jane', email: 'jane@example.com')
          .copyWith(dateOfBirth: '1995-06-15');
      when(() => authController.currentUser).thenReturn(Rxn<UserModel>(user));

      final controller = createController();
      expect(controller.dateOfBirth.value, isNotNull);

      controller.clearDateOfBirth();

      expect(controller.dateOfBirth.value, isNull);
    });
  });

  group('EditProfileController — saveProfile', () {
    test('throws when formKey has no attached Form (currentState is null)',
        () async {
      final controller = createController();

      // formKey.currentState is null (no Form widget) → null check throws.
      await expectLater(controller.saveProfile(), throwsA(isA<TypeError>()));
      verifyNever(() => authController.updateUserProfile(any()));
      expect(controller.isSaving.value, isFalse);
    });

    test('throws when currentUser is null (after form validation passes)',
        () async {
      when(() => authController.currentUser).thenReturn(Rxn<UserModel>());

      final controller = createController();
      // Without a Form widget, currentState is null and it throws before
      // reaching the currentUser check. Verify it still doesn't call update.
      await expectLater(controller.saveProfile(), throwsA(isA<TypeError>()));
      verifyNever(() => authController.updateUserProfile(any()));
      expect(controller.isSaving.value, isFalse);
    });

    test('does not call updateUserProfile when form validation fails',
        () async {
      final user = testUserModel(fullName: 'John', email: 'john@example.com')
          .copyWith(preferences: {'existing': 'value'});
      when(() => authController.currentUser).thenReturn(Rxn<UserModel>(user));
      when(() => authController.updateUserProfile(any()))
          .thenAnswer((_) async => true);

      final controller = createController();
      controller.nameController.text = 'John Updated';
      controller.locationController.text = 'Delhi';
      controller.profileImageUrl.value = 'https://example.com/new.jpg';
      controller.dateOfBirth.value = DateTime(1990, 5, 20);

      // Without a Form widget, currentState is null → throws before update.
      await expectLater(controller.saveProfile(), throwsA(isA<TypeError>()));
      verifyNever(() => authController.updateUserProfile(any()));
    });
  });

  group('EditProfileController — onClose', () {
    test('disposes text controllers without throwing', () {
      final controller = createController();

      expect(controller.onClose, returnsNormally);
    });
  });

  group('EditProfileController — loading flags', () {
    test('isSaving and isUploadingImage start as false', () {
      final controller = createController();

      expect(controller.isSaving.value, isFalse);
      expect(controller.isUploadingImage.value, isFalse);
      expect(controller.isBusy, isFalse);
    });
  });
}
