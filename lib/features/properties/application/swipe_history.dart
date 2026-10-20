import 'dart:async';

import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:ghar360/core/controllers/offline_queue_service.dart';
import 'package:ghar360/core/data/models/property_model.dart';
import 'package:ghar360/core/data/ports/swipes_port.dart';
import 'package:ghar360/core/providers/app_database_provider.dart';
import 'package:ghar360/core/providers/network_providers.dart';
import 'package:ghar360/core/utils/app_exceptions.dart';
import 'package:ghar360/features/properties/application/property_queries.dart';

enum SwipePhase { submitting, confirmed, pending, unresolved }

class SwipeEntry {
  SwipeEntry({
    required this.property,
    required this.isLiked,
    required this.revision,
    required this.phase,
    this.operationId,
    this.restored = false,
    Iterable<String> queryIdentities = const [],
    this.discoverInputIdentity,
  }) : queryIdentities = Set.unmodifiable(queryIdentities);
  final PropertyModel property;
  final bool isLiked;
  final int revision;
  final SwipePhase phase;
  final String? operationId;
  final bool restored;
  final Set<String> queryIdentities;
  final String? discoverInputIdentity;
  SwipeEntry withOutcome(SwipeOutcome outcome) => SwipeEntry(
    property: property,
    isLiked: isLiked,
    revision: revision,
    restored: restored,
    phase: outcome is PendingSwipe ? SwipePhase.pending : SwipePhase.confirmed,
    operationId: switch (outcome) {
      PendingSwipe(:final action) => action.operationId,
      ConfirmedSwipe(:final operationId) => operationId,
    },
    queryIdentities: queryIdentities,
    discoverInputIdentity: discoverInputIdentity,
  );
  SwipeEntry discarded() => SwipeEntry(
    property: property,
    isLiked: isLiked,
    revision: revision,
    phase: SwipePhase.unresolved,
    queryIdentities: queryIdentities,
    discoverInputIdentity: discoverInputIdentity,
  );
}

class SwipeHistoryState {
  SwipeHistoryState({
    Map<int, SwipeEntry> entries = const {},
    Set<int> excluded = const {},
    Set<int> unresolvedExcluded = const {},
    Map<int, AppException> failures = const {},
    this.storageError,
    this.hydrated = false,
    Map<String, AsyncValue<bool>> pendingOperations = const {},
  }) : entries = Map.unmodifiable(entries),
       excluded = Set.unmodifiable(excluded),
       unresolvedExcluded = Set.unmodifiable(unresolvedExcluded),
       failures = Map.unmodifiable(failures),
       pendingOperations = Map.unmodifiable(pendingOperations);
  final Map<int, SwipeEntry> entries;
  final Set<int> excluded;

  /// Discarded ambiguous actions must outlive the bounded recent summary.
  final Set<int> unresolvedExcluded;
  final Map<int, AppException> failures;
  final Object? storageError;
  final bool hydrated;
  final Map<String, AsyncValue<bool>> pendingOperations;
  SwipeHistoryState copyWith({
    Map<int, SwipeEntry>? entries,
    Set<int>? excluded,
    Set<int>? unresolvedExcluded,
    Map<int, AppException>? failures,
    Object? storageError = _unchanged,
    bool? hydrated,
    Map<String, AsyncValue<bool>>? pendingOperations,
  }) => SwipeHistoryState(
    entries: entries ?? this.entries,
    excluded: excluded ?? this.excluded,
    unresolvedExcluded: unresolvedExcluded ?? this.unresolvedExcluded,
    failures: failures ?? this.failures,
    storageError: identical(storageError, _unchanged) ? this.storageError : storageError,
    hydrated: hydrated ?? this.hydrated,
    pendingOperations: pendingOperations ?? this.pendingOperations,
  );
  int get likes => entries.values.where((entry) => entry.isLiked && !entry.restored).length;
  int get passes => entries.values.where((entry) => !entry.isLiked && !entry.restored).length;
  int get pendingCount => entries.values.where((entry) => entry.phase == SwipePhase.pending).length;
}

