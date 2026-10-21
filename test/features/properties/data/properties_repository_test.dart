// test/features/properties/data/properties_repository_test.dart
//
// Unit tests for [PropertiesRepository]. Covers:
// - getProperties success
// - getProperties error propagation
// - getPropertyDetail success

import 'package:flutter_test/flutter_test.dart';
import 'package:ghar360/core/data/models/unified_filter_model.dart';
import 'package:ghar360/core/utils/app_exceptions.dart';
import 'package:ghar360/features/properties/data/properties_repository.dart';
import 'package:mocktail/mocktail.dart';

import '../../../helpers/mocks.dart';

void main() {
  late MockPropertiesRemoteDatasource mockRemoteDatasource;
  late MockApiClient mockApiClient;
  late PropertiesRepository repository;

  setUpAll(() {
    registerFallbackValue(const UnifiedFilterModel());
    registerFallbackValue(<int>[]);
  });

  setUp(() {
    mockRemoteDatasource = MockPropertiesRemoteDatasource();
    mockApiClient = MockApiClient();

    repository = PropertiesRepository(
      remoteDatasource: mockRemoteDatasource,
      apiClient: mockApiClient,
    );
  });

  group('PropertiesRepository', () {
    // ── getProperties success ──────────────────────────────────────────

    test('getProperties returns response on success', () async {
      final expectedResponse = testPropertyResponse(
        items: [testPropertyModel(id: 1), testPropertyModel(id: 2)],
        hasMore: false,
      );

      when(
        () => mockRemoteDatasource.fetchProperties(
          filters: any(named: 'filters'),
          latitude: any(named: 'latitude'),
          longitude: any(named: 'longitude'),
          radiusKm: any(named: 'radiusKm'),
          cursor: any(named: 'cursor'),
          limit: any(named: 'limit'),
          excludeSwiped: any(named: 'excludeSwiped'),
          useCache: any(named: 'useCache'),
        ),
      ).thenAnswer((_) async => expectedResponse);

      final result = await repository.getProperties(
        filters: const UnifiedFilterModel(),
        cursor: null,
        limit: 20,
        latitude: 28.6139,
        longitude: 77.2090,
      );

      expect(result.items.length, 2);
      expect(result.hasMore, false);
      expect(result.items.first.id, 1);
    });

    // ── getProperties error propagation ────────────────────────────────

    test('getProperties propagates AppException', () async {
      when(
        () => mockRemoteDatasource.fetchProperties(
          filters: any(named: 'filters'),
          latitude: any(named: 'latitude'),
          longitude: any(named: 'longitude'),
          radiusKm: any(named: 'radiusKm'),
          cursor: any(named: 'cursor'),
          limit: any(named: 'limit'),
          excludeSwiped: any(named: 'excludeSwiped'),
          useCache: any(named: 'useCache'),
        ),
      ).thenThrow(NetworkException('No internet'));

      expect(
        () => repository.getProperties(
          filters: const UnifiedFilterModel(),
          cursor: null,
          limit: 20,
          latitude: 28.6139,
          longitude: 77.2090,
        ),
        throwsA(isA<NetworkException>()),
      );
    });

    test('getProperties propagates unexpected exceptions', () async {
      when(
        () => mockRemoteDatasource.fetchProperties(
          filters: any(named: 'filters'),
          latitude: any(named: 'latitude'),
          longitude: any(named: 'longitude'),
          radiusKm: any(named: 'radiusKm'),
          cursor: any(named: 'cursor'),
          limit: any(named: 'limit'),
          excludeSwiped: any(named: 'excludeSwiped'),
          useCache: any(named: 'useCache'),
        ),
      ).thenThrow(Exception('Unexpected'));

      expect(
        () => repository.getProperties(
          filters: const UnifiedFilterModel(),
          cursor: null,
          limit: 20,
          latitude: 28.6139,
          longitude: 77.2090,
        ),
        throwsA(isA<Exception>()),
      );
    });

    // ── getPropertyDetail success ──────────────────────────────────────

    test('getPropertyDetail returns property on success', () async {
      final property = testPropertyModel(id: 42);

      when(() => mockRemoteDatasource.fetchPropertyById('42')).thenAnswer((_) async => property);

      final result = await repository.getPropertyDetail(42);

      expect(result.id, 42);
      expect(result.title, 'Test Property 42');
    });

    test('getPropertyDetail propagates AppException', () async {
      when(
        () => mockRemoteDatasource.fetchPropertyById('99'),
      ).thenThrow(NetworkException('Timeout'));

      expect(() => repository.getPropertyDetail(99), throwsA(isA<NetworkException>()));
    });

    // ── searchProperties ───────────────────────────────────────────────

    test('searchProperties delegates to getProperties with useCache=false', () async {
      final expectedResponse = testPropertyResponse(items: [testPropertyModel(id: 5)]);
      when(
        () => mockRemoteDatasource.fetchProperties(
          filters: any(named: 'filters'),
          latitude: any(named: 'latitude'),
          longitude: any(named: 'longitude'),
          radiusKm: any(named: 'radiusKm'),
          cursor: any(named: 'cursor'),
          limit: any(named: 'limit'),
          excludeSwiped: any(named: 'excludeSwiped'),
          useCache: any(named: 'useCache'),
        ),
      ).thenAnswer((_) async => expectedResponse);

      final result = await repository.searchProperties(
        filters: const UnifiedFilterModel(),
        cursor: null,
        limit: 10,
        latitude: 28.0,
        longitude: 77.0,
      );

      expect(result.items.length, 1);
      // searchProperties defaults useCache=false; verify the remote was called
      // with useCache=false.
      verify(
        () => mockRemoteDatasource.fetchProperties(
          filters: any(named: 'filters'),
          latitude: any(named: 'latitude'),
          longitude: any(named: 'longitude'),
          radiusKm: any(named: 'radiusKm'),
          cursor: any(named: 'cursor'),
          limit: any(named: 'limit'),
          excludeSwiped: any(named: 'excludeSwiped'),
          useCache: false,
        ),
      ).called(1);
    });

    // ── clearCache ─────────────────────────────────────────────────────

    test('clearCache invalidates transport cache', () async {
      when(() => mockApiClient.clearCache()).thenAnswer((_) async {});
      await repository.clearCache();
      verify(() => mockApiClient.clearCache()).called(1);
    });

    // ── getProperties radius/excludeSwiped forwarding ───────────────────

    test('getProperties forwards excludeSwiped and radiusKm to remote', () async {
      final expectedResponse = testPropertyResponse();
      when(
        () => mockRemoteDatasource.fetchProperties(
          filters: any(named: 'filters'),
          latitude: any(named: 'latitude'),
          longitude: any(named: 'longitude'),
          radiusKm: 25.0,
          cursor: any(named: 'cursor'),
          limit: any(named: 'limit'),
          excludeSwiped: true,
          useCache: any(named: 'useCache'),
        ),
      ).thenAnswer((_) async => expectedResponse);

      await repository.getProperties(
        filters: const UnifiedFilterModel(),
        cursor: null,
        limit: 20,
        latitude: 28.0,
        longitude: 77.0,
        radiusKm: 25.0,
        excludeSwiped: true,
      );

      verify(
        () => mockRemoteDatasource.fetchProperties(
          filters: any(named: 'filters'),
          latitude: any(named: 'latitude'),
          longitude: any(named: 'longitude'),
          radiusKm: 25.0,
          cursor: any(named: 'cursor'),
          limit: any(named: 'limit'),
          excludeSwiped: true,
          useCache: any(named: 'useCache'),
        ),
      ).called(1);
    });
  });
}
