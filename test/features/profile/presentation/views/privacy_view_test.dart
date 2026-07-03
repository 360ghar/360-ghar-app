import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:get/get.dart';
import 'package:ghar360/core/controllers/auth_controller.dart';
import 'package:ghar360/core/translations/app_translations.dart';
import 'package:ghar360/features/auth/data/auth_repository.dart';
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

void main() {
  late MockAuthRepository authRepository;
  late MockAuthController authController;
  late _FakeUser user;

  setUp(() {
    GetxTestBinding.init();

    authRepository = MockAuthRepository();
    authController = MockAuthController();
    user = _FakeUser(email: 'owner@example.com');

    when(() => authController.isDeleting).thenReturn(false.obs);
    when(() => authRepository.currentUser).thenReturn(user);

    GetxTestBinding.bind()
      ..register<AuthRepository>(authRepository)
      ..register<AuthController>(authController);
  });

  tearDown(() {
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
}
