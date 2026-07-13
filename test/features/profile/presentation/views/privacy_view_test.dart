import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:get/get.dart';
import 'package:ghar360/core/controllers/auth_controller.dart';
import 'package:ghar360/core/translations/app_translations.dart';
import 'package:ghar360/features/auth/data/auth_repository.dart';
import 'package:ghar360/features/profile/data/static_page_repository.dart';
import 'package:ghar360/features/profile/presentation/views/privacy_view.dart';
import 'package:mocktail/mocktail.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../../../../helpers/getx_test_binding.dart';
import '../../../../helpers/mocks.dart';

class _FakeUser extends Fake implements User {
  _FakeUser({this.email});

  @override
  final String? email;

  @override
  String? get phone => null;

  @override
  String get id => 'fake-user-id';
}

class _MockStaticPageRepository extends GetxServiceMock implements StaticPageRepository {}

void main() {
  late MockAuthRepository authRepository;
  late MockAuthController authController;
  late _MockStaticPageRepository staticPageRepository;
  late _FakeUser user;

  setUp(() {
    // Suppress RenderFlex overflow errors that occur in narrow test screens,
    // while still forwarding other errors to the original handler so
    // takeException() can retrieve them.
    final originalOnError = FlutterError.onError;
    FlutterError.onError = (details) {
      if (!details.summary.toString().contains('overflowed')) {
        originalOnError?.call(details);
      }
    };

    GetxTestBinding.init();

    authRepository = MockAuthRepository();
    authController = MockAuthController();
    staticPageRepository = _MockStaticPageRepository();
    user = _FakeUser(email: 'owner@example.com');

    when(() => authController.isDeleting).thenReturn(false.obs);
    when(() => authRepository.currentUser).thenReturn(user);
    when(() => authController.deleteAccount()).thenAnswer((_) async => true);

    GetxTestBinding.bind()
      ..register<AuthRepository>(authRepository)
      ..register<AuthController>(authController)
      ..register<StaticPageRepository>(staticPageRepository);
  });

  tearDown(() {
    FlutterError.onError = FlutterError.presentError;
    GetxTestBinding.reset();
  });

  Future<void> pumpPrivacyView(WidgetTester tester) async {
    await tester.pumpWidget(
      GetMaterialApp(
        translations: AppTranslations(),
        locale: const Locale('en', 'US'),
        fallbackLocale: const Locale('en', 'US'),
        home: const PrivacyView(),
      ),
    );
  }

  Future<void> openAndFillPasswordDialog(
    WidgetTester tester, {
    required String currentPassword,
    required String newPassword,
  }) async {
    await tester.tap(find.byKey(const ValueKey('qa.profile.privacy.change_password')));
    await tester.pumpAndSettle();

    final fields = find.byType(TextFormField);
    expect(fields, findsNWidgets(3));

    await tester.enterText(fields.at(0), currentPassword);
    await tester.enterText(fields.at(1), newPassword);
    await tester.enterText(fields.at(2), newPassword);
  }

  testWidgets('verifies the current password before updating to a new password', (tester) async {
    when(
      () => authRepository.signInWithEmailPassword('owner@example.com', 'CurrentPass1!'),
    ).thenAnswer((_) async => AuthResponse(user: user));
    when(() => authRepository.updateUserPassword('NewPass123!')).thenAnswer((_) async => user);

    await pumpPrivacyView(tester);
    await openAndFillPasswordDialog(
      tester,
      currentPassword: 'CurrentPass1!',
      newPassword: 'NewPass123!',
    );

    await tester.tap(find.text('Update Password'));
    await tester.pumpAndSettle();

    verify(
      () => authRepository.signInWithEmailPassword('owner@example.com', 'CurrentPass1!'),
    ).called(1);
    verify(() => authRepository.updateUserPassword('NewPass123!')).called(1);

    await tester.pump(const Duration(seconds: 4));
    await tester.pumpAndSettle();
  });

  testWidgets('does not update the password when current password verification fails', (
    tester,
  ) async {
    when(
      () => authRepository.signInWithEmailPassword('owner@example.com', 'WrongPass1!'),
    ).thenThrow(Exception('bad password'));

    await pumpPrivacyView(tester);
    await openAndFillPasswordDialog(
      tester,
      currentPassword: 'WrongPass1!',
      newPassword: 'NewPass123!',
    );

    await tester.tap(find.text('Update Password'));
    await tester.pumpAndSettle();

    expect(find.text('Incorrect password'), findsOneWidget);
    verify(
      () => authRepository.signInWithEmailPassword('owner@example.com', 'WrongPass1!'),
    ).called(1);
    verifyNever(() => authRepository.updateUserPassword(any()));
  });

  group('PrivacyView — screen layout', () {
    testWidgets('renders the screen semantics identifier', (tester) async {
      await pumpPrivacyView(tester);
      await tester.pump();

      expect(find.byKey(const ValueKey('qa.profile.privacy.screen')), findsOneWidget);
    });

    testWidgets('renders account security section with change password item', (tester) async {
      await pumpPrivacyView(tester);
      await tester.pump();

      expect(find.text('account_security'.tr), findsOneWidget);
      expect(find.text('change_password'.tr), findsOneWidget);
      expect(find.text('update_account_password'.tr), findsOneWidget);
      expect(find.byKey(const ValueKey('qa.profile.privacy.change_password')), findsOneWidget);
    });

    testWidgets('renders policies legal section with all five policy items', (tester) async {
      await pumpPrivacyView(tester);
      await tester.pump();

      expect(find.text('policies_legal'.tr), findsOneWidget);
      expect(find.text('privacy_terms_of_service_title'.tr), findsOneWidget);
      expect(find.text('privacy_policy_item_title'.tr), findsOneWidget);
      expect(find.text('privacy_content_guidelines_title'.tr), findsOneWidget);
      expect(find.text('privacy_content_takedown_title'.tr), findsOneWidget);
      expect(find.text('privacy_grievance_redressal_title'.tr), findsOneWidget);
    });

    testWidgets('renders policy item icons', (tester) async {
      await pumpPrivacyView(tester);
      await tester.pump();

      expect(find.byIcon(Icons.description_outlined), findsOneWidget);
      expect(find.byIcon(Icons.privacy_tip_outlined), findsOneWidget);
      expect(find.byIcon(Icons.rule_folder_outlined), findsOneWidget);
      expect(find.byIcon(Icons.remove_circle_outline), findsOneWidget);
      expect(find.byIcon(Icons.support_agent), findsOneWidget);
    });

    testWidgets('renders account management section with delete button', (tester) async {
      await pumpPrivacyView(tester);
      await tester.pump();

      expect(find.text('account_management'.tr), findsOneWidget);
      expect(find.text('delete_account_description'.tr), findsOneWidget);
      expect(find.byKey(const ValueKey('qa.profile.privacy.delete_account')), findsOneWidget);
      expect(find.text('delete_account'.tr), findsOneWidget);
    });

    testWidgets('tapping change password opens the change password dialog', (tester) async {
      await pumpPrivacyView(tester);
      await tester.pump();

      await tester.tap(find.byKey(const ValueKey('qa.profile.privacy.change_password')));
      await tester.pumpAndSettle();

      expect(find.text('change_password'.tr), findsWidgets);
      expect(find.text('current_password'.tr), findsOneWidget);
      expect(find.text('new_password'.tr), findsOneWidget);
      expect(find.text('confirm_password'.tr), findsOneWidget);
    });

    testWidgets('cancel button closes the change password dialog', (tester) async {
      await pumpPrivacyView(tester);
      await tester.pump();

      await tester.tap(find.byKey(const ValueKey('qa.profile.privacy.change_password')));
      await tester.pumpAndSettle();

      // Tap the cancel button in the dialog.
      await tester.tap(find.text('cancel'.tr).last);
      await tester.pumpAndSettle();

      // Dialog closed — current_password label no longer visible.
      expect(find.text('current_password'.tr), findsNothing);
    });
  });

  group('PrivacyView — delete account dialog', () {
    testWidgets('tapping delete account opens the confirmation dialog', (tester) async {
      await pumpPrivacyView(tester);
      await tester.pump();

      // Scroll the delete button into view.
      await tester.ensureVisible(find.byKey(const ValueKey('qa.profile.privacy.delete_account')));
      await tester.pump();

      await tester.tap(
        find.byKey(const ValueKey('qa.profile.privacy.delete_account')),
        warnIfMissed: false,
      );
      await tester.pumpAndSettle();

      // The dialog content text is unique (the title collides with the main
      // button's "Delete Account" label).
      expect(find.text('delete_account_dialog_content'.tr), findsOneWidget);
      expect(find.byType(AlertDialog), findsOneWidget);
    });

    testWidgets('delete button is disabled until DELETE is typed', (tester) async {
      await pumpPrivacyView(tester);
      await tester.pump();

      await tester.ensureVisible(find.byKey(const ValueKey('qa.profile.privacy.delete_account')));
      await tester.pump();
      await tester.tap(
        find.byKey(const ValueKey('qa.profile.privacy.delete_account')),
        warnIfMissed: false,
      );
      await tester.pumpAndSettle();

      // The confirm TextButton wraps the "Delete" text.
      final deleteButtonFinder = find.ancestor(
        of: find.text('delete'.tr),
        matching: find.byType(TextButton),
      );
      final button = tester.widget<TextButton>(deleteButtonFinder);
      expect(button.onPressed, isNull);
    });

    testWidgets('typing DELETE enables the delete button', (tester) async {
      await pumpPrivacyView(tester);
      await tester.pump();

      await tester.ensureVisible(find.byKey(const ValueKey('qa.profile.privacy.delete_account')));
      await tester.pump();
      await tester.tap(
        find.byKey(const ValueKey('qa.profile.privacy.delete_account')),
        warnIfMissed: false,
      );
      await tester.pumpAndSettle();

      // Type DELETE into the confirmation field.
      await tester.enterText(find.byType(TextFormField), 'DELETE');
      await tester.pump();

      // The delete button should now be enabled (onPressed not null).
      final deleteButtonFinder = find.ancestor(
        of: find.text('delete'.tr),
        matching: find.byType(TextButton),
      );
      final button = tester.widget<TextButton>(deleteButtonFinder);
      expect(button.onPressed, isNotNull);
    });

    testWidgets('typing wrong text does not enable the delete button', (tester) async {
      await pumpPrivacyView(tester);
      await tester.pump();

      await tester.ensureVisible(find.byKey(const ValueKey('qa.profile.privacy.delete_account')));
      await tester.pump();
      await tester.tap(
        find.byKey(const ValueKey('qa.profile.privacy.delete_account')),
        warnIfMissed: false,
      );
      await tester.pumpAndSettle();

      await tester.enterText(find.byType(TextFormField), 'remove');
      await tester.pump();

      final deleteButtonFinder = find.ancestor(
        of: find.text('delete'.tr),
        matching: find.byType(TextButton),
      );
      final button = tester.widget<TextButton>(deleteButtonFinder);
      expect(button.onPressed, isNull);
    });

    testWidgets('delete account dialog has cancel and delete actions', (tester) async {
      await pumpPrivacyView(tester);
      await tester.pump();

      await tester.ensureVisible(find.byKey(const ValueKey('qa.profile.privacy.delete_account')));
      await tester.pump();
      await tester.tap(
        find.byKey(const ValueKey('qa.profile.privacy.delete_account')),
        warnIfMissed: false,
      );
      await tester.pumpAndSettle();

      // The dialog has both cancel and delete action buttons.
      expect(find.text('cancel'.tr), findsOneWidget);
      expect(find.text('delete'.tr), findsOneWidget);
      expect(find.byType(TextButton), findsNWidgets(2));
    });
  });

  group('PrivacyView — policy navigation', () {
    testWidgets('tapping a policy item navigates to PolicyPageView', (tester) async {
      when(() => staticPageRepository.fetchPublicPage(any())).thenThrow(Exception('network error'));

      await pumpPrivacyView(tester);
      await tester.pump();

      // Tap the first policy item (terms of service).
      await tester.tap(find.text('privacy_terms_of_service_title'.tr));
      await tester.pumpAndSettle();

      // PolicyPageView should be pushed and show the error fallback.
      expect(find.text('failed_to_load_content'.tr), findsOneWidget);
    });

    testWidgets('tapping privacy policy item navigates to PolicyPageView', (tester) async {
      when(() => staticPageRepository.fetchPublicPage(any())).thenThrow(Exception('network error'));

      await pumpPrivacyView(tester);
      await tester.pump();

      await tester.tap(find.text('privacy_policy_item_title'.tr));
      await tester.pumpAndSettle();

      expect(find.text('failed_to_load_content'.tr), findsOneWidget);
    });
  });
}
