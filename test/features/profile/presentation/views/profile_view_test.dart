import 'package:flutter/material.dart';

import 'package:flutter_test/flutter_test.dart';

import 'package:ghar360/core/controllers/auth_controller.dart';
import 'package:ghar360/core/storage/storage_failure.dart';
import 'package:ghar360/core/widgets/common/loading_states.dart';
import 'package:ghar360/features/profile/presentation/views/profile_view.dart';
import '../../../../helpers/profile_test_harness.dart';

void main() {
  late ProfileHarness h;
  setUp(() => h = ProfileHarness());
  tearDown(() => h.close());
  Future<void> pumpView(WidgetTester tester) => h.pump(tester, const ProfileView());
  group('ProfileView', () {
    testWidgets('shows loading indicator when isLoading is true', (tester) async {
      h.session.initial = h.session.initial.copyWith(user: null, resolving: true);
      await pumpView(tester);

      expect(find.byType(Skeleton), findsOneWidget);
    });

    testWidgets('shows empty state when currentUser is null', (tester) async {
      h.session.initial = h.session.initial.copyWith(user: null);
      await pumpView(tester);

      expect(find.text(tr('no_user_data_available')), findsOneWidget);
    });

    testWidgets('renders profile header and menu items when user is present', (tester) async {
      h.session.initial = h.session.initial.copyWith(
        user: profile().copyWith(fullName: 'Test User', email: 'test@example.com'),
      );
      // A tall surface: the menu is a lazy sliver list, so every row is on screen.
      tester.view.physicalSize = const Size(800, 1800);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.reset);
      await pumpView(tester);

      expect(find.bySemanticsIdentifier('qa.profile.screen'), findsOneWidget);
      expect(find.text('Test User'), findsOneWidget);
      expect(find.byKey(const ValueKey('qa.profile.menu.edit_profile')), findsOneWidget);
      expect(find.byKey(const ValueKey('qa.profile.menu.preferences')), findsOneWidget);
      expect(find.byKey(const ValueKey('qa.profile.menu.tools')), findsOneWidget);
      expect(find.byKey(const ValueKey('qa.profile.menu.help')), findsOneWidget);
      expect(find.byKey(const ValueKey('qa.profile.menu.about')), findsOneWidget);
      expect(find.byKey(const ValueKey('qa.profile.logout')), findsOneWidget);
    });

    testWidgets('shows user email in header', (tester) async {
      h.session.initial = h.session.initial.copyWith(
        user: profile().copyWith(fullName: 'Jane', email: 'jane@example.com'),
      );
      await pumpView(tester);

      expect(find.text('jane@example.com'), findsOneWidget);
    });

    testWidgets('shows profile completion bar', (tester) async {
      h.session.initial = h.session.initial.copyWith(user: profile().copyWith(fullName: 'Test'));
      await pumpView(tester);

      expect(find.byKey(const ValueKey('qa.profile.completion')), findsOneWidget);
      expect(find.textContaining(RegExp(r'\d+% ')), findsOneWidget);
    });

    testWidgets('tapping logout shows confirmation dialog', (tester) async {
      h.session.initial = h.session.initial.copyWith(user: profile().copyWith(fullName: 'Test'));
      await pumpView(tester);

      // Scroll to the logout button first (it may be off-screen).
      await tester.scrollUntilVisible(find.byKey(const ValueKey('qa.profile.logout')), 100);
      await tester.pumpAndSettle();

      await tester.tap(find.byKey(const ValueKey('qa.profile.logout')));
      await tester.pumpAndSettle(const Duration(seconds: 2));

      expect(find.text(tr('logout_confirm_message')), findsOneWidget);
      expect(find.text(tr('cancel')), findsOneWidget);
    });

    testWidgets('confirming logout calls signOut', (tester) async {
      h.session.initial = h.session.initial.copyWith(user: profile().copyWith(fullName: 'Test'));
      await pumpView(tester);

      // Scroll to the logout button first (it may be off-screen).
      await tester.scrollUntilVisible(find.byKey(const ValueKey('qa.profile.logout')), 100);
      await tester.pumpAndSettle();

      await tester.tap(find.byKey(const ValueKey('qa.profile.logout')));
      await tester.pumpAndSettle(const Duration(seconds: 2));

      // Tap the 'logout' confirmation button (not the cancel).
      final logoutButtons = find.text(tr('logout'));
      await tester.tap(logoutButtons.last);
      await tester.pumpAndSettle();

      expect(h.session.signOuts, 1);
    });
  });
  testWidgets('Assistant entry is explicit and opens the assistant route', (tester) async {
    await pumpView(tester);
    await tester.ensureVisible(find.byKey(const ValueKey('qa.profile.menu.assistant')));
    await tester.tap(find.byKey(const ValueKey('qa.profile.menu.assistant')));
    await tester.pumpAndSettle();
    expect(find.text('/assistant'), findsOneWidget);
  });
  testWidgets('profile uses new session user without another controller', (tester) async {
    await pumpView(tester);
    h.session.set(
      h.container.read(authProvider).copyWith(user: profile().copyWith(fullName: 'Updated')),
    );
    await tester.pumpAndSettle();
    expect(find.text('Updated'), findsOneWidget);
    expect(find.text('Test User'), findsNothing);
  });
  testWidgets('stale profile remains visible and offers refresh', (tester) async {
    h.session.initial = h.session.initial.copyWith(stale: true);
    await pumpView(tester);
    expect(find.text('Test User'), findsOneWidget);
    await tester.ensureVisible(find.byKey(const ValueKey('qa.content.retry')));
    await tester.tap(find.byKey(const ValueKey('qa.content.retry')));
    expect(h.session.retries, 1);
  });
  testWidgets('empty profile offers a retry', (tester) async {
    h.session.initial = h.session.initial.copyWith(user: null);
    await pumpView(tester);
    await tester.tap(find.text(tr('retry')));
    expect(h.session.retries, 1);
  });
  testWidgets('local cache failure is distinct from network failure', (tester) async {
    h.session.initial = h.session.initial.copyWith(error: StorageFailure('cache-profile'));
    await pumpView(tester);
    expect(find.text(tr('preferences_save_error')), findsOneWidget);
    expect(find.text(tr('network_error')), findsNothing);
  });
}
