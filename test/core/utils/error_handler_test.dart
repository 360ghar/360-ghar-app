import 'package:flutter_test/flutter_test.dart';
import 'package:ghar360/core/utils/app_exceptions.dart';
import 'package:ghar360/core/utils/error_handler.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../../helpers/getx_test_binding.dart';

void main() {
  // Required now that this file has no `testWidgets` cases left to initialize
  // the binding implicitly; AppToast reaches WidgetsBinding.instance.
  TestWidgetsFlutterBinding.ensureInitialized();

  setUp(() {
    GetxTestBinding.init();
  });

  tearDown(() {
    GetxTestBinding.reset();
  });

  group('ErrorHandler.handleAuthError', () {
    test('does not throw for an AuthException with otp_expired code', () {
      final error = const AuthException('Invalid OTP', code: 'otp_expired');

      // AppToast._show is a no-op when Get.overlayContext is null (unit test).
      expect(() => ErrorHandler.handleAuthError(error), returnsNormally);
    });

    test('does not throw for an AuthException with otp_disabled code', () {
      final error = const AuthException('OTP disabled', code: 'otp_disabled');

      expect(() => ErrorHandler.handleAuthError(error), returnsNormally);
    });

    test('does not throw for an AuthException with rate limit code', () {
      final error = const AuthException('Rate limit', code: 'over_request_rate_limit');

      expect(() => ErrorHandler.handleAuthError(error), returnsNormally);
    });

    test('does not throw for an AuthException with sms_send_failed code', () {
      final error = const AuthException('SMS failed', code: 'sms_send_failed');

      expect(() => ErrorHandler.handleAuthError(error), returnsNormally);
    });

    test('does not throw for an AuthException with bad_jwt code', () {
      final error = const AuthException('Bad JWT', code: 'bad_jwt');

      expect(() => ErrorHandler.handleAuthError(error), returnsNormally);
    });

    test('does not throw for an AuthException with email_address_not_authorized code', () {
      final error = const AuthException('Not authorized', code: 'email_address_not_authorized');

      expect(() => ErrorHandler.handleAuthError(error), returnsNormally);
    });

    test('does not throw for an AuthException with email_not_confirmed code', () {
      final error = const AuthException('Email not confirmed', code: 'email_not_confirmed');

      expect(() => ErrorHandler.handleAuthError(error), returnsNormally);
    });

    test('does not throw for an AuthException with invalid login credentials message', () {
      final error = const AuthException('Invalid login credentials');

      expect(() => ErrorHandler.handleAuthError(error), returnsNormally);
    });

    test('does not throw for an AuthException with user not found message', () {
      final error = const AuthException('User not found');

      expect(() => ErrorHandler.handleAuthError(error), returnsNormally);
    });

    test('does not throw for an AuthException with session not found message', () {
      final error = const AuthException('Session not found');

      expect(() => ErrorHandler.handleAuthError(error), returnsNormally);
    });

    test('does not throw for an unrecognized AuthException message', () {
      final error = const AuthException('Some completely unknown error message');

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
      final error = const AuthException('Invalid login credentials');

      expect(() => ErrorHandler.handleAuthError(error, onRetry: () {}), returnsNormally);
    });

    test('does not throw with a stackTrace', () {
      final error = const AuthException('Token has expired', code: 'otp_expired');

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

      expect(() => ErrorHandler.handleNetworkError(error, onRetry: () {}), returnsNormally);
    });

    test('does not throw with a stackTrace', () {
      final error = NetworkException('Connection failed');

      expect(
        () => ErrorHandler.handleNetworkError(error, stackTrace: StackTrace.current),
        returnsNormally,
      );
    });
  });

  group('ErrorHandler.showInfo', () {
    test('does not throw', () {
      expect(() => ErrorHandler.showInfo('New features available'), returnsNormally);
    });
  });
}
