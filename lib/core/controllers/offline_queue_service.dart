import 'dart:async';

import 'package:connectivity_plus/connectivity_plus.dart';
import 'package:get/get.dart';
import 'package:get_storage/get_storage.dart';

import 'package:ghar360/core/controllers/offline_action.dart';
import 'package:ghar360/core/utils/app_exceptions.dart';
import 'package:ghar360/core/utils/debug_logger.dart';
import 'package:ghar360/features/swipes/data/datasources/swipes_remote_datasource.dart';
import 'package:ghar360/features/visits/data/datasources/visits_remote_datasource.dart';

/// Maximum number of actions the queue will hold. Oldest actions are
/// dropped when the limit is exceeded during enqueue.
const maxOfflineQueueSize = 100;

/// Maximum number of retry attempts per action before it is dropped.
const maxOfflineRetries = 5;

/// Actions older than this duration are considered stale and dropped.
const maxOfflineActionAge = Duration(hours: 24);

/// Persistence seam for [OfflineQueueService] (GetStorage in prod, in-memory in tests).
abstract class OfflineQueueStorage {
  List<dynamic>? readList(String key);
  void writeList(String key, List<dynamic> value);
  void remove(String key);
}

/// Default [OfflineQueueStorage] backed by [GetStorage].
class GetStorageOfflineQueueStorage implements OfflineQueueStorage {
  GetStorageOfflineQueueStorage([GetStorage? storage]) : _storage = storage ?? GetStorage();

  final GetStorage _storage;

  @override
  List<dynamic>? readList(String key) => _storage.read<List<dynamic>>(key);

  @override
  void writeList(String key, List<dynamic> value) => _storage.write(key, value);

  @override
  void remove(String key) => _storage.remove(key);
}

/// In-memory store for unit tests (no path_provider / plugin required).
class InMemoryOfflineQueueStorage implements OfflineQueueStorage {
  final Map<String, List<dynamic>> _data = {};

  @override
  List<dynamic>? readList(String key) {
    final value = _data[key];
    return value == null ? null : List<dynamic>.from(value);
  }

  @override
  void writeList(String key, List<dynamic> value) {
    _data[key] = List<dynamic>.from(value);
  }

  @override
  void remove(String key) => _data.remove(key);
}

/// Lightweight queue for deferring network actions when offline.
///
/// Stores typed [OfflineAction]s and retries when connectivity returns.
/// Dependencies are constructor-injectable for unit tests.
///
/// All mutations ([enqueueSwipe]/[enqueueVisit]/[processQueue], [clearQueue])
/// are serialized on a single chain so a flush cannot overwrite concurrent
/// enqueues, and a logout clear cannot be undone by a late `_saveQueue`.
class OfflineQueueService extends GetxService {
  static const storageKey = 'offline_action_queue';

  static const _connectedResults = {
    ConnectivityResult.mobile,
    ConnectivityResult.wifi,
    ConnectivityResult.ethernet,
    ConnectivityResult.vpn,
  };

  OfflineQueueService({
    OfflineQueueStorage? storage,
    SwipesRemoteDatasource? swipesRemoteDatasource,
    VisitsRemoteDatasource? visitsRemoteDatasource,
    this.connectivityStream,
  }) : _storage = storage ?? GetStorageOfflineQueueStorage(),
       _swipesRemoteDatasource = swipesRemoteDatasource ?? Get.find<SwipesRemoteDatasource>(),
       _visitsRemoteDatasource = visitsRemoteDatasource ?? Get.find<VisitsRemoteDatasource>();

  final OfflineQueueStorage _storage;
  final SwipesRemoteDatasource _swipesRemoteDatasource;
  final VisitsRemoteDatasource _visitsRemoteDatasource;

  /// Optional test seam; production uses [Connectivity.onConnectivityChanged].
  final Stream<List<ConnectivityResult>>? connectivityStream;

