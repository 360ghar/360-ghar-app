import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:ghar360/core/controllers/auth_controller.dart';
import 'package:ghar360/core/data/models/auth_status.dart';
import 'package:ghar360/core/design/paper/knife_icons.dart';
import 'package:ghar360/core/utils/app_exceptions.dart';
import 'package:ghar360/features/profile/presentation/views/privacy_view.dart';
import 'package:mocktail/mocktail.dart';
import 'package:supabase_flutter/supabase_flutter.dart' hide AuthState;

import '../../../../helpers/auth_test_harness.dart' show MockAuthRepository;
import '../../../../helpers/knife_finders.dart';
import '../../../../helpers/profile_test_harness.dart';

void main() {
  late ProfileHarness h;
  late MockAuthRepository authRepository;
  late User user;
  setUp(() {
    h = ProfileHarness();
    authRepository = h.repository;
    user = const User(
      id: 'account-a',
      appMetadata: {},
      userMetadata: {},
      aud: 'authenticated',
      createdAt: '2024-01-01',
      email: 'owner@example.com',
    );
    when(() => authRepository.currentUser).thenReturn(user);
  });
  tearDown(() => h.close());
  Future<void> pumpPrivacyView(WidgetTester tester) => h.pump(tester, const PrivacyView());
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

  testWidgets('account change clears password fields owned by the previous user', (tester) async {
    await pumpPrivacyView(tester);
    await openAndFillPasswordDialog(
      tester,
      currentPassword: 'OldSecret1!',
      newPassword: 'NewSecret1!',
    );
    h.session.set(AuthState(status: AuthStatus.authenticated, user: profile('account-b')));
    await tester.pumpAndSettle();
    for (final field in tester.widgetList<TextFormField>(find.byType(TextFormField))) {
      expect(field.controller!.text, isEmpty);
    }
    verifyNever(() => authRepository.updateUserPassword(any()));
  });

  testWidgets('account change requires a new destructive confirmation', (tester) async {
    await pumpPrivacyView(tester);
    final open = find.byKey(const ValueKey('qa.profile.privacy.delete_account'));
    await tester.pumpAndSettle();
    await tester.scrollUntilVisible(open, 250);
    await tester.pumpAndSettle();
    await tester.ensureVisible(open);
    await tester.pumpAndSettle();
    await tester.tap(open);
    await tester.pumpAndSettle();
    final confirmation = find.byKey(const ValueKey('qa.profile.privacy.delete_confirm_input'));
    final submit = find.byKey(const ValueKey('qa.profile.privacy.delete_confirm'));
    await tester.enterText(confirmation, 'DELETE');
    await tester.pump();
    expect(tester.widget<TextButton>(submit).onPressed, isNotNull);
    h.session.set(AuthState(status: AuthStatus.authenticated, user: profile('account-b')));
    await tester.pumpAndSettle();
    expect(tester.widget<TextField>(confirmation).controller!.text, isEmpty);
    expect(tester.widget<TextButton>(submit).onPressed, isNull);
    expect(h.session.deletes, 0);
    h.session.set(const AuthState(status: AuthStatus.unauthenticated));
    await tester.pumpAndSettle();
    await tester.enterText(confirmation, 'DELETE');
    await tester.pump();
    expect(tester.widget<TextButton>(submit).onPressed, isNull);
  });

  group('PrivacyView — screen layout', () {
    testWidgets('renders the screen semantics identifier', (tester) async {
      final semantics = tester.ensureSemantics();
      try {
        await pumpPrivacyView(tester);
        await tester.pump();

        expect(find.byKey(const ValueKey('qa.profile.privacy.screen')), findsOneWidget);
        expect(find.bySemanticsIdentifier('qa.profile.privacy.screen'), findsOneWidget);
        expect(find.bySemanticsLabel(RegExp(r'qa\.profile')), findsNothing);
      } finally {
        semantics.dispose();
      }
    });

    testWidgets('renders account security section with change password item', (tester) async {
      final semantics = tester.ensureSemantics();
      try {
        await pumpPrivacyView(tester);
        await tester.pump();

        expect(find.text(tr('account_security')), findsOneWidget);
        expect(find.text(tr('change_password')), findsOneWidget);
        expect(find.text(tr('update_account_password')), findsOneWidget);
        expect(find.byKey(const ValueKey('qa.profile.privacy.change_password')), findsOneWidget);
        expect(find.bySemanticsIdentifier('qa.profile.privacy.change_password'), findsOneWidget);
        expect(find.bySemanticsLabel(RegExp(r'qa\.profile')), findsNothing);
      } finally {
        semantics.dispose();
      }
    });

    testWidgets('renders policies legal section with all five policy items', (tester) async {
      await pumpPrivacyView(tester);
      await tester.pump();

      expect(find.text(tr('policies_legal')), findsOneWidget);
      expect(find.text(tr('privacy_terms_of_service_title')), findsOneWidget);
      expect(find.text(tr('privacy_policy_item_title')), findsOneWidget);
      expect(find.text(tr('privacy_content_guidelines_title')), findsOneWidget);
      expect(find.text(tr('privacy_content_takedown_title')), findsOneWidget);
      expect(find.text(tr('privacy_grievance_redressal_title')), findsOneWidget);
    });

    testWidgets('renders policy item icons', (tester) async {
      await pumpPrivacyView(tester);
      await tester.pump();

      // Terms of service and content guidelines share the document icon.
      expect(findKnife(KnifeIcon.document), findsNWidgets(2));
      expect(findKnife(KnifeIcon.shield), findsOneWidget);
      expect(findKnife(KnifeIcon.minus), findsOneWidget);
      expect(findKnife(KnifeIcon.chat), findsOneWidget);
    });

    testWidgets('renders account management section with delete button', (tester) async {
      await pumpPrivacyView(tester);
      await tester.pump();

      await tester.scrollUntilVisible(
        find.byKey(const ValueKey('qa.profile.privacy.delete_account')),
        250,
      );
      expect(find.text(tr('account_management')), findsOneWidget);
      expect(find.text(tr('delete_account_description')), findsOneWidget);
      expect(find.byKey(const ValueKey('qa.profile.privacy.delete_account')), findsOneWidget);
      expect(find.text(tr('delete_account')), findsOneWidget);
    });

    testWidgets('tapping change password opens the change password dialog', (tester) async {
      await pumpPrivacyView(tester);
      await tester.pump();

      await tester.tap(find.byKey(const ValueKey('qa.profile.privacy.change_password')));
      await tester.pumpAndSettle();

      expect(find.text(tr('change_password')), findsWidgets);
      expect(find.text(tr('current_password')), findsOneWidget);
      expect(find.text(tr('new_password')), findsOneWidget);
      expect(find.text(tr('confirm_password')), findsOneWidget);
    });

    testWidgets('cancel button closes the change password dialog', (tester) async {
      await pumpPrivacyView(tester);
      await tester.pump();

      await tester.tap(find.byKey(const ValueKey('qa.profile.privacy.change_password')));
      await tester.pumpAndSettle();

      // Tap the cancel button in the dialog.
      await tester.tap(find.text(tr('cancel')).last);
      await tester.pumpAndSettle();

      // Dialog closed — current_password label no longer visible.
      expect(find.text(tr('current_password')), findsNothing);
    });
  });

  group('PrivacyView — delete account dialog', () {
    testWidgets('tapping delete account opens the confirmation dialog', (tester) async {
      await pumpPrivacyView(tester);
      await tester.pump();

      // Scroll the delete button into view.
      await tester.scrollUntilVisible(
        find.byKey(const ValueKey('qa.profile.privacy.delete_account')),
        250,
      );
      await tester.pump();

      await tester.tap(
        find.byKey(const ValueKey('qa.profile.privacy.delete_account')),
        warnIfMissed: false,
      );
      await tester.pumpAndSettle();

      // The dialog content text is unique (the title collides with the main
      // button's "Delete Account" label).
      expect(find.text(tr('delete_account_dialog_content')), findsOneWidget);
      expect(find.byType(AlertDialog), findsOneWidget);
    });

    testWidgets('delete button is disabled until DELETE is typed', (tester) async {
      await pumpPrivacyView(tester);
      await tester.pump();

      await tester.scrollUntilVisible(
        find.byKey(const ValueKey('qa.profile.privacy.delete_account')),
        250,
      );
      await tester.pump();
      await tester.tap(
        find.byKey(const ValueKey('qa.profile.privacy.delete_account')),
        warnIfMissed: false,
      );
      await tester.pumpAndSettle();

      // The confirm TextButton wraps the "Delete" text.
      final deleteButtonFinder = find.ancestor(
        of: find.text(tr('delete')),
        matching: find.byType(TextButton),
      );
      final button = tester.widget<TextButton>(deleteButtonFinder);
      expect(button.onPressed, isNull);
    });

    testWidgets('typing DELETE enables the delete button', (tester) async {
      await pumpPrivacyView(tester);
      await tester.pump();

      await tester.scrollUntilVisible(
        find.byKey(const ValueKey('qa.profile.privacy.delete_account')),
        250,
      );
      await tester.pump();
      await tester.tap(
        find.byKey(const ValueKey('qa.profile.privacy.delete_account')),
        warnIfMissed: false,
      );
      await tester.pumpAndSettle();

      // Type DELETE into the confirmation field.
      await tester.enterText(
        find.byKey(const ValueKey('qa.profile.privacy.delete_confirm_input')),
        'DELETE',
      );
      await tester.pump();

      // The delete button should now be enabled (onPressed not null).
      final deleteButtonFinder = find.ancestor(
        of: find.text(tr('delete')),
        matching: find.byType(TextButton),
      );
      final button = tester.widget<TextButton>(deleteButtonFinder);
      expect(button.onPressed, isNotNull);
    });

    testWidgets('typing wrong text does not enable the delete button', (tester) async {
      await pumpPrivacyView(tester);
      await tester.pump();

      await tester.scrollUntilVisible(
        find.byKey(const ValueKey('qa.profile.privacy.delete_account')),
        250,
      );
      await tester.pump();
      await tester.tap(
        find.byKey(const ValueKey('qa.profile.privacy.delete_account')),
        warnIfMissed: false,
      );
      await tester.pumpAndSettle();

      await tester.enterText(
        find.byKey(const ValueKey('qa.profile.privacy.delete_confirm_input')),
        'remove',
      );
      await tester.pump();

      final deleteButtonFinder = find.ancestor(
        of: find.text(tr('delete')),
        matching: find.byType(TextButton),
      );
      final button = tester.widget<TextButton>(deleteButtonFinder);
      expect(button.onPressed, isNull);
    });

    testWidgets('delete account dialog has cancel and delete actions', (tester) async {
      await pumpPrivacyView(tester);
      await tester.pump();

      await tester.scrollUntilVisible(
        find.byKey(const ValueKey('qa.profile.privacy.delete_account')),
        250,
      );
      await tester.pump();
      await tester.tap(
        find.byKey(const ValueKey('qa.profile.privacy.delete_account')),
        warnIfMissed: false,
      );
      await tester.pumpAndSettle();

      // The dialog has both cancel and delete action buttons.
      expect(find.text(tr('cancel')), findsOneWidget);
      expect(find.text(tr('delete')), findsOneWidget);
      expect(
        find.descendant(of: find.byType(AlertDialog), matching: find.byType(TextButton)),
        findsNWidgets(2),
      );
    });
  });

  group('PrivacyView — policy navigation', () {
    testWidgets('tapping a policy item navigates to PolicyPageView', (tester) async {
      when(() => h.pages.fetchPublicPage(any())).thenThrow(Exception('network error'));

      await pumpPrivacyView(tester);
      await tester.pump();

      // Tap the first policy item (terms of service).
      await tester.tap(find.text(tr('privacy_terms_of_service_title')));
      await tester.pumpAndSettle();

      // PolicyPageView should be pushed and show the error fallback.
      expect(find.text('/policy/terms-of-service'), findsOneWidget);
    });

    testWidgets('tapping privacy policy item navigates to PolicyPageView', (tester) async {
      when(() => h.pages.fetchPublicPage(any())).thenThrow(Exception('network error'));

      await pumpPrivacyView(tester);
      await tester.pump();

      await tester.tap(find.text(tr('privacy_policy_item_title')));
      await tester.pumpAndSettle();

      expect(find.text('/policy/privacy-policy'), findsOneWidget);
    });
  });
  testWidgets('delete cancellation sends no request', (tester) async {
    await pumpPrivacyView(tester);
    await tester.scrollUntilVisible(
      find.byKey(const ValueKey('qa.profile.privacy.delete_account')),
      250,
    );
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const ValueKey('qa.profile.privacy.delete_account')));
    await tester.pumpAndSettle();
    await tester.tap(find.text(tr('cancel')));
    await tester.pumpAndSettle();
    expect(h.session.deletes, 0);
  });
  testWidgets('confirmed delete failure keeps confirmation open for retry', (tester) async {
    h.session.delete = () async {
      h.session.set(
        h.container
            .read(authProvider)
            .copyWith(
              mutationKind: AuthMutation.deleteAccount,
              mutation: AsyncError(NetworkException('offline'), StackTrace.current),
            ),
      );
      return false;
    };
    await pumpPrivacyView(tester);
    await tester.scrollUntilVisible(
      find.byKey(const ValueKey('qa.profile.privacy.delete_account')),
      250,
    );
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const ValueKey('qa.profile.privacy.delete_account')));
    await tester.pumpAndSettle();
    await tester.enterText(
      find.byKey(const ValueKey('qa.profile.privacy.delete_confirm_input')),
      'DELETE',
    );
    await tester.pump();
    await tester.tap(find.byKey(const ValueKey('qa.profile.privacy.delete_confirm')));
    await tester.pumpAndSettle();
    expect(h.session.deletes, 1);
    expect(find.byType(AlertDialog), findsOneWidget);
    expect(find.text(tr('something_went_wrong')), findsOneWidget);
    h.session.delete = () async {
      h.session.set(h.container.read(authProvider).copyWith(mutation: const AsyncData(null)));
      return true;
    };
    await tester.tap(find.byKey(const ValueKey('qa.profile.privacy.delete_confirm')));
    await tester.pumpAndSettle();
    expect(h.session.deletes, 2);
    expect(find.byType(AlertDialog), findsNothing);
  });
  testWidgets('password dialog scrolls with keyboard and large text', (tester) async {
    tester.view.physicalSize = const Size(320, 720);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    addTearDown(tester.view.resetViewInsets);
    await h.pump(tester, const PrivacyView(), scale: 2);
    await tester.tap(find.byKey(const ValueKey('qa.profile.privacy.change_password')));
    await tester.pumpAndSettle();
    tester.view.viewInsets = const FakeViewPadding(bottom: 260);
    await tester.pump();
    expect(tester.takeException(), isNull);
    expect(find.byType(AlertDialog), findsOneWidget);
    await tester.ensureVisible(find.byType(TextFormField).last);
    await tester.pump();
    expect(tester.takeException(), isNull);
  });
}
