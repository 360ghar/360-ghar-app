import 'dart:io';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:ghar360/core/data/models/page_state_model.dart';
import 'package:ghar360/core/data/models/property_model.dart';
import 'package:ghar360/core/data/models/unified_filter_model.dart';
import 'package:ghar360/core/data/models/unified_property_response.dart';
import 'package:ghar360/core/data/ports/properties_port.dart';
import 'package:ghar360/core/data/ports/swipes_port.dart';
import 'package:ghar360/core/providers/app_database_provider.dart';
import 'package:ghar360/core/providers/network_providers.dart';
import 'package:ghar360/core/storage/app_database.dart';
import 'package:ghar360/features/properties/application/property_location.dart';
import 'package:ghar360/features/properties/application/property_queries.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';

class QueryScope extends StorageScopeNotifier {
  @override
  StorageScope build() =>
      ref.read(appDatabaseProvider).activateScope(environment: 'test', accountId: 'a');
  void change(String? id) =>
      state = ref.read(appDatabaseProvider).activateScope(environment: 'test', accountId: id);
}

class QueryLocation extends PropertyLocation {
  QueryLocation(super.page);
  @override
  PropertyLocationState build() {
    ref.watch(storageScopeProvider);
    return const PropertyLocationState(
      location: LocationData(name: 'Delhi', latitude: 28.6, longitude: 77.2),
    );
  }

  @override
  Future<void> ensureLocation() async {}
  void replace(
    LocationData? value, {
    AsyncValue<void> load = const AsyncData(null),
    LocationSource source = LocationSource.initial,
  }) => state = PropertyLocationState(location: value, load: load, source: source);
}

class PropertyRequest {
  const PropertyRequest({
    required this.filters,
    required this.cursor,
    required this.latitude,
    required this.longitude,
    required this.limit,
    required this.radiusKm,
    required this.excludeSwiped,
    required this.useCache,
  });
  final UnifiedFilterModel filters;
  final String? cursor;
  final double latitude, longitude;
  final int limit;
  final double? radiusKm;
  final bool excludeSwiped, useCache;
}

class QueryProperties extends Fake implements PropertiesPort {
  final requests = <PropertyRequest>[];
  Future<UnifiedPropertyResponse> Function(String?) response = (_) async => queryPage([1]);
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
  }) {
    requests.add(
      PropertyRequest(
        filters: filters,
        cursor: cursor,
        latitude: latitude,
        longitude: longitude,
        limit: limit,
        radiusKm: radiusKm,
        excludeSwiped: excludeSwiped,
        useCache: useCache,
      ),
    );
    return response(cursor);
  }
}

class QuerySwipes extends Fake implements SwipesPort {
  final retryRequests = <PendingAction>[];
  Future<SwipeOutcome> Function(PendingAction) retryResponse = (action) async =>
      ConfirmedSwipe(operationId: action.operationId);
  @override
  Future<SwipeOutcome> retryPendingSwipe(PendingAction action) {
    retryRequests.add(action);
    return retryResponse(action);
  }

  final mutations = <({int id, bool liked})>[];
  Future<SwipeOutcome> Function(int, bool) mutation = (_, _) async => const ConfirmedSwipe();
  @override
  Future<SwipeOutcome> recordSwipe({required int propertyId, required bool isLiked}) {
    mutations.add((id: propertyId, liked: isLiked));
    return mutation(propertyId, isLiked);
  }

  final requests =
      <
        ({
          UnifiedFilterModel filters,
          String? cursor,
          double? latitude,
          double? longitude,
          int limit,
          bool? liked,
        })
      >[];
  Future<UnifiedPropertyResponse> Function(String?, bool?) response = (_, _) async =>
      queryPage([1]);
  @override
  Future<UnifiedPropertyResponse> getSwipeHistoryProperties({
    required UnifiedFilterModel filters,
    double? latitude,
    double? longitude,
    String? cursor,
    int limit = 50,
    bool? isLiked,
  }) {
    requests.add((
      filters: filters,
      cursor: cursor,
      latitude: latitude,
      longitude: longitude,
      limit: limit,
      liked: isLiked,
    ));
    return response(cursor, isLiked);
  }
}

PropertyModel queryProperty(int id) => PropertyModel(
  id: id,
  ownerId: 7,
  createdAt: DateTime.utc(2026, 9, 30),
  updatedAt: DateTime.utc(2026, 9, 30),
  title: 'Property $id',
  basePrice: 1000000,
  isAvailable: true,
  viewCount: 0,
  likeCount: 0,
  interestCount: 0,
);
UnifiedPropertyResponse queryPage(List<int> ids, [String? cursor]) => UnifiedPropertyResponse(
  items: ids.map(queryProperty).toList(),
  nextCursor: cursor,
  hasMore: cursor != null,
);
Future<void> waitForQuery(bool Function() condition) async {
  for (var i = 0; i < 200; i++) {
    if (condition()) return;
    await Future<void>.delayed(const Duration(milliseconds: 5));
  }
  fail('Provider did not reach expected state within one second.');
}

class PropertyQueryHarness {
  PropertyQueryHarness._(
    this.directory,
    this.database,
    this.raw,
    this.container,
    this.properties,
    this.swipes,
  );
  final Directory directory;
  final AppDatabase database;
  final Database raw;
  ProviderContainer container;
  final QueryProperties properties;
  final QuerySwipes swipes;
  bool _disposed = false;
  void disposeProviders() {
    if (!_disposed) {
      container.dispose();
      _disposed = true;
    }
  }

  static Future<PropertyQueryHarness> create({Map<String, Object?> legacy = const {}}) async {
    sqfliteFfiInit();
    final directory = await Directory.systemTemp.createTemp('property-query-test-');
    final path = '${directory.path}/app.db';
    final database = await AppDatabase.open(
      factory: databaseFactoryFfi,
      databasePath: path,
      legacyReader: () async => legacy,
    );
    final raw = await databaseFactoryFfi.openDatabase(path);
    final properties = QueryProperties();
    final swipes = QuerySwipes();
    final container = ProviderContainer(
      retry: (_, _) => null,
      overrides: [
        appDatabaseProvider.overrideWithValue(database),
        storageScopeProvider.overrideWith(QueryScope.new),
        propertiesRepositoryProvider.overrideWithValue(properties),
        swipesRepositoryProvider.overrideWithValue(swipes),
        for (final page in PageType.values)
          propertyLocationProvider(page).overrideWith(() => QueryLocation(page)),
      ],
    );
    return PropertyQueryHarness._(directory, database, raw, container, properties, swipes);
  }

  PropertyPageState state([PropertyFeed feed = PropertyFeed.explore]) =>
      container.read(propertyQueryProvider(feed));
  PropertyQuery query([PropertyFeed feed = PropertyFeed.explore]) =>
      container.read(propertyQueryProvider(feed).notifier);
  QueryScope get scope => container.read(storageScopeProvider.notifier) as QueryScope;
  QueryLocation location([PageType page = PageType.explore]) =>
      container.read(propertyLocationProvider(page).notifier) as QueryLocation;
  Future<void> loaded([PropertyFeed feed = PropertyFeed.explore]) async {
    state(feed);
    await waitForQuery(() => state(feed).updatedAt != null && !state(feed).busy);
    // A visible response may precede its optional disk write.
    await raw.query('cache');
  }

  Future<void> close() async {
    disposeProviders();
    await database.close();
    await directory.delete(recursive: true);
  }
}