  StreamSubscription? _connectivitySub;

  /// Serializes enqueue / process / clear so read-modify-write cannot race.
  Future<void> _mutex = Future<void>.value();

  /// Bumped on [clearQueue]. [processQueue] aborts `_saveQueue` if this changes
  /// mid-flush (e.g. logout while replaying).
  int _generation = 0;

  /// Number of actions currently stored (for tests/metrics).
  int get queueLength => _getQueue().length;

  Future<OfflineQueueService> init() async {
    final stream = connectivityStream ?? Connectivity().onConnectivityChanged;
    _connectivitySub = stream.listen(
      (event) async {
        await _handleConnectivityEvent(event);
      },
      onError: (Object e, StackTrace st) {
        DebugLogger.warning('OfflineQueue connectivity stream error: $e');
      },
    );

    // Await so cold-start flush finishes before callers assume the queue is idle.
    await processQueue();
    return this;
  }

  @override
  void onClose() {
    _connectivitySub?.cancel();
    super.onClose();
  }

  Future<void> enqueueSwipe({required int propertyId, required bool isLiked}) async {
    await _enqueue(
      OfflineSwipeAction(propertyId: propertyId, isLiked: isLiked, timestamp: DateTime.now()),
    );
    DebugLogger.info('🕓 Queued swipe action for property $propertyId');
  }

  Future<void> enqueueVisit({
    required int propertyId,
    required String scheduledDate,
    String? specialRequirements,
  }) async {
    await _enqueue(
      OfflineVisitAction(
        propertyId: propertyId,
        scheduledDate: scheduledDate,
        specialRequirements: specialRequirements,
        timestamp: DateTime.now(),
      ),
    );
    DebugLogger.info('🕓 Queued visit booking for property $propertyId');
  }

  Future<void> processQueue() async {
    await _runExclusive(() async {
      final generation = _generation;
      final queue = _getQueue();
      if (queue.isEmpty) return;

      final now = DateTime.now();
      queue.removeWhere((action) {
        if (now.difference(action.timestamp) > maxOfflineActionAge) {
          DebugLogger.warning(
            '🗑️ Dropping stale offline action '
            '(type=${action.type}, age=${now.difference(action.timestamp).inHours}h)',
          );
          return true;
        }
        return false;
      });

      DebugLogger.info('🔁 Processing ${queue.length} offline actions...');
      final remaining = <OfflineAction>[];

      for (var i = 0; i < queue.length; i++) {
        if (generation != _generation) {
          DebugLogger.info('🗑️ Offline queue cleared mid-flush — aborting processQueue');
          return;
        }

        final action = queue[i];

        if (action.retries >= maxOfflineRetries) {
          DebugLogger.warning(
            '🗑️ Dropping offline action after $maxOfflineRetries retries '
            '(type=${action.type})',
          );
          continue;
        }

        try {
          await _processAction(action);
        } on NetworkException catch (e, st) {
          DebugLogger.warning(
            '🌐 Network error while replaying "${action.type}" — '
            'keeping in queue (retry ${action.retries + 1}/$maxOfflineRetries)',
            e,
            st,
          );
          remaining.add(action.copyWithRetries(action.retries + 1));
          remaining.addAll(queue.sublist(i + 1));
          break;
        } on AppException catch (e, st) {
          DebugLogger.error(
            '❌ Non-network error on queued "${action.type}" — '
            'dropping action: ${e.message}',
            e,
            st,
          );
        } catch (e, st) {
          DebugLogger.error(
            '❌ Unexpected error processing offline "${action.type}" '
            '(retry ${action.retries + 1}/$maxOfflineRetries): $e',
            e,
            st,
          );
          // Fail-fast: keep failed item + unprocessed tail so concurrent
          // enqueues (serialized after us) are not mixed with a partial flush.
          remaining.add(action.copyWithRetries(action.retries + 1));
          remaining.addAll(queue.sublist(i + 1));
          break;
        }
      }

      if (generation != _generation) {
        DebugLogger.info('🗑️ Offline queue cleared mid-flush — skipping save');
        return;
      }

      _saveQueue(remaining);
      final processed = queue.length - remaining.length;
      if (processed > 0) {
        DebugLogger.success('📤 Flushed $processed queued action(s)');
      }
    });
  }

