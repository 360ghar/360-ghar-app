// test/features/notifications/data/notifications_remote_datasource_test.dart
//
// Unit tests for [NotificationsRemoteDatasource].
// Mocks [ApiClient] to verify device-token registration and unregistration.

import 'package:flutter_test/flutter_test.dart';
import 'package:ghar360/core/network/api_client.dart';
import 'package:ghar360/core/network/api_paths.dart';
import 'package:ghar360/features/notifications/data/datasources/notifications_remote_datasource.dart';
import 'package:mocktail/mocktail.dart';

import '../../../helpers/mocks.dart';

void main() {
  late MockApiClient apiClient;
  late NotificationsRemoteDatasource datasource;

  setUp(() {
    apiClient = MockApiClient();
    datasource = NotificationsRemoteDatasource(apiClient);
  });

  ApiResponse successResponse({dynamic body = const <String, dynamic>{}}) {
    return ApiResponse(statusCode: 200, body: body, headers: {});
  }

  ApiResponse errorResponse({int statusCode = 500}) {
    return ApiResponse(statusCode: statusCode, body: {'error': 'fail'}, headers: {});
  }

  group('registerDeviceToken', () {
    test('returns true on successful registration', () async {
      when(
        () => apiClient.post(ApiPaths.notificationsDeviceRegister, body: any(named: 'body')),
      ).thenAnswer((_) async => successResponse());

      final result = await datasource.registerDeviceToken(
        token: 'fcm-token-abc',
        userId: 'user-123',
      );

      expect(result, isTrue);
      verify(
        () => apiClient.post(ApiPaths.notificationsDeviceRegister, body: any(named: 'body')),
      ).called(1);
    });

    test('returns false when API returns non-success status', () async {
      when(
        () => apiClient.post(ApiPaths.notificationsDeviceRegister, body: any(named: 'body')),
      ).thenAnswer((_) async => errorResponse(statusCode: 500));

      final result = await datasource.registerDeviceToken(
        token: 'fcm-token-abc',
        userId: 'user-123',
      );

      expect(result, isFalse);
    });

    test('trims token and user id before registration', () async {
      when(
        () => apiClient.post(ApiPaths.notificationsDeviceRegister, body: any(named: 'body')),
      ).thenAnswer((_) async => successResponse());

      final result = await datasource.registerDeviceToken(
        token: '  fcm-token-abc  ',
        userId: '  user-123  ',
      );

      expect(result, isTrue);
      final captured =
          verify(
                () => apiClient.post(
                  ApiPaths.notificationsDeviceRegister,
                  body: captureAny(named: 'body'),
                ),
              ).captured.single
              as Map<String, dynamic>;
      expect(captured['token'], 'fcm-token-abc');
      expect(captured['user_id'], 'user-123');
    });

    test('returns false when token is empty', () async {
      final result = await datasource.registerDeviceToken(token: '  ', userId: 'user-123');

      expect(result, isFalse);
      verifyNever(() => apiClient.post(any(), body: any(named: 'body')));
    });

    test('returns false when userId is null', () async {
      final result = await datasource.registerDeviceToken(token: 'fcm-token-abc', userId: null);

      expect(result, isFalse);
      // Should not make any API call.
      verifyNever(() => apiClient.post(any(), body: any(named: 'body')));
    });

    test('returns false when userId is empty string', () async {
      final result = await datasource.registerDeviceToken(token: 'fcm-token-abc', userId: '');

      expect(result, isFalse);
      verifyNever(() => apiClient.post(any(), body: any(named: 'body')));
    });

    test('returns false when API call throws an exception', () async {
      when(
        () => apiClient.post(ApiPaths.notificationsDeviceRegister, body: any(named: 'body')),
      ).thenThrow(Exception('network error'));

      final result = await datasource.registerDeviceToken(
        token: 'fcm-token-abc',
        userId: 'user-123',
      );

      expect(result, isFalse);
    });
  });

  group('unregisterDeviceToken', () {
    test('returns false when token is empty', () async {
      final result = await datasource.unregisterDeviceToken('  ');

      expect(result, isFalse);
      verifyNever(() => apiClient.delete(any(), queryParams: any(named: 'queryParams')));
    });

    test('trims token before unregistration', () async {
      when(
        () => apiClient.delete(
          ApiPaths.notificationsDeviceUnregister,
          queryParams: any(named: 'queryParams'),
        ),
      ).thenAnswer((_) async => successResponse());

      final result = await datasource.unregisterDeviceToken('  fcm-token-abc  ');

      expect(result, isTrue);
      verify(
        () => apiClient.delete(
          ApiPaths.notificationsDeviceUnregister,
          queryParams: {'token': 'fcm-token-abc'},
        ),
      ).called(1);
    });

    test('returns true on successful unregistration', () async {
      when(
        () => apiClient.delete(
          ApiPaths.notificationsDeviceUnregister,
          queryParams: any(named: 'queryParams'),
        ),
      ).thenAnswer((_) async => successResponse());

      final result = await datasource.unregisterDeviceToken('fcm-token-abc');

      expect(result, isTrue);
      verify(
        () => apiClient.delete(
          ApiPaths.notificationsDeviceUnregister,
          queryParams: {'token': 'fcm-token-abc'},
        ),
      ).called(1);
    });

    test('returns false when API returns non-success status', () async {
      when(
        () => apiClient.delete(
          ApiPaths.notificationsDeviceUnregister,
          queryParams: any(named: 'queryParams'),
        ),
      ).thenAnswer((_) async => errorResponse(statusCode: 400));

      final result = await datasource.unregisterDeviceToken('fcm-token-abc');

      expect(result, isFalse);
    });

    test('returns false when API call throws an exception', () async {
      when(
        () => apiClient.delete(
          ApiPaths.notificationsDeviceUnregister,
          queryParams: any(named: 'queryParams'),
        ),
      ).thenThrow(Exception('network down'));

      final result = await datasource.unregisterDeviceToken('fcm-token-abc');

      expect(result, isFalse);
    });
  });
}
