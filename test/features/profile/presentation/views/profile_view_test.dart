// test/features/profile/presentation/views/profile_view_test.dart

import 'package:flutter/material.dart';

import 'package:flutter_test/flutter_test.dart';
import 'package:get/get.dart';

import 'package:ghar360/core/data/models/user_model.dart';
import 'package:ghar360/features/profile/presentation/controllers/profile_controller.dart';
import 'package:ghar360/features/profile/presentation/views/profile_view.dart';
import '../../../../helpers/getx_test_binding.dart';
import '../../../../helpers/mocks.dart';
import '../../../../helpers/pump_app.dart';

// ---------------------------------------------------------------------------
// Stub controller
// ---------------------------------------------------------------------------

class _StubProfileController extends GetxServiceMock implements ProfileController {
  @override
  final RxBool isProfileLoading = false.obs;

  @override
  Rxn<UserModel> get currentUser => _currentUser;
  final Rxn<UserModel> _currentUser = Rxn<UserModel>();

  @override
  bool get isLoading => isProfileLoading.value;

  bool signOutCalled = false;

  @override
  Future<void> signOut() async {
    signOutCalled = true;
  }
}

// ---------------------------------------------------------------------------
// Tests
// ---------------------------------------------------------------------------

void main() {
  setUp(() {
    GetxTestBinding.init();
  });

  tearDown(() => GetxTestBinding.reset());

  Future<void> pumpView(WidgetTester tester, _StubProfileController controller) async {
    Get.put<ProfileController>(controller);
    await tester.pumpApp(const ProfileView());
    await tester.pump();
  }

  group('ProfileView', () {
    testWidgets('shows loading indicator when isLoading is true', (tester) async {
      final controller = _StubProfileController();
      controller.isProfileLoading.value = true;
      await pumpView(tester, controller);

      expect(find.byType(CircularProgressIndicator), findsOneWidget);
    });

    testWidgets('shows empty state when currentUser is null', (tester) async {
      final controller = _StubProfileController();
      await pumpView(tester, controller);

      expect(find.text('no_user_data_available'.tr), findsOneWidget);
    });

    testWidgets('renders profile header and menu items when user is present', (tester) async {
      final controller = _StubProfileController();
      controller.currentUser.value = testUserModel(fullName: 'Test User', email: 'test@example.com');
      await pumpView(tester, controller);

      expect(find.bySemanticsLabel('qa.profile.screen'), findsOneWidget);
      expect(find.text('Test User'), findsOneWidget);
      expect(find.byKey(const ValueKey('qa.profile.menu.edit_profile')), findsOneWidget);
      expect(find.byKey(const ValueKey('qa.profile.menu.preferences')), findsOneWidget);
      expect(find.byKey(const ValueKey('qa.profile.menu.tools')), findsOneWidget);
      expect(find.byKey(const ValueKey('qa.profile.menu.help')), findsOneWidget);
      expect(find.byKey(const ValueKey('qa.profile.menu.about')), findsOneWidget);
      expect(find.byKey(const ValueKey('qa.profile.logout')), findsOneWidget);
    });

    testWidgets('shows user email in header', (tester) async {
      final controller = _StubProfileController();
      controller.currentUser.value = testUserModel(fullName: 'Jane', email: 'jane@example.com');
      await pumpView(tester, controller);

      expect(find.text('jane@example.com'), findsOneWidget);
    });

    testWidgets('shows profile completion bar', (tester) async {
      final controller = _StubProfileController();
      controller.currentUser.value = testUserModel(fullName: 'Test');
      await pumpView(tester, controller);

      expect(find.byType(LinearProgressIndicator), findsOneWidget);
    });

    testWidgets('tapping logout shows confirmation dialog', (tester) async {
      final controller = _StubProfileController();
      controller.currentUser.value = testUserModel(fullName: 'Test');
      await pumpView(tester, controller);

      // Scroll to the logout button first (it may be off-screen).
      await tester.scrollUntilVisible(
        find.byKey(const ValueKey('qa.profile.logout')),
        100,
      );
      await tester.pumpAndSettle();

      await tester.tap(find.byKey(const ValueKey('qa.profile.logout')));
      await tester.pumpAndSettle(const Duration(seconds: 2));

      expect(find.text('logout_confirm_message'.tr), findsOneWidget);
      expect(find.text('cancel'.tr), findsOneWidget);
    });

    testWidgets('confirming logout calls signOut', (tester) async {
      final controller = _StubProfileController();
      controller.currentUser.value = testUserModel(fullName: 'Test');
      await pumpView(tester, controller);

      // Scroll to the logout button first (it may be off-screen).
      await tester.scrollUntilVisible(
        find.byKey(const ValueKey('qa.profile.logout')),
        100,
      );
      await tester.pumpAndSettle();

      await tester.tap(find.byKey(const ValueKey('qa.profile.logout')));
      await tester.pumpAndSettle(const Duration(seconds: 2));

      // Tap the 'logout' confirmation button (not the cancel).
      final logoutButtons = find.text('logout'.tr);
      await tester.tap(logoutButtons.last);
      await tester.pumpAndSettle();

      expect(controller.signOutCalled, isTrue);
    });
  });
}