  Future<void> _processAction(OfflineAction action) async {
    switch (action) {
      case OfflineSwipeAction(:final propertyId, :final isLiked):
        await _swipesRemoteDatasource.swipeProperty(propertyId: propertyId, isLiked: isLiked);
        DebugLogger.success('✅ Replayed swipe for property $propertyId');
      case OfflineVisitAction(:final propertyId, :final scheduledDate, :final specialRequirements):
        await _visitsRemoteDatasource.scheduleVisit(
          propertyId: propertyId,
          scheduledDate: scheduledDate,
          specialRequirements: specialRequirements,
        );
        DebugLogger.success('✅ Replayed visit booking for $propertyId');
    }
  }

  Future<void> _enqueue(OfflineAction action) async {
    await _runExclusive(() async {
      // Snapshot generation so a concurrent clearQueue (logout) cannot be
      // undone by writing a stale in-memory list back to storage.
      final generation = _generation;
      final list = _getQueue();
      list.add(action);

      while (list.length > maxOfflineQueueSize) {
        final dropped = list.removeAt(0);
        DebugLogger.warning(
          '🗑️ Queue full ($maxOfflineQueueSize) — dropping oldest action '
          '(type=${dropped.type})',
        );
      }

      if (generation != _generation) {
        DebugLogger.info('🗑️ Offline queue cleared mid-enqueue — skipping save');
        return;
      }

      _saveQueue(list);
    });
  }

  List<OfflineAction> _getQueue() {
    final raw = _storage.readList(storageKey) ?? <dynamic>[];
    final actions = <OfflineAction>[];
    for (final e in raw) {
      if (e is! Map) continue;
      final map = Map<String, dynamic>.from(e);
      final parsed = OfflineAction.tryParse(map);
      if (parsed != null) {
        actions.add(parsed);
      } else {
        DebugLogger.warning('🗑️ Dropping unparseable offline action: $map');
      }
    }
    return actions;
  }

  void _saveQueue(List<OfflineAction> queue) {
    _storage.writeList(storageKey, queue.map((a) => a.toJson()).toList());
  }

  /// Drops all queued actions (call on logout to avoid cross-user replay).
  ///
  /// Bumps generation immediately so in-flight [processQueue]/[_enqueue]
  /// abort their saves, then removes storage. The exclusive chain is also
  /// scheduled so any enqueue that was already waiting on the mutex still
  /// observes an empty queue after it acquires the lock.
  void clearQueue() {
    _generation++;
    _storage.remove(storageKey);
    DebugLogger.info('🗑️ Offline action queue cleared');
    // Best-effort: re-clear after any in-flight exclusive work finishes.
    unawaited(
      _runExclusive(() async {
        _storage.remove(storageKey);
      }),
    );
  }

  Future<void> _handleConnectivityEvent(List<ConnectivityResult> results) async {
    final hasConnection = results.any(_connectedResults.contains);
    if (hasConnection) {
      DebugLogger.info('📶 Connectivity restored — attempting to flush queue');
      await processQueue();
    }
  }

  /// Runs [action] after all prior exclusive work, keeping the chain alive on error.
  Future<T> _runExclusive<T>(Future<T> Function() action) {
    final completer = Completer<T>();
    _mutex = _mutex
        .then((_) async {
          try {
            completer.complete(await action());
          } catch (e, st) {
            completer.completeError(e, st);
          }
        })
        .catchError((Object _) {
          // Keep the mutex chain from permanently failing.
        });
    return completer.future;
  }
}
