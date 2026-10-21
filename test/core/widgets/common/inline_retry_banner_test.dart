import 'package:flutter/material.dart';

import 'package:flutter_test/flutter_test.dart';

import 'package:ghar360/core/utils/app_exceptions.dart';
import 'package:ghar360/core/widgets/common/inline_retry_banner.dart';
import '../../../helpers/provider_test_app.dart';

void main() {
  testWidgets('retry stays inline and retains button size while loading', (tester) async {
    var retries = 0;
    Widget banner(bool loading) => Scaffold(
      body: Column(
        children: [
          InlineRetryBanner(
            message: 'Could not refresh.',
            onRetry: () => retries++,
            isLoading: loading,
          ),
          const Text('Loaded property'),
        ],
      ),
    );
    await tester.pumpProviderApp(banner(false));
    final before = tester.getSize(find.byType(TextButton));
    await tester.tap(find.byType(TextButton));
    expect(retries, 1);
    await tester.pumpProviderApp(banner(true));
    expect(tester.getSize(find.byType(TextButton)), before);
    expect(tester.widget<TextButton>(find.byType(TextButton)).onPressed, isNull);
    expect(find.text('Loaded property'), findsOneWidget);
    expect(find.byType(CircularProgressIndicator), findsOneWidget);
  });

  testWidgets('large text fits and automation ID is not a spoken label', (tester) async {
    tester.view.physicalSize = const Size(320, 700);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    await tester.pumpProviderApp(
      Scaffold(
        body: InlineRetryBanner(
          message: 'Could not refresh. Your loaded results are still available.',
          onRetry: () {},
        ),
      ),
      textScale: 2,
    );
    expect(tester.takeException(), isNull);
    final semantics = tester.widgetList<Semantics>(find.byType(Semantics));
    expect(semantics.any((s) => s.properties.label?.contains('qa.') ?? false), isFalse);
  });

  testWidgets('a rate limit disables retry until Retry-After has passed', (tester) async {
    var retried = 0;
    await tester.pumpProviderApp(
      Scaffold(
        body: InlineRetryBanner(
          message: 'Could not refresh.',
          error: RateLimitException('slow', retryAfter: const Duration(seconds: 2)),
          onRetry: () => retried++,
        ),
      ),
    );
    expect(find.text('Try again in 2 s'), findsOneWidget);
    await tester.tap(find.byKey(const ValueKey('qa.content.retry')));
    expect(retried, 0);
    await tester.pump(const Duration(seconds: 2));
    await tester.tap(find.byKey(const ValueKey('qa.content.retry')));
    expect(retried, 1);
  });
}
