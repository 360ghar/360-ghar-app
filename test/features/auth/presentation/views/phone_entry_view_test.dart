// test/features/auth/presentation/views/phone_entry_view_test.dart

import 'package:flutter/material.dart';

import 'package:flutter_test/flutter_test.dart';
import 'package:get/get.dart';

import 'package:ghar360/features/auth/data/auth_method.dart';
import 'package:ghar360/features/auth/presentation/controllers/phone_entry_controller.dart';
import 'package:ghar360/features/auth/presentation/views/phone_entry_view.dart';
import '../../../../helpers/getx_test_binding.dart';
import '../../../../helpers/mocks.dart';
import '../../../../helpers/pump_app.dart';

// ---------------------------------------------------------------------------
// Stub controller
// ---------------------------------------------------------------------------

class _StubPhoneEntryController extends GetxServiceMock implements PhoneEntryController {
  @override
  final GlobalKey<FormState> formKey = GlobalKey<FormState>();

  @override
  final TextEditingController identifierController = TextEditingController();

  @override
  final FocusNode identifierFocusNode = FocusNode();

  @override
  final Rx<IdentifierEntryState> state = IdentifierEntryState.idle.obs;

  @override
  final RxBool isLoading = false.obs;

  @override
  final RxBool isGoogleLoading = false.obs;

  @override
  final RxBool isAppleLoading = false.obs;

  @override
  final RxString errorMessage = ''.obs;

  @override
  final RxBool isIdentifierFocused = false.obs;

  @override
  final RxInt validationShakeTrigger = 0.obs;

  @override
  final RxBool looksLikeEmail = false.obs;

  @override
  final Rxn<AuthMethod> lastMethod = Rxn<AuthMethod>();

  @override
  final RxString lastIdentifierHint = ''.obs;

  @override
  bool get isGoogleAvailable => true;

  @override
  bool get isAppleAvailable => false;

  bool checkAndNavigateCalled = false;
  bool signInWithGoogleCalled = false;
  bool signInWithAppleCalled = false;

  @override
  String? validateIdentifier(String? value) {
    final raw = (value ?? '').trim();
    if (raw.isEmpty) return 'identifier_required'.tr;
    return null;
  }

  @override
  Future<void> requestPhoneNumberHint() async {}

  @override
  Future<void> signInWithGoogle() async {
    signInWithGoogleCalled = true;
  }

  @override
  Future<void> signInWithApple() async {
    signInWithAppleCalled = true;
  }

  @override
  Future<void> checkAndNavigate() async {
    checkAndNavigateCalled = true;
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

  Future<void> pumpPhoneEntryView(WidgetTester tester, _StubPhoneEntryController controller) async {
    Get.put<PhoneEntryController>(controller);
    await tester.pumpApp(const PhoneEntryView());
    await tester.pump();
  }

  group('PhoneEntryView', () {
    testWidgets('renders screen with identifier input and continue button', (tester) async {
      final controller = _StubPhoneEntryController();
      await pumpPhoneEntryView(tester, controller);

      expect(find.byKey(const ValueKey('qa.auth.phone_entry.screen')), findsOneWidget);
      expect(find.byKey(const ValueKey('qa.auth.phone_entry.identifier_input')), findsOneWidget);
      expect(find.byKey(const ValueKey('qa.auth.phone_entry.continue')), findsOneWidget);
    });

    testWidgets('tapping continue calls checkAndNavigate', (tester) async {
      final controller = _StubPhoneEntryController();
      await pumpPhoneEntryView(tester, controller);

      await tester.tap(find.byKey(const ValueKey('qa.auth.phone_entry.continue')));
      await tester.pump();

      expect(controller.checkAndNavigateCalled, isTrue);
    });

    testWidgets('shows loading spinner on continue button when isLoading', (tester) async {
      final controller = _StubPhoneEntryController();
      controller.isLoading.value = true;
      await pumpPhoneEntryView(tester, controller);

      // When loading, the button shows a CircularProgressIndicator + 'checking_account' text.
      expect(find.text('checking_account'.tr), findsOneWidget);
    });

    testWidgets('shows inline error message when errorMessage is set', (tester) async {
      final controller = _StubPhoneEntryController();
      controller.errorMessage.value = 'Network error';
      await pumpPhoneEntryView(tester, controller);

      expect(find.text('Network error'), findsOneWidget);
    });

    testWidgets('shows last method hint when lastMethod is set', (tester) async {
      final controller = _StubPhoneEntryController();
      controller.lastMethod.value = AuthMethod.phonePassword;
      controller.lastIdentifierHint.value = '+91 ******3210';
      await pumpPhoneEntryView(tester, controller);

      expect(find.byIcon(Icons.history), findsOneWidget);
    });

    testWidgets('hides last method hint when lastMethod is null', (tester) async {
      final controller = _StubPhoneEntryController();
      await pumpPhoneEntryView(tester, controller);

      expect(find.byIcon(Icons.history), findsNothing);
    });

    testWidgets('entering text into identifier field updates controller', (tester) async {
      final controller = _StubPhoneEntryController();
      await pumpPhoneEntryView(tester, controller);

      await tester.enterText(
        find.byKey(const ValueKey('qa.auth.phone_entry.identifier_input')),
        'test@example.com',
      );
      await tester.pump();

      expect(controller.identifierController.text, 'test@example.com');
    });

    testWidgets('renders Google sign-in button on non-iOS platforms', (tester) async {
      final controller = _StubPhoneEntryController();
      await pumpPhoneEntryView(tester, controller);

      // The Google sign-in button is rendered with a ValueKey.
      expect(find.byKey(const ValueKey('qa.auth.google_signin')), findsOneWidget);
    });
  });
}
