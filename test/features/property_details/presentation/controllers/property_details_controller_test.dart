import 'dart:async';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';

import 'package:ghar360/core/data/models/property_model.dart';
import 'package:ghar360/core/data/ports/properties_port.dart';
import 'package:ghar360/core/network/cache_policy.dart';
import 'package:ghar360/core/providers/app_database_provider.dart';
import 'package:ghar360/core/providers/network_providers.dart';
import 'package:ghar360/core/storage/app_database.dart';
import 'package:ghar360/core/utils/app_exceptions.dart';
import 'package:ghar360/features/properties/application/property_queries.dart';
import 'package:ghar360/features/property_details/presentation/controllers/property_details_controller.dart';
import '../../../../helpers/visits_test_support.dart';

class MockDetailRepository extends Mock implements PropertiesPort {}

void main() {
  late AppDatabase database;
  late MockDetailRepository repository;
  late ProviderContainer container;
  late TestVisitScope scope;
  final provider = propertyDetailsProvider(100);
  PropertyDetailsState state() => container.read(provider);
  PropertyDetailsController controller() => container.read(provider.notifier);
  Future<void> settle() async {
    await container.pump();
    for (var i = 0; i < 100 && state().busy; i++) {
      await Future<void>.delayed(const Duration(milliseconds: 5));
    }
    // Wait for the optional cache write, then the next refresh can start.
    await database.readCache(scope: container.read(storageScopeProvider), key: 'property:100');
    await Future<void>.delayed(Duration.zero);
  }

  setUp(() async {
    database = await visitTestDatabase();
    repository = MockDetailRepository();
    scope = TestVisitScope(database);
    when(() => repository.getPropertyDetail(any())).thenAnswer((_) async => propertyFixture());
    container = ProviderContainer(
      retry: (_, _) => null,
      overrides: [
        appDatabaseProvider.overrideWithValue(database),
        storageScopeProvider.overrideWith(() => scope),
        propertiesRepositoryProvider.overrideWithValue(repository),
      ],
    );
  });
  tearDown(() async {
    container.dispose();
    await database.close();
  });
  void listen() => container.listen(provider, (_, _) {});
  Future<void> cache(PropertyModel property) async {
    final now = DateTime.now();
    await database.writeCache(
      scope: container.read(storageScopeProvider),
      key: 'property:100',
      value: property.toJson(),
      freshUntil: now.subtract(const Duration(minutes: 1)),
      expiresAt: now.add(const Duration(days: 1)),
    );
  }

  test('typed ID resolves authoritative detail once', () async {
    listen();
    expect(state().phase, PropertyDetailPhase.loading);
    await settle();
    expect(state().property!.id, 100);
    expect(state().failure, isNull);
    verify(() => repository.getPropertyDetail(100)).called(1);
  });
  test('invalid ID rejects without network or cache', () {
    final value = container.read(propertyDetailsProvider(0));
    expect(value.failure, isA<ValidationException>());
    verifyNever(() => repository.getPropertyDetail(any()));
  });
  test('refresh retains content and clears the old failure on success', () async {
    listen();
    await settle();
    final pending = Completer<PropertyModel>();
    when(() => repository.getPropertyDetail(100)).thenAnswer((_) => pending.future);
    final request = controller().refresh();
    expect(state().phase, PropertyDetailPhase.refreshing);
    expect(state().property!.id, 100);
    pending.complete(
      PropertyModel.fromJson({...propertyFixture().toJson(), 'title': 'Authoritative title'}),
    );
    await request;
    expect(state().property!.title, 'Authoritative title');
    expect(state().stale, false);
  });
  test('failed refresh retains detail with recoverable typed error', () async {
    listen();
    await settle();
    when(() => repository.getPropertyDetail(100)).thenThrow(NetworkException('private payload'));
    await controller().refresh();
    expect(state().phase, PropertyDetailPhase.content);
    expect(state().property!.id, 100);
    expect(state().failure, isA<NetworkException>());
    expect(state().stale, true);
  });
  test('initial error can retry without recreating a route', () async {
    when(() => repository.getPropertyDetail(100)).thenThrow(NetworkException('offline'));
    listen();
    await settle();
    expect(state().phase, PropertyDetailPhase.failed);
    when(() => repository.getPropertyDetail(100)).thenAnswer((_) async => propertyFixture());
    await controller().refresh();
    expect(state().property!.id, 100);
    expect(state().failure, isNull);
  });
  test('untyped exception is sanitized', () async {
    when(() => repository.getPropertyDetail(100)).thenThrow(Exception('secret payload'));
    listen();
    await settle();
    expect(state().failure, isA<ApiException>());
    expect(state().failure!.message, isNot(contains('secret')));
  });
  test('mismatched response is a malformed error and is never cached', () async {
    when(() => repository.getPropertyDetail(100)).thenAnswer((_) async => propertyFixture(id: 200));
    listen();
    await settle();
    expect(state().property, isNull);
    expect(state().failure!.code, 'MALFORMED_RESPONSE');
    expect(
      await database.readCache(scope: container.read(storageScopeProvider), key: 'property:100'),
      isNull,
    );
  });
  test('cached detail remains usable on a failed network refresh', () async {
    await cache(PropertyModel.fromJson({...propertyFixture().toJson(), 'title': 'Cached title'}));
    when(() => repository.getPropertyDetail(100)).thenThrow(NetworkException('offline'));
    listen();
    await settle();
    expect(state().property!.title, 'Cached title');
    expect(state().stale, true);
  });
  test('a detail marked no-store is shown, never stored, and an older copy is deleted', () async {
    await cache(propertyFixture());
    when(() => repository.getPropertyDetail(100)).thenAnswer(
      (_) async => markCachePolicy(propertyFixture(), {'cache-control': 'private, no-store'}),
    );
    listen();
    await settle();
    expect(state().property!.id, 100);
    expect(state().failure, isNull);
    expect(
      await database.readCache(scope: container.read(storageScopeProvider), key: 'property:100'),
      isNull,
    );
  });
  test('a stored detail holds no owner, agent or company phone number', () async {
    when(() => repository.getPropertyDetail(100)).thenAnswer(
      (_) async => PropertyModel.fromJson({
        ...propertyFixture().toJson(),
        'owner_contact': '+911800000360',
        'agent': {'id': 4, 'name': 'Ravi Kumar', 'contact_number': '+919811111111'},
      }),
    );
    listen();
    await settle();
    final row = await database.readCache(
      scope: container.read(storageScopeProvider),
      key: 'property:100',
    );
    final stored = row!.value as Map;
    expect(stored.containsKey('owner_contact'), isFalse);
    expect((stored['agent'] as Map).containsKey('contact_number'), isFalse);
    expect((stored['agent'] as Map)['name'], 'Ravi Kumar');
    // The visible copy still has the number the user can call.
    expect(state().property!.contactNumber, '+919811111111');
  });
  test('deleted listing removes cached detail from visible state', () async {
    await cache(propertyFixture());
    when(() => repository.getPropertyDetail(100)).thenThrow(NotFoundException('deleted'));
    listen();
    await settle();
    expect(state().property, isNull);
    expect(state().phase, PropertyDetailPhase.failed);
    expect(
      await database.readCache(scope: container.read(storageScopeProvider), key: 'property:100'),
      isNull,
    );
  });
  test('concurrent refreshes issue only one network request', () async {
    listen();
    await settle();
    clearInteractions(repository);
    final pending = Completer<PropertyModel>();
    when(() => repository.getPropertyDetail(100)).thenAnswer((_) => pending.future);
    final request = controller().refresh();
    await controller().refresh();
    verify(() => repository.getPropertyDetail(100)).called(1);
    pending.complete(propertyFixture());
    await request;
  });
  test('account transition clears visible detail synchronously and rejects late result', () async {
    final oldRequest = Completer<PropertyModel>();
    when(() => repository.getPropertyDetail(100)).thenAnswer((_) => oldRequest.future);
    listen();
    await Future<void>.delayed(const Duration(milliseconds: 20));
    when(() => repository.getPropertyDetail(100)).thenAnswer(
      (_) async => PropertyModel.fromJson({...propertyFixture().toJson(), 'title': 'Account B'}),
    );
    scope.change('account-b');
    expect(state().property, isNull);
    await settle();
    oldRequest.complete(
      PropertyModel.fromJson({...propertyFixture().toJson(), 'title': 'Account A'}),
    );
    await container.pump();
    expect(state().property!.title, 'Account B');
  });
  test('A to B to A cannot accept the original A request', () async {
    final oldRequest = Completer<PropertyModel>();
    when(() => repository.getPropertyDetail(100)).thenAnswer((_) => oldRequest.future);
    listen();
    await Future<void>.delayed(const Duration(milliseconds: 20));
    scope.change('account-b');
    container.read(provider);
    when(() => repository.getPropertyDetail(100)).thenAnswer(
      (_) async => PropertyModel.fromJson({...propertyFixture().toJson(), 'title': 'New A'}),
    );
    scope.change('account-a');
    await settle();
    oldRequest.complete(PropertyModel.fromJson({...propertyFixture().toJson(), 'title': 'Old A'}));
    await container.pump();
    expect(state().property!.title, 'New A');
  });
  test('disposal ignores in-flight completion and leaves no cache write', () async {
    final pending = Completer<PropertyModel>();
    when(() => repository.getPropertyDetail(100)).thenAnswer((_) => pending.future);
    final subscription = container.listen(provider, (_, _) {});
    await Future<void>.delayed(const Duration(milliseconds: 20));
    final lease = container.read(storageScopeProvider);
    subscription.close();
    await container.pump();
    pending.complete(propertyFixture());
    await Future<void>.delayed(Duration.zero);
    expect(await database.readCache(scope: lease, key: 'property:100'), isNull);
  });
}