const _unchanged = Object();

final swipeHistoryProvider = NotifierProvider<SwipeHistory, SwipeHistoryState>(SwipeHistory.new);

/// Optimistic intent is overlaid on server pages. Fetch completions therefore
/// cannot restore swiped cards or overwrite a newer local Like/Pass action.
class SwipeHistory extends Notifier<SwipeHistoryState> {
  final Map<int, Future<void>> _requests = {};
  Future<void> _writes = Future.value();
  final Map<String, Future<bool>> _pendingJobs = {};
  int _revision = 0;
  int _generation = 0;

  @override
  SwipeHistoryState build() {
    final scope = ref.watch(storageScopeProvider);
    final database = ref.watch(appDatabaseProvider);
    final generation = ++_generation;
    _requests.clear();
    _pendingJobs.clear();
    ref.onDispose(() {
      _generation++;
    });
    scheduleMicrotask(() async {
      try {
        final value = await database.readDraft(scope: scope, key: 'swipe_history_v1');
        final actions = await database.listActions(scope: scope);
        if (!ref.mounted || generation != _generation) return;
        final excluded = <int>{};
        final unresolvedExcluded =
            (value?['unresolvedExcluded'] is List ? value!['unresolvedExcluded'] as List : const [])
                .whereType<int>()
                .toSet();
        excluded.addAll(unresolvedExcluded);
        final entries = <int, SwipeEntry>{};
        if (value?['excluded'] is List) {
          excluded.addAll((value!['excluded'] as List).whereType<int>());
        }
        for (final raw in value?['entries'] is List ? value!['entries'] as List : const []) {
          try {
            final item = Map<String, dynamic>.from(raw as Map);
            final property = PropertyModel.fromJson(
              Map<String, dynamic>.from(item['property'] as Map),
            );
            entries[property.id] = SwipeEntry(
              property: property,
              isLiked: item['isLiked'] == true,
              revision: ++_revision,
              phase: item['unresolved'] == true
                  ? SwipePhase.unresolved
                  : item['pending'] == true
                  ? SwipePhase.pending
                  : SwipePhase.confirmed,
              operationId: item['operationId'] as String?,
              restored: item['restored'] == true,
              queryIdentities:
                  (item['queryIdentities'] is List ? item['queryIdentities'] as List : const [])
                      .whereType<String>(),
              discoverInputIdentity: item['discoverInputIdentity'] as String?,
            );
          } on Object {
            // One corrupt summary does not restore another swiped property.
          }
        }
        final latest = <int, PendingAction>{};
        for (final action in actions) {
          if (action.kind == 'swipe' && action.payload['property_id'] is int) {
            latest[action.payload['property_id'] as int] = action;
          }
        }
        for (final action in latest.values) {
          final id = action.payload['property_id'] as int;
          if (action.status == PendingActionStatus.pending ||
              action.status == PendingActionStatus.needsReconciliation ||
              action.status == PendingActionStatus.confirmed) {
            excluded.add(id);
            final entry = entries[id];
            if (entry != null) {
              final sameOperation = entry.operationId == action.operationId;
              entries[id] = SwipeEntry(
                property: entry.property,
                isLiked: action.payload['is_liked'] == true,
                revision: entry.revision,
                phase: action.status == PendingActionStatus.confirmed
                    ? SwipePhase.confirmed
                    : SwipePhase.pending,
                operationId: action.operationId,
                restored: sameOperation && entry.restored,
                queryIdentities: entry.queryIdentities,
                discoverInputIdentity: entry.discoverInputIdentity,
              );
              if (sameOperation && entry.restored) excluded.remove(id);
            }
          }
        }
        final combined = {...entries, ...state.entries};
        final combinedExcluded = {...excluded, ...state.excluded};
        for (final entry in state.entries.values) {
          if (entry.restored) combinedExcluded.remove(entry.property.id);
        }
        state = state.copyWith(
          entries: combined,
          excluded: combinedExcluded,
          unresolvedExcluded: {...unresolvedExcluded, ...state.unresolvedExcluded},
          failures: state.failures,
          storageError: state.storageError,
          hydrated: true,
        );
      } catch (error) {
        if (ref.mounted && generation == _generation) {
          state = state.copyWith(
            entries: state.entries,
            excluded: state.excluded,
            failures: state.failures,
            storageError: error,
            hydrated: true,
          );
        }
      }
    });
    return SwipeHistoryState();
  }

