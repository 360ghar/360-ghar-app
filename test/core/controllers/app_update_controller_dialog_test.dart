import 'dart:async';

import 'package:flutter/material.dart';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:ghar360/core/controllers/app_update_controller.dart';
import 'package:ghar360/core/storage/app_database.dart';
import 'package:ghar360/core/widgets/common/app_update_dialog.dart';
import 'package:ghar360/core/widgets/common/app_update_host.dart';
import '../../helpers/app_update_test_harness.dart';
import '../../helpers/provider_test_app.dart';

void main() {
  late UpdateTestHarness harness;
  late GlobalKey<NavigatorState> navigatorKey;
  setUp(() {
    harness = UpdateTestHarness();
    navigatorKey = GlobalKey<NavigatorState>();
  });
  tearDown(() => harness.dispose());
  Future<void> pump(WidgetTester tester, {bool enabled = true, double scale = 1}) async {
    await tester.pumpProviderApp(
      UncontrolledProviderScope(
        container: harness.container,
        child: AppUpdateHost(
          enabled: enabled,
          navigatorKey: navigatorKey,
          child: Navigator(
            key: navigatorKey,
            onGenerateRoute: (_) =>
                MaterialPageRoute<void>(builder: (_) => const Scaffold(body: Text('App content'))),
          ),
        ),
      ),
      textScale: scale,
    );
    await tester.pumpAndSettle();
  }

  Future<void> dispose(WidgetTester tester) async {
    await tester.pumpWidget(const SizedBox());
    await tester.pumpAndSettle();
  }

  testWidgets('mandatory Update launches store; back and barrier cannot dismiss', (tester) async {
    harness.repository.response = () async => updateAvailable.copyWith(isMandatory: true);
    await pump(tester);
    expect(find.text('Update Now'), findsOneWidget);
    await tester.tapAt(const Offset(10, 10));
    await tester.pumpAndSettle();
    expect(find.byType(AppUpdateDialog), findsOneWidget);
    await Navigator.of(tester.element(find.byType(AppUpdateDialog))).maybePop();
    await tester.pumpAndSettle();
    expect(find.byType(AppUpdateDialog), findsOneWidget);
    await tester.tap(find.text('Update Now'));
    await tester.pumpAndSettle();
    expect(harness.platform.opened.single.toString(), 'https://store.test/update');
    expect(harness.state.check.isLoading, isFalse);
    expect(find.byType(AppUpdateDialog), findsNothing);
    await dispose(tester);
  });
  testWidgets('optional Not Now stores skipped version', (tester) async {
    harness.repository.response = () async => updateAvailable;
    await pump(tester);
    expect(harness.database.values[AppUpdateController.skippedVersionKey], isNull);
    await tester.tap(find.text('Not Now'));
    await tester.pumpAndSettle();
    expect(harness.database.values[AppUpdateController.skippedVersionKey], '2.0.0');
    expect(find.byType(AppUpdateDialog), findsNothing);
    await dispose(tester);
  });
  testWidgets('optional Update launches store', (tester) async {
    harness.repository.response = () async => updateAvailable;
    await pump(tester);
    await tester.tap(find.text('Update'));
    await tester.pumpAndSettle();
    expect(harness.platform.opened, hasLength(1));
    expect(find.byType(AppUpdateDialog), findsNothing);
    await dispose(tester);
  });
  testWidgets('optional barrier dismissal stores skipped version', (tester) async {
    harness.repository.response = () async => updateAvailable;
    await pump(tester);
    await tester.tapAt(const Offset(10, 10));
    await tester.pumpAndSettle();
    expect(harness.database.values[AppUpdateController.skippedVersionKey], '2.0.0');
    expect(find.byType(AppUpdateDialog), findsNothing);
    await dispose(tester);
  });
  testWidgets('store failure keeps dialog and allows explicit retry', (tester) async {
    harness.repository.response = () async => updateAvailable;
    harness.platform.launch = () async => false;
    await pump(tester);
    await tester.tap(find.text('Update'));
    await tester.pumpAndSettle();
    expect(find.text('Could not open the store. Try again.'), findsOneWidget);
    expect(find.byType(AppUpdateDialog), findsOneWidget);
    harness.platform.launch = () async => true;
    await tester.tap(find.text('Update'));
    await tester.pumpAndSettle();
    expect(find.byType(AppUpdateDialog), findsNothing);
    await dispose(tester);
  });
  testWidgets('skip write failure keeps dialog and retry commits', (tester) async {
    harness.repository.response = () async => updateAvailable;
    harness.database.writeError = StorageFailure('disk full');
    await pump(tester);
    await tester.tap(find.text('Not Now'));
    await tester.pumpAndSettle();
    expect(find.text('Could not save your choice. Try again.'), findsOneWidget);
    expect(find.byType(AppUpdateDialog), findsOneWidget);
    harness.database.writeError = null;
    await tester.tap(find.text('Not Now'));
    await tester.pumpAndSettle();
    expect(find.byType(AppUpdateDialog), findsNothing);
    await dispose(tester);
  });
  testWidgets('pending store launch disables actions and blocks optional back', (tester) async {
    final launch = Completer<bool>();
    harness.repository.response = () async => updateAvailable;
    harness.platform.launch = () => launch.future;
    await pump(tester);
    await tester.tap(find.text('Update'));
    await tester.pump();
    expect(find.byType(LinearProgressIndicator), findsOneWidget);
    expect(tester.widget<ElevatedButton>(find.byType(ElevatedButton)).onPressed, isNull);
    expect(tester.widget<TextButton>(find.widgetWithText(TextButton, 'Not Now')).onPressed, isNull);
    await tester.tapAt(const Offset(10, 10));
    await tester.pump();
    expect(find.byType(AppUpdateDialog), findsOneWidget);
    launch.complete(true);
    await tester.pumpAndSettle();
    expect(harness.platform.opened, hasLength(1));
    await dispose(tester);
  });
  testWidgets('disabled host waits for Firebase readiness and ignores background events', (
    tester,
  ) async {
    await pump(tester, enabled: false);
    final state = tester.state(find.byType(AppUpdateHost)) as WidgetsBindingObserver;
    state.didChangeAppLifecycleState(AppLifecycleState.resumed);
    await tester.pumpAndSettle();
    expect(harness.repository.requests, isEmpty);
    await pump(tester);
    expect(harness.repository.requests, hasLength(1));
    harness.now = harness.now.add(const Duration(minutes: 6));
    for (final lifecycle in [
      AppLifecycleState.paused,
      AppLifecycleState.inactive,
      AppLifecycleState.detached,
    ]) {
      state.didChangeAppLifecycleState(lifecycle);
    }
    await tester.pumpAndSettle();
    expect(harness.repository.requests, hasLength(1));
    state.didChangeAppLifecycleState(AppLifecycleState.resumed);
    await tester.pumpAndSettle();
    expect(harness.repository.requests, hasLength(2));
    await dispose(tester);
  });
  testWidgets('narrow large-text update dialog scrolls without overflow', (tester) async {
    tester.view.physicalSize = const Size(320, 640);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    harness.repository.response = () async => updateAvailable.copyWith(
      releaseNotes: List.filled(10, 'Update with improvements.').join(' '),
    );
    await pump(tester, scale: 2);
    expect(find.byType(AppUpdateDialog), findsOneWidget);
    expect(tester.takeException(), isNull);
    await tester.tap(find.text('Not Now'));
    await tester.pumpAndSettle();
    await dispose(tester);
  });
}
