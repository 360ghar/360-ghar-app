import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:ghar360/core/design/app_design_theme.dart';
import 'package:ghar360/core/providers/network_providers.dart';
import 'package:ghar360/core/routes/app_routes.dart';
import 'package:ghar360/core/storage/app_database.dart';
import 'package:ghar360/core/translations/app_localizations.dart';
import 'package:ghar360/core/widgets/common/sign_in_gate.dart';
import 'package:go_router/go_router.dart';

class _Scope extends Fake implements StorageScope {
  _Scope(this.accountId);
  @override
  final String? accountId;
}

class _Notifier extends StorageScopeNotifier {
  _Notifier(this.id);
  final String? id;
  @override
  StorageScope build() => _Scope(id);
}

void main() {
  late bool? result;
  Future<GoRouter> pump(WidgetTester tester, {String? account, String? returnTo}) async {
    result = null;
    final router = GoRouter(
      routes: [
        GoRoute(
          path: '/property/:id',
          builder: (_, _) => Scaffold(
            body: Consumer(
              builder: (context, ref, _) => TextButton(
                onPressed: () async =>
                    result = await requireAccount(context, ref, returnTo: returnTo),
                child: const Text('Act'),
              ),
            ),
          ),
        ),
        GoRoute(
          path: AppRoutes.phoneEntry,
          builder: (_, state) =>
              Scaffold(body: Text('Sign-in destination ${state.uri.queryParameters['from']}')),
        ),
        GoRoute(
          path: '/policy/privacy-policy',
          builder: (_, _) => const Text('Privacy policy page'),
        ),
      ],
      initialLocation: '/property/7',
    );
    addTearDown(router.dispose);
    await tester.pumpWidget(
      ProviderScope(
        overrides: [storageScopeProvider.overrideWith(() => _Notifier(account))],
        child: MaterialApp.router(
          routerConfig: router,
          theme: AppDesignTheme.light(),
          supportedLocales: AppLocalizations.supportedLocales,
          localizationsDelegates: const [
            AppLocalizations.delegate,
            GlobalMaterialLocalizations.delegate,
            GlobalWidgetsLocalizations.delegate,
            GlobalCupertinoLocalizations.delegate,
          ],
        ),
      ),
    );
    await tester.pumpAndSettle();
    return router;
  }

  testWidgets('a signed-in user passes with no sheet', (tester) async {
    await pump(tester, account: 'a');
    await tester.tap(find.text('Act'));
    await tester.pumpAndSettle();
    expect(result, true);
    expect(find.text('Sign in to continue'), findsNothing);
  });

  testWidgets('a guest sees the sheet; Not now returns false and stays', (tester) async {
    final router = await pump(tester);
    await tester.tap(find.text('Act'));
    await tester.pumpAndSettle();
    expect(find.text('Sign in to continue'), findsOneWidget);
    expect(
      find.text('Sign in to save properties, book visits and chat with the assistant.'),
      findsOneWidget,
    );
    await tester.tap(find.byKey(const ValueKey('qa.sign_in_gate.not_now')));
    await tester.pumpAndSettle();
    expect(result, false);
    expect(router.state.uri.path, '/property/7');
  });

  testWidgets('Sign in returns false and opens sign-in with the current location', (tester) async {
    final router = await pump(tester);
    await tester.tap(find.text('Act'));
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const ValueKey('qa.sign_in_gate.sign_in')));
    await tester.pumpAndSettle();
    expect(result, false);
    expect(router.state.uri.path, AppRoutes.phoneEntry);
    expect(find.text('Sign-in destination /property/7'), findsOneWidget);
  });

  testWidgets('an explicit returnTo wins over the current location', (tester) async {
    await pump(tester, returnTo: '/likes');
    await tester.tap(find.text('Act'));
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const ValueKey('qa.sign_in_gate.sign_in')));
    await tester.pumpAndSettle();
    expect(find.text('Sign-in destination /likes'), findsOneWidget);
  });

  testWidgets('the privacy link opens the public policy page', (tester) async {
    await pump(tester);
    await tester.tap(find.text('Act'));
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const ValueKey('qa.sign_in_gate.policy')));
    await tester.pumpAndSettle();
    expect(find.text('Privacy policy page'), findsOneWidget);
  });
}
