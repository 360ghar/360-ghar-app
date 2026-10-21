// Repository identity now belongs to ProviderContainer instead of a global locator.

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:ghar360/core/controllers/offline_queue_service.dart';
import 'package:ghar360/core/providers/app_database_provider.dart';
import 'package:ghar360/core/providers/network_providers.dart';
import 'package:ghar360/core/storage/app_database.dart';
import 'package:ghar360/features/properties/application/property_queries.dart';
import 'package:ghar360/features/properties/data/properties_repository.dart';
import 'package:ghar360/features/swipes/data/swipes_repository.dart';
import 'package:ghar360/features/visits/data/visits_repository.dart';
import 'package:ghar360/features/visits/presentation/controllers/visits_controller.dart';
import '../../helpers/mocks.dart';
import '../../helpers/visits_test_support.dart';

void main() {
  late AppDatabase database;
  late ProviderContainer container;
  setUp(() async {
    database = await visitTestDatabase();
    container = ProviderContainer(
      overrides: [
        appDatabaseProvider.overrideWithValue(database),
        apiClientProvider.overrideWithValue(MockApiClient()),
        storageScopeProvider.overrideWith(() => TestVisitScope(database)),
      ],
    );
  });
  tearDown(() async {
    container.dispose();
    await database.close();
  });
  test('properties port resolves to one explicitly injected repository', () {
    final first = container.read(propertiesRepositoryProvider);
    expect(first, isA<PropertiesRepository>());
    expect(identical(first, container.read(propertiesRepositoryProvider)), isTrue);
  });
  test('swipes port resolves to one explicitly injected repository', () {
    final first = container.read(swipesRepositoryProvider);
    expect(first, isA<SwipesRepository>());
    expect(identical(first, container.read(swipesRepositoryProvider)), isTrue);
  });
  test('visits repository resolves with the shared durable queue', () {
    expect(container.read(visitsRepositoryProvider), isA<VisitsRepository>());
    expect(
      identical(container.read(visitsRepositoryProvider), container.read(visitsRepositoryProvider)),
      isTrue,
    );
    expect(
      container.read(offlineQueueServiceProvider),
      same((container.read(swipesRepositoryProvider) as SwipesRepository).offlineQueue),
    );
  });
  test('repositories can be read in either order', () {
    container.read(swipesRepositoryProvider);
    container.read(visitsRepositoryProvider);
    expect(container.read(propertiesRepositoryProvider), isA<PropertiesRepository>());
  });
  test('new provider container cannot reuse a prior global repository', () {
    final second = ProviderContainer(
      overrides: [apiClientProvider.overrideWithValue(MockApiClient())],
    );
    addTearDown(second.dispose);
    expect(
      second.read(propertiesRepositoryProvider),
      isNot(same(container.read(propertiesRepositoryProvider))),
    );
  });
}
