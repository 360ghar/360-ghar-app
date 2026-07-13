import 'package:flutter/material.dart';

import 'package:flutter_test/flutter_test.dart';
import 'package:get/get.dart';

import 'package:ghar360/core/translations/app_translations.dart';
import 'package:ghar360/core/utils/app_exceptions.dart';
import 'package:ghar360/core/widgets/common/error_states.dart';
import '../../../helpers/getx_test_binding.dart';

void main() {
  setUp(() {
    GetxTestBinding.init();
    Get.locale = const Locale('en', 'US');
    Get.addTranslations(AppTranslations().keys);
  });
  tearDown(() => GetxTestBinding.reset());

  Future<void> pumpWidget(WidgetTester tester, Widget child) async {
    await tester.pumpWidget(
      GetMaterialApp(
        translations: AppTranslations(),
        locale: const Locale('en', 'US'),
        fallbackLocale: const Locale('en', 'US'),
        home: Scaffold(body: child),
      ),
    );
  }

  group('genericError', () {
    testWidgets('renders error title and message for a String error', (tester) async {
      await pumpWidget(tester, ErrorStates.genericError(error: 'Something broke'));

      expect(find.text('Error'), findsOneWidget);
      expect(find.text('Something broke'), findsOneWidget);
      expect(find.byIcon(Icons.error_outline_rounded), findsOneWidget);
    });

    testWidgets('renders retry button when onRetry is provided for String error', (tester) async {
      var retryCalled = false;
      await pumpWidget(
        tester,
        ErrorStates.genericError(error: 'Something broke', onRetry: () => retryCalled = true),
      );

      // String errors are retryable, so the button is shown.
      final retryButton = find.byType(ElevatedButton);
      expect(retryButton, findsOneWidget);
      expect(find.byIcon(Icons.refresh), findsOneWidget);

      await tester.tap(retryButton);
      await tester.pumpAndSettle();

      expect(retryCalled, isTrue);
    });

    testWidgets('does not render retry button when onRetry is null', (tester) async {
      await pumpWidget(tester, ErrorStates.genericError(error: 'Something broke'));

      expect(find.byType(ElevatedButton), findsNothing);
    });

    testWidgets('renders custom message when provided', (tester) async {
      await pumpWidget(
        tester,
        ErrorStates.genericError(error: 'Something broke', customMessage: 'A friendlier message'),
      );

      expect(find.text('A friendlier message'), findsOneWidget);
      // The original message is NOT shown when customMessage is provided.
      expect(find.text('Something broke'), findsNothing);
    });

    testWidgets('renders NetworkException with wifi_off icon and retryable button', (tester) async {
      await pumpWidget(
        tester,
        ErrorStates.genericError(
          error: NetworkException('No connection', code: 'CONNECTION_ERROR'),
          onRetry: () {},
        ),
      );

      expect(find.text('Connection Problem'), findsOneWidget);
      expect(find.text('No connection'), findsOneWidget);
      expect(find.byIcon(Icons.wifi_off_rounded), findsOneWidget);
      // NetworkException is retryable.
      expect(find.byType(ElevatedButton), findsOneWidget);
    });

    testWidgets('renders AuthenticationException with lock icon and no retry button', (
      tester,
    ) async {
      await pumpWidget(
        tester,
        ErrorStates.genericError(
          error: AuthenticationException('Session expired', code: 'UNAUTHORIZED'),
          onRetry: () {},
        ),
      );

      expect(find.text('Authentication Required'), findsOneWidget);
      expect(find.text('Session expired'), findsOneWidget);
      expect(find.byIcon(Icons.lock_outline_rounded), findsOneWidget);
      // AuthenticationException is NOT retryable, so no button even with onRetry.
      expect(find.byType(ElevatedButton), findsNothing);
    });

    testWidgets('renders ValidationException with warning icon and no retry button', (
      tester,
    ) async {
      await pumpWidget(
        tester,
        ErrorStates.genericError(error: ValidationException('Bad input'), onRetry: () {}),
      );

      expect(find.text('Invalid Input'), findsOneWidget);
      expect(find.text('Bad input'), findsOneWidget);
      expect(find.byIcon(Icons.warning_amber_rounded), findsOneWidget);
      expect(find.byType(ElevatedButton), findsNothing);
    });

    testWidgets('renders NotFoundException with search_off icon', (tester) async {
      await pumpWidget(tester, ErrorStates.genericError(error: NotFoundException('Not here')));

      expect(find.text('Not Found'), findsOneWidget);
      expect(find.text('Not here'), findsOneWidget);
      expect(find.byIcon(Icons.search_off_rounded), findsOneWidget);
    });

    testWidgets('renders ServerException with build icon and retryable button', (tester) async {
      await pumpWidget(
        tester,
        ErrorStates.genericError(error: ServerException('Down', statusCode: 500), onRetry: () {}),
      );

      expect(find.text('Server Error'), findsOneWidget);
      expect(find.text('Down'), findsOneWidget);
      expect(find.byIcon(Icons.build_circle_outlined), findsOneWidget);
      // ServerException with 5xx is retryable.
      expect(find.byType(ElevatedButton), findsOneWidget);
    });

    testWidgets('renders fallback for unknown error type', (tester) async {
      await pumpWidget(tester, ErrorStates.genericError(error: 42));

      expect(find.text('Error'), findsOneWidget);
      expect(find.text('Something went wrong'), findsOneWidget);
      expect(find.byIcon(Icons.error_outline_rounded), findsOneWidget);
    });
  });

  group('networkError', () {
    testWidgets('renders wifi off icon, title and message', (tester) async {
      await pumpWidget(tester, ErrorStates.networkError());

      expect(find.byIcon(Icons.wifi_off), findsOneWidget);
      expect(find.text('Connection Error'), findsOneWidget);
    });

    testWidgets('renders retry button when onRetry is provided', (tester) async {
      var retryCalled = false;
      await pumpWidget(tester, ErrorStates.networkError(onRetry: () => retryCalled = true));

      final retryButton = find.byType(ElevatedButton);
      expect(retryButton, findsOneWidget);

      await tester.tap(retryButton);
      await tester.pumpAndSettle();

      expect(retryCalled, isTrue);
    });
  });

  group('emptyState', () {
    testWidgets('renders title, message and default icon', (tester) async {
      await pumpWidget(
        tester,
        ErrorStates.emptyState(title: 'No Items', message: 'Nothing here yet'),
      );

      expect(find.text('No Items'), findsOneWidget);
      expect(find.text('Nothing here yet'), findsOneWidget);
      expect(find.byIcon(Icons.inbox_outlined), findsOneWidget);
    });

    testWidgets('renders custom icon when provided', (tester) async {
      await pumpWidget(
        tester,
        ErrorStates.emptyState(title: 'No Items', message: 'Nothing here yet', icon: Icons.search),
      );

      expect(find.byIcon(Icons.search), findsOneWidget);
      expect(find.byIcon(Icons.inbox_outlined), findsNothing);
    });

    testWidgets('renders emoji when provided (overrides icon)', (tester) async {
      await pumpWidget(
        tester,
        ErrorStates.emptyState(title: 'No Items', message: 'Nothing here yet', emoji: '🏠'),
      );

      expect(find.text('🏠'), findsOneWidget);
    });

    testWidgets('renders action button when onAction and actionText provided', (tester) async {
      var actionCalled = false;
      await pumpWidget(
        tester,
        ErrorStates.emptyState(
          title: 'No Items',
          message: 'Nothing here yet',
          onAction: () => actionCalled = true,
          actionText: 'Add Item',
        ),
      );

      final button = find.byType(ElevatedButton);
      expect(button, findsOneWidget);
      expect(find.text('Add Item'), findsOneWidget);

      await tester.tap(button);
      await tester.pumpAndSettle();

      expect(actionCalled, isTrue);
    });
  });

  group('inlineError', () {
    testWidgets('renders message and error icon', (tester) async {
      await pumpWidget(tester, ErrorStates.inlineError(message: 'Inline failure'));

      expect(find.text('Inline failure'), findsOneWidget);
      expect(find.byIcon(Icons.error_outline), findsOneWidget);
    });

    testWidgets('hides icon when showIcon is false', (tester) async {
      await pumpWidget(tester, ErrorStates.inlineError(message: 'Inline failure', showIcon: false));

      expect(find.byIcon(Icons.error_outline), findsNothing);
    });

    testWidgets('renders retry TextButton when onRetry provided', (tester) async {
      var retryCalled = false;
      await pumpWidget(
        tester,
        ErrorStates.inlineError(message: 'Inline failure', onRetry: () => retryCalled = true),
      );

      final button = find.byType(TextButton);
      expect(button, findsOneWidget);
      expect(find.text('Retry'), findsOneWidget);

      await tester.tap(button);
      await tester.pumpAndSettle();

      expect(retryCalled, isTrue);
    });
  });

  group('errorBanner', () {
    testWidgets('renders message, error icon and dismiss icon', (tester) async {
      await pumpWidget(
        tester,
        ErrorStates.errorBanner(message: 'Banner failure', onDismiss: () {}),
      );

      expect(find.text('Banner failure'), findsOneWidget);
      expect(find.byIcon(Icons.error_outline), findsOneWidget);
      expect(find.byIcon(Icons.close), findsOneWidget);
    });

    testWidgets('renders retry button when onRetry provided', (tester) async {
      await pumpWidget(tester, ErrorStates.errorBanner(message: 'Banner failure', onRetry: () {}));

      expect(find.text('Retry'), findsOneWidget);
    });
  });

  group('swipeDeckEmpty', () {
    testWidgets('renders home icon, title and message', (tester) async {
      await pumpWidget(tester, ErrorStates.swipeDeckEmpty());

      expect(find.byIcon(Icons.home_outlined), findsOneWidget);
      expect(find.text('No More Properties'), findsOneWidget);
    });

    testWidgets('renders change filters button when onChangeFilters provided', (tester) async {
      await pumpWidget(tester, ErrorStates.swipeDeckEmpty(onChangeFilters: () {}));

      expect(find.byIcon(Icons.tune), findsOneWidget);
      expect(find.text('Adjust Filters'), findsOneWidget);
    });

    testWidgets('renders refresh button when onRefresh provided', (tester) async {
      await pumpWidget(tester, ErrorStates.swipeDeckEmpty(onRefresh: () {}));

      expect(find.byIcon(Icons.refresh), findsOneWidget);
      expect(find.text('Refresh'), findsOneWidget);
    });

    testWidgets('does not render action buttons when callbacks are null', (tester) async {
      await pumpWidget(tester, ErrorStates.swipeDeckEmpty());

      expect(find.byIcon(Icons.tune), findsNothing);
      expect(find.byIcon(Icons.refresh), findsNothing);
    });
  });

  group('searchEmpty', () {
    testWidgets('renders search off icon and no results title', (tester) async {
      await pumpWidget(tester, ErrorStates.searchEmpty(searchQuery: 'apartment'));

      expect(find.byIcon(Icons.search_off), findsOneWidget);
      expect(find.text('No Results Found'), findsOneWidget);
    });

    testWidgets('renders clear search button when onClearSearch provided', (tester) async {
      await pumpWidget(tester, ErrorStates.searchEmpty(searchQuery: 'test', onClearSearch: () {}));

      expect(find.text('Clear Search'), findsOneWidget);
    });

    testWidgets('renders try different search button when provided', (tester) async {
      await pumpWidget(
        tester,
        ErrorStates.searchEmpty(searchQuery: 'test', onTryDifferentSearch: () {}),
      );

      expect(find.text('Try Different Search'), findsOneWidget);
    });

    testWidgets('does not render buttons when callbacks are null', (tester) async {
      await pumpWidget(tester, ErrorStates.searchEmpty(searchQuery: 'test'));

      expect(find.text('Clear Search'), findsNothing);
      expect(find.text('Try Different Search'), findsNothing);
    });
  });

  group('locationPermissionDenied', () {
    testWidgets('renders location off icon and title', (tester) async {
      await pumpWidget(tester, ErrorStates.locationPermissionDenied());

      expect(find.byIcon(Icons.location_off), findsOneWidget);
      expect(find.text('Location Access Needed'), findsOneWidget);
    });

    testWidgets('renders grant permission button when provided', (tester) async {
      await pumpWidget(tester, ErrorStates.locationPermissionDenied(onRequestPermission: () {}));

      expect(find.byIcon(Icons.location_on), findsOneWidget);
      expect(find.text('Grant Permission'), findsOneWidget);
    });

    testWidgets('renders open settings button when provided', (tester) async {
      await pumpWidget(tester, ErrorStates.locationPermissionDenied(onOpenSettings: () {}));

      expect(find.text('Open Settings'), findsOneWidget);
    });

    testWidgets('tapping grant permission calls callback', (tester) async {
      var permissionCalled = false;
      await pumpWidget(
        tester,
        ErrorStates.locationPermissionDenied(onRequestPermission: () => permissionCalled = true),
      );

      await tester.tap(find.text('Grant Permission'));
      await tester.pumpAndSettle();

      expect(permissionCalled, isTrue);
    });

    testWidgets('tapping open settings calls callback', (tester) async {
      var settingsCalled = false;
      await pumpWidget(
        tester,
        ErrorStates.locationPermissionDenied(onOpenSettings: () => settingsCalled = true),
      );

      await tester.tap(find.text('Open Settings'));
      await tester.pumpAndSettle();

      expect(settingsCalled, isTrue);
    });
  });

  group('profileLoadError', () {
    testWidgets('renders account icon and title', (tester) async {
      await pumpWidget(tester, ErrorStates.profileLoadError());

      expect(find.byIcon(Icons.account_circle_outlined), findsOneWidget);
      expect(find.text('Profile Load Error'), findsOneWidget);
    });

    testWidgets('renders custom message when provided', (tester) async {
      await pumpWidget(tester, ErrorStates.profileLoadError(customMessage: 'Custom error'));

      expect(find.text('Custom error'), findsOneWidget);
    });

    testWidgets('renders retry button when onRetry provided and not retrying', (tester) async {
      await pumpWidget(tester, ErrorStates.profileLoadError(onRetry: () {}));

      expect(find.byIcon(Icons.refresh), findsOneWidget);
      expect(find.text('Retry'), findsOneWidget);
    });

    testWidgets('shows retrying indicator when isRetrying is true', (tester) async {
      await pumpWidget(tester, ErrorStates.profileLoadError(onRetry: () {}, isRetrying: true));

      expect(find.byType(CircularProgressIndicator), findsOneWidget);
      expect(find.text('Retrying...'), findsOneWidget);
    });

    testWidgets('renders sign out button when onSignOut provided', (tester) async {
      await pumpWidget(tester, ErrorStates.profileLoadError(onSignOut: () {}));

      expect(find.byIcon(Icons.logout), findsOneWidget);
      expect(find.text('Sign Out'), findsOneWidget);
    });

    testWidgets('tapping retry calls callback', (tester) async {
      var retryCalled = false;
      await pumpWidget(tester, ErrorStates.profileLoadError(onRetry: () => retryCalled = true));

      await tester.tap(find.text('Retry'));
      await tester.pumpAndSettle();

      expect(retryCalled, isTrue);
    });

    testWidgets('tapping sign out calls callback', (tester) async {
      var signOutCalled = false;
      await pumpWidget(tester, ErrorStates.profileLoadError(onSignOut: () => signOutCalled = true));

      await tester.tap(find.text('Sign Out'));
      await tester.pumpAndSettle();

      expect(signOutCalled, isTrue);
    });
  });

  group('genericError with customRetryText', () {
    testWidgets('renders custom retry text when provided', (tester) async {
      await pumpWidget(
        tester,
        ErrorStates.genericError(
          error: 'Something broke',
          onRetry: () {},
          customRetryText: 'Try Again Now',
        ),
      );

      expect(find.text('Try Again Now'), findsOneWidget);
    });

    testWidgets('renders custom retry text for AppException', (tester) async {
      await pumpWidget(
        tester,
        ErrorStates.genericError(
          error: NetworkException('No connection', code: 'CONNECTION_ERROR'),
          onRetry: () {},
          customRetryText: 'Reconnect',
        ),
      );

      expect(find.text('Reconnect'), findsOneWidget);
    });
  });
}
