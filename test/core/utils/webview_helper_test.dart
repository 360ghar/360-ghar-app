// test/core/utils/webview_helper_test.dart
//
// Unit and widget tests for [WebViewHelper]. Covers:
// - ensureInitialized / isSupported lifecycle
// - createInteractiveGestureRecognizers structure
// - createController error propagation (no platform in test env)
// - createSafeWebView error fallback widget rendering
// - _buildErrorWidget visual output with and without custom errorWidget

import 'package:flutter/foundation.dart';
import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart';

import 'package:flutter_test/flutter_test.dart';
import 'package:get/get.dart';

import 'package:ghar360/core/translations/app_translations.dart';
import 'package:ghar360/core/utils/webview_helper.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  setUpAll(() {
    Get.testMode = true;
  });

  /// Helper that forces a non-Android target platform for the duration of a
  /// single test. This avoids the Android-specific pigeon channel path in
  /// [WebViewHelper.createBaseController] (which makes async platform calls
  /// that fail in the test host and leak errors after test completion).
  ///
  /// The override is registered with [addTearDown] so it is cleared BEFORE the
  /// Flutter test framework's `_verifyInvariants` check (which asserts all
  /// foundation debug vars are unset between tests).
  void useNonAndroidPlatform() {
    debugDefaultTargetPlatformOverride = TargetPlatform.iOS;
    addTearDown(() => debugDefaultTargetPlatformOverride = null);
  }

  // ── ensureInitialized / isSupported ──────────────────────────────────────

  group('WebViewHelper.ensureInitialized', () {
    test('completes without throwing', () {
      expect(() => WebViewHelper.ensureInitialized(), returnsNormally);
    });

    test('is idempotent — multiple calls are safe', () {
      WebViewHelper.ensureInitialized();
      WebViewHelper.ensureInitialized();
      expect(() => WebViewHelper.ensureInitialized(), returnsNormally);
    });
  });

  group('WebViewHelper.isSupported', () {
    test('returns true after ensureInitialized has run', () {
      // isSupported calls ensureInitialized() internally, which sets
      // _isInitialized = true.
      expect(WebViewHelper.isSupported, isTrue);
    });
  });

  // ── createInteractiveGestureRecognizers ──────────────────────────────────

  group('WebViewHelper.createInteractiveGestureRecognizers', () {
    test('returns a non-empty set', () {
      final recognizers = WebViewHelper.createInteractiveGestureRecognizers();
      expect(recognizers, isNotEmpty);
      expect(recognizers.length, 1);
    });

    test('returns a set containing a Factory<OneSequenceGestureRecognizer>', () {
      final recognizers = WebViewHelper.createInteractiveGestureRecognizers();
      final factory = recognizers.first;
      expect(factory, isA<Factory<OneSequenceGestureRecognizer>>());
    });

    test('the factory produces an EagerGestureRecognizer', () {
      final recognizers = WebViewHelper.createInteractiveGestureRecognizers();
      final recognizer = recognizers.first.constructor();
      expect(recognizer, isA<EagerGestureRecognizer>());
    });

    test('returns a new set instance on each call', () {
      final a = WebViewHelper.createInteractiveGestureRecognizers();
      final b = WebViewHelper.createInteractiveGestureRecognizers();
      expect(identical(a, b), isFalse);
      expect(a.length, b.length);
    });
  });

  // ── createController (no platform → throws) ──────────────────────────────

  group('WebViewHelper.createController', () {
    test('throws when WebView platform is not registered (test env)', () {
      useNonAndroidPlatform();
      // In the unit-test environment no WebViewPlatform implementation is
      // registered, so createBaseController throws an assertion error.
      // createController catches the error, logs it, and rethrows.
      expect(
        () => WebViewHelper.createController(url: 'https://example.com'),
        throwsA(isA<Object>()),
      );
    });

    test('throws for an empty URL when platform is unavailable', () {
      useNonAndroidPlatform();
      expect(() => WebViewHelper.createController(url: ''), throwsA(isA<Object>()));
    });
  });

  // ── createBaseController (no platform → throws) ──────────────────────────

  group('WebViewHelper.createBaseController', () {
    test('throws when WebView platform is not registered (test env)', () {
      useNonAndroidPlatform();
      expect(() => WebViewHelper.createBaseController(), throwsA(isA<Object>()));
    });

    test('accepts an onPermissionRequest callback without crashing the call site', () {
      useNonAndroidPlatform();
      // The callback is only invoked at runtime by the platform; in the test
      // env the platform assertion fires first, so the callback is never
      // called. We pass it to verify the parameter is accepted.
      expect(
        () => WebViewHelper.createBaseController(onPermissionRequest: (_) {}),
        throwsA(isA<Object>()),
      );
    });
  });

  // ── createSafeWebView (error fallback) ───────────────────────────────────

  group('WebViewHelper.createSafeWebView', () {
    Future<void> pumpWithGet(WidgetTester tester, WidgetBuilder builder) async {
      await tester.pumpWidget(
        GetMaterialApp(
          translations: AppTranslations(),
          locale: const Locale('en', 'US'),
          fallbackLocale: const Locale('en', 'US'),
          home: Scaffold(body: Builder(builder: builder)),
        ),
      );
    }

    testWidgets('renders default error widget when platform unavailable', (tester) async {
      await pumpWithGet(
        tester,
        (context) => WebViewHelper.createSafeWebView(context: context, url: 'https://example.com'),
      );

      // The default error widget shows the public_off icon and translated
      // title/body text.
      expect(find.byIcon(Icons.public_off), findsOneWidget);
      expect(find.text('360° Tour Unavailable'), findsOneWidget);
      expect(find.text('Virtual tour could not be loaded'), findsOneWidget);
    });

    testWidgets('renders default error widget with width and height', (tester) async {
      await pumpWithGet(
        tester,
        (context) => WebViewHelper.createSafeWebView(
          context: context,
          url: 'https://example.com',
          width: 300,
          height: 200,
        ),
      );

      // The Container is wrapped in a SizedBox with the given dimensions.
      expect(find.byType(SizedBox), findsWidgets);
      expect(find.byIcon(Icons.public_off), findsOneWidget);
    });

    testWidgets('uses custom errorWidget when provided', (tester) async {
      await pumpWithGet(
        tester,
        (context) => WebViewHelper.createSafeWebView(
          context: context,
          url: 'https://example.com',
          errorWidget: const Text('CUSTOM_FALLBACK'),
        ),
      );

      expect(find.text('CUSTOM_FALLBACK'), findsOneWidget);
      // The default error widget should NOT be shown.
      expect(find.byIcon(Icons.public_off), findsNothing);
    });

    testWidgets('error widget is returned for invalid URL too', (tester) async {
      await pumpWithGet(
        tester,
        (context) => WebViewHelper.createSafeWebView(context: context, url: 'not-a-valid-url'),
      );

      // Even with an invalid URL, the platform-unavailable error path is
      // triggered first (createBaseController throws before URL parsing).
      expect(find.byIcon(Icons.public_off), findsOneWidget);
    });

    testWidgets('error widget is returned for empty URL', (tester) async {
      await pumpWithGet(
        tester,
        (context) => WebViewHelper.createSafeWebView(context: context, url: ''),
      );

      expect(find.byIcon(Icons.public_off), findsOneWidget);
    });

    testWidgets('onPageStarted/onPageFinished callbacks are accepted', (tester) async {
      // These callbacks are passed to createController which throws before
      // they can be used; the error widget is returned instead.
      await pumpWithGet(
        tester,
        (context) => WebViewHelper.createSafeWebView(
          context: context,
          url: 'https://example.com',
          onPageStarted: (_) {},
          onPageFinished: (_) {},
        ),
      );

      expect(find.byIcon(Icons.public_off), findsOneWidget);
    });
  });
}