  /// Requests for the same property run in order. Different cards can be
  /// swiped concurrently. Only the current revision can commit or roll back.
  Future<bool> record(PropertyModel property, bool isLiked, {bool restored = false}) {
    final revision = ++_revision;
    final generation = _generation;
    final scope = ref.read(storageScopeProvider);
    final repository = ref.read(swipesRepositoryProvider);
    final before = state.entries[property.id];
    final wasExcluded = state.excluded.contains(property.id);
    final identities = <String>{...?before?.queryIdentities};
    String? discoverIdentity = before?.discoverInputIdentity;
    for (final feed in PropertyFeed.values) {
      if (!ref.exists(propertyQueryProvider(feed))) continue;
      final page = ref.read(propertyQueryProvider(feed));
      final identity = ref.read(propertyQueryInputProvider(feed));
      if (identity != null &&
          page.inputIdentity == identity &&
          page.items.any((item) => item.id == property.id)) {
        identities.add(identity);
        if (feed == PropertyFeed.discover && !restored) discoverIdentity = identity;
      }
    }
    final entry = SwipeEntry(
      property: property,
      isLiked: isLiked,
      revision: revision,
      phase: SwipePhase.submitting,
      restored: restored,
      queryIdentities: identities,
      discoverInputIdentity: discoverIdentity,
    );
    final entries = {...state.entries, property.id: entry};
    final excluded = {...state.excluded};
    if (restored) {
      excluded.remove(property.id);
    } else {
      excluded.add(property.id);
    }
    final failures = {...state.failures}..remove(property.id);
    state = state.copyWith(
      entries: entries,
      excluded: excluded,
      failures: failures,
      storageError: state.storageError,
      hydrated: state.hydrated,
    );
    final result = Completer<bool>();
    final previous = _requests[property.id] ?? Future.value();
    final request = previous.then((_) async {
      if (!ref.mounted ||
          generation != _generation ||
          !identical(scope, ref.read(storageScopeProvider))) {
        result.complete(false);
        return;
      }
      try {
        final outcome = await repository.recordSwipe(propertyId: property.id, isLiked: isLiked);
        if (!ref.mounted || generation != _generation) {
          result.complete(false);
          return;
        }
        if (state.entries[property.id]?.revision == revision) {
          state = state.copyWith(
            entries: {...state.entries, property.id: entry.withOutcome(outcome)},
            excluded: state.excluded,
            unresolvedExcluded: outcome is ConfirmedSwipe
                ? ({...state.unresolvedExcluded}..remove(property.id))
                : state.unresolvedExcluded,
            failures: state.failures,
            storageError: state.storageError,
            hydrated: true,
          );
          await _persist();
          if (_active(generation, scope) && outcome is ConfirmedSwipe) _refreshHistory();
        }
        result.complete(_active(generation, scope));
      } catch (error) {
        if (ref.mounted &&
            generation == _generation &&
            state.entries[property.id]?.revision == revision) {
          final rolledBack = {...state.entries}..remove(property.id);
          if (before != null) rolledBack[property.id] = before;
          final excluded = {...state.excluded};
          if (wasExcluded) {
            excluded.add(property.id);
          } else {
            excluded.remove(property.id);
          }
          state = state.copyWith(
            entries: rolledBack,
            excluded: excluded,
            failures: {
              ...state.failures,
              property.id: error is AppException
                  ? error
                  : ServerException('Swipe failed', code: 'UNKNOWN'),
            },
            storageError: state.storageError,
            hydrated: true,
          );
        }
        result.complete(false);
      }
    });
    _requests[property.id] = request;
    unawaited(
      request.whenComplete(() {
        if (identical(_requests[property.id], request)) _requests.remove(property.id);
      }),
    );
    return result.future;
  }

