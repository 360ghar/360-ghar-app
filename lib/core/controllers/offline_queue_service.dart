import 'dart:async';

import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:ghar360/core/providers/app_database_provider.dart';
import 'package:ghar360/core/providers/network_providers.dart';
import 'package:ghar360/core/storage/app_database.dart';

export 'package:ghar360/core/storage/app_database.dart'
    show PendingAction, PendingActionStatus, StorageScope;

final offlineQueueServiceProvider = Provider<OfflineQueueService>((ref) {
  final service = OfflineQueueService(
    database: ref.watch(appDatabaseProvider),
    scope: () => ref.read(storageScopeProvider),
  );
  ref.onDispose(service.close);
  return service;
});

/// Account-owned durable intents. Connectivity never proves that an ambiguous
/// mutation failed on the server, so this service does not replay requests.
class OfflineQueueService {
  OfflineQueueService({required this._database, required this._scope});

  final AppDatabase _database;
  final StorageScope Function() _scope;
  final _changes = StreamController<void>.broadcast(sync: true);
  Future<void> _writes = Future.value();
  Stream<void> get changes => _changes.stream;
  StorageScope get scope => _scope();

  Future<List<PendingAction>> list({StorageScope? scope}) =>
      _database.listActions(scope: scope ?? _scope());

  Future<PendingAction> enqueueSwipe({
    required int propertyId,
    required bool isLiked,
    required StorageScope scope,
  }) {
    final owner = scope;
    return _serial(() async {
      final action = await create(
        kind: 'swipe',
        scope: owner,
        payload: {'property_id': propertyId, 'is_liked': isLiked},
      );
      // Persist the replacement first. A failed write leaves the old intent intact.
      for (final previous in await list(scope: owner)) {
        if (previous.kind == 'swipe' &&
            previous.operationId != action.operationId &&
            previous.payload['property_id'] == propertyId &&
            previous.status != PendingActionStatus.confirmed) {
          await _update(
            previous,
            scope: owner,
            status: PendingActionStatus.failed,
            failureCode: 'SUPERSEDED',
          );
        }
      }
      return action;
    });
  }

  Future<T> _serial<T>(Future<T> Function() work) {
    final result = _writes.then((_) => work());
    _writes = result.then<void>((_) {}, onError: (Object _, StackTrace _) {});
    return result;
  }

  Future<PendingAction> create({
    required String kind,
    required Map<String, Object?> payload,
    StorageScope? scope,
    PendingActionStatus status = PendingActionStatus.pending,
  }) async {
    final owner = scope ?? _scope();
    final id = await _database.createAction(
      scope: owner,
      kind: kind,
      payload: payload,
      status: status,
    );
    // Built from what was just written; re-reading the whole history would decode every past row.
    final action = PendingAction(
      operationId: id,
      scopeKey: owner.key,
      kind: kind,
      payload: payload.cast<String, dynamic>(),
      createdAt: DateTime.now(),
      status: status,
    );
    _notify();
    return action;
  }

  /// Serialized with [enqueueSwipe], so a status write cannot overwrite a SUPERSEDED marker.
  Future<void> update(
    PendingAction action, {
    required StorageScope scope,
    required PendingActionStatus status,
    String? failureCode,
    bool attempted = false,
  }) => _serial(
    () => _update(
      action,
      scope: scope,
      status: status,
      failureCode: failureCode,
      attempted: attempted,
    ),
  );

  Future<void> _update(
    PendingAction action, {
    required StorageScope scope,
    required PendingActionStatus status,
    String? failureCode,
    bool attempted = false,
  }) async {
    await _database.updateAction(
      scope: scope,
      operationId: action.operationId,
      status: status,
      attempts: action.attempts + (attempted ? 1 : 0),
      failureCode: failureCode,
    );
    _notify();
  }

  Future<void> discard(String operationId, {StorageScope? scope}) => _serial(() async {
    await _database.discardAction(scope: scope ?? _scope(), operationId: operationId);
    _notify();
  });

  void _notify() {
    if (!_changes.isClosed) _changes.add(null);
  }

  /// Closes the change stream once queued writes have finished, so none outlives the database.
  void close() {
    unawaited(_writes.whenComplete(_changes.close));
  }
}
