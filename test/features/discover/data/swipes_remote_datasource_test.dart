// test/features/discover/data/swipes_remote_datasource_test.dart
//
// Unit tests for [SwipesRemoteDatasource].
// Mocks [ApiClient] to verify property-swipe recording.

import 'package:flutter_test/flutter_test.dart';
import 'package:ghar360/core/network/api_client.dart';
import 'package:ghar360/core/network/api_paths.dart';
import 'package:ghar360/core/utils/app_exceptions.dart';
import 'package:ghar360/features/swipes/data/datasources/swipes_remote_datasource.dart';
import 'package:mocktail/mocktail.dart';

import '../../../helpers/mocks.dart';

void main() {
  late MockApiClient apiClient;
  late SwipesRemoteDatasource datasource;

  setUp(() {
    apiClient = MockApiClient();
    datasource = SwipesRemoteDatasource(apiClient);
  });

  ApiResponse successResponse() => ApiResponse(statusCode: 200, body: {'ok': true}, headers: {});

  group('swipeProperty', () {
    test('posts liked swipe successfully', () async {
      when(
        () => apiClient.post(
          ApiPaths.swipes,
          body: any(named: 'body'),
          idempotent: any(named: 'idempotent'),
        ),
      ).thenAnswer((_) async => successResponse());

      await datasource.swipeProperty(propertyId: 200, isLiked: true);

      verify(
        () => apiClient.post(
          ApiPaths.swipes,
          body: {'property_id': 200, 'is_liked': true},
          idempotent: true,
        ),
      ).called(1);
    });

    test('posts passed swipe successfully', () async {
      when(
        () => apiClient.post(
          ApiPaths.swipes,
          body: any(named: 'body'),
          idempotent: any(named: 'idempotent'),
        ),
      ).thenAnswer((_) async => successResponse());

      await datasource.swipeProperty(propertyId: 300, isLiked: false);

      verify(
        () => apiClient.post(
          ApiPaths.swipes,
          body: {'property_id': 300, 'is_liked': false},
          idempotent: true,
        ),
      ).called(1);
    });

    test('propagates network exception', () async {
      when(
        () => apiClient.post(
          ApiPaths.swipes,
          body: any(named: 'body'),
          idempotent: any(named: 'idempotent'),
        ),
      ).thenThrow(NetworkException('offline'));

      expect(
        () => datasource.swipeProperty(propertyId: 200, isLiked: true),
        throwsA(isA<NetworkException>()),
      );
    });
  });
}
