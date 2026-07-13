// test/features/properties/data/properties_repository_test.dart
//
// Unit tests for [PropertiesRepository]. Covers:
// - getProperties success
// - getProperties error propagation
// - getPropertyDetail success
// - getPropertiesByIds handles individual failures gracefully (batch with try/catch)

import 'package:flutter_test/flutter_test.dart';
import 'package:ghar360/core/data/models/property_media_payload.dart';
import 'package:ghar360/core/data/models/unified_filter_model.dart';
import 'package:ghar360/core/network/api_client.dart';
import 'package:ghar360/core/network/api_paths.dart';
import 'package:ghar360/core/utils/app_exceptions.dart';
import 'package:ghar360/features/properties/data/datasources/properties_remote_datasource.dart';
import 'package:ghar360/features/properties/data/properties_repository.dart';
import 'package:mocktail/mocktail.dart';

import '../../../helpers/getx_test_binding.dart';
import '../../../helpers/mocks.dart';
import '../../../helpers/test_data.dart';

void main() {
  late MockPropertiesRemoteDatasource mockRemoteDatasource;
  late MockApiClient mockApiClient;
  late PropertiesRepository repository;

  setUpAll(() {
    registerFallbackValue(const UnifiedFilterModel());
    registerFallbackValue(<int>[]);
  });

  setUp(() {
    GetxTestBinding.init();
    mockRemoteDatasource = MockPropertiesRemoteDatasource();
    mockApiClient = MockApiClient();

    GetxTestBinding.bind()
      ..register<PropertiesRemoteDatasource>(mockRemoteDatasource)
      ..register<ApiClient>(mockApiClient);

    repository = PropertiesRepository();
  });

  tearDown(() {
    GetxTestBinding.reset();
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

    // ── getPropertiesByIds ─────────────────────────────────────────────

    test('getPropertiesByIds returns empty list for empty input', () async {
      final result = await repository.getPropertiesByIds([]);

      expect(result, isEmpty);
    });

    test('getPropertiesByIds returns results from batch endpoint', () async {
      final properties = [testPropertyModel(id: 1), testPropertyModel(id: 2)];

      when(
        () => mockRemoteDatasource.fetchPropertiesByIds(any()),
      ).thenAnswer((_) async => properties);

      final result = await repository.getPropertiesByIds([1, 2]);

      expect(result.length, 2);
      expect(result.first.id, 1);
    });

    test('getPropertiesByIds falls back to individual fetch on batch failure', () async {
      when(
        () => mockRemoteDatasource.fetchPropertiesByIds(any()),
      ).thenThrow(Exception('Batch endpoint not supported'));

      // Individual fetch succeeds
      when(() => mockRemoteDatasource.fetchPropertyById(any())).thenAnswer((invocation) async {
        final id = invocation.positionalArguments[0] as String;
        return testPropertyModel(id: int.parse(id));
      });

      final result = await repository.getPropertiesByIds([10, 20, 30]);

      expect(result.length, 3);
      expect(result.map((p) => p.id), containsAll([10, 20, 30]));
    });

    test('getPropertiesByIds handles individual failures gracefully', () async {
      when(
        () => mockRemoteDatasource.fetchPropertiesByIds(any()),
      ).thenThrow(Exception('Batch failed'));

      // Individual fetches: id=10 succeeds, id=20 fails, id=30 succeeds
      when(() => mockRemoteDatasource.fetchPropertyById(any())).thenAnswer((invocation) async {
        final id = invocation.positionalArguments[0] as String;
        if (id == '20') throw Exception('Not found');
        return testPropertyModel(id: int.parse(id));
      });

      final result = await repository.getPropertiesByIds([10, 20, 30]);

      // Should have 2 results (id=20 was skipped)
      expect(result.length, 2);
      expect(result.map((p) => p.id), containsAll([10, 30]));
    });

    test('getPropertiesByIds returns empty when all individual fetches fail', () async {
      when(
        () => mockRemoteDatasource.fetchPropertiesByIds(any()),
      ).thenThrow(Exception('Batch failed'));

      when(() => mockRemoteDatasource.fetchPropertyById(any())).thenThrow(Exception('All failed'));

      final result = await repository.getPropertiesByIds([1, 2]);

      expect(result, isEmpty);
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

    // ── createProperty ─────────────────────────────────────────────────

    ApiResponse propertyResponse(int id) => ApiResponse(
      statusCode: 201,
      body: {'data': testPropertyJson(id: id)},
      headers: {},
    );

    test('createProperty POSTs payload and returns parsed PropertyModel', () async {
      final data = {'title': 'New Home', 'base_price': 1000000.0};
      when(
        () => mockApiClient.post(ApiPaths.properties, body: any(named: 'body')),
      ).thenAnswer((_) async => propertyResponse(42));

      final property = await repository.createProperty(propertyData: data);

      expect(property.id, 42);
      expect(property.title, 'Test Property');
      verify(() => mockApiClient.post(ApiPaths.properties, body: data)).called(1);
    });

    test('createProperty merges media payload into the request body', () async {
      final data = {'title': 'With Media'};
      final media = const PropertyMediaPayload(mainImageUrl: 'https://img.com/a.jpg');
      when(
        () => mockApiClient.post(ApiPaths.properties, body: any(named: 'body')),
      ).thenAnswer((_) async => propertyResponse(7));

      await repository.createProperty(propertyData: data, mediaPayload: media);

      final captured = verify(
        () => mockApiClient.post(ApiPaths.properties, body: captureAny(named: 'body')),
      ).captured;
      final body = captured.single as Map<String, dynamic>;
      expect(body['title'], 'With Media');
      expect(body['main_image_url'], 'https://img.com/a.jpg');
    });

    test('createProperty throws FormatException on empty payload', () async {
      when(() => mockApiClient.post(ApiPaths.properties, body: any(named: 'body'))).thenAnswer(
        (_) async => ApiResponse(statusCode: 201, body: {'data': <String, dynamic>{}}, headers: {}),
      );

      expect(
        () => repository.createProperty(propertyData: {'title': 'x'}),
        throwsA(isA<FormatException>()),
      );
    });

    test('createProperty propagates AppException', () async {
      when(
        () => mockApiClient.post(ApiPaths.properties, body: any(named: 'body')),
      ).thenThrow(ServerException('Down', statusCode: 500));

      expect(
        () => repository.createProperty(propertyData: {'title': 'x'}),
        throwsA(isA<ServerException>()),
      );
    });

    // ── updateProperty ─────────────────────────────────────────────────

    test('updateProperty PUTs fields to propertyById endpoint', () async {
      when(
        () => mockApiClient.put(ApiPaths.propertyById('9'), body: any(named: 'body')),
      ).thenAnswer((_) async => propertyResponse(9));

      final property = await repository.updateProperty(propertyId: 9, fields: {'title': 'Updated'});

      expect(property.id, 9);
      verify(
        () => mockApiClient.put(ApiPaths.propertyById('9'), body: {'title': 'Updated'}),
      ).called(1);
    });

    test('updateProperty merges media update payload (excluding images)', () async {
      final media = const PropertyMediaPayload(
        mainImageUrl: 'https://img.com/main.jpg',
        virtualTourUrl: 'https://tour.com',
      );
      when(
        () => mockApiClient.put(ApiPaths.propertyById('3'), body: any(named: 'body')),
      ).thenAnswer((_) async => propertyResponse(3));

      await repository.updateProperty(propertyId: 3, fields: {'title': 'X'}, mediaPayload: media);

      final captured = verify(
        () => mockApiClient.put(ApiPaths.propertyById('3'), body: captureAny(named: 'body')),
      ).captured;
      final body = captured.single as Map<String, dynamic>;
      expect(body['title'], 'X');
      expect(body['main_image_url'], 'https://img.com/main.jpg');
      expect(body['virtual_tour_url'], 'https://tour.com');
      // toPropertyUpdateJson strips the `images` relation field.
      expect(body.containsKey('images'), isFalse);
    });

    test('updateProperty propagates AppException', () async {
      when(
        () => mockApiClient.put(ApiPaths.propertyById('1'), body: any(named: 'body')),
      ).thenThrow(NetworkException('Offline'));

      expect(
        () => repository.updateProperty(propertyId: 1, fields: {'title': 'X'}),
        throwsA(isA<NetworkException>()),
      );
    });

    // ── updatePropertyMedia ────────────────────────────────────────────

    test('updatePropertyMedia PUTs scalar media fields to propertyById', () async {
      when(
        () => mockApiClient.put(ApiPaths.propertyById('12'), body: any(named: 'body')),
      ).thenAnswer((_) async => propertyResponse(12));

      final property = await repository.updatePropertyMedia(
        propertyId: 12,
        mainImageUrl: 'https://img.com/main.jpg',
        videoTourUrl: 'https://video.com/tour',
        floorPlanUrl: 'https://floor.com/plan',
      );

      expect(property.id, 12);
      final captured = verify(
        () => mockApiClient.put(ApiPaths.propertyById('12'), body: captureAny(named: 'body')),
      ).captured;
      final body = captured.single as Map<String, dynamic>;
      expect(body['main_image_url'], 'https://img.com/main.jpg');
      expect(body['video_tour_url'], 'https://video.com/tour');
      expect(body['floor_plan_url'], 'https://floor.com/plan');
      // images relation is stripped from update payload.
      expect(body.containsKey('images'), isFalse);
    });

    test('updatePropertyMedia propagates AppException', () async {
      when(
        () => mockApiClient.put(ApiPaths.propertyById('12'), body: any(named: 'body')),
      ).thenThrow(ServerException('Down', statusCode: 500));

      expect(
        () => repository.updatePropertyMedia(propertyId: 12, mainImageUrl: 'x'),
        throwsA(isA<ServerException>()),
      );
    });

    // ── clearCache ─────────────────────────────────────────────────────

    test('clearCache completes without throwing', () {
      expect(repository.clearCache, returnsNormally);
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
