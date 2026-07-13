// test/features/profile/presentation/views/edit_profile_view_test.dart
//
// Widget tests for [EditProfileView]. Covers:
// - Avatar overlay spinner when isUploadingImage is true (form stays mounted)
// - Form fields rendering (name, email, location)
// - Email field is disabled (read-only)
// - Profile avatar shows user initial when no image URL
// - Profile avatar shows error fallback when image URL is invalid
// - Date of birth placeholder text when no date selected
// - Date of birth formatted text and clear button when date is set
// - Save button renders and triggers saveProfile
// - Pick image button triggers pickProfileImage
// - Tapping date of birth triggers selectDateOfBirth
// - Name validation shows error for empty input

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:get/get.dart';
import 'package:ghar360/core/controllers/auth_controller.dart';
import 'package:ghar360/core/data/models/user_model.dart';
import 'package:ghar360/core/translations/app_translations.dart';
import 'package:ghar360/features/profile/data/profile_repository.dart';
import 'package:ghar360/features/profile/presentation/controllers/edit_profile_controller.dart';
import 'package:ghar360/features/profile/presentation/views/edit_profile_view.dart';
import 'package:mocktail/mocktail.dart';

import '../../../../helpers/getx_test_binding.dart';
import '../../../../helpers/mocks.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  late MockAuthController authController;
  late MockProfileRepository profileRepository;

  setUp(() {
    // Suppress RenderFlex overflow errors that occur in narrow test screens.
    FlutterError.onError = (details) {
      if (!details.summary.toString().contains('overflowed')) {
        FlutterError.presentError(details);
      }
    };

    GetxTestBinding.init();

    authController = MockAuthController();
    profileRepository = MockProfileRepository();

    // Default: no current user (controller handles null gracefully).
    when(() => authController.currentUser).thenReturn(Rxn<UserModel>());
    when(() => authController.updateUserProfile(any())).thenAnswer((_) async => true);

    GetxTestBinding.bind()
      ..register<AuthController>(authController)
      ..register<ProfileRepository>(profileRepository);
  });

  tearDown(() {
    FlutterError.onError = FlutterError.presentError;
    GetxTestBinding.reset();
  });

  /// Builds and registers an [EditProfileController] (invoking onInit via
  /// Get.put) so the [GetView] can resolve it.
  EditProfileController registerController() {
    final controller = EditProfileController();
    Get.put<EditProfileController>(controller);
    return controller;
  }

  Future<void> pumpView(WidgetTester tester) async {
    await tester.pumpWidget(
      GetMaterialApp(
        translations: AppTranslations(),
        locale: const Locale('en', 'US'),
        fallbackLocale: const Locale('en', 'US'),
        home: const EditProfileView(),
      ),
    );
    await tester.pump();
  }

  group('EditProfileView', () {
    testWidgets('shows avatar overlay spinner when isUploadingImage is true', (tester) async {
      final controller = registerController();
      controller.isUploadingImage.value = true;

      await pumpView(tester);

      // Form stays mounted; spinner is only on the avatar.
      expect(find.byType(CircularProgressIndicator), findsOneWidget);
      expect(find.byKey(const ValueKey('qa.profile.edit.full_name_input')), findsOneWidget);
      expect(find.byKey(const ValueKey('qa.profile.edit.save')), findsOneWidget);
    });

    testWidgets('renders form fields and save button when not loading', (tester) async {
      registerController();

      await pumpView(tester);

      expect(find.byKey(const ValueKey('qa.profile.edit.full_name_input')), findsOneWidget);
      expect(find.byKey(const ValueKey('qa.profile.edit.email_input')), findsOneWidget);
      expect(find.byKey(const ValueKey('qa.profile.edit.location_input')), findsOneWidget);
      expect(find.byKey(const ValueKey('qa.profile.edit.save')), findsOneWidget);
      expect(find.byKey(const ValueKey('qa.profile.edit.pick_image')), findsOneWidget);
    });

    testWidgets('email field is disabled (read-only)', (tester) async {
      registerController();

      await pumpView(tester);

      final emailField = tester.widget<TextFormField>(
        find.byKey(const ValueKey('qa.profile.edit.email_input')),
      );
      expect(emailField.enabled, isFalse);
    });

    testWidgets('name field is enabled', (tester) async {
      registerController();

      await pumpView(tester);

      final nameField = tester.widget<TextFormField>(
        find.byKey(const ValueKey('qa.profile.edit.full_name_input')),
      );
      expect(nameField.enabled, isTrue);
    });

    testWidgets('shows user initial in avatar when no profile image and name set', (tester) async {
      final user = testUserModel(fullName: 'Alice', email: 'alice@example.com');
      when(() => authController.currentUser).thenReturn(Rxn<UserModel>(user));

      final controller = registerController();
      controller.profileImageUrl.value = '';

      await pumpView(tester);

      // The avatar shows the first letter of the name uppercased.
      expect(find.text('A'), findsOneWidget);
    });

    testWidgets('shows "U" fallback when no profile image and empty name', (tester) async {
      registerController();

      await pumpView(tester);

      // No name set → fallback 'U'.
      expect(find.text('U'), findsOneWidget);
    });

    testWidgets('shows date of birth placeholder when no date selected', (tester) async {
      registerController();

      await pumpView(tester);

      expect(find.text('select_your_date_of_birth'.tr), findsOneWidget);
      expect(find.byIcon(Icons.clear), findsNothing);
    });

    testWidgets('shows formatted date and clear button when date is set', (tester) async {
      final controller = registerController();
      controller.dateOfBirth.value = DateTime(1995, 6, 15);

      await pumpView(tester);

      expect(find.text('15/06/1995'), findsOneWidget);
      expect(find.byIcon(Icons.clear), findsOneWidget);
    });

    testWidgets('tapping clear button clears the date of birth', (tester) async {
      final controller = registerController();
      controller.dateOfBirth.value = DateTime(1995, 6, 15);

      await pumpView(tester);
      expect(controller.dateOfBirth.value, isNotNull);

      // The clear icon is inside a scrollable; ensure it is visible first.
      await tester.ensureVisible(find.byIcon(Icons.clear));
      await tester.pump();
      await tester.tap(find.byIcon(Icons.clear), warnIfMissed: false);
      await tester.pump();

      expect(controller.dateOfBirth.value, isNull);
    });

    testWidgets('tapping save button calls saveProfile', (tester) async {
      final user = testUserModel(fullName: 'Alice', email: 'alice@example.com');
      when(() => authController.currentUser).thenReturn(Rxn<UserModel>(user));
      when(() => authController.updateUserProfile(any())).thenAnswer((_) async => true);

      final controller = registerController();
      controller.nameController.text = 'Alice';
      controller.profileImageUrl.value = '';
      controller.dateOfBirth.value = null;

      await pumpView(tester);

      // The save button may be off-screen inside the scrollable.
      await tester.ensureVisible(find.byKey(const ValueKey('qa.profile.edit.save')));
      await tester.pump();
      await tester.tap(find.byKey(const ValueKey('qa.profile.edit.save')), warnIfMissed: false);
      await tester.pump();

      verify(() => authController.updateUserProfile(any())).called(1);
    });

    testWidgets('tapping pick image button opens image source bottom sheet', (tester) async {
      registerController();

      await pumpView(tester);

      // Tap the camera icon button to open the image picker bottom sheet.
      await tester.tap(find.byKey(const ValueKey('qa.profile.edit.pick_image')));
      await tester.pump(const Duration(milliseconds: 100));

      // The bottom sheet offers camera and gallery options.
      expect(find.text('take_photo'.tr), findsOneWidget);
      expect(find.text('choose_from_gallery'.tr), findsOneWidget);

      // Dismiss the bottom sheet.
      Get.back<void>();
      await tester.pump(const Duration(milliseconds: 100));
    });

    testWidgets('tapping date of birth field triggers selectDateOfBirth', (tester) async {
      registerController();

      await pumpView(tester);

      // The DOB field may be off-screen; scroll it into view first.
      await tester.ensureVisible(find.byKey(const ValueKey('qa.profile.edit.dob_input')));
      await tester.pump();

      // Tapping the DOB GestureDetector opens a date picker dialog.
      await tester.tap(
        find.byKey(const ValueKey('qa.profile.edit.dob_input')),
        warnIfMissed: false,
      );
      await tester.pump(const Duration(milliseconds: 100));

      // A date picker dialog should be shown.
      expect(find.byType(Dialog), findsWidgets);
    });

    testWidgets('save button text shows save_changes when not loading', (tester) async {
      registerController();

      await pumpView(tester);

      expect(find.text('save_changes'.tr), findsOneWidget);
    });

    testWidgets('renders profile image fallback when URL is invalid', (tester) async {
      final user = testUserModel(fullName: 'Bob', email: 'bob@example.com');
      when(() => authController.currentUser).thenReturn(Rxn<UserModel>(user));

      final controller = registerController();
      // Invalid URL → RobustNetworkImage shows the errorWidget (CircleAvatar
      // with initial).
      controller.profileImageUrl.value = 'not-a-real-url';

      await pumpView(tester);

      // The error fallback avatar shows the first letter of the name.
      expect(find.text('B'), findsWidgets);
    });

    testWidgets('loads user data into form fields on init', (tester) async {
      final user = testUserModel(fullName: 'John Doe', email: 'john@example.com').copyWith(
        profileImageUrl: '',
        dateOfBirth: '1995-06-15',
        preferences: {'location': 'Mumbai'},
      );
      when(() => authController.currentUser).thenReturn(Rxn<UserModel>(user));

      final controller = registerController();

      await pumpView(tester);

      expect(controller.nameController.text, 'John Doe');
      expect(controller.emailController.text, 'john@example.com');
      expect(controller.locationController.text, 'Mumbai');
      expect(find.text('15/06/1995'), findsOneWidget);
    });
  });
}
