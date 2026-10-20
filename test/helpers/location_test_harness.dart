import 'dart:async';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_riverpod/misc.dart';
import 'package:geolocator/geolocator.dart';
import 'package:mocktail/mocktail.dart';

import 'package:ghar360/core/data/models/page_state_model.dart';
import 'package:ghar360/core/data/models/unified_filter_model.dart';
import 'package:ghar360/core/providers/app_database_provider.dart';
import 'package:ghar360/core/providers/network_providers.dart';
import 'package:ghar360/core/services/google_places_service.dart';
import 'package:ghar360/core/storage/app_database.dart';
import 'package:ghar360/features/location/application/location_backend_sync.dart';
import 'package:ghar360/features/location/application/location_search_controller.dart';
import 'package:ghar360/features/location/application/location_source.dart';
import 'package:ghar360/features/properties/application/property_location.dart';

class LocationTestScope extends Fake implements StorageScope {
  LocationTestScope(this.accountId);
  @override
  final String? accountId;
  @override
  String get key => 'test:$accountId';
}

class LocationTestDatabase extends Fake implements AppDatabase {
  StorageScope scope = LocationTestScope('a');
  final preferences = <String, Object?>{};
  final drafts = <String, Map<String, Object?>>{};
  Object? readError;
  Object? writeError;
  Future<void> Function()? beforeRead;
  Future<void> Function()? beforeWrite;
  int writes = 0;
  @override
  T? readPreference<T>(String key) => preferences[key] as T?;
  @override
  Future<void> writePreferences(Map<String, Object?> values) async {
    if (writeError != null) throw writeError!;
    preferences.addAll(values);
  }

  @override
  Future<Map<String, dynamic>?> readDraft({
    required StorageScope scope,
    required String key,
  }) async {
    await beforeRead?.call();
    if (!identical(scope, this.scope)) throw StorageFailure('obsolete lease');
    if (readError != null) throw readError!;
    final value = drafts['${scope.key}:$key'];
    return value == null ? null : Map<String, dynamic>.from(value);
  }

  @override
  Future<void> writeDraft({
    required StorageScope scope,
    required String key,
    required Map<String, Object?> value,
  }) async {
    writes++;
    await beforeWrite?.call();
    if (!identical(scope, this.scope)) throw StorageFailure('obsolete lease');
    if (writeError != null) throw writeError!;
    drafts['${scope.key}:$key'] = Map.of(value);
  }
}

class LocationScopeNotifier extends StorageScopeNotifier {
  LocationScopeNotifier(this.database);
  final LocationTestDatabase database;
  @override
  StorageScope build() => database.scope;
  void change(String id) {
    database.scope = LocationTestScope(id);
    state = database.scope;
  }
}

const delhi = LocationData(name: 'Delhi', latitude: 28.6, longitude: 77.2);
const mumbai = LocationData(name: 'Mumbai', latitude: 19.07, longitude: 72.87);
const delhiSuggestion = PlaceSuggestion(
  placeId: 'delhi',
  description: 'Delhi, India',
  mainText: 'Delhi',
  secondaryText: 'India',
);

class LocationTestPlaces extends Fake implements GooglePlacesService {
  final requests = <({String query, bool fallback})>[];
  Future<List<PlaceSuggestion>> Function(String) response = (query) async =>
      query == 'Delhi' ? [delhiSuggestion] : [];
  Future<LocationData> Function() details = () async => delhi;
  int detailCalls = 0;
  @override
  Future<List<PlaceSuggestion>> getPlaceSuggestions(
    String query, {
    Position? currentPosition,
    bool allowFallback = true,
    bool Function()? isCurrent,
  }) {
    requests.add((query: query, fallback: allowFallback));
    return response(query);
  }

  @override
  Future<LocationData> getPlaceDetails(String placeId, {String? preferredName}) {
    detailCalls++;
    return details();
  }
}

class LocationTestDevice extends Fake implements DeviceLocationSource {
  Future<LocationResolution> Function() response = () async =>
      const LocationResolution(delhi, LocationSource.gps);
  Future<LocationData> Function(Position) geocode = (_) async => mumbai;
  final stream = StreamController<Position>.broadcast();
  int currentCalls = 0;
  int streamCalls = 0;
  Object? streamError;
  bool settingsResult = true;
  int settingsCalls = 0;
  final prompts = <bool>[];
  bool undetermined = false;
  @override
  Future<LocationResolution> current({
    bool allowIpFallback = true,
    bool forceRefresh = false,
    bool prompt = true,
  }) {
    currentCalls++;
    prompts.add(prompt);
    return response();
  }

  @override
  Future<bool> permissionUndetermined() async => undetermined;

  @override
  Future<LocationData> locationFor(Position value) => geocode(value);
  @override
  Stream<Position> positions() {
    streamCalls++;
    if (streamError != null) throw streamError!;
    return stream.stream;
  }

  @override
  Future<bool> openAppSettings() async {
    settingsCalls++;
    return settingsResult;
  }

  @override
  Future<bool> openLocationSettings() async {
    settingsCalls++;
    return settingsResult;
  }
}

class LocationTestHarness {
  LocationTestHarness() {
    overrides = [
      appDatabaseProvider.overrideWithValue(database),
      storageScopeProvider.overrideWith(() => LocationScopeNotifier(database)),
      deviceLocationSourceProvider.overrideWithValue(device),
      googlePlacesServiceProvider.overrideWithValue(places),
      locationBackendSyncProvider.overrideWithValue(LocationBackendSync(send: null)),
    ];
    container = ProviderContainer(overrides: overrides, retry: (_, _) => null);
  }
  final database = LocationTestDatabase();
  final places = LocationTestPlaces();
  final device = LocationTestDevice();
  late final List<Override> overrides;
  late final ProviderContainer container;
  LocationSearchController search([PageType page = PageType.explore]) {
    container.listen(locationSearchProvider(page), (_, _) {});
    return container.read(locationSearchProvider(page).notifier);
  }

  PropertyLocation location([PageType page = PageType.explore]) =>
      container.read(propertyLocationProvider(page).notifier);
  PropertyLocationState state([PageType page = PageType.explore]) =>
      container.read(propertyLocationProvider(page));
  void changeAccount(String id) =>
      (container.read(storageScopeProvider.notifier) as LocationScopeNotifier).change(id);
  Future<void> dispose() async {
    container.dispose();
    await device.stream.close();
  }
}
