import 'package:flutter/material.dart';

import 'package:flutter_test/flutter_test.dart';

import 'package:ghar360/core/design/app_design_theme.dart';
import 'package:ghar360/core/storage/storage_failure.dart';
import 'package:ghar360/core/utils/app_exceptions.dart';
import 'package:ghar360/core/widgets/common/error_states.dart';
import 'package:ghar360/core/widgets/paper/paper_vignette.dart';
import '../../../helpers/provider_test_app.dart';

Future<void> _pump(
  WidgetTester tester,
  Widget child, {
  bool dark = false,
  double scale = 1,
  Locale locale = const Locale('en', 'US'),
}) async {
  await tester.pumpProviderApp(
    Scaffold(body: child),
    theme: dark ? AppDesignTheme.dark() : AppDesignTheme.light(),
    textScale: scale,
    locale: locale,
  );
  await tester.pump();
}

Finder _action(String id) => find.byKey(ValueKey('qa.state.$id.action'));

PaperScene _scene(WidgetTester tester) =>
    tester.widget<PaperVignette>(find.byType(PaperVignette)).scene;

void main() {
  group('genericError', () {
    testWidgets('network failure shows the offline scene and retries', (tester) async {
      var retried = 0;
      await _pump(
        tester,
        ErrorStates.genericError(
          error: NetworkException('offline', code: 'NETWORK_ERROR'),
          onRetry: () => retried++,
          seed: 'saved',
        ),
      );
      expect(_scene(tester), PaperScene.offline);
      expect(find.text('Could not connect'), findsOneWidget);
      await tester.tap(_action('error'));
      expect(retried, 1);
    });

    testWidgets('authentication and validation failures offer no retry', (tester) async {
      for (final error in [
        AuthenticationException('expired', code: AppException.unauthorizedCode),
        ValidationException('bad'),
        NetworkException('stop', code: 'CANCELLED'),
      ]) {
        await _pump(tester, ErrorStates.genericError(error: error, onRetry: () {}));
        expect(_action('error'), findsNothing, reason: '$error');
      }
    });

    testWidgets('not found shows the Sector 404 scene', (tester) async {
      await _pump(
        tester,
        ErrorStates.genericError(error: ApiException('gone', statusCode: 404), seed: 'details'),
      );
      expect(_scene(tester), PaperScene.notFound);
      // A missing home gets the property cut, not the route cut.
      expect(tester.widget<PaperVignette>(find.byType(PaperVignette)).seed, 'property');
    });

    testWidgets('a rate limit waits out Retry-After before retry is enabled', (tester) async {
      var retried = 0;
      await _pump(
        tester,
        ErrorStates.genericError(
          error: RateLimitException('slow down', retryAfter: const Duration(seconds: 3)),
          onRetry: () => retried++,
        ),
      );
      expect(find.text('Too many requests'), findsOneWidget);
      expect(find.text('Try again in 3 s'), findsOneWidget);
      expect(tester.widget<FilledButton>(_action('error')).onPressed, isNull);
      await tester.pump(const Duration(seconds: 1));
      expect(find.text('Try again in 2 s'), findsOneWidget);
      await tester.pump(const Duration(seconds: 2));
      expect(find.text('Retry'), findsOneWidget);
      await tester.tap(_action('error'));
      expect(retried, 1);
    });

    testWidgets('storage and unknown failures stay retryable with custom text', (tester) async {
      await _pump(
        tester,
        ErrorStates.genericError(
          error: StorageFailure('disk', code: 'WRITE_FAILED'),
          onRetry: () {},
          customMessage: 'Custom body',
          customRetryText: 'Load again',
        ),
      );
      expect(find.text('Custom body'), findsOneWidget);
      expect(find.text('Load again'), findsOneWidget);
    });
  });

  testWidgets('empty state has one action and a per-screen scene', (tester) async {
    var tapped = false;
    await _pump(
      tester,
      ErrorStates.emptyState(
        title: 'Nothing saved',
        message: 'Like a home to keep it here.',
        actionText: 'Discover homes',
        onAction: () => tapped = true,
        seed: 'liked',
      ),
    );
    expect(tester.widget<PaperVignette>(find.byType(PaperVignette)).seed, 'liked');
    await tester.tap(_action('empty'));
    expect(tapped, isTrue);
  });

  testWidgets('search empty clears the query', (tester) async {
    var cleared = false;
    await _pump(
      tester,
      ErrorStates.searchEmpty(searchQuery: 'villa', onClearSearch: () => cleared = true),
    );
    await tester.tap(_action('search_empty'));
    expect(cleared, isTrue);
  });

  testWidgets('empty deck changes filters and keeps refresh as a quiet link', (tester) async {
    var filters = 0, refresh = 0;
    await _pump(
      tester,
      ErrorStates.swipeDeckEmpty(onChangeFilters: () => filters++, onRefresh: () => refresh++),
    );
    await tester.tap(_action('deck_empty'));
    await tester.tap(find.byKey(const ValueKey('qa.state.deck_empty.secondary')));
    expect((filters, refresh), (1, 1));
  });

  testWidgets('inline error announces and retries', (tester) async {
    var retried = false;
    await _pump(
      tester,
      ErrorStates.inlineError(message: 'Could not calculate', onRetry: () => retried = true),
    );
    await tester.tap(find.text('Retry'));
    expect(retried, isTrue);
  });

  testWidgets('inline error stacks retry under the message at 320 px, Hindi 2x', (tester) async {
    tester.view.physicalSize = const Size(320, 640);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    const message = 'सुविधाएँ लोड नहीं हो सकीं';
    await _pump(
      tester,
      ErrorStates.inlineError(message: message, onRetry: () {}),
      locale: const Locale('hi', 'IN'),
      scale: 2,
      dark: true,
    );
    expect(tester.takeException(), isNull);
    expect(tester.getSize(find.text(message)).width, greaterThan(150));
    expect(
      tester.getTopLeft(find.byType(TextButton)).dy,
      greaterThan(tester.getTopLeft(find.text(message)).dy),
    );
  });

  testWidgets('profile error retries, shows progress and signs out', (tester) async {
    var retried = false, signedOut = false;
    await _pump(
      tester,
      ErrorStates.profileLoadError(
        onRetry: () => retried = true,
        onSignOut: () => signedOut = true,
      ),
    );
    await tester.tap(_action('profile_error'));
    await tester.tap(find.byKey(const ValueKey('qa.state.profile_error.secondary')));
    expect((retried, signedOut), (true, true));
    await _pump(tester, ErrorStates.profileLoadError(onRetry: () {}, isRetrying: true));
    expect(tester.widget<FilledButton>(_action('profile_error')).onPressed, isNull);
  });

  for (final dark in [false, true]) {
    testWidgets('states fit 320 px Hindi at 2x text (${dark ? 'dark' : 'light'})', (tester) async {
      tester.view.physicalSize = const Size(320, 640);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);
      await _pump(
        tester,
        ErrorStates.swipeDeckEmpty(onChangeFilters: () {}, onRefresh: () {}),
        dark: dark,
        scale: 2,
        locale: const Locale('hi', 'IN'),
      );
      expect(tester.takeException(), isNull);
    });
  }
}
