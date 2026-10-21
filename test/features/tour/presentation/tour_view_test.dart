import 'package:flutter/material.dart';

import 'package:flutter_test/flutter_test.dart';

import 'package:ghar360/core/design/app_design_theme.dart';
import 'package:ghar360/core/widgets/common/error_states.dart';
import 'package:ghar360/features/tour/presentation/views/tour_view.dart';
import '../../../helpers/fake_webview_platform.dart';
import '../../../helpers/provider_test_app.dart';

void main() {
  setUp(installFakeWebViewPlatform);
  tearDown(uninstallFakeWebViewPlatform);
  testWidgets('invalid typed URL returns to the previous route', (tester) async {
    await tester.pumpProviderApp(
      Builder(
        builder: (context) => Scaffold(
          body: TextButton(
            onPressed: () => Navigator.of(
              context,
            ).push(MaterialPageRoute<void>(builder: (_) => const TourView(url: 'invalid'))),
            child: const Text('Open tour'),
          ),
        ),
      ),
    );
    await tester.tap(find.text('Open tour'));
    await tester.pumpAndSettle();
    expect(find.byType(StateBlock), findsOneWidget);
    await tester.tap(find.byKey(const ValueKey('qa.tour.invalid_state.action')));
    await tester.pumpAndSettle();
    expect(find.text('Open tour'), findsOneWidget);
    expect(find.byType(StateBlock), findsNothing);
  });
  for (final url in ['invalid', 'https://example.com/tour']) {
    testWidgets('320 px, Hindi, 2x text and dark theme fit for $url', (tester) async {
      tester.view.physicalSize = const Size(320, 640);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);
      await tester.pumpProviderApp(
        TourView(url: url),
        locale: const Locale('hi', 'IN'),
        textScale: 2,
        theme: AppDesignTheme.dark(),
      );
      await tester.pump(const Duration(milliseconds: 200));
      expect(find.byType(StateBlock), url == 'invalid' ? findsOneWidget : findsNothing);
      expect(tester.takeException(), isNull);
    });
  }
  testWidgets('typed title is shown and theme update does not reload the native page', (
    tester,
  ) async {
    await tester.pumpProviderApp(
      const TourView(url: 'https://example.com/tour', title: 'Listing tour'),
    );
    final controller = lastWebViewController!;
    await tester.pumpProviderApp(
      const TourView(url: 'https://example.com/tour', title: 'Listing tour'),
      theme: ThemeData.dark(),
    );
    expect(lastWebViewController, same(controller));
    expect(controller.loadRequestCalls, 1);
    expect(find.text('Listing tour'), findsOneWidget);
  });
}
