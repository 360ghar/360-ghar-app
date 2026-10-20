import 'dart:async';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_riverpod/misc.dart';
import 'package:mocktail/mocktail.dart';

import 'package:ghar360/core/data/models/page_state_model.dart';
import 'package:ghar360/core/data/models/property_model.dart';
import 'package:ghar360/core/data/ports/swipes_port.dart';
import 'package:ghar360/core/providers/app_database_provider.dart';
import 'package:ghar360/core/providers/network_providers.dart';
import 'package:ghar360/core/storage/app_database.dart';
import 'package:ghar360/features/explore/presentation/controllers/explore_controller.dart';
import 'package:ghar360/features/location/application/location_backend_sync.dart';
import 'package:ghar360/features/location/application/location_search_controller.dart';
import 'package:ghar360/features/location/application/location_source.dart';
import 'package:ghar360/features/properties/application/property_location.dart';
import 'package:ghar360/features/properties/application/property_queries.dart';
import 'package:ghar360/features/properties/application/swipe_history.dart';
import 'location_test_harness.dart';

export 'location_test_harness.dart' show delhi, mumbai;

class ExploreDatabase extends LocationTestDatabase {
  @override
  Future<List<PendingAction>> listActions({required StorageScope scope}) async => [];
}

class ExploreDevice extends LocationTestDevice {
  int addressCalls = 0;
  Future<String> Function(double, double) addressResponse = (_, _) async => 'Map area';
  @override
  Future<String> address(double latitude, double longitude) {
    addressCalls++;
    return addressResponse(latitude, longitude);
  }
}

class ExploreSwipes extends Fake implements SwipesPort {
  final calls = <({int id, bool liked})>[];
  Future<SwipeOutcome> Function(int, bool) response = (_, _) async => const ConfirmedSwipe();
  @override
  Future<SwipeOutcome> recordSwipe({required int propertyId, required bool isLiked}) {
    calls.add((id: propertyId, liked: isLiked));
    return response(propertyId, isLiked);
  }
}

class ExploreTestQuery extends PropertyQuery {
  ExploreTestQuery(super.feed, this.initial);
  final PropertyPageState initial;
  int refreshCalls = 0;
  int loadCalls = 0;
  int loadMoreCalls = 0;
  bool? lastRetry;
  Future<void> Function()? onRefresh;
  @override
  PropertyPageState build() => initial;
  void seed(PropertyPageState value) => state = value;
  @override
  Future<void> load({bool refresh = false}) async {
    loadCalls++;
    if (refresh) refreshCalls++;
    await onRefresh?.call();
  }

  @override
  Future<void> loadMore({bool retry = false}) async {
    if (!state.hasMore || state.busy || (state.paginationError != null && !retry)) return;
    loadMoreCalls++;
    lastRetry = retry;
  }
}

class ExploreTestHarness {
  ExploreTestHarness({List<PropertyModel> items = const [], bool located = true}) {
    if (located) {
      database.preferences['explore_state'] = {'selectedLocation': delhi.toJson()};
    }
    overrides = [
      appDatabaseProvider.overrideWithValue(database),
      storageScopeProvider.overrideWith(() => LocationScopeNotifier(database)),
      deviceLocationSourceProvider.overrideWithValue(device),
      locationBackendSyncProvider.overrideWithValue(LocationBackendSync(send: null)),
      googlePlacesServiceProvider.overrideWithValue(LocationTestPlaces()),
      propertyQueryProvider.overrideWith2(
        (feed) => ExploreTestQuery(
          feed,
          PropertyPageState(
            phase: items.isEmpty ? PropertyLoadPhase.empty : PropertyLoadPhase.content,
            items: items,
          ),
        ),
      ),
      swipesRepositoryProvider.overrideWithValue(swipes),
    ];
    container = ProviderContainer(overrides: overrides, retry: (_, _) => null);
  }
  final database = ExploreDatabase();
  final device = ExploreDevice();
  final swipes = ExploreSwipes();
  late final List<Override> overrides;
  late final ProviderContainer container;
  ExploreController get controller => container.read(exploreProvider.notifier);
  ExploreMapState get state => container.read(exploreProvider);
  ExploreTestQuery get query =>
      container.read(propertyQueryProvider(PropertyFeed.explore).notifier) as ExploreTestQuery;
  PropertyLocation get location =>
      container.read(propertyLocationProvider(PageType.explore).notifier);
  SwipeHistoryState get history => container.read(swipeHistoryProvider);
  void changeAccount(String id) =>
      (container.read(storageScopeProvider.notifier) as LocationScopeNotifier).change(id);
  Future<void> dispose() async {
    container.dispose();
    await device.stream.close();
  }
}

PropertyModel exploreProperty(
  int id, {
  double? latitude = 28.6,
  double? longitude = 77.2,
  double price = 5000000,
  bool liked = false,
}) => PropertyModel(
  id: id,
  title: 'Property $id',
  basePrice: price,
  propertyType: PropertyType.house,
  purpose: PropertyPurpose.buy,
  bedrooms: 2,
  bathrooms: 1,
  areaSqft: 1000,
  city: 'Pune',
  state: 'Maharashtra',
  isAvailable: true,
  viewCount: 1,
  likeCount: 1,
  interestCount: 1,
  latitude: latitude,
  longitude: longitude,
  liked: liked,
);
