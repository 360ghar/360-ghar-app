import 'dart:async';

import 'package:flutter/material.dart';

import 'package:flutter_test/flutter_test.dart';

import 'package:ghar360/core/design/app_design_theme.dart';
import 'package:ghar360/core/providers/app_database_provider.dart';
import 'package:ghar360/core/storage/app_database.dart';
import 'package:ghar360/features/splash/presentation/views/splash_view.dart';
import 'package:ghar360/features/splash/presentation/widgets/gurugram_diorama.dart';
import '../../../../helpers/provider_test_app.dart';
import '../../../../helpers/settings_test_database.dart';

void main() {
  late SettingsTestDatabase database;
  setUp(() => database = SettingsTestDatabase());
  Future<void> pump(
    WidgetTester tester, {
    Locale locale = const Locale('en', 'US'),
    double scale = 1,
    bool dark = false,
  }) async {
    await tester.pumpProviderApp(
      const SplashView(),
      overrides: [
        appDatabaseProvider.overrideWithValue(database),
        gyroscopeProvider.overrideWithValue(const Stream.empty()),
      ],
      locale: locale,
      textScale: scale,
      theme: dark ? AppDesignTheme.dark() : AppDesignTheme.light(),
    );
    await tester.pumpAndSettle();
  }

  Finder button(String name) => find.byKey(ValueKey('qa.splash.$name'));
  testWidgets('first slide renders immediately with page controller and animation', (tester) async {
    await pump(tester);
    expect(find.byKey(const ValueKey('qa.splash.screen')), findsOneWidget);
    expect(find.byType(PageView), findsOneWidget);
    expect(tester.widget<PageView>(find.byType(PageView)).controller!.page, 0);
    expect(button('skip'), findsOneWidget);
    expect(button('next'), findsOneWidget);
    expect(button('back').hitTestable(), findsNothing);
    expect(find.byType(CircularProgressIndicator), findsNothing);
  });
  testWidgets('next, back, and page swipe keep the step and button state aligned', (tester) async {
    await pump(tester);
    await tester.tap(button('next'));
    await tester.pumpAndSettle();
    expect(tester.widget<PageView>(find.byType(PageView)).controller!.page, 1);
    expect(button('back').hitTestable(), findsOneWidget);
    expect(tester.widget<TextButton>(button('back')).onPressed, isNotNull);
    await tester.tap(button('next'));
    await tester.pumpAndSettle();
    expect(tester.widget<PageView>(find.byType(PageView)).controller!.page, 2);
    expect(button('get_started'), findsOneWidget);
    expect(button('next'), findsNothing);
    await tester.tap(button('back'));
    await tester.pumpAndSettle();
    expect(tester.widget<PageView>(find.byType(PageView)).controller!.page, 1);
    await tester.drag(find.byType(PageView), const Offset(700, 0));
    await tester.pumpAndSettle();
    expect(tester.widget<PageView>(find.byType(PageView)).controller!.page, 0);
    expect(button('back').hitTestable(), findsNothing);
  });
  testWidgets('Skip persists the boolean completion flag', (tester) async {
    await pump(tester);
    await tester.tap(button('skip'));
    await tester.pumpAndSettle();
    expect(database.values['has_seen_onboarding'], isTrue);
  });
  testWidgets('Get started on last slide persists completion without advancing past it', (
    tester,
  ) async {
    await pump(tester);
    for (var i = 0; i < 2; i++) {
      await tester.tap(button('next'));
      await tester.pumpAndSettle();
    }
    await tester.tap(button('get_started'));
    await tester.pumpAndSettle();
    expect(database.values['has_seen_onboarding'], isTrue);
    expect(tester.widget<PageView>(find.byType(PageView)).controller!.page, 2);
  });
  testWidgets('failed save keeps the screen and exposes a retryable message', (tester) async {
    database.writeFailure = StorageFailure('disk full');
    await pump(tester);
    await tester.tap(button('skip'));
    await tester.pumpAndSettle();
    expect(
      find.text('Could not save on this device. Free some space and try again.'),
      findsOneWidget,
    );
    expect(database.values['has_seen_onboarding'], isNull);
    database.writeFailure = null;
    await tester.tap(button('skip'));
    await tester.pumpAndSettle();
    expect(database.values['has_seen_onboarding'], isTrue);
  });
  testWidgets('pending write disables controls and disposal cancels widget animations', (
    tester,
  ) async {
    final write = Completer<void>();
    database.beforeWrite = () => write.future;
    await pump(tester);
    await tester.tap(button('skip'));
    await tester.pump();
    expect(tester.widget<TextButton>(button('skip')).onPressed, isNull);
    expect(tester.widget<FilledButton>(button('next')).onPressed, isNull);
    await tester.pumpWidget(const SizedBox.shrink());
    write.complete();
    await tester.pumpAndSettle();
    expect(tester.takeException(), isNull);
  });
  for (final dark in [false, true]) {
    testWidgets('narrow Hindi large text remains scrollable in ${dark ? 'dark' : 'light'} theme', (
      tester,
    ) async {
      tester.view.physicalSize = const Size(320, 568);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);
      await pump(tester, locale: const Locale('hi', 'IN'), scale: 2, dark: dark);
      expect(tester.takeException(), isNull);
      expect(button('skip'), findsOneWidget);
      expect(button('next'), findsOneWidget);
      await tester.tap(button('next'));
      await tester.pumpAndSettle();
      expect(tester.takeException(), isNull);
    });
  }
}
