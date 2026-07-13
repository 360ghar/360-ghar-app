import 'package:flutter/material.dart';

import 'package:flutter_test/flutter_test.dart';
import 'package:get/get.dart';

import 'package:ghar360/core/translations/app_translations.dart';
import 'package:ghar360/core/widgets/common/max_content_width.dart';
import '../../../helpers/getx_test_binding.dart';

void main() {
  setUp(() => GetxTestBinding.init());
  tearDown(() => GetxTestBinding.reset());

  Future<void> pumpWidget(
    WidgetTester tester,
    Widget child, {
    Size size = const Size(400, 800),
  }) async {
    await tester.pumpWidget(
      GetMaterialApp(
        translations: AppTranslations(),
        locale: const Locale('en', 'US'),
        fallbackLocale: const Locale('en', 'US'),
        home: MediaQuery(
          data: MediaQueryData(size: size),
          child: Scaffold(body: child),
        ),
      ),
    );
  }

  /// Finds the [ConstrainedBox] that is a direct descendant of
  /// [MaxContentWidth] (i.e. the one it creates), ignoring the Scaffold's own
  /// internal ConstrainedBox.
  Finder constrainedBoxInMaxContent() =>
      find.descendant(of: find.byType(MaxContentWidth), matching: find.byType(ConstrainedBox));

  Finder centerInMaxContent() =>
      find.descendant(of: find.byType(MaxContentWidth), matching: find.byType(Center));

  testWidgets('renders the provided child', (tester) async {
    await pumpWidget(tester, const MaxContentWidth(child: Text('Content')));

    expect(find.byType(MaxContentWidth), findsOneWidget);
    expect(find.text('Content'), findsOneWidget);
  });

  testWidgets('on compact width returns child directly (no Center/ConstrainedBox)', (tester) async {
    // Compact width (< 600) → contentMaxWidth is double.infinity → child returned as-is.
    await pumpWidget(
      tester,
      const MaxContentWidth(child: Text('Content')),
      size: const Size(400, 800),
    );

    expect(find.byType(MaxContentWidth), findsOneWidget);
    // No Center or ConstrainedBox created by MaxContentWidth on compact.
    expect(centerInMaxContent(), findsNothing);
    expect(constrainedBoxInMaxContent(), findsNothing);
  });

  testWidgets('on medium width wraps child in Center + ConstrainedBox', (tester) async {
    // Medium width (600–840) → contentMaxWidth is 600.
    await pumpWidget(
      tester,
      const MaxContentWidth(child: Text('Content')),
      size: const Size(700, 800),
    );

    expect(centerInMaxContent(), findsOneWidget);
    expect(constrainedBoxInMaxContent(), findsOneWidget);
    expect(find.text('Content'), findsOneWidget);
  });

  testWidgets('respects explicit maxWidth parameter', (tester) async {
    await pumpWidget(
      tester,
      const MaxContentWidth(maxWidth: 500, child: Text('Content')),
      size: const Size(1200, 800),
    );

    final constrainedBox = tester.widget<ConstrainedBox>(constrainedBoxInMaxContent());
    expect(constrainedBox.constraints.maxWidth, 500);
  });

  testWidgets('explicit maxWidth overrides responsive value even on compact', (tester) async {
    await pumpWidget(
      tester,
      const MaxContentWidth(maxWidth: 400, child: Text('Content')),
      size: const Size(300, 800),
    );

    // Even on compact, an explicit maxWidth forces Center + ConstrainedBox.
    expect(centerInMaxContent(), findsOneWidget);
    expect(constrainedBoxInMaxContent(), findsOneWidget);

    final constrainedBox = tester.widget<ConstrainedBox>(constrainedBoxInMaxContent());
    expect(constrainedBox.constraints.maxWidth, 400);
  });

  testWidgets('on large width caps content to large max width', (tester) async {
    await pumpWidget(
      tester,
      const MaxContentWidth(child: Text('Content')),
      size: const Size(1400, 800),
    );

    expect(centerInMaxContent(), findsOneWidget);
    expect(constrainedBoxInMaxContent(), findsOneWidget);

    final constrainedBox = tester.widget<ConstrainedBox>(constrainedBoxInMaxContent());
    // Large class → 960.
    expect(constrainedBox.constraints.maxWidth, 960);
  });
}
