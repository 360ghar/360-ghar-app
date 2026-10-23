import 'dart:async';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:ghar360/core/data/models/page_state_model.dart';
import 'package:ghar360/core/data/models/unified_filter_model.dart';
import 'package:ghar360/core/services/google_places_service.dart';
import 'package:ghar360/core/storage/app_database.dart';
import 'package:ghar360/core/utils/app_exceptions.dart';
import 'package:ghar360/features/location/application/location_search_controller.dart';
import 'package:ghar360/features/location/application/location_source.dart';
import 'package:ghar360/features/properties/application/property_location.dart';
import '../../../helpers/fake_location_platform.dart';
import '../../../helpers/location_test_harness.dart';

Future<void> flush() => Future<void>.delayed(Duration.zero);
void main() {
  late LocationTestHarness harness;
  setUp(() => harness = LocationTestHarness());
  tearDown(() => harness.dispose());
  test(
    'search starts empty, debounces Google only, and explicit submit enables fallback',
    () async {
      final search = harness.search();
      expect(harness.container.read(locationSearchProvider(PageType.explore)).suggestions, isEmpty);
      search.updateQuery('D');
      await Future<void>.delayed(const Duration(milliseconds: 410));
      expect(harness.places.requests, isEmpty);
      search.updateQuery('Delhi');
      await Future<void>.delayed(const Duration(milliseconds: 410));
      expect(harness.places.requests, [(query: 'Delhi', fallback: false)]);
      await search.search();
      expect(harness.places.requests.last.fallback, isTrue);
      final value = harness.container.read(locationSearchProvider(PageType.explore));
      expect(value.suggestions.single.mainText, 'Delhi');
      expect(() => value.suggestions.clear(), throwsUnsupportedError);
    },
  );
  test('query change immediately clears old results and rejects stale response', () async {
    final search = harness.search();
    final first = Completer<List<PlaceSuggestion>>();
    harness.places.response = (_) => first.future;
    search.updateQuery('Delhi');
    final pending = search.search();
    search.updateQuery('Mumbai');
    first.complete([delhiSuggestion]);
    await pending;
    final state = harness.container.read(locationSearchProvider(PageType.explore));
    expect(state.query, 'Mumbai');
    expect(state.suggestions, isEmpty);
    search.updateQuery('');
  });
  test('search failures retain existing same-query results and explicit retry recovers', () async {
    final search = harness.search()..updateQuery('Delhi');
    await search.search();
    harness.places.response = (_) async => throw NetworkException('private response');
    await search.search();
    var value = harness.container.read(locationSearchProvider(PageType.explore));
    expect(value.suggestions.single.mainText, 'Delhi');
    expect(value.search.error, isA<NetworkException>());
    harness.places.response = (_) async => [];
    await search.search();
    value = harness.container.read(locationSearchProvider(PageType.explore));
    expect(value.search.hasError, isFalse);
    expect(value.suggestions, isEmpty);
  });
  test(
    'selection has distinct errors, prevents duplicates, and rejects query/scope changes',
    () async {
      final search = harness.search()..updateQuery('Delhi');
      final detail = Completer<LocationData>();
      harness.places.details = () => detail.future;
      final pending = search.resolve(delhiSuggestion);
      expect(await search.resolve(delhiSuggestion), isNull);
      expect(harness.places.detailCalls, 1);
      search.updateQuery('Mumbai');
      detail.complete(delhi);
      expect(await pending, isNull);
      harness.places.details = () async => throw NetworkException('details');
      expect(await search.resolve(delhiSuggestion), isNull);
      expect(
        harness.container.read(locationSearchProvider(PageType.explore)).selection.hasError,
        isTrue,
      );
      expect(harness.container.read(locationSearchProvider(PageType.explore)).query, 'Mumbai');
      harness.places.details = () async => delhi;
      expect((await search.resolve(delhiSuggestion))?.name, 'Delhi');
      expect(
        harness.container.read(locationSearchProvider(PageType.explore)).selection.hasError,
        isFalse,
      );
    },
  );
  test('scope change clears search and rejects old account response', () async {
    final search = harness.search()..updateQuery('Delhi');
    final pending = Completer<List<PlaceSuggestion>>();
    harness.places.response = (_) => pending.future;
    final work = search.search();
    harness.changeAccount('b');
    expect(harness.container.read(locationSearchProvider(PageType.explore)).query, isEmpty);
    pending.complete([delhiSuggestion]);
    await work;
    expect(harness.container.read(locationSearchProvider(PageType.explore)).suggestions, isEmpty);
  });
  test(
    'OSM result signals visible attribution and direct coordinates avoid extra detail request',
    () async {
      const item = PlaceSuggestion(
        placeId: 'osm:28.6,77.2',
        description: 'Delhi',
        mainText: 'Delhi',
        secondaryText: '',
        latitude: 28.6,
        longitude: 77.2,
      );
      harness.places.response = (_) async => [item];
      final search = harness.search()..updateQuery('Delhi');
      await search.search();
      expect(harness.container.read(locationSearchProvider(PageType.explore)).usedFallback, isTrue);
      expect((await search.resolve(item))?.latitude, 28.6);
      expect(harness.places.detailCalls, 0);
    },
  );
  test('manual selection persists per page and survives provider replacement', () async {
    expect(await harness.location().select(delhi), isTrue);
    expect(harness.state().source, LocationSource.manual);
    expect(harness.state(PageType.likes).location, isNull);
    harness.container.invalidate(propertyLocationProvider(PageType.explore));
    await harness.location().ensureLocation();
    expect(harness.state().location?.name, 'Delhi');
    expect(harness.device.currentCalls, 0);
  });
  test('explicit manual selection supersedes pending disk hydration', () async {
    final read = Completer<void>();
    harness.database.beforeRead = () => read.future;
    harness.database.drafts['test:a:location:explore'] = {
      'location': mumbai.toJson(),
      'source': 'manual',
    };
    final location = harness.location();
    await flush();
    await location.select(delhi);
    read.complete();
    await flush();
    expect(harness.state().location?.name, 'Delhi');
  });
  test('GPS failure retains manual selection and explicit retry replaces it', () async {
    final location = harness.location();
    await location.select(mumbai);
    harness.device.response = () async =>
        throw LocationException('denied', code: 'LOCATION_DENIED');
    await location.useCurrent();
    expect(harness.state().location?.name, 'Mumbai');
    expect(harness.state().source, LocationSource.manual);
    expect(harness.state().load.error, isA<LocationException>());
    harness.device.response = () async => const LocationResolution(delhi, LocationSource.gps);
    await location.useCurrent();
    expect(harness.state().location?.name, 'Delhi');
    expect(harness.state().source, LocationSource.gps);
    expect(harness.state().load.hasError, isFalse);
  });
  test('IP fallback is explicit and does not subscribe to GPS updates', () async {
    final location = harness.location()..setVisible(true);
    harness.device.response = () async => const LocationResolution(delhi, LocationSource.ip);
    await location.useCurrent();
    expect(harness.state().source, LocationSource.ip);
    expect(harness.device.streamCalls, 0);
  });
  test('manual change rejects pending GPS and duplicate GPS requests are suppressed', () async {
    final location = harness.location();
    final gps = Completer<LocationResolution>();
    harness.device.response = () => gps.future;
    final pending = location.useCurrent();
    await location.useCurrent();
    expect(harness.device.currentCalls, 1);
    await location.select(mumbai);
    gps.complete(const LocationResolution(delhi, LocationSource.gps));
    await pending;
    expect(harness.state().location?.name, 'Mumbai');
  });
  test('inactive page cancels stream and rejects pending GPS and geocodes', () async {
    final location = harness.location()..setVisible(true);
    await location.select(delhi, source: LocationSource.gps);
    expect(harness.device.stream.hasListener, isTrue);
    final reverse = Completer<LocationData>();
    harness.device.geocode = (_) => reverse.future;
    harness.device.stream.add(testPosition());
    await flush();
    location.setVisible(false);
    reverse.complete(mumbai);
    await flush();
    expect(harness.state().location?.name, 'Delhi');
    expect(harness.device.stream.hasListener, isFalse);
    location.setVisible(true);
    final gps = Completer<LocationResolution>();
    harness.device.response = () => gps.future;
    final pending = location.useCurrent();
    location.setVisible(false);
    gps.complete(const LocationResolution(mumbai, LocationSource.gps));
    await pending;
    await flush();
    expect(harness.state().location?.name, 'Delhi');
    expect(harness.state().load.isLoading, isFalse);
  });
  test('newest stream position wins and manual selection stops stream', () async {
    final location = harness.location()..setVisible(true);
    await location.select(delhi, source: LocationSource.gps);
    harness.device.geocode = (_) async =>
        const LocationData(name: 'Noida', latitude: 28.5355, longitude: 77.391);
    harness.device.stream.add(testPosition());
    await flush();
    expect(harness.state().location?.name, 'Noida');
    expect(harness.device.streamCalls, 1);
    await location.select(delhi);
    expect(harness.device.stream.hasListener, isFalse);
  });
  test(
    'a stream position outside the service area moves to Gurugram and stops the stream',
    () async {
      final location = harness.location()..setVisible(true);
      await location.select(delhi, source: LocationSource.gps);
      harness.device.stream.add(testPosition());
      await flush();
      expect(harness.state().location?.name, 'Gurugram');
      expect(harness.state().source, LocationSource.fallback);
      expect(harness.device.stream.hasListener, isFalse);
    },
  );
  test('a saved fallback is replaced by an in-area fix and kept when the read fails', () async {
    harness.database.drafts['test:a:location:explore'] = {
      'location': ServiceArea.center.toJson(),
      'source': 'fallback',
    };
    harness.device.response = () async => throw LocationException('off', code: 'LOCATION_DISABLED');
    final location = harness.location();
    await location.ensureLocation();
    await flush();
    expect(harness.state().source, LocationSource.fallback);
    expect(harness.state().load.hasError, isFalse);
    expect(harness.device.currentCalls, 1);
    harness.device.response = () async => const LocationResolution(delhi, LocationSource.ip);
    await location.ensureLocation();
    await flush();
    expect(harness.state().source, LocationSource.ip);
    expect(harness.state().location?.name, 'Delhi');
  });
  test('inactive page never automatically asks for GPS', () async {
    final location = harness.location()..setVisible(false);
    await location.ensureLocation();
    expect(harness.device.currentCalls, 0);
    location.setVisible(true);
    await location.ensureLocation();
    expect(harness.device.currentCalls, 1);
  });
  test('storage failure retains selected area with retry and no automatic resubmit', () async {
    final location = harness.location();
    harness.database.writeError = StorageFailure('disk full');
    expect(await location.select(delhi), isFalse);
    expect(harness.state().location?.name, 'Delhi');
    expect(harness.state().save.error, isA<StorageFailure>());
    expect(harness.database.writes, 1);
    harness.database.writeError = null;
    expect(await location.retrySave(), isTrue);
    expect(harness.state().save.hasError, isFalse);
  });
  test('read failure retry reads again instead of overwriting unknown saved area', () async {
    harness.database.readError = StorageFailure('read failed');
    final location = harness.location();
    await flush();
    expect(harness.state().save.hasError, isTrue);
    await location.ensureLocation();
    expect(harness.device.currentCalls, 0);
    harness.database.readError = null;
    harness.database.drafts['test:a:location:explore'] = {
      'location': mumbai.toJson(),
      'source': 'manual',
    };
    expect(await location.retrySave(), isTrue);
    expect(harness.state().location?.name, 'Mumbai');
    expect(harness.database.writes, 0);
  });
  test('account transition rejects pending write and does not restore old location', () async {
    final write = Completer<void>();
    harness.database.beforeWrite = () => write.future;
    final pending = harness.location().select(delhi);
    await flush();
    harness.changeAccount('b');
    expect(harness.state().location, isNull);
    write.complete();
    expect(await pending, isFalse);
    await flush();
    expect(harness.state().location, isNull);
    expect(harness.database.drafts, isEmpty);
  });
  test('visibility changes do not strand manual save state', () async {
    final write = Completer<void>();
    harness.database.beforeWrite = () => write.future;
    final location = harness.location();
    final pending = location.select(delhi);
    location.setVisible(false);
    write.complete();
    expect(await pending, isTrue);
    expect(harness.state().save.isLoading, isFalse);
  });
  test('stream failures remain recoverable without discarding the selected location', () async {
    final location = harness.location()..setVisible(true);
    harness.device.streamError = LocationException('stream unavailable');
    await location.select(delhi, source: LocationSource.gps);
    expect(harness.state().load.hasError, isTrue);
    expect(harness.state().location?.name, 'Delhi');
    harness.device.streamError = null;
    await location.useCurrent();
    expect(harness.state().load.hasError, isFalse);
    harness.device.stream.addError(LocationException('stream disconnected'), StackTrace.current);
    await flush();
    expect(harness.state().load.hasError, isTrue);
    expect(harness.state().location?.name, 'Delhi');
  });
  test('older stream geocode cannot replace a newer completed location', () async {
    final location = harness.location()..setVisible(true);
    await location.select(delhi, source: LocationSource.gps);
    final older = Completer<LocationData>();
    harness.device.geocode = (position) => position.latitude == 1
        ? older.future
        : Future.value(const LocationData(name: 'Noida', latitude: 28.5355, longitude: 77.391));
    harness.device.stream.add(testPosition(latitude: 1));
    await flush();
    harness.device.stream.add(testPosition(latitude: 2));
    await flush();
    older.complete(delhi);
    await flush();
    expect(harness.state().location?.name, 'Noida');
  });
  test('disposed search and location reject pending completion', () async {
    final pendingSearch = Completer<List<PlaceSuggestion>>();
    final pendingGps = Completer<LocationResolution>();
    harness.places.response = (_) => pendingSearch.future;
    harness.device.response = () => pendingGps.future;
    final search = harness.search()..updateQuery('Delhi');
    final searchWork = search.search();
    final gpsWork = harness.location().useCurrent();
    harness.container.dispose();
    pendingSearch.complete([delhiSuggestion]);
    pendingGps.complete(const LocationResolution(delhi, LocationSource.gps));
    await Future.wait([searchWork, gpsWork]);
    expect(harness.database.writes, 0);
  });
}