  Future<bool> undo(int propertyId) {
    final entry = state.entries[propertyId];
    if (entry == null || entry.restored) return Future.value(false);
    return record(entry.property, !entry.isLiked, restored: true);
  }

  Future<bool> retry(PropertyModel property, bool isLiked) => record(property, isLiked);
  void dismissFailure(int propertyId) {
    state = state.copyWith(
      entries: state.entries,
      excluded: state.excluded,
      failures: {...state.failures}..remove(propertyId),
      storageError: state.storageError,
      hydrated: state.hydrated,
    );
  }

  void _refreshHistory() {
    for (final feed in [PropertyFeed.liked, PropertyFeed.passed]) {
      if (ref.exists(propertyQueryProvider(feed))) {
        unawaited(ref.read(propertyQueryProvider(feed).notifier).load(refresh: true));
      }
    }
  }

  bool _active(int generation, StorageScope scope) =>
      ref.mounted && generation == _generation && identical(scope, ref.read(storageScopeProvider));
  AppException _pendingFailure(Object error) => error is AppException
      ? error
      : CacheException('Saved swipe could not be updated.', code: 'SWIPE_RECOVERY_FAILED');
  Future<PendingAction> _savedAction(
    PendingAction expected,
    StorageScope scope, {
    required bool latest,
  }) async {
    if (expected.kind != 'swipe' ||
        expected.scopeKey != scope.key ||
        expected.payload['property_id'] is! int ||
        expected.payload['is_liked'] is! bool) {
      throw ValidationException('Saved swipe is not owned by this account.', code: 'INVALID_SWIPE');
    }
    final actions = (await ref.read(offlineQueueServiceProvider).list(scope: scope))
        .where(
          (action) =>
              action.kind == 'swipe' &&
              action.payload['property_id'] == expected.payload['property_id'],
        )
        .toList();
    final candidates = actions.where((action) => action.operationId == expected.operationId);
    if (candidates.isEmpty) {
      throw ValidationException('Saved swipe no longer exists.', code: 'SWIPE_NOT_FOUND');
    }
    final action = candidates.single;
    if (action.status == PendingActionStatus.confirmed ||
        action.payload['is_liked'] != expected.payload['is_liked'] ||
        (latest &&
            (actions.last.operationId != action.operationId ||
                action.failureCode == 'SUPERSEDED'))) {
      throw ValidationException('A newer swipe replaced this request.', code: 'SWIPE_SUPERSEDED');
    }
    return action;
  }

