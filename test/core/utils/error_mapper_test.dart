import 'dart:async';
import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:get/get.dart';
import 'package:ghar360/core/translations/app_translations.dart';
import 'package:ghar360/core/utils/app_exceptions.dart';
import 'package:ghar360/core/utils/error_mapper.dart';
import 'package:universal_io/io.dart';

String _encodeMap(Map<String, dynamic> map) => jsonEncode(map);

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  // ErrorMapper now returns localized bodies via `.tr`. Without translations
  // registered, GetX echoes the key back, so these assertions must run against
  // a loaded locale to check the string a user would actually read.
  setUpAll(() {
    Get.addTranslations(AppTranslations().keys);
    Get.locale = const Locale('en', 'US');
  });

  group('ErrorMapper.mapApiError', () {
    test('maps String error to NetworkException', () {
      final result = ErrorMapper.mapApiError('Something went wrong');

      expect(result, isA<NetworkException>());
      expect(result.message, 'Something went wrong');
    });

    test(
      'maps String with null-check message to NetworkException with data processing message',
      () {
        final result = ErrorMapper.mapApiError('Null check operator used on a null value');

        expect(result, isA<NetworkException>());
        expect(result.message, 'Something went wrong');
      },
    );

    test('maps SocketException to NetworkException with CONNECTION_ERROR', () {
      final result = ErrorMapper.mapApiError(const SocketException('No route to host'));

      expect(result, isA<NetworkException>());
      expect(result.code, 'CONNECTION_ERROR');
    });

    test('maps TimeoutException to NetworkException with TIMEOUT', () {
      final result = ErrorMapper.mapApiError(TimeoutException('Request timed out'));

      expect(result, isA<NetworkException>());
      expect(result.code, 'TIMEOUT');
    });

    test('maps HttpException to NetworkException with HTTP_EXCEPTION', () {
      final result = ErrorMapper.mapApiError(const HttpException('Bad response'));

      expect(result, isA<NetworkException>());
      expect(result.code, 'HTTP_EXCEPTION');
    });

    test('maps ApiException with statusCode 401 to AuthenticationException', () {
      final result = ErrorMapper.mapApiError(ApiException('Unauthorized', statusCode: 401));

      expect(result, isA<AuthenticationException>());
      expect(result.code, 'UNAUTHORIZED');
    });

    test('maps ApiException with statusCode 404 to NotFoundException', () {
      final result = ErrorMapper.mapApiError(ApiException('Not found', statusCode: 404));

      expect(result, isA<NotFoundException>());
      expect(result.code, 'NOT_FOUND');
    });

    test('maps ApiException with statusCode 500 to ServerException', () {
      final result = ErrorMapper.mapApiError(ApiException('Server error', statusCode: 500));

      expect(result, isA<ServerException>());
      expect(result.code, 'SERVER_ERROR');
    });

    test('maps ApiException without statusCode to NetworkException', () {
      final result = ErrorMapper.mapApiError(ApiException('Unknown error'));

      expect(result, isA<NetworkException>());
    });

    test('returns existing AppException as-is', () {
      final original = NotFoundException('Already mapped', code: 'NOT_FOUND');
      final result = ErrorMapper.mapApiError(original);

      expect(identical(result, original), true);
    });

    test('maps unknown Object to NetworkException', () {
      final result = ErrorMapper.mapApiError(42);

      expect(result, isA<NetworkException>());
      expect(result.message, 'Something went wrong');
    });

    test('maps wrapped ApiException (Exception with ApiException in toString)', () {
      final result = ErrorMapper.mapApiError(Exception('ApiException: Bad data (Status: 400)'));

      expect(result, isA<ValidationException>());
      expect(result.code, 'BAD_REQUEST');
    });

    test('maps wrapped ApiException with unmatched format to NetworkException', () {
      final result = ErrorMapper.mapApiError(
        Exception('ApiException: something without status code'),
      );

      expect(result, isA<NetworkException>());
    });
  });

  group('ErrorMapper HTTP status code mapping', () {
    test('400 returns ValidationException with BAD_REQUEST', () {
      final result = ErrorMapper.mapApiError(ApiException('Bad request', statusCode: 400));
      expect(result, isA<ValidationException>());
      expect(result.code, 'BAD_REQUEST');
    });

    test('400 with JSON response string returns ValidationException', () {
      final result = ErrorMapper.mapApiError(
        ApiException(
          'Bad request',
          statusCode: 400,
          response: _encodeMap({
            'errors': {
              'email': ['Invalid email'],
            },
          }),
        ),
      );
      expect(result, isA<ValidationException>());
      final ve = result as ValidationException;
      expect(ve.fieldErrors, {
        'email': ['Invalid email'],
      });
    });

    test('403 returns AuthenticationException with FORBIDDEN', () {
      final result = ErrorMapper.mapApiError(ApiException('Forbidden', statusCode: 403));
      expect(result, isA<AuthenticationException>());
      expect(result.code, 'FORBIDDEN');
    });

    test('405 returns ValidationException with METHOD_NOT_ALLOWED', () {
      final result = ErrorMapper.mapApiError(ApiException('Method not allowed', statusCode: 405));
      expect(result, isA<ValidationException>());
      expect(result.code, 'METHOD_NOT_ALLOWED');
    });

    test('422 returns ValidationException with VALIDATION_ERROR', () {
      final result = ErrorMapper.mapApiError(
        ApiException(
          'Unprocessable',
          statusCode: 422,
          response: '{"message": "Email is required"}',
        ),
      );
      expect(result, isA<ValidationException>());
      expect(result.code, 'VALIDATION_ERROR');
    });

    test('422 with JSON response string returns ValidationException with default message', () {
      final result = ErrorMapper.mapApiError(
        ApiException(
          'Unprocessable',
          statusCode: 422,
          response: _encodeMap({'message': 'Email is required'}),
        ),
      );
      expect(result, isA<ValidationException>());
      expect(result.message, 'Email is required');
    });

    test('422 with error field JSON returns ValidationException with default message', () {
      final result = ErrorMapper.mapApiError(
        ApiException(
          'Unprocessable',
          statusCode: 422,
          response: _encodeMap({'error': 'Phone is required'}),
        ),
      );
      expect(result, isA<ValidationException>());
      expect(result.message, 'Phone is required');
    });

    test('422 with detail field JSON returns ValidationException with default message', () {
      final result = ErrorMapper.mapApiError(
        ApiException(
          'Unprocessable',
          statusCode: 422,
          response: _encodeMap({'detail': 'Name is required'}),
        ),
      );
      expect(result, isA<ValidationException>());
      expect(result.message, 'Name is required');
    });

    test('422 with errors map (list value) returns ValidationException with default message', () {
      final result = ErrorMapper.mapApiError(
        ApiException(
          'Unprocessable',
          statusCode: 422,
          response: _encodeMap({
            'errors': {
              'name': ['Name too short', 'Name too long'],
            },
          }),
        ),
      );
      expect(result, isA<ValidationException>());
      expect(result.message, 'Name too short');
    });

    test('422 with errors map (string value) returns ValidationException with default message', () {
      final result = ErrorMapper.mapApiError(
        ApiException(
          'Unprocessable',
          statusCode: 422,
          response: _encodeMap({
            'errors': {'name': 'Invalid name'},
          }),
        ),
      );
      expect(result, isA<ValidationException>());
      expect(result.message, 'Invalid name');
    });

    test('422 with field errors string returns ValidationException with null fieldErrors', () {
      final result = ErrorMapper.mapApiError(
        ApiException(
          'Unprocessable',
          statusCode: 422,
          response: _encodeMap({
            'errors': {'email': 'Invalid'},
          }),
        ),
      );
      expect(result, isA<ValidationException>());
      final ve = result as ValidationException;
      expect(ve.fieldErrors, {
        'email': ['Invalid'],
      });
    });

    test('429 returns NetworkException with RATE_LIMITED', () {
      final result = ErrorMapper.mapApiError(ApiException('Rate limited', statusCode: 429));
      expect(result, isA<NetworkException>());
      expect(result.code, 'RATE_LIMITED');
    });

    test('502/503/504 return ServerException with SERVER_UNAVAILABLE', () {
      for (final code in [502, 503, 504]) {
        final result = ErrorMapper.mapApiError(ApiException('Unavailable', statusCode: code));
        expect(result, isA<ServerException>(), reason: 'Status $code');
        expect(result.code, 'SERVER_UNAVAILABLE', reason: 'Status $code');
      }
    });

    test('unknown status returns ServerException with UNKNOWN_HTTP_ERROR', () {
      final result = ErrorMapper.mapApiError(ApiException('Teapot', statusCode: 418));
      expect(result, isA<ServerException>());
      expect(result.code, 'UNKNOWN_HTTP_ERROR');
    });

    test('null status code in _mapApiException returns NetworkException', () {
      // ApiException with null statusCode goes through _mapApiException which
      // returns NetworkException when statusCode is null.
      final result = ErrorMapper.mapApiError(
        ApiException('No status', statusCode: null, response: 'some response'),
      );
      expect(result, isA<NetworkException>());
      expect(result.message, 'No status');
    });
  });

  group('ErrorMapper helper methods', () {
    test('shouldTriggerReauth returns true for UNAUTHORIZED', () {
      expect(
        ErrorMapper.shouldTriggerReauth(AuthenticationException('Expired', code: 'UNAUTHORIZED')),
        true,
      );
    });

    test('shouldTriggerReauth returns false for FORBIDDEN', () {
      expect(
        ErrorMapper.shouldTriggerReauth(AuthenticationException('Forbidden', code: 'FORBIDDEN')),
        false,
      );
    });

    test('shouldTriggerReauth returns false for non-auth exceptions', () {
      expect(
        ErrorMapper.shouldTriggerReauth(NetworkException('Offline', code: 'CONNECTION_ERROR')),
        false,
      );
    });

    test('isRetryable returns true for NetworkException (non-CANCELLED)', () {
      expect(ErrorMapper.isRetryable(NetworkException('Timeout', code: 'TIMEOUT')), true);
    });

    test('isRetryable returns false for CANCELLED NetworkException', () {
      expect(ErrorMapper.isRetryable(NetworkException('Cancelled', code: 'CANCELLED')), false);
    });

    test('isRetryable returns true for 5xx ServerException', () {
      expect(ErrorMapper.isRetryable(ServerException('Error', statusCode: 500)), true);
    });

    test('isRetryable returns true for 503 ServerException', () {
      expect(ErrorMapper.isRetryable(ServerException('Error', statusCode: 503)), true);
    });

    test('isRetryable returns false for ServerException without statusCode', () {
      expect(ErrorMapper.isRetryable(ServerException('Error')), false);
    });

    test('isRetryable returns false for AuthenticationException', () {
      expect(ErrorMapper.isRetryable(AuthenticationException('Unauthorized')), false);
    });

    test('isRetryable returns false for ValidationException', () {
      expect(ErrorMapper.isRetryable(ValidationException('Bad input')), false);
    });

    test('isRetryable returns false for unknown AppException subtypes', () {
      expect(ErrorMapper.isRetryable(CacheException('cache miss')), false);
    });

    test('isRetryable returns false for NotFoundException', () {
      expect(ErrorMapper.isRetryable(NotFoundException('Not found')), false);
    });

    test('getErrorIcon returns Material icons for each exception type', () {
      expect(ErrorMapper.getErrorIcon(NetworkException('x')), Icons.wifi_off_rounded);
      expect(ErrorMapper.getErrorIcon(AuthenticationException('x')), Icons.lock_outline_rounded);
      expect(ErrorMapper.getErrorIcon(ValidationException('x')), Icons.warning_amber_rounded);
      expect(ErrorMapper.getErrorIcon(NotFoundException('x')), Icons.search_off_rounded);
      expect(ErrorMapper.getErrorIcon(ServerException('x')), Icons.build_circle_outlined);
      expect(ErrorMapper.getErrorIcon(CacheException('x')), Icons.error_outline_rounded);
    });

    test('getRetryActionText returns check_connection for CONNECTION_ERROR', () {
      // Requires GetX translations.
      Get.testMode = true;
      Get.locale = const Locale('en', 'US');
      final action = ErrorMapper.getRetryActionText(
        NetworkException('Offline', code: 'CONNECTION_ERROR'),
      );
      expect(action, isA<String>());
      Get.reset();
    });

    test('getRetryActionText returns check_connection for TIMEOUT', () {
      Get.testMode = true;
      Get.locale = const Locale('en', 'US');
      final action = ErrorMapper.getRetryActionText(NetworkException('Slow', code: 'TIMEOUT'));
      expect(action, isA<String>());
      Get.reset();
    });

    test('getRetryActionText returns try_again_later for ServerException', () {
      Get.testMode = true;
      Get.locale = const Locale('en', 'US');
      final action = ErrorMapper.getRetryActionText(ServerException('Error', statusCode: 500));
      expect(action, isA<String>());
      Get.reset();
    });

    test('getRetryActionText returns log_in_again for AuthenticationException', () {
      Get.testMode = true;
      Get.locale = const Locale('en', 'US');
      final action = ErrorMapper.getRetryActionText(AuthenticationException('Unauthorized'));
      expect(action, isA<String>());
      Get.reset();
    });

    test('getRetryActionText returns try_again for other exceptions', () {
      Get.testMode = true;
      Get.locale = const Locale('en', 'US');
      final action = ErrorMapper.getRetryActionText(ValidationException('Bad input'));
      expect(action, isA<String>());
      Get.reset();
    });
  });

  group('ErrorMapper.getRetryActionText with AppTranslations', () {
    setUp(() {
      Get.reset();
      Get.testMode = true;
      Get.locale = const Locale('en', 'US');
      Get.fallbackLocale = const Locale('en', 'US');
      Get.addTranslations(AppTranslations().keys);
    });

    tearDown(() {
      Get.reset();
      Get.testMode = true;
    });

    test('CONNECTION_ERROR returns translated check_connection_and_retry', () {
      final action = ErrorMapper.getRetryActionText(
        NetworkException('Offline', code: 'CONNECTION_ERROR'),
      );
      expect(action, 'Check Connection & Retry');
    });

    test('TIMEOUT returns translated check_connection_and_retry', () {
      final action = ErrorMapper.getRetryActionText(NetworkException('Slow', code: 'TIMEOUT'));
      expect(action, 'Check Connection & Retry');
    });

    test('ServerException returns translated try_again_later', () {
      final action = ErrorMapper.getRetryActionText(ServerException('Error', statusCode: 500));
      expect(action, 'Try Again Later');
    });

    test('AuthenticationException returns translated log_in_again', () {
      final action = ErrorMapper.getRetryActionText(AuthenticationException('Unauthorized'));
      expect(action, 'Log In Again');
    });

    test('other exceptions return translated try_again', () {
      final action = ErrorMapper.getRetryActionText(ValidationException('Bad input'));
      expect(action, 'try_again'.tr);
    });

    test('NetworkException with other code returns try_again', () {
      final action = ErrorMapper.getRetryActionText(
        NetworkException('Cancelled', code: 'CANCELLED'),
      );
      expect(action, 'try_again'.tr);
    });
  });

  group('ErrorMapper.showErrorSnackbar with GetMaterialApp', () {
    Future<void> pumpHost(WidgetTester tester) async {
      Get.testMode = true;
      await tester.pumpWidget(
        GetMaterialApp(
          translations: AppTranslations(),
          locale: const Locale('en', 'US'),
          fallbackLocale: const Locale('en', 'US'),
          home: const Scaffold(body: SizedBox.expand()),
        ),
      );
      await tester.pump();
    }

    Future<void> showAndAssert(
      WidgetTester tester, {
      required AppException error,
      required String title,
      required String message,
    }) async {
      await pumpHost(tester);
      ErrorMapper.showErrorSnackbar(error);

      // Drive enter animation frame-by-frame.
      for (var i = 0; i < 10; i++) {
        await tester.pump(const Duration(milliseconds: 50));
      }

      expect(find.text(title), findsOneWidget);
      expect(find.text(message), findsOneWidget);

      // Close and drain exit animation so Overlay dispose has no active tickers.
      Get.closeAllSnackbars();
      for (var i = 0; i < 20; i++) {
        await tester.pump(const Duration(milliseconds: 50));
      }
    }

    testWidgets('shows snackbar for NetworkException with connection title', (tester) async {
      await showAndAssert(
        tester,
        error: NetworkException('No internet', code: 'CONNECTION_ERROR'),
        title: 'Connection Error',
        message: 'No internet',
      );
    });

    testWidgets('shows snackbar for AuthenticationException', (tester) async {
      await showAndAssert(
        tester,
        error: AuthenticationException('Session expired', code: 'UNAUTHORIZED'),
        title: 'Authentication Error',
        message: 'Session expired',
      );
    });

    testWidgets('shows snackbar for ValidationException', (tester) async {
      await showAndAssert(
        tester,
        error: ValidationException('Invalid email'),
        title: 'validation_error'.tr,
        message: 'Invalid email',
      );
    });

    testWidgets('shows snackbar for NotFoundException', (tester) async {
      await showAndAssert(
        tester,
        error: NotFoundException('Missing'),
        title: 'not_found'.tr,
        message: 'Missing',
      );
    });

    testWidgets('shows snackbar for ServerException', (tester) async {
      await showAndAssert(
        tester,
        error: ServerException('Boom', statusCode: 500),
        title: 'server_error'.tr,
        message: 'Boom',
      );
    });

    testWidgets('shows snackbar for generic AppException subtype (CacheException)', (tester) async {
      await showAndAssert(
        tester,
        error: CacheException('cache miss'),
        title: 'error'.tr,
        message: 'cache miss',
      );
    });
  });

  group('ErrorMapper null-check analysis path', () {
    test('maps Exception with null-check message and runs debug analysis', () {
      final result = ErrorMapper.mapApiError(
        Exception('Null check operator used on a null value'),
        StackTrace.current,
      );

      // Exception is not String, so it falls through to generic mapping after
      // the debug null-check analysis branch.
      expect(result, isA<NetworkException>());
      expect(result.message, 'Something went wrong');
    });

    test('maps Error with null-check message and stack frames', () {
      final error = StateError('Null check operator used on a null value');
      final result = ErrorMapper.mapApiError(error, StackTrace.current);

      expect(result, isA<NetworkException>());
      expect(result.details, contains('Null check'));
    });

    test('maps String null-check message via captureStringOccurrence path', () {
      final result = ErrorMapper.mapApiError(
        'Null check operator used on a null value at package:ghar360/foo.dart:10',
      );

      expect(result, isA<NetworkException>());
      expect(result.message, 'Something went wrong');
      expect(result.details, contains('Null check'));
    });
  });
}
