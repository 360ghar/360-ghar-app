import 'package:flutter/material.dart';

import 'package:flutter_test/flutter_test.dart';
import 'package:get/get.dart';

import 'package:ghar360/core/translations/app_translations.dart';
import 'package:ghar360/core/widgets/common/animated_content_switcher.dart';
import '../../../helpers/getx_test_binding.dart';

void main() {
  setUp(() => GetxTestBinding.init());
  tearDown(() => GetxTestBinding.reset());

  Future<void> pumpWidget(WidgetTester tester, Widget child) async {
    await tester.pumpWidget(
      GetMaterialApp(
        translations: AppTranslations(),
        locale: const Locale('en', 'US'),
        fallbackLocale: const Locale('en', 'US'),
        home: Scaffold(body: Center(child: child)),
      ),
    );
  }

  group('AnimatedContentSwitcher', () {
    testWidgets('renders loading widget when isLoading is true', (tester) async {
      await pumpWidget(
        tester,
        const AnimatedContentSwitcher(
          isLoading: true,
          loadingWidget: Text('Loading...'),
          contentWidget: Text('Content'),
        ),
      );

      expect(find.byType(AnimatedContentSwitcher), findsOneWidget);
      expect(find.text('Loading...'), findsOneWidget);
      expect(find.text('Content'), findsNothing);
    });

    testWidgets('renders content widget when isLoading is false', (tester) async {
      await pumpWidget(
        tester,
        const AnimatedContentSwitcher(
          isLoading: false,
          loadingWidget: Text('Loading...'),
          contentWidget: Text('Content'),
        ),
      );

      expect(find.text('Content'), findsOneWidget);
      expect(find.text('Loading...'), findsNothing);
    });

    testWidgets('switches between loading and content with animation', (tester) async {
      await pumpWidget(
        tester,
        const AnimatedContentSwitcher(
          isLoading: true,
          loadingWidget: Text('Loading...'),
          contentWidget: Text('Content'),
        ),
      );

      expect(find.text('Loading...'), findsOneWidget);

      // Switch to content.
      await pumpWidget(
        tester,
        const AnimatedContentSwitcher(
          isLoading: false,
          loadingWidget: Text('Loading...'),
          contentWidget: Text('Content'),
        ),
      );

      // Pump through the AnimatedSwitcher transition.
      await tester.pumpAndSettle();

      expect(find.text('Content'), findsOneWidget);
    });

    testWidgets('uses FadeTransition as the transition builder', (tester) async {
      await pumpWidget(
        tester,
        const AnimatedContentSwitcher(
          isLoading: true,
          loadingWidget: Text('Loading...'),
          contentWidget: Text('Content'),
        ),
      );

      expect(find.byType(FadeTransition), findsWidgets);
    });
  });

  group('AnimatedStateBuilder', () {
    testWidgets('renders loading state when isLoading is true', (tester) async {
      await pumpWidget(
        tester,
        AnimatedStateBuilder<String>(
          isLoading: true,
          data: null,
          loadingBuilder: () => const Text('Loading...'),
          errorBuilder: (e) => Text(e),
          contentBuilder: (d) => Text(d),
        ),
      );

      expect(find.text('Loading...'), findsOneWidget);
    });

    testWidgets('renders error state when error is set', (tester) async {
      await pumpWidget(
        tester,
        AnimatedStateBuilder<String>(
          isLoading: false,
          error: 'Oops',
          data: null,
          loadingBuilder: () => const Text('Loading...'),
          errorBuilder: (e) => Text(e),
          contentBuilder: (d) => Text(d),
        ),
      );

      expect(find.text('Oops'), findsOneWidget);
    });

    testWidgets('renders content state when data is set', (tester) async {
      await pumpWidget(
        tester,
        AnimatedStateBuilder<String>(
          isLoading: false,
          data: 'Hello',
          loadingBuilder: () => const Text('Loading...'),
          errorBuilder: (e) => Text(e),
          contentBuilder: (d) => Text(d),
        ),
      );

      expect(find.text('Hello'), findsOneWidget);
    });

    testWidgets('renders empty state when data is null and emptyBuilder provided', (tester) async {
      await pumpWidget(
        tester,
        AnimatedStateBuilder<String>(
          isLoading: false,
          data: null,
          loadingBuilder: () => const Text('Loading...'),
          errorBuilder: (e) => Text(e),
          contentBuilder: (d) => Text(d),
          emptyBuilder: () => const Text('Empty'),
        ),
      );

      expect(find.text('Empty'), findsOneWidget);
    });
  });

  group('FadeInWidget', () {
    testWidgets('renders child and animates on build', (tester) async {
      await pumpWidget(tester, const FadeInWidget(child: Text('Fade In')));

      expect(find.byType(FadeInWidget), findsOneWidget);
      expect(find.text('Fade In'), findsOneWidget);

      await tester.pumpAndSettle();
      expect(find.text('Fade In'), findsOneWidget);
    });

    testWidgets('respects delay before animating', (tester) async {
      await pumpWidget(
        tester,
        const FadeInWidget(delay: Duration(milliseconds: 100), child: Text('Delayed')),
      );

      // Before the delay elapses the widget is present but not yet animated.
      expect(find.text('Delayed'), findsOneWidget);

      await tester.pump(const Duration(milliseconds: 150));
      await tester.pumpAndSettle();

      expect(find.text('Delayed'), findsOneWidget);
    });
  });
}