  Future<bool> retryPending(PendingAction action) {
    final existing = _pendingJobs[action.operationId];
    if (existing != null) return existing;
    if (state.pendingOperations[action.operationId]?.isLoading == true) return Future.value(false);
    final scope = ref.read(storageScopeProvider);
    final generation = _generation;
    final id = action.payload['property_id'];
    final entry = id is int ? state.entries[id] : null;
    final revision = entry?.revision;
    state = state.copyWith(
      pendingOperations: {...state.pendingOperations, action.operationId: const AsyncLoading()},
    );
    final previous = id is int ? (_requests[id] ?? Future<void>.value()) : Future<void>.value();
    final work = previous.then((_) async {
      try {
        if (!_active(generation, scope)) return false;
        final saved = await _savedAction(action, scope, latest: true);
        if (!_active(generation, scope)) return false;
        final current = state.entries[id];
        if (current?.revision != revision || current?.phase == SwipePhase.submitting) {
          throw ValidationException(
            'A newer swipe replaced this request.',
            code: 'SWIPE_SUPERSEDED',
          );
        }
        // A failed latest request can have rolled the UI back to an older
        // summary. The durable latest-operation check above owns retry order.
        final recovering = current == null
            ? null
            : SwipeEntry(
                property: current.property,
                isLiked: saved.payload['is_liked']! as bool,
                revision: current.revision,
                phase: SwipePhase.pending,
                operationId: saved.operationId,
                restored: current.operationId == saved.operationId && current.restored,
                queryIdentities: current.queryIdentities,
                discoverInputIdentity: current.discoverInputIdentity,
              );
        final outcome = await ref.read(swipesRepositoryProvider).retryPendingSwipe(saved);
        if (!_active(generation, scope)) return false;
        if (state.entries[id]?.revision == revision) {
          state = state.copyWith(
            entries: {
              ...state.entries,
              if (recovering != null) id as int: recovering.withOutcome(outcome),
            },
            excluded: recovering?.restored == true
                ? ({...state.excluded}..remove(id))
                : {...state.excluded, if (id is int) id},
            failures: {...state.failures}..remove(id),
            unresolvedExcluded: outcome is ConfirmedSwipe
                ? ({...state.unresolvedExcluded}..remove(id))
                : state.unresolvedExcluded,
          );
          await _persist();
        }
        if (!_active(generation, scope)) return false;
        final confirmed = outcome is ConfirmedSwipe;
        state = state.copyWith(
          pendingOperations: {
            ...state.pendingOperations,
            action.operationId: confirmed
                ? const AsyncData(true)
                : AsyncError(
                    NetworkException('Swipe remains unresolved.', code: 'SWIPE_UNRESOLVED'),
                    StackTrace.current,
                  ),
          },
        );
        if (confirmed) _refreshHistory();
        return confirmed;
      } catch (error, stack) {
        if (_active(generation, scope)) {
          state = state.copyWith(
            pendingOperations: {
              ...state.pendingOperations,
              action.operationId: AsyncError(_pendingFailure(error), stack),
            },
          );
        }
        return false;
      }
    });
    _pendingJobs[action.operationId] = work;
    final request = work.then<void>((_) {});
    if (id is int) _requests[id] = request;
    unawaited(
      work.then((_) {
        if (identical(_pendingJobs[action.operationId], work)) {
          _pendingJobs.remove(action.operationId);
        }
        if (id is int && identical(_requests[id], request)) _requests.remove(id);
      }),
    );
    return work;
  }

  Future<bool> discardPending(PendingAction action) async {
    final id = action.payload['property_id'];
    if (state.pendingOperations[action.operationId]?.isLoading == true ||
        _pendingJobs.containsKey(action.operationId) ||
        (id is int && _requests.containsKey(id))) {
      return false;
    }
    final scope = ref.read(storageScopeProvider);
    final generation = _generation;
    SwipeEntry? before;
    SwipeEntry? discarded;
    final wasExcluded = state.excluded.contains(id);
    state = state.copyWith(
      pendingOperations: {...state.pendingOperations, action.operationId: const AsyncLoading()},
    );
    try {
      await _savedAction(action, scope, latest: false);
      if (!_active(generation, scope)) return false;
      final entry = id is int ? state.entries[id] : null;
      before = entry;
      if (entry?.operationId == action.operationId) discarded = entry!.discarded();
      // Persist the unresolved exclusion before removing its durable action.
      // Discard means stop retrying, not that the server accepted an undo.
      state = state.copyWith(
        entries: {...state.entries, if (discarded != null && id is int) id: discarded},
        excluded: {...state.excluded, if (id is int && (entry == null || discarded != null)) id},
        unresolvedExcluded: {
          ...state.unresolvedExcluded,
          if (id is int && (entry == null || discarded != null)) id,
        },
      );
      await _persist();
      if (!_active(generation, scope)) return false;
      if (state.storageError != null) throw state.storageError!;
      await ref.read(offlineQueueServiceProvider).discard(action.operationId, scope: scope);
      if (!_active(generation, scope)) return false;
      state = state.copyWith(
        pendingOperations: {...state.pendingOperations, action.operationId: const AsyncData(true)},
      );
      return true;
    } catch (error, stack) {
      if (_active(generation, scope)) {
        final rollback = before != null && identical(state.entries[id], discarded);
        state = state.copyWith(
          entries: {...state.entries, if (rollback) id as int: before},
          excluded: rollback && !wasExcluded ? ({...state.excluded}..remove(id)) : state.excluded,
          pendingOperations: {
            ...state.pendingOperations,
            action.operationId: AsyncError(_pendingFailure(error), stack),
          },
        );
      }
      return false;
    }
  }

