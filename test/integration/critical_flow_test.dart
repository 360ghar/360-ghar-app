// Integration-style happy path without live network:
// swipe record → offline queue enqueue on failure → visit schedule via repository.
//
// This is the Dart-layer seam for "login → swipe → book visit" until full
// Maestro credentials are available in every environment.

import 'package:flutter_test/flutter_test.dart';
import 'package:ghar360/core/controllers/offline_queue_service.dart';
import 'package:ghar360/core/data/models/property_model.dart';
import 'package:ghar360/core/data/models/unified_filter_model.dart';
import 'package:ghar360/core/data/models/unified_property_response.dart';
import 'package:ghar360/core/data/models/visit_model.dart';
import 'package:ghar360/core/data/ports/properties_port.dart';
import 'package:ghar360/core/data/ports/swipes_port.dart';
import 'package:ghar360/core/utils/app_exceptions.dart';
import 'package:ghar360/features/swipes/data/swipes_repository.dart';
import 'package:ghar360/features/visits/data/datasources/visits_remote_datasource.dart';
import 'package:ghar360/features/visits/data/visits_repository.dart';
import 'package:mocktail/mocktail.dart';

import '../helpers/getx_test_binding.dart';
import '../helpers/mocks.dart';

class _FakeSwipesPort extends Fake implements SwipesPort {
  final List<({int propertyId, bool isLiked})> swipes = [];

  @override
  Future<void> recordSwipe({required int propertyId, required bool isLiked}) async {
    swipes.add((propertyId: propertyId, isLiked: isLiked));
  }

  @override
  Future<UnifiedPropertyResponse> getSwipeHistoryProperties({
    required UnifiedFilterModel filters,
    double? latitude,
    double? longitude,
    String? cursor,
    int limit = 50,
    bool? isLiked,
  }) async {
    return const UnifiedPropertyResponse(items: <PropertyModel>[], hasMore: false);
  }
}

class _FakePropertiesPort extends Fake implements PropertiesPort {
  @override
  Future<UnifiedPropertyResponse> searchProperties({
    required UnifiedFilterModel filters,
    required String? cursor,
    required int limit,
    required double latitude,
    required double longitude,
    double? radiusKm,
    bool excludeSwiped = false,
    bool useCache = false,
  }) async {
    return UnifiedPropertyResponse(items: [testPropertyModel(id: 1)], hasMore: false);
  }

  @override
  Future<PropertyModel> getPropertyDetail(int propertyId) async =>
      testPropertyModel(id: propertyId);

  @override
  Future<List<PropertyModel>> getPropertiesByIds(List<int> propertyIds) async =>
      propertyIds.map((id) => testPropertyModel(id: id)).toList();

  @override
  void clearCache() {}
}

class _MockVisitsRemote extends Mock implements VisitsRemoteDatasource {}

class _MockOfflineQueue extends Mock implements OfflineQueueService {}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  setUp(() {
    GetxTestBinding.init();
  });

  tearDown(GetxTestBinding.reset);

  group('Critical flow (mocked network)', () {
    test('properties port returns deck candidates', () async {
      final properties = _FakePropertiesPort();
      final response = await properties.searchProperties(
        filters: const UnifiedFilterModel(),
        cursor: null,
        limit: 20,
        latitude: 28.6,
        longitude: 77.2,
      );
      expect(response.items, isNotEmpty);
      expect(response.items.first.id, 1);
    });

    test('swipe port records like action', () async {
      final swipes = _FakeSwipesPort();
      await swipes.recordSwipe(propertyId: 42, isLiked: true);
      expect(swipes.swipes.single.propertyId, 42);
      expect(swipes.swipes.single.isLiked, isTrue);
    });

    test('swipe repository enqueues offline on NetworkException', () async {
      final api = MockApiClient();
      final queue = _MockOfflineQueue();
      final repo = SwipesRepository(apiClient: api, offlineQueue: queue);

      when(
        () => api.post(any(), body: any(named: 'body')),
      ).thenThrow(NetworkException('offline', code: 'CONNECTION_ERROR'));
      when(() => queue.enqueueSwipe(propertyId: 7, isLiked: true)).thenAnswer((_) async {});

      await repo.recordSwipe(propertyId: 7, isLiked: true);

      verify(() => queue.enqueueSwipe(propertyId: 7, isLiked: true)).called(1);
    });

    test('visit repository schedules and returns model', () async {
      final remote = _MockVisitsRemote();
      final repo = VisitsRepository(remoteDatasource: remote);
      final visit = VisitModel(
        id: 99,
        propertyId: 7,
        userId: 1,
        scheduledDate: DateTime.utc(2024, 8, 1),
        status: VisitStatus.scheduled,
        createdAt: DateTime.utc(2024, 7, 1),
      );

      when(
        () => remote.scheduleVisit(
          propertyId: 7,
          scheduledDate: '2024-08-01T00:00:00.000Z',
          specialRequirements: 'notes',
        ),
      ).thenAnswer((_) async => visit);

      final result = await repo.scheduleVisit(
        propertyId: 7,
        scheduledDate: '2024-08-01T00:00:00.000Z',
        specialRequirements: 'notes',
      );

      expect(result.id, 99);
      expect(result.propertyId, 7);
    });

    test('end-to-end orchestration: discover swipe then book visit', () async {
      final swipes = _FakeSwipesPort();
      final remote = _MockVisitsRemote();
      final visits = VisitsRepository(remoteDatasource: remote);

      // User likes a property in the discover deck.
      await swipes.recordSwipe(propertyId: 100, isLiked: true);

      // User books a visit for that property.
      when(
        () => remote.scheduleVisit(
          propertyId: 100,
          scheduledDate: any(named: 'scheduledDate'),
          specialRequirements: any(named: 'specialRequirements'),
        ),
      ).thenAnswer(
        (_) async => VisitModel(
          id: 1,
          propertyId: 100,
          userId: 1,
          scheduledDate: DateTime.utc(2024, 9, 1),
          status: VisitStatus.scheduled,
          createdAt: DateTime.utc(2024, 8, 1),
        ),
      );

      final booked = await visits.scheduleVisit(
        propertyId: 100,
        scheduledDate: DateTime.utc(2024, 9, 1).toIso8601String(),
        specialRequirements: 'morning',
      );

      expect(swipes.swipes, hasLength(1));
      expect(swipes.swipes.first.isLiked, isTrue);
      expect(booked.propertyId, 100);
      expect(booked.status, VisitStatus.scheduled);
    });
  });
}
