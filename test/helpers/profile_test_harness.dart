import 'package:flutter/material.dart';

import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_riverpod/misc.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:mocktail/mocktail.dart';
import 'package:package_info_plus/package_info_plus.dart';
import 'package:supabase_flutter/supabase_flutter.dart' show AuthResponse;

import 'package:ghar360/core/controllers/auth_controller.dart';
import 'package:ghar360/core/data/models/auth_status.dart';
import 'package:ghar360/core/data/models/bug_report_model.dart';
import 'package:ghar360/core/providers/auth_providers.dart';
import 'package:ghar360/core/translations/app_localizations.dart';
import 'package:ghar360/core/utils/app_toast.dart';
import 'package:ghar360/features/profile/data/static_page_repository.dart';
import 'package:ghar360/features/profile/data/support_repository.dart';
import 'package:ghar360/features/profile/presentation/controllers/feedback_controller.dart';
import 'package:ghar360/features/profile/presentation/views/about_view.dart';
import 'package:ghar360/features/profile/presentation/views/policy_page_view.dart';
import 'auth_test_harness.dart' show profile, sdkUser, MockAuthRepository;

export 'auth_test_harness.dart' show profile, sdkUser;

String tr(String key) => const AppLocalizations(Locale('en', 'US')).text(key);

class MockSupportRepository extends Mock implements SupportRepository {}

class MockStaticPageRepository extends Mock implements StaticPageRepository {}

class ProfileTestSession extends AuthController {
  AuthState initial = AuthState(status: AuthStatus.authenticated, user: profile());
  int signOuts = 0, deletes = 0, retries = 0;
  Map<String, dynamic>? lastProfile;
  Map<String, dynamic>? lastPreferences;
  String? lastImage;
  Future<bool> Function()? save, savePreferences, upload, logout, delete;
  @override
  AuthState build() => initial;
  void set(AuthState value) => state = value;
  @override
  Future<bool> updateUserProfile(Map<String, dynamic> value) async {
    lastProfile = value;
    return await save?.call() ?? true;
  }

  @override
  Future<bool> updateUserPreferences(Map<String, dynamic> patch) async {
    lastPreferences = patch;
    return await savePreferences?.call() ?? true;
  }

  @override
  Future<bool> updateProfileImage(String path) async {
    lastImage = path;
    return await upload?.call() ?? true;
  }

  @override
  Future<bool> signOut() async {
    signOuts++;
    return await logout?.call() ?? true;
  }

  @override
  Future<bool> deleteAccount() async {
    deletes++;
    return await delete?.call() ?? true;
  }

  @override
  Future<void> retryProfileLoad() async {
    retries++;
  }
}

class ProfileHarness {
  final session = ProfileTestSession();
  final repository = MockAuthRepository();
  final support = MockSupportRepository();
  final pages = MockStaticPageRepository();
  PackageInfo? info = PackageInfo(
    appName: '360ghar',
    packageName: 'app.ghar360',
    version: '1.2.3',
    buildNumber: '42',
  );
  late final container = ProviderContainer(
    overrides: [
      authProvider.overrideWith(() => session),
      authRepositoryProvider.overrideWithValue(repository),
      supportRepositoryProvider.overrideWithValue(support),
      staticPageRepositoryProvider.overrideWithValue(pages),
      feedbackPackageInfoProvider.overrideWithValue(() async => info),
      packageVersionProvider.overrideWith((ref) async => info),
    ],
  );
  ProfileHarness() {
    registerFallbackValue(
      const BugReportRequest(
        source: 'mobile',
        bugType: BugType.uiBug,
        severity: BugSeverity.medium,
        title: 'Title',
        description: 'Description',
      ),
    );
    when(() => repository.currentUser).thenReturn(sdkUser());
    when(
      () => repository.signInWithEmailPassword(any(), any()),
    ).thenAnswer((_) async => AuthResponse());
    when(
      () => repository.signInWithPhonePassword(any(), any()),
    ).thenAnswer((_) async => AuthResponse());
    when(() => repository.updateUserPassword(any())).thenAnswer((_) async => sdkUser());
    when(() => support.submitBugReport(any())).thenAnswer((_) async => bugResponse());
  }
  ProviderSubscription<T> listen<T>(ProviderListenable<T> provider) =>
      container.listen(provider, (_, _) {});
  void close() => container.dispose();
  GoRouter? router;
  Object? routeExtra;
  Future<void> pump(
    WidgetTester tester,
    Widget child, {
    double scale = 1,
    Brightness brightness = Brightness.light,
  }) async {
    router = GoRouter(
      initialLocation: '/',
      routes: [
        GoRoute(
          path: '/',
          builder: (_, _) => const Scaffold(body: Text('Back destination')),
          routes: [GoRoute(path: 'screen', builder: (_, _) => child)],
        ),
        for (final route in [
          '/feedback',
          '/edit-profile',
          '/preferences',
          '/tools',
          '/help',
          '/about',
          '/privacy',
          '/assistant',
          '/policy/:slug',
        ])
          GoRoute(
            path: route,
            builder: (_, state) {
              routeExtra = state.extra;
              return Scaffold(
                body: Text(route == '/feedback' ? 'Feedback Route Destination' : state.uri.path),
              );
            },
          ),
      ],
    );
    router!.go('/screen');
    addTearDown(router!.dispose);
    await tester.pumpWidget(
      UncontrolledProviderScope(
        container: container,
        child: MaterialApp.router(
          routerConfig: router,
          theme: ThemeData(brightness: brightness),
          locale: const Locale('en', 'US'),
          localizationsDelegates: const [
            AppLocalizations.delegate,
            GlobalMaterialLocalizations.delegate,
            GlobalWidgetsLocalizations.delegate,
            GlobalCupertinoLocalizations.delegate,
          ],
          builder: (context, child) => MediaQuery(
            data: MediaQuery.of(context).copyWith(textScaler: TextScaler.linear(scale)),
            child: AppToastHost(child: child!),
          ),
        ),
      ),
    );
    await tester.pump();
  }
}

BugReportResponse bugResponse() => BugReportResponse(
  id: 42,
  source: 'mobile',
  bugType: BugType.uiBug,
  severity: BugSeverity.medium,
  status: BugStatus.open,
  title: 'Title',
  description: 'Description',
  createdAt: DateTime.utc(2026, 9, 30),
);