  Future<void> retrySave() => _persist();
  Future<void> _persist() {
    final database = ref.read(appDatabaseProvider);
    final scope = ref.read(storageScopeProvider);
    final generation = _generation;
    final snapshot = state;
    final write = _writes.then((_) async {
      try {
        await database.writeDraft(
          scope: scope,
          key: 'swipe_history_v1',
          value: {
            // Discover server requests always exclude swiped IDs and never
            // hydrate a cached deck. This bounded recent ledger also covers lag.
            'excluded': snapshot.excluded.toList().reversed.take(2000).toList(),
            'unresolvedExcluded': snapshot.unresolvedExcluded.toList(),
            'entries': snapshot.entries.values
                .toList()
                .reversed
                .take(200)
                .map(
                  (entry) => {
                    'property': entry.property.toStorableJson(),
                    'isLiked': entry.isLiked,
                    'pending': entry.phase == SwipePhase.pending,
                    'unresolved': entry.phase == SwipePhase.unresolved,
                    'operationId': entry.operationId,
                    'restored': entry.restored,
                    'queryIdentities': entry.queryIdentities.toList(),
                    'discoverInputIdentity': entry.discoverInputIdentity,
                  },
                )
                .toList(),
          },
        );
        if (ref.mounted && generation == _generation && state.storageError != null) {
          state = state.copyWith(
            entries: state.entries,
            excluded: state.excluded,
            failures: state.failures,
            hydrated: state.hydrated,
            storageError: null,
          );
        }
      } catch (error) {
        if (ref.mounted && generation == _generation) {
          state = state.copyWith(
            entries: state.entries,
            excluded: state.excluded,
            failures: state.failures,
            storageError: error,
            hydrated: state.hydrated,
          );
        }
      }
    });
    _writes = write;
    return write;
  }
}

/// UI rows derive from the server response plus the latest local intent.
/// No feature controller keeps another mutable copy of these collections.
final visiblePropertiesProvider = Provider.family<List<PropertyModel>, PropertyFeed>((ref, feed) {
  final page = ref.watch(propertyQueryProvider(feed));
  final history = ref.watch(swipeHistoryProvider);
  final identity = ref.watch(propertyQueryInputProvider(feed));
  if (feed == PropertyFeed.explore) return page.items;
  if (feed == PropertyFeed.discover) {
    if (!history.hydrated) return const [];
    final restored = history.entries.values
        .where(
          (entry) => entry.restored && identity != null && entry.discoverInputIdentity == identity,
        )
        .map((entry) => entry.property);
    final seen = <int>{};
    return List.unmodifiable(
      [
        ...restored,
        ...page.items,
      ].where((property) => !history.excluded.contains(property.id) && seen.add(property.id)),
    );
  }
  final liked = feed == PropertyFeed.liked;
  final overrides = history.entries;
  final rows = [
    ...overrides.values
        .where(
          (entry) =>
              !entry.restored &&
              entry.isLiked == liked &&
              identity != null &&
              entry.queryIdentities.contains(identity),
        )
        .map((entry) => entry.property),
    ...page.items.where((property) {
      final entry = overrides[property.id];
      return entry == null || (!entry.restored && entry.isLiked == liked);
    }),
  ];
  final seen = <int>{};
  return List.unmodifiable(rows.where((property) => seen.add(property.id)));
});
