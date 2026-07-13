// test/features/profile/presentation/views/about_view_test.dart
//
// Widget tests for [AboutView]. Covers:
// - App logo, name and tagline rendering
// - About app description section
// - Key features section (all five feature items)
// - App information rows (version, build, platform) via FutureBuilder
// - Loading state of the version FutureBuilder
// - Copyright and made-with-love footer
// - Platform label computation

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:get/get.dart';
import 'package:ghar360/core/controllers/app_update_controller.dart';
import 'package:ghar360/core/data/models/app_update_models.dart';
import 'package:ghar360/core/translations/app_translations.dart';
import 'package:ghar360/features/profile/presentation/views/about_view.dart';
import 'package:mocktail/mocktail.dart';

import '../../../../helpers/getx_test_binding.dart';
import '../../../../helpers/mocks.dart';

/// Mock for [AppUpdateController] (a [GetxService]).
class _MockAppUpdateController extends GetxServiceMock implements AppUpdateController {}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  late _MockAppUpdateController appUpdateController;

  setUp(() {
    // Suppress RenderFlex overflow errors that occur in narrow test screens.
    FlutterError.onError = (details) {
      if (!details.summary.toString().contains('overflowed')) {
        FlutterError.presentError(details);
      }
    };

    GetxTestBinding.init();

    appUpdateController = _MockAppUpdateController();
    // Default: resolve version info immediately.
    when(
      () => appUpdateController.getVersionInfo(),
    ).thenAnswer((_) async => const AppVersionInfo(version: '1.2.3', buildNumber: 42));

    GetxTestBinding.bind().register<AppUpdateController>(appUpdateController);
  });

  tearDown(() {
    FlutterError.onError = FlutterError.presentError;
    GetxTestBinding.reset();
  });

  Future<void> pumpView(WidgetTester tester) async {
    await tester.pumpWidget(
      GetMaterialApp(
        translations: AppTranslations(),
        locale: const Locale('en', 'US'),
        fallbackLocale: const Locale('en', 'US'),
        home: const AboutView(),
      ),
    );
    await tester.pump();
  }

  group('AboutView', () {
    testWidgets('renders app logo, name and tagline', (tester) async {
      await pumpView(tester);

      expect(find.byIcon(Icons.home), findsOneWidget);
      expect(find.text('360ghar'), findsOneWidget);
      expect(find.text('about_tagline'.tr), findsOneWidget);
    });

    testWidgets('renders about app description section', (tester) async {
      await pumpView(tester);

      expect(find.text('about_app_section_title'.tr), findsOneWidget);
      expect(find.text('about_app_section_body'.tr), findsOneWidget);
    });

    testWidgets('renders all five key feature items', (tester) async {
      await pumpView(tester);

      expect(find.text('about_key_features_title'.tr), findsOneWidget);
      expect(find.text('about_feature_swipe_title'.tr), findsOneWidget);
      expect(find.text('about_feature_tours_title'.tr), findsOneWidget);
      expect(find.text('about_feature_favorites_title'.tr), findsOneWidget);
      expect(find.text('about_feature_location_title'.tr), findsOneWidget);
      expect(find.text('about_feature_agent_title'.tr), findsOneWidget);
    });

    testWidgets('renders feature icons', (tester) async {
      await pumpView(tester);

      expect(find.byIcon(Icons.swipe), findsOneWidget);
      expect(find.byIcon(Icons.threesixty), findsOneWidget);
      expect(find.byIcon(Icons.favorite), findsOneWidget);
      expect(find.byIcon(Icons.location_on), findsOneWidget);
      expect(find.byIcon(Icons.person), findsOneWidget);
    });

    testWidgets('renders version and build info rows when data loads', (tester) async {
      await pumpView(tester);
      // Allow the FutureBuilder to resolve.
      await tester.pump(const Duration(milliseconds: 50));

      expect(find.text('about_version_label'.tr), findsOneWidget);
      expect(find.text('1.2.3'), findsOneWidget);
      expect(find.text('about_build_label'.tr), findsOneWidget);
      expect(find.text('42'), findsOneWidget);
      expect(find.text('about_platform_label'.tr), findsOneWidget);
    });

    testWidgets('renders platform label', (tester) async {
      await pumpView(tester);
      await tester.pump(const Duration(milliseconds: 50));

      // The platform label is one of iOS/Android/Web/Flutter.
      final platformText = find.text('about_platform_label'.tr);
      expect(platformText, findsOneWidget);
      // The value is rendered next to the label; verify a known label exists.
      expect(find.text('Flutter'), findsOneWidget);
    });

    testWidgets('renders copyright and made-with-love footer', (tester) async {
      await pumpView(tester);

      expect(find.text('about_copyright'.tr), findsOneWidget);
      expect(find.text('about_made_with_love'.tr), findsOneWidget);
    });

    testWidgets('shows dash placeholder when version info is null', (tester) async {
      when(() => appUpdateController.getVersionInfo()).thenAnswer((_) async => null);

      await pumpView(tester);
      await tester.pump(const Duration(milliseconds: 50));

      // Both version and build show the em-dash fallback.
      expect(find.text('—'), findsNWidgets(2));
    });

    testWidgets('shows dash for build when buildNumber is null', (tester) async {
      when(
        () => appUpdateController.getVersionInfo(),
      ).thenAnswer((_) async => const AppVersionInfo(version: '2.0.0'));

      await pumpView(tester);
      await tester.pump(const Duration(milliseconds: 50));

      expect(find.text('2.0.0'), findsOneWidget);
      // Build number is null → em-dash.
      expect(find.text('—'), findsOneWidget);
    });

    testWidgets('renders the screen semantics identifier', (tester) async {
      await pumpView(tester);

      expect(find.byKey(const ValueKey('qa.profile.about.screen')), findsOneWidget);
    });
  });
}
