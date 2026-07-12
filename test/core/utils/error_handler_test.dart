import 'package:flutter/material.dart';

import 'package:flutter_test/flutter_test.dart';
import 'package:get/get.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import 'package:ghar360/core/utils/app_exceptions.dart';
import 'package:ghar360/core/utils/error_handler.dart';

import '../../helpers/getx_test_binding.dart';

void main() {
  setUp(() {
    GetxTestBinding.init();
  });

  tearDown(() {
    GetxTestBinding.reset();
  });

  group('ErrorHandler.handleAuthError', () {
    test('does not throw for an AuthException with otp_expired code', () {
      final error = AuthException('Invalid OTP', code: 'otp_expired');

      // AppToast._show is a no-op when Get.overlayContext is null (unit test).
      expect(
        () => ErrorHandler.handleAuthError(error),
        returnsNormally,
      );
    });

    test('does not throw for an AuthException with otp_disabled code', () {
      final error = AuthException('OTP disabled', code: 'otp_disabled');

      expect(() => ErrorHandler.handleAuthError(error), returnsNormally);
    });

    test('does not throw for an AuthException with rate limit code', () {
      final error = AuthException('Rate limit', code: 'over_request_rate_limit');

      expect(() => ErrorHandler.handleAuthError(error), returnsNormally);
    });

    test('does not throw for an AuthException with sms_send_failed code', () {
      final error = AuthException('SMS failed', code: 'sms_send_failed');

      expect(() => ErrorHandler.handleAuthError(error), returnsNormally);
    });

    test('does not throw for an AuthException with bad_jwt code', () {
      final error = AuthException('Bad JWT', code: 'bad_jwt');

      expect(() => ErrorHandler.handleAuthError(error), returnsNormally);
    });

    test('does not throw for an AuthException with email_address_not_authorized code', () {
      final error = AuthException('Not authorized', code: 'email_address_not_authorized');

      expect(() => ErrorHandler.handleAuthError(error), returnsNormally);
    });

    test('does not throw for an AuthException with email_not_confirmed code', () {
      final error = AuthException('Email not confirmed', code: 'email_not_confirmed');

      expect(() => ErrorHandler.handleAuthError(error), returnsNormally);
    });

    test('does not throw for an AuthException with invalid login credentials message', () {
      final error = AuthException('Invalid login credentials');

      expect(() => ErrorHandler.handleAuthError(error), returnsNormally);
    });

    test('does not throw for an AuthException with user not found message', () {
      final error = AuthException('User not found');

      expect(() => ErrorHandler.handleAuthError(error), returnsNormally);
    });

    test('does not throw for an AuthException with session not found message', () {
      final error = AuthException('Session not found');

      expect(() => ErrorHandler.handleAuthError(error), returnsNormally);
    });

    test('does not throw for an unrecognized AuthException message', () {
      final error = AuthException('Some completely unknown error message');

      // Falls through to the default branch which records to Crashlytics
      // (wrapped in try-catch) and surfaces the raw message.
      expect(() => ErrorHandler.handleAuthError(error), returnsNormally);
    });

    test('does not throw for a generic Exception', () {
      final error = Exception('Something went wrong');

      expect(() => ErrorHandler.handleAuthError(error), returnsNormally);
    });

    test('does not throw for a non-Exception error', () {
      const error = 'a string error';

      expect(() => ErrorHandler.handleAuthError(error), returnsNormally);
    });

    test('does not throw with a retry callback', () {
      final error = AuthException('Invalid login credentials');
      var retryCalled = false;

      expect(
        () => ErrorHandler.handleAuthError(error, onRetry: () => retryCalled = true),
        returnsNormally,
      );
    });

    test('does not throw with a stackTrace', () {
      final error = AuthException('Token has expired', code: 'otp_expired');

      expect(
        () => ErrorHandler.handleAuthError(error, stackTrace: StackTrace.current),
        returnsNormally,
      );
    });
  });

  group('ErrorHandler.handleNetworkError', () {
    test('does not throw for a NetworkException', () {
      final error = NetworkException('Connection failed');

      expect(() => ErrorHandler.handleNetworkError(error), returnsNormally);
    });

    test('does not throw for an AuthenticationException', () {
      final error = AuthenticationException('Unauthorized');

      expect(() => ErrorHandler.handleNetworkError(error), returnsNormally);
    });

    test('does not throw for a ServerException', () {
      final error = ServerException('Internal server error');

      expect(() => ErrorHandler.handleNetworkError(error), returnsNormally);
    });

    test('does not throw for a ValidationException', () {
      final error = ValidationException('Validation failed');

      expect(() => ErrorHandler.handleNetworkError(error), returnsNormally);
    });

    test('does not throw for a NotFoundException', () {
      final error = NotFoundException('Resource not found');

      expect(() => ErrorHandler.handleNetworkError(error), returnsNormally);
    });

    test('does not throw for a generic String error', () {
      expect(() => ErrorHandler.handleNetworkError('network error'), returnsNormally);
    });

    test('does not throw with a retry callback', () {
      final error = NetworkException('Connection failed');
      var retryCalled = false;

      expect(
        () => ErrorHandler.handleNetworkError(error, onRetry: () => retryCalled = true),
        returnsNormally,
      );
    });

    test('does not throw with a stackTrace', () {
      final error = NetworkException('Connection failed');

      expect(
        () => ErrorHandler.handleNetworkError(error, stackTrace: StackTrace.current),
        returnsNormally,
      );
    });
  });

  group('ErrorHandler.handleValidationError', () {
    test('does not throw', () {
      // AppToast.warning is a no-op when Get.overlayContext is null.
      expect(
        () => ErrorHandler.handleValidationError('Email', 'Invalid email'),
        returnsNormally,
      );
    });
  });

  group('ErrorHandler.showSuccess', () {
    test('does not throw', () {
      expect(() => ErrorHandler.showSuccess('Profile saved'), returnsNormally);
    });
  });

  group('ErrorHandler.showInfo', () {
    test('does not throw', () {
      expect(() => ErrorHandler.showInfo('New features available'), returnsNormally);
    });
  });

  group('ErrorHandler.buildErrorWidget', () {
    testWidgets('renders an error icon and message', (tester) async {
      await tester.pumpWidget(
        MaterialApp(home: Scaffold(body: ErrorHandler.buildErrorWidget('Something broke'))),
      );

      expect(find.byIcon(Icons.error_outline), findsOneWidget);
      expect(find.text('Something broke'), findsOneWidget);
    });

    testWidgets('renders without a retry button when onRetry is null', (tester) async {
      await tester.pumpWidget(
        MaterialApp(home: Scaffold(body: ErrorHandler.buildErrorWidget('Error'))),
      );

      expect(find.byType(ElevatedButton), findsNothing);
    });

    testWidgets('renders a retry button when onRetry is provided', (tester) async {
      var retryCalled = false;
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: ErrorHandler.buildErrorWidget(
              'Error',
              onRetry: () => retryCalled = true,
            ),
          ),
        ),
      );

      expect(find.byType(ElevatedButton), findsOneWidget);
      expect(find.byIcon(Icons.refresh), findsOneWidget);

      await tester.tap(find.byType(ElevatedButton));
      await tester.pump();

      expect(retryCalled, isTrue);
    });
  });

  group('ErrorHandler.buildLoadingWidget', () {
    testWidgets('renders a CircularProgressIndicator', (tester) async {
      await tester.pumpWidget(
        MaterialApp(home: Scaffold(body: ErrorHandler.buildLoadingWidget())),
      );

      expect(find.byType(CircularProgressIndicator), findsOneWidget);
    });

    testWidgets('renders a message when provided', (tester) async {
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(body: ErrorHandler.buildLoadingWidget(message: 'Loading data...')),
        ),
      );

      expect(find.text('Loading data...'), findsOneWidget);
    });

    testWidgets('does not render a message when null', (tester) async {
      await tester.pumpWidget(
        MaterialApp(home: Scaffold(body: ErrorHandler.buildLoadingWidget())),
      );

      expect(find.byType(Text), findsNothing);
    });
  });

  group('ErrorHandler.buildEmptyWidget', () {
    testWidgets('renders a default icon when icon is not provided', (tester) async {
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: ErrorHandler.buildEmptyWidget(
              title: 'No Results',
              message: 'Try adjusting your filters',
            ),
          ),
        ),
      );

      expect(find.byIcon(Icons.inbox_outlined), findsOneWidget);
      expect(find.text('No Results'), findsOneWidget);
      expect(find.text('Try adjusting your filters'), findsOneWidget);
    });

    testWidgets('renders a custom icon when provided', (tester) async {
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: ErrorHandler.buildEmptyWidget(
              title: 'Empty',
              message: 'Nothing here',
              icon: Icons.search_off,
            ),
          ),
        ),
      );

      expect(find.byIcon(Icons.search_off), findsOneWidget);
    });

    testWidgets('does not render an action button when onAction is null', (tester) async {
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: ErrorHandler.buildEmptyWidget(title: 'Empty', message: 'Nothing'),
          ),
        ),
      );

      expect(find.byType(ElevatedButton), findsNothing);
    });

    testWidgets('renders an action button when onAction and actionLabel are provided',
        (tester) async {
      var actionCalled = false;
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: ErrorHandler.buildEmptyWidget(
              title: 'Empty',
              message: 'Nothing here',
              onAction: () => actionCalled = true,
              actionLabel: 'Retry',
            ),
          ),
        ),
      );

      expect(find.byType(ElevatedButton), findsOneWidget);
      expect(find.text('Retry'), findsOneWidget);

      await tester.tap(find.byType(ElevatedButton));
      await tester.pump();

      expect(actionCalled, isTrue);
    });
  });
}
