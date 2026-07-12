import 'package:flutter/material.dart';

import 'package:flutter_test/flutter_test.dart';
import 'package:get/get.dart';
import 'package:ghar360/core/data/models/app_update_models.dart';
import 'package:ghar360/core/translations/app_translations.dart';
import 'package:ghar360/core/widgets/common/app_update_dialog.dart';

import '../../../helpers/getx_test_binding.dart';

void main() {
  setUp(() => GetxTestBinding.init());
  tearDown(() => GetxTestBinding.reset());

  Future<void> pumpDialog(WidgetTester tester, AppUpdateDialog dialog) async {
    await tester.pumpWidget(
      GetMaterialApp(
        translations: AppTranslations(),
        locale: const Locale('en', 'US'),
        fallbackLocale: const Locale('en', 'US'),
        home: Scaffold(body: Center(child: dialog)),
      ),
    );
  }

  testWidgets('renders optional update dialog with version info and release notes',
      (tester) async {
    await pumpDialog(
      tester,
      AppUpdateDialog(
        currentVersion: '1.0.0',
        response: const AppVersionCheckResponse(
          updateAvailable: true,
          isMandatory: false,
          latestVersion: '1.1.0',
          minSupportedVersion: '0.9.0',
          releaseNotes: 'Bug fixes and improvements',
        ),
      ),
    );

    expect(find.byType(AppUpdateDialog), findsOneWidget);
    expect(find.byType(AlertDialog), findsOneWidget);
    // Title for optional update.
    expect(find.text('Update Available'), findsOneWidget);
    // Current version label.
    expect(find.text('Current version: 1.0.0'), findsOneWidget);
    // Latest version label.
    expect(find.text('Latest version: 1.1.0'), findsOneWidget);
    // Minimum supported version label.
    expect(find.text('Minimum supported: 0.9.0'), findsOneWidget);
    // Release notes text.
    expect(find.text('Bug fixes and improvements'), findsOneWidget);
    // Optional update has two action buttons: "Not Now" and "Update".
    expect(find.text('Not Now'), findsOneWidget);
    expect(find.text('Update'), findsOneWidget);
  });

  testWidgets('renders mandatory update dialog with single update button',
      (tester) async {
    await pumpDialog(
      tester,
      AppUpdateDialog(
        currentVersion: '1.0.0',
        response: const AppVersionCheckResponse(
          updateAvailable: true,
          isMandatory: true,
          latestVersion: '2.0.0',
          releaseNotes: 'Critical security update',
        ),
      ),
    );

    // Title for mandatory update.
    expect(find.text('Mandatory Update Required'), findsOneWidget);
    expect(find.text('Latest version: 2.0.0'), findsOneWidget);
    expect(find.text('Critical security update'), findsOneWidget);
    // Mandatory update has only the "Update Now" button.
    expect(find.text('Update Now'), findsOneWidget);
    expect(find.text('Not Now'), findsNothing);
  });

  testWidgets('shows optional description when release notes are empty',
      (tester) async {
    await pumpDialog(
      tester,
      AppUpdateDialog(
        currentVersion: '1.0.0',
        response: const AppVersionCheckResponse(
          updateAvailable: true,
          isMandatory: false,
          latestVersion: '1.1.0',
          releaseNotes: '',
        ),
      ),
    );

    expect(
      find.text('A new update is available with the latest improvements.'),
      findsOneWidget,
    );
  });

  testWidgets('shows mandatory description when release notes are null',
      (tester) async {
    await pumpDialog(
      tester,
      AppUpdateDialog(
        currentVersion: '1.0.0',
        response: const AppVersionCheckResponse(
          updateAvailable: true,
          isMandatory: true,
          latestVersion: '2.0.0',
        ),
      ),
    );

    expect(
      find.text('Please update the app to continue using all features.'),
      findsOneWidget,
    );
  });

  testWidgets('omits latest version line when latestVersion is null',
      (tester) async {
    await pumpDialog(
      tester,
      AppUpdateDialog(
        currentVersion: '1.0.0',
        response: const AppVersionCheckResponse(
          updateAvailable: true,
          isMandatory: false,
        ),
      ),
    );

    expect(find.textContaining('Latest version:'), findsNothing);
    // Current version is still shown.
    expect(find.text('Current version: 1.0.0'), findsOneWidget);
  });

  testWidgets('mandatory dialog prevents back navigation (PopScope)', (tester) async {
    await pumpDialog(
      tester,
      AppUpdateDialog(
        currentVersion: '1.0.0',
        response: const AppVersionCheckResponse(
          updateAvailable: true,
          isMandatory: true,
          latestVersion: '2.0.0',
        ),
      ),
    );

    final popScope = tester.widget<PopScope>(find.byType(PopScope));
    // Mandatory update should NOT allow popping.
    expect(popScope.canPop, isFalse);
  });

  testWidgets('optional dialog allows back navigation (PopScope)', (tester) async {
    await pumpDialog(
      tester,
      AppUpdateDialog(
        currentVersion: '1.0.0',
        response: const AppVersionCheckResponse(
          updateAvailable: true,
          isMandatory: false,
          latestVersion: '1.1.0',
        ),
      ),
    );

    final popScope = tester.widget<PopScope>(find.byType(PopScope));
    // Optional update should allow popping.
    expect(popScope.canPop, isTrue);
  });
}
