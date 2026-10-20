// test/features/notifications/data/notifications_remote_datasource_test.dart
//
// Unit tests for [NotificationsRemoteDatasource].
// Mocks [ApiClient] to verify device-token registration and unregistration.

import 'package:flutter/foundation.dart';

import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';

import 'package:ghar360/core/network/api_client.dart';
import 'package:ghar360/core/network/api_paths.dart';
import 'package:ghar360/features/notifications/data/datasources/notifications_remote_datasource.dart';
import '../../../helpers/log_capture.dart';
import '../../../helpers/mocks.dart';

void main() {
  late MockApiClient apiClient;
  late NotificationsRemoteDatasource datasource;

  setUp(() {
    apiClient = MockApiClient();
    datasource = NotificationsRemoteDatasource(apiClient);
  });

  tearDown(() => debugDefaultTargetPlatformOverride = null);

  ApiResponse registered() => const ApiResponse(
    statusCode: 201,
    body: {'platform': 'android', 'app_key': 'ghar', 'last_seen': '2026-09-30T10:15:02Z'},
    headers: {},
  );

  ApiResponse noContent() => const ApiResponse(statusCode: 204, body: null, headers: {});

  ApiResponse errorResponse({int statusCode = 500}) {
    return ApiResponse(
      statusCode: statusCode,
      body: {
        'error': {'code': 'INTERNAL_ERROR', 'message': 'fail'},
      },
      headers: const {},
    );
  }

  test('token transport errors cannot print the token or response data', () async {
    final logs = LogCapture();
    addTearDown(logs.close);
    when(
      () => apiClient.post(ApiPaths.notificationsDeviceRegister, body: any(named: 'body')),
    ).thenThrow(StateError('private-fcm-token private-response'));
    expect(await datasource.registerDeviceToken(token: 'private-fcm-token'), false);
    expect(logs.text, contains('StateError'));
    expect(logs.text, isNot(contains('private-')));
  });

  group('registerDeviceToken', () {
    test('returns true on a 201 registration', () async {
      when(
        () => apiClient.post(ApiPaths.notificationsDeviceRegister, body: any(named: 'body')),
      ).thenAnswer((_) async => registered());

      final result = await datasource.registerDeviceToken(token: 'fcm-token-abc');

      expect(result, isTrue);
      verify(
        () => apiClient.post(ApiPaths.notificationsDeviceRegister, body: any(named: 'body')),
      ).called(1);
    });

    test('the body names the app and the platform and carries no user id', () async {
      debugDefaultTargetPlatformOverride = TargetPlatform.iOS;
      when(
        () => apiClient.post(ApiPaths.notificationsDeviceRegister, body: any(named: 'body')),
      ).thenAnswer((_) async => registered());

      await datasource.registerDeviceToken(token: '  fcm-token-abc  ');

      final captured =
          verify(
                () => apiClient.post(
                  ApiPaths.notificationsDeviceRegister,
                  body: captureAny(named: 'body'),
                ),
              ).captured.single
              as Map<String, dynamic>;
      expect(captured['token'], 'fcm-token-abc');
      expect(captured['platform'], 'ios');
      expect(captured['app_key'], 'ghar');
      expect(captured.containsKey('user_id'), isFalse);
      // Only keys of DeviceRegisterIn.
      expect(
        {'token', 'platform', 'app_key', 'app_version', 'locale'}.containsAll(captured.keys),
        isTrue,
      );
      final version = captured['app_version'];
      if (version != null) expect((version as String).length, lessThanOrEqualTo(64));
      expect((captured['locale'] as String).length, lessThanOrEqualTo(32));
    });

    test('desktop builds register as web, the closest platform the backend knows', () async {
      debugDefaultTargetPlatformOverride = TargetPlatform.macOS;
      expect(NotificationsRemoteDatasource.platform?.wire, 'web');
    });

    test('a platform the backend does not know is not registered', () async {
      debugDefaultTargetPlatformOverride = TargetPlatform.fuchsia;

      expect(await datasource.registerDeviceToken(token: 'fcm-token-abc'), isFalse);
      verifyNever(() => apiClient.post(any(), body: any(named: 'body')));
    });

    test('returns false when API returns non-success status', () async {
      when(
        () => apiClient.post(ApiPaths.notificationsDeviceRegister, body: any(named: 'body')),
      ).thenAnswer((_) async => errorResponse(statusCode: 500));

      expect(await datasource.registerDeviceToken(token: 'fcm-token-abc'), isFalse);
    });

    test('returns false when token is empty', () async {
      final result = await datasource.registerDeviceToken(token: '  ');

      expect(result, isFalse);
      verifyNever(() => apiClient.post(any(), body: any(named: 'body')));
    });

    test('returns false when API call throws an exception', () async {
      when(
        () => apiClient.post(ApiPaths.notificationsDeviceRegister, body: any(named: 'body')),
      ).thenThrow(Exception('network error'));

      expect(await datasource.registerDeviceToken(token: 'fcm-token-abc'), isFalse);
    });
  });

  group('unregisterDeviceToken', () {
    test('returns false when token is empty', () async {
      final result = await datasource.unregisterDeviceToken('  ');

      expect(result, isFalse);
      verifyNever(() => apiClient.delete(any(), body: any(named: 'body')));
    });

    test('sends the trimmed token in a JSON body, never in the URL', () async {
      when(
        () => apiClient.delete(ApiPaths.notificationsDeviceUnregister, body: any(named: 'body')),
      ).thenAnswer((_) async => noContent());

      final result = await datasource.unregisterDeviceToken('  fcm-token-abc  ');

      expect(result, isTrue);
      verify(
        () => apiClient.delete(
          ApiPaths.notificationsDeviceUnregister,
          body: {'token': 'fcm-token-abc'},
        ),
      ).called(1);
    });

    test('returns false when API returns non-success status', () async {
      when(
        () => apiClient.delete(ApiPaths.notificationsDeviceUnregister, body: any(named: 'body')),
      ).thenAnswer((_) async => errorResponse(statusCode: 400));

      expect(await datasource.unregisterDeviceToken('fcm-token-abc'), isFalse);
    });

    test('returns false when API call throws an exception', () async {
      when(
        () => apiClient.delete(ApiPaths.notificationsDeviceUnregister, body: any(named: 'body')),
      ).thenThrow(Exception('network down'));

      expect(await datasource.unregisterDeviceToken('fcm-token-abc'), isFalse);
    });
  });
}
