import 'dart:async';

import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:ghar360/core/controllers/offline_queue_service.dart';
import 'package:ghar360/core/providers/app_database_provider.dart';
import 'package:ghar360/core/providers/network_providers.dart';
import 'package:ghar360/core/utils/app_exceptions.dart';

enum PendingActionsPhase { loading, ready, refreshing, failed }

class PendingActionsState {
  PendingActionsState({
    List<PendingAction> actions = const [],
    this.phase = PendingActionsPhase.loading,
    this.failure,
  }) : actions = List.unmodifiable(actions);
  final List<PendingAction> actions;
  final PendingActionsPhase phase;
  final AppException? failure;
}

final pendingActionsProvider = NotifierProvider<PendingActionsController, PendingActionsState>(
  PendingActionsController.new,
);

class PendingActionsController extends Notifier<PendingActionsState> {
  int _generation = 0;
  int _request = 0;
  @override
  PendingActionsState build() {
    final scope = ref.watch(storageScopeProvider);
    final queue = ref.watch(offlineQueueServiceProvider);
    final generation = ++_generation;
    final subscription = queue.changes.listen((_) {
      unawaited(reload());
    });
    ref.onDispose(() {
      _generation++;
      unawaited(subscription.cancel());
    });
    if (scope.accountId != null) {
      Future.microtask(() {
        if (ref.mounted && generation == _generation) unawaited(reload());
      });
      return PendingActionsState();
    }
    return PendingActionsState(phase: PendingActionsPhase.ready);
  }

  Future<void> reload() async {
    final generation = _generation;
    final request = ++_request;
    final scope = ref.read(storageScopeProvider);
    final queue = ref.read(offlineQueueServiceProvider);
    state = PendingActionsState(
      actions: state.actions,
      phase: state.actions.isEmpty ? PendingActionsPhase.loading : PendingActionsPhase.refreshing,
    );
    try {
      final actions = scope.accountId == null ? <PendingAction>[] : await queue.list(scope: scope);
      if (ref.mounted && generation == _generation && request == _request) {
        state = PendingActionsState(
          actions: actions
              .where((action) => action.status != PendingActionStatus.confirmed)
              .toList(),
          phase: PendingActionsPhase.ready,
        );
      }
    } catch (error) {
      if (ref.mounted && generation == _generation && request == _request) {
        state = PendingActionsState(
          actions: state.actions,
          phase: PendingActionsPhase.failed,
          failure: error is AppException
              ? error
              : CacheException('Could not read saved requests.', code: 'QUEUE_READ_FAILED'),
        );
      }
    }
  }

  Future<void> discard(String operationId) async {
    await ref.read(offlineQueueServiceProvider).discard(operationId);
    if (ref.mounted) await reload();
  }
}

final unownedActionsProvider = FutureProvider<List<PendingAction>>(
  (ref) => ref.watch(appDatabaseProvider).readUnownedLegacyActions(),
);
