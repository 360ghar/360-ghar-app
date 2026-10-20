import 'dart:io';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';

import 'package:ghar360/core/controllers/offline_queue_service.dart';
import 'package:ghar360/core/providers/app_database_provider.dart';
import 'package:ghar360/core/providers/network_providers.dart';
import 'package:ghar360/core/providers/pending_actions_provider.dart';
import 'package:ghar360/core/storage/app_database.dart';
import '../../helpers/visits_test_support.dart';

void main() {
  late AppDatabase db;
  late StorageScope scope;
  late OfflineQueueService queue;
  setUp(() async {
    db = await visitTestDatabase();
    scope = db.activateScope(environment: 'test', accountId: 'a');
    queue = OfflineQueueService(database: db, scope: () => scope);
  });
  tearDown(() async {
    queue.close();
    await db.close();
  });
  test('durable action has unique operation ID, account, and immutable payload copy', () async {
    final action = await queue.enqueueSwipe(propertyId: 1, isLiked: true, scope: scope);
    expect(action.operationId, isNotEmpty);
    expect(action.scopeKey, scope.key);
    expect(action.kind, 'swipe');
    expect(action.status, PendingActionStatus.pending);
    expect(action.attempts, 0);
    expect(() => action.payload['property_id'] = 99, throwsUnsupportedError);
    expect((await queue.list()).single.payload['property_id'], 1);
  });
  test('new same-property intent supersedes the older intent without deleting it', () async {
    final first = await queue.enqueueSwipe(propertyId: 1, isLiked: true, scope: scope);
    final second = await queue.enqueueSwipe(propertyId: 1, isLiked: false, scope: scope);
    final actions = await queue.list();
    expect(actions.length, 2);
    expect(actions.first.operationId, first.operationId);
    expect(actions.first.failureCode, 'SUPERSEDED');
    expect(actions.last.operationId, second.operationId);
    expect(actions.last.status, PendingActionStatus.pending);
  });
  test('concurrent enqueue keeps only the latest intent eligible for retry', () async {
    await Future.wait([
      for (var i = 0; i < 8; i++)
        queue.enqueueSwipe(propertyId: 1, isLiked: i.isEven, scope: scope),
    ]);
    final actions = await queue.list();
    expect(actions.length, 8);
    expect(actions.where((a) => a.failureCode != 'SUPERSEDED').length, 1);
    expect(actions.last.payload['is_liked'], false);
  });
  test('old-account enqueue cannot move an action into the new account', () async {
    final old = scope;
    scope = db.activateScope(environment: 'test', accountId: 'b');
    await expectLater(
      queue.enqueueSwipe(propertyId: 1, isLiked: true, scope: old),
      throwsA(isA<StorageFailure>()),
    );
    expect(await queue.list(), isEmpty);
  });
  test('account A to B to A invalidates the original lease', () async {
    final old = scope;
    db.activateScope(environment: 'test', accountId: 'b');
    scope = db.activateScope(environment: 'test', accountId: 'a');
    await expectLater(
      queue.create(kind: 'visit', payload: {}, scope: old),
      throwsA(isA<StorageFailure>()),
    );
  });
  test('logout hides saved requests without deleting them', () async {
    await queue.create(
      kind: 'visit',
      payload: {'property_id': 1},
      status: PendingActionStatus.needsReconciliation,
    );
    scope = db.activateScope(environment: 'test');
    expect(await queue.list(), isEmpty);
    scope = db.activateScope(environment: 'test', accountId: 'a');
    expect((await queue.list()).length, 1);
  });
  test('guest action fails before claiming it is saved', () async {
    scope = db.activateScope(environment: 'test');
    await expectLater(
      queue.create(kind: 'visit', payload: {}),
      throwsA(isA<StorageFailure>().having((e) => e.code, 'code', 'ACTION_OWNER_REQUIRED')),
    );
  });
  test('failed requests and retry metadata remain until explicit discard', () async {
    final action = await queue.create(
      kind: 'visit',
      payload: {'scheduled_date': '2000-01-01'},
      status: PendingActionStatus.needsReconciliation,
    );
    await db.updateAction(
      scope: scope,
      operationId: action.operationId,
      status: PendingActionStatus.failed,
      attempts: 99,
      failureCode: 'REVIEW',
    );
    final persisted = (await queue.list()).single;
    expect(persisted.attempts, 99);
    expect(persisted.status, PendingActionStatus.failed);
    await queue.discard(action.operationId);
    expect(await queue.list(), isEmpty);
  });
  test('queue cap fails explicitly and preserves all existing requests', () async {
    for (var i = 0; i < AppDatabase.maxPendingActions; i++) {
      await queue.create(kind: 'visit', payload: {'property_id': i});
    }
    await expectLater(
      queue.create(kind: 'visit', payload: {}),
      throwsA(isA<StorageFailure>().having((e) => e.code, 'code', 'ACTION_QUEUE_FULL')),
    );
    expect((await queue.list()).length, AppDatabase.maxPendingActions);
  });
  test('closed database reports storage failure instead of saved outcome', () async {
    await db.close();
    await expectLater(
      queue.enqueueSwipe(propertyId: 1, isLiked: true, scope: scope),
      throwsA(isA<StorageFailure>()),
    );
  });
  test('confirmed actions stay recorded and stop consuming pending capacity', () async {
    final action = await queue.create(kind: 'visit', payload: {});
    await queue.update(
      action,
      scope: scope,
      status: PendingActionStatus.confirmed,
      attempted: true,
    );
    expect((await queue.list()).single.status, PendingActionStatus.confirmed);
    expect((await queue.list()).single.attempts, 1);
  });
  test('failed serialized write does not block later valid writes', () async {
    final old = scope;
    scope = db.activateScope(environment: 'test', accountId: 'b');
    await expectLater(
      queue.enqueueSwipe(propertyId: 1, isLiked: true, scope: old),
      throwsA(isA<StorageFailure>()),
    );
    final saved = await queue.enqueueSwipe(propertyId: 1, isLiked: false, scope: scope);
    expect(saved.scopeKey, scope.key);
  });
  test('queue provider owns lifecycle and account-filtered list changes', () async {
    final owner = TestVisitScope(db);
    final container = ProviderContainer(
      retry: (_, _) => null,
      overrides: [
        appDatabaseProvider.overrideWithValue(db),
        storageScopeProvider.overrideWith(() => owner),
      ],
    );
    addTearDown(container.dispose);
    final queue = container.read(offlineQueueServiceProvider);
    await container.read(pendingActionsProvider.notifier).reload();
    final action = await queue.create(kind: 'visit', payload: {});
    await container.read(pendingActionsProvider.notifier).reload();
    expect(container.read(pendingActionsProvider).actions.single.operationId, action.operationId);
    owner.change('other');
    expect(container.read(pendingActionsProvider).actions, isEmpty);
    await container.read(pendingActionsProvider.notifier).reload();
    expect(container.read(pendingActionsProvider).actions, isEmpty);
  });
  test('actions survive reopening and are never automatically replayed', () async {
    final dir = await Directory.systemTemp.createTemp('visits-queue-');
    final path = '${dir.path}/test.db';
    var durable = await AppDatabase.open(
      factory: databaseFactoryFfi,
      databasePath: path,
      legacyReader: () async => {},
    );
    var owner = durable.activateScope(environment: 'test', accountId: 'a');
    final operation = await durable.createAction(
      scope: owner,
      kind: 'visit',
      payload: {'property_id': 1},
      status: PendingActionStatus.needsReconciliation,
    );
    await durable.close();
    durable = await AppDatabase.open(factory: databaseFactoryFfi, databasePath: path);
    owner = durable.activateScope(environment: 'test', accountId: 'a');
    final saved = (await durable.listActions(scope: owner)).single;
    expect(saved.operationId, operation);
    expect(saved.status, PendingActionStatus.needsReconciliation);
    await durable.close();
    await dir.delete(recursive: true);
  });
}
