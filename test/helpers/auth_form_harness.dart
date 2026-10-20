import 'package:flutter/material.dart';

import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_riverpod/misc.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:mocktail/mocktail.dart';
import 'package:supabase_flutter/supabase_flutter.dart' show AuthResponse;

import 'package:ghar360/core/controllers/auth_controller.dart';
import 'package:ghar360/core/data/models/auth_status.dart';
import 'package:ghar360/core/data/models/user_model.dart';
import 'package:ghar360/core/providers/auth_providers.dart';
import 'package:ghar360/core/translations/app_localizations.dart';
import 'package:ghar360/features/auth/data/auth_method.dart';
import 'package:ghar360/features/auth/data/last_auth_method_store.dart';
import 'package:ghar360/features/auth/data/models/auth_flow_args.dart';
import 'package:ghar360/features/auth/data/models/identifier_status.dart';
import 'auth_test_harness.dart' show sdkUser, MockAuthRepository, MockProfileRepository;
import 'settings_test_database.dart';

AuthFlowArgs flowArgs({
  bool email = true,
  bool otp = false,
  bool exists = true,
  bool password = true,
}) => AuthFlowArgs(
  identifier: email ? 'test@example.com' : '+919876543210',
  status: IdentifierStatus(
    exists: exists,
    verified: !otp,
    hasPassword: password,
    channel: email ? IdentifierChannel.email : IdentifierChannel.phone,
    nextStep: otp ? IdentifierNextStep.otp : IdentifierNextStep.password,
  ),
);

class TestSessionController extends AuthController {
  AuthState initial = const AuthState(status: AuthStatus.unauthenticated);
  int passwordWrites = 0, profileWrites = 0;
  bool passwordSuccess = true, profileSuccess = true;
  bool gate = false;
  @override
  AuthState build() => initial;
  void set(AuthState next) => state = next;
  @override
  void markRequiresPasswordSetup() {
    gate = true;
  }

  @override
  void clearRequiresPasswordSetup() {
    gate = false;
  }

  @override
  Future<bool> completePasswordSetup(String password) async {
    passwordWrites++;
    if (passwordSuccess) gate = false;
    return passwordSuccess;
  }

  @override
  Future<bool> updateUserProfile(Map<String, dynamic> profileData) async {
    profileWrites++;
    return profileSuccess;
  }

  @override
  void deferProfileCompletion() {
    state = state.copyWith(profileCompletionDeferred: true, status: AuthStatus.authenticated);
  }
}

class AuthFormHarness {
  final repository = MockAuthRepository();
  final profiles = MockProfileRepository();
  final database = SettingsTestDatabase();
  final session = TestSessionController();
  late final container = ProviderContainer(
    overrides: [
      authRepositoryProvider.overrideWithValue(repository),
      profileRepositoryProvider.overrideWithValue(profiles),
      authProvider.overrideWith(() => session),
    ],
  );
  AuthFormHarness() {
    registerFallbackValue(AuthMethod.google);
    when(() => repository.currentUser).thenReturn(sdkUser());
    when(() => repository.isAppleSignInSupported).thenReturn(false);
    when(() => repository.lastAuthMethodStore).thenReturn(LastAuthMethodStore(database: database));
    when(
      () => repository.recordLastMethod(any(), identifier: any(named: 'identifier')),
    ).thenAnswer((_) async {});
    when(() => repository.signInWithGoogle()).thenAnswer((_) async {});
    when(() => repository.signInWithApple()).thenAnswer((_) async => AuthResponse());
    when(() => repository.checkIdentifierStatus(any())).thenAnswer((_) async => flowArgs().status);
    when(
      () => repository.signInWithEmailPassword(any(), any()),
    ).thenAnswer((_) async => AuthResponse());
    when(
      () => repository.signInWithPhonePassword(any(), any()),
    ).thenAnswer((_) async => AuthResponse());
    when(() => repository.sendEmailOtp(any())).thenAnswer((_) async {});
    when(() => repository.sendPhoneOtp(any())).thenAnswer((_) async {});
    when(
      () => repository.verifyEmailOtp(
        email: any(named: 'email'),
        token: any(named: 'token'),
      ),
    ).thenAnswer((_) async => AuthResponse());
    when(
      () => repository.verifyPhoneOtp(
        phone: any(named: 'phone'),
        token: any(named: 'token'),
      ),
    ).thenAnswer((_) async => AuthResponse());
    when(
      () => repository.signUpWithEmailOtp(any(), data: any(named: 'data')),
    ).thenAnswer((_) async {});
    when(
      () => repository.signUpWithPhonePassword(any(), any(), data: any(named: 'data')),
    ).thenAnswer((_) async => AuthResponse());
    when(() => repository.startAddPhone(any())).thenAnswer((_) async {});
    when(
      () => repository.addAndVerifyPhone(
        phone: any(named: 'phone'),
        token: any(named: 'token'),
      ),
    ).thenAnswer((_) async => AuthResponse());
    when(
      () => profiles.updateUserPreferences(any()),
    ).thenAnswer((_) async => const UserPreferences());
  }
  ProviderSubscription<T> listen<T>(ProviderListenable<T> provider) =>
      container.listen(provider, (_, _) {});
  bool _closed = false;
  void close() {
    if (!_closed) {
      _closed = true;
      container.dispose();
    }
  }

  Future<void> pump(
    WidgetTester tester,
    Widget child, {
    double scale = 1,
    Brightness brightness = Brightness.light,
  }) async {
    final router = GoRouter(
      routes: [
        GoRoute(path: '/', builder: (_, _) => child),
        for (final route in ['/phone-entry', '/login', '/signup', '/forgot-password'])
          GoRoute(path: route, builder: (_, _) => Text(route)),
      ],
    );
    addTearDown(router.dispose);
    await tester.pumpWidget(
      UncontrolledProviderScope(
        container: container,
        child: MaterialApp.router(
          routerConfig: router,
          theme: ThemeData(brightness: brightness),
          localizationsDelegates: const [
            AppLocalizations.delegate,
            GlobalMaterialLocalizations.delegate,
            GlobalWidgetsLocalizations.delegate,
            GlobalCupertinoLocalizations.delegate,
          ],
          builder: (context, child) => MediaQuery(
            data: MediaQuery.of(context).copyWith(textScaler: TextScaler.linear(scale)),
            child: child!,
          ),
        ),
      ),
    );
    await tester.pump();
  }
}
