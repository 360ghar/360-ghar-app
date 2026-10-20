import 'package:flutter/material.dart';

import 'package:flutter_test/flutter_test.dart';
import 'package:package_info_plus/package_info_plus.dart';

import 'package:ghar360/core/design/paper/knife_icons.dart';
import 'package:ghar360/features/profile/presentation/views/about_view.dart';
import '../../../../helpers/knife_finders.dart';
import '../../../../helpers/profile_test_harness.dart';

void main() {
  late ProfileHarness h;
  setUp(() => h = ProfileHarness());
  tearDown(() => h.close());
  Future<void> pumpView(WidgetTester tester) => h.pump(tester, const AboutView());
  group('AboutView', () {
    testWidgets('renders app logo, name and tagline', (tester) async {
      await pumpView(tester);

      // The real logo mark, bare: no icon in a coloured tile.
      expect(find.byType(Image), findsOneWidget);
      expect(findKnife(KnifeIcon.home), findsNothing);
      expect(find.text('360ghar'), findsOneWidget);
      expect(find.text(tr('about_tagline')), findsOneWidget);
    });

    testWidgets('renders about app description section', (tester) async {
      await pumpView(tester);

      expect(find.text(tr('about_app_section_title')), findsOneWidget);
      expect(find.text(tr('about_app_section_body')), findsOneWidget);
    });

    testWidgets('renders all five key feature items', (tester) async {
      await pumpView(tester);

      expect(find.text(tr('about_key_features_title')), findsOneWidget);
      expect(find.text(tr('about_feature_swipe_title')), findsOneWidget);
      expect(find.text(tr('about_feature_tours_title')), findsOneWidget);
      expect(find.text(tr('about_feature_favorites_title')), findsOneWidget);
      expect(find.text(tr('about_feature_location_title')), findsOneWidget);
      expect(find.text(tr('about_feature_agent_title')), findsOneWidget);
    });

    testWidgets('renders feature icons', (tester) async {
      await pumpView(tester);

      expect(findKnife(KnifeIcon.compare), findsOneWidget);
      expect(findKnife(KnifeIcon.tour), findsOneWidget);
      expect(findKnife(KnifeIcon.heartSolid), findsOneWidget);
      expect(findKnife(KnifeIcon.pin), findsOneWidget);
      expect(findKnife(KnifeIcon.user), findsOneWidget);
    });

    testWidgets('renders version and build info rows when data loads', (tester) async {
      await pumpView(tester);
      // Allow the FutureBuilder to resolve.
      await tester.pump(const Duration(milliseconds: 50));

      expect(find.text(tr('about_version_label')), findsOneWidget);
      expect(find.text('1.2.3'), findsOneWidget);
      expect(find.text(tr('about_build_label')), findsOneWidget);
      expect(find.text('42'), findsOneWidget);
      expect(find.text(tr('about_platform_label')), findsOneWidget);
    });

    testWidgets('renders platform label', (tester) async {
      await pumpView(tester);
      await tester.pump(const Duration(milliseconds: 50));

      // The platform label is one of iOS/Android/Web/Flutter.
      final platformText = find.text(tr('about_platform_label'));
      expect(platformText, findsOneWidget);
      // The value is rendered next to the label; verify a known label exists.
      expect(find.text('Android'), findsOneWidget);
    });

    testWidgets('renders copyright and made-with-love footer', (tester) async {
      await pumpView(tester);

      expect(find.text(tr('about_copyright')), findsOneWidget);
      expect(find.text(tr('about_made_with_love')), findsOneWidget);
    });

    testWidgets('shows Unavailable when version info is null', (tester) async {
      h.info = null;

      await pumpView(tester);
      await tester.pump(const Duration(milliseconds: 50));

      // Both version and build say so in words.
      expect(find.text('Unavailable'), findsNWidgets(2));
    });

    testWidgets('shows Unavailable for build when buildNumber is empty', (tester) async {
      h.info = PackageInfo(appName: 'App', packageName: 'app', version: '2.0.0', buildNumber: '');

      await pumpView(tester);
      await tester.pump(const Duration(milliseconds: 50));

      expect(find.text('2.0.0'), findsOneWidget);
      expect(find.text('Unavailable'), findsOneWidget);
    });

    testWidgets('renders the screen semantics identifier', (tester) async {
      await pumpView(tester);

      expect(find.byKey(const ValueKey('qa.profile.about.screen')), findsOneWidget);
    });
  });
}
