import 'dart:async';

import 'package:ghar360/core/controllers/offline_queue_service.dart';
import 'package:ghar360/core/data/models/swipe_models.dart';
import 'package:ghar360/core/data/models/unified_filter_model.dart';
import 'package:ghar360/core/data/models/unified_property_response.dart';
import 'package:ghar360/core/data/ports/swipes_port.dart';
import 'package:ghar360/core/network/api_client.dart';
import 'package:ghar360/core/network/api_paths.dart';
import 'package:ghar360/core/network/cache_policy.dart';
import 'package:ghar360/core/network/response_parser.dart';
import 'package:ghar360/core/storage/storage_failure.dart';
import 'package:ghar360/core/utils/app_exceptions.dart';
import 'package:ghar360/core/utils/debug_logger.dart';

class SwipesRepository implements SwipesPort {
  SwipesRepository({required this._apiClient, required this.offlineQueue});
  final ApiClient _apiClient;
  final OfflineQueueService offlineQueue;

  final Map<String, Future<SwipeOutcome>> _pendingRequests = {};

  @override
  Future<SwipeOutcome> recordSwipe({required int propertyId, required bool isLiked}) async {
    if (propertyId <= 0) {
      throw ValidationException('Invalid property.', code: 'INVALID_SWIPE');
    }
    final scope = offlineQueue.scope;
    // Durable latest intent precedes the network. A crash cannot leave an older
    // action eligible for replay after this newer intent was sent.
    final action = await offlineQueue.enqueueSwipe(
      propertyId: propertyId,
      isLiked: isLiked,
      scope: scope,
    );
    return _submit(action, scope);
  }

  @override
  Future<SwipeOutcome> retryPendingSwipe(PendingAction action) {
    final existing = _pendingRequests[action.operationId];
    if (existing != null) return existing;
    final scope = offlineQueue.scope;
    final result = _submit(action, scope);
    _pendingRequests[action.operationId] = result;
    unawaited(
      result.then<void>(
        (_) {
          if (identical(_pendingRequests[action.operationId], result)) {
            _pendingRequests.remove(action.operationId);
          }
        },
        onError: (Object _, StackTrace _) {
          if (identical(_pendingRequests[action.operationId], result)) {
            _pendingRequests.remove(action.operationId);
          }
        },
      ),
    );
    return result;
  }

  Future<PendingAction> _latest(PendingAction expected, StorageScope scope) async {
    if (!identical(scope, offlineQueue.scope) ||
        expected.scopeKey != scope.key ||
        expected.kind != 'swipe') {
      throw NetworkException('Account changed.', code: 'CANCELLED');
    }
    final propertyId = expected.payload['property_id'];
    if (propertyId is! int || propertyId <= 0 || expected.payload['is_liked'] is! bool) {
      throw ValidationException('Invalid saved swipe.', code: 'INVALID_SWIPE');
    }
    final matches = (await offlineQueue.list(scope: scope))
        .where((action) => action.kind == 'swipe' && action.payload['property_id'] == propertyId)
        .toList();
    if (matches.isEmpty ||
        matches.last.operationId != expected.operationId ||
        matches.last.failureCode == 'SUPERSEDED') {
      throw ValidationException('A newer swipe replaced this request.', code: 'SWIPE_SUPERSEDED');
    }
    final current = matches.last;
    if (current.payload['is_liked'] != expected.payload['is_liked']) {
      throw ValidationException('Saved swipe changed.', code: 'INVALID_SWIPE');
    }
    return current;
  }

  Future<SwipeOutcome> _submit(PendingAction expected, StorageScope scope) async {
    final action = await _latest(expected, scope);
    if (action.status == PendingActionStatus.confirmed) {
      return ConfirmedSwipe(operationId: action.operationId);
    }
    await offlineQueue.update(
      action,
      scope: scope,
      status: PendingActionStatus.pending,
      attempted: true,
    );
    // Check again after asynchronous storage work, before sending an old intent.
    await _latest(action, scope);
    if (!identical(scope, offlineQueue.scope)) {
      throw NetworkException('Cancelled.', code: 'CANCELLED');
    }
    SwipeOut? receipt;
    try {
      final response = await _apiClient.post(
        ApiPaths.swipes,
        body: action.payload,
        idempotent: false,
      );
      try {
        receipt = SwipeOut.fromJson(ResponseParser.object(response.body));
      } on Object catch (error, stack) {
        // The server answered 2xx, so the swipe is stored. An unreadable receipt does not undo it.
        DebugLogger.warning('Swipe receipt unreadable', error.runtimeType, stack);
      }
    } catch (error) {
      if (!identical(scope, offlineQueue.scope)) {
        throw NetworkException('Cancelled.', code: 'CANCELLED');
      }
      final failure = error is AppException
          ? error
          : ServerException('Swipe outcome is unknown.', code: 'UNKNOWN');
      final unresolved =
          failure.isRetryableOffline ||
          failure is ServerException ||
          (failure is ApiException && (failure.statusCode == null || failure.statusCode! >= 500));
      final latest = await _latest(action, scope);
      try {
        await offlineQueue.update(
          latest,
          scope: scope,
          status: unresolved ? PendingActionStatus.pending : PendingActionStatus.failed,
          failureCode: failure.code ?? (unresolved ? 'UNRESOLVED' : 'REJECTED'),
        );
      } on StorageFailure {
        if (!identical(scope, offlineQueue.scope)) {
          throw NetworkException('Cancelled.', code: 'CANCELLED');
        }
        if (unresolved) return PendingSwipe(latest);
        rethrow;
      }
      if (!unresolved) throw failure;
      return PendingSwipe(await _latest(action, scope));
    }
    if (!identical(scope, offlineQueue.scope)) {
      throw NetworkException('Cancelled.', code: 'CANCELLED');
    }
    final latest = await _latest(action, scope);
    try {
      await offlineQueue.update(latest, scope: scope, status: PendingActionStatus.confirmed);
    } on StorageFailure {
      if (!identical(scope, offlineQueue.scope)) {
        throw NetworkException('Cancelled.', code: 'CANCELLED');
      }
      // The server reply is known, but its durable receipt is not. Keep the
      // existing operation visible for explicit review instead of inventing a
      // replacement operation or claiming its local confirmation was saved.
      return PendingSwipe(latest);
    }
    return ConfirmedSwipe(operationId: action.operationId, swipe: receipt);
  }

  // Get swipe history properties with comprehensive filtering
  @override
  Future<UnifiedPropertyResponse> getSwipeHistoryProperties({
    required UnifiedFilterModel filters,
    double? latitude,
    double? longitude,
    String? cursor,
    int limit = 50,
    bool? isLiked,
  }) async {
    try {
      DebugLogger.api(
        '📜 Fetching swipe history properties: cursor=${cursor == null ? "first" : "next"}, '
        'limit=$limit, liked=$isLiked, filters=${filters.activeFilterCount} active',
      );

      final queryParams = <String, dynamic>{'limit': limit.clamp(1, 100).toString()};
      // Omit `cursor` on the first page; backend treats absence/null as page 1.
      if (cursor != null && cursor.isNotEmpty) {
        queryParams['cursor'] = cursor;
      }

      if (latitude != null) queryParams['lat'] = latitude.toString();
      if (longitude != null) queryParams['lng'] = longitude.toString();
      if (filters.radiusKm != null) {
        queryParams['radius'] = UnifiedFilterModel.apiRadiusKm(filters.radiusKm!).toString();
      }
      // GET /swipes takes the same filter keys as GET /properties, so every filter applies.
      final canonicalFilterParams = filters.toApiQueryParams();
      canonicalFilterParams.forEach((key, value) {
        if (value == null) return;
        if (value is List) {
          final cleanList = value
              .where((item) => item != null && item.toString().trim().isNotEmpty)
              .map((item) => item.toString().trim())
              .toList();
          if (cleanList.isNotEmpty) {
            queryParams[key] = cleanList;
          }
          return;
        }
        final scalar = value.toString().trim();
        if (scalar.isNotEmpty) {
          queryParams[key] = scalar;
        }
      });
      if (isLiked != null) queryParams['is_liked'] = isLiked.toString();

      DebugLogger.api('🔍 Fetching swipes with ApiClient');
      final apiResponse = await _apiClient.get(
        ApiPaths.swipes,
        queryParams: queryParams,
        useCache: false,
      );
      // A row that cannot be read fails the page, so a partial page never looks complete.
      final UnifiedPropertyResponse unifiedResponse;
      try {
        unifiedResponse = markCachePolicy(
          UnifiedPropertyResponse.fromJson(ResponseParser.object(apiResponse.body)),
          apiResponse.headers,
        );
      } on Object {
        throw ServerException('Invalid swipe history response', code: 'MALFORMED_RESPONSE');
      }

      DebugLogger.success(
        '✅ Loaded ${unifiedResponse.items.length} properties from swipe history '
        '(hasMore=${unifiedResponse.hasMore}, nextCursor=${unifiedResponse.nextCursor != null})',
      );
      return unifiedResponse;
    } on AppException catch (e) {
      DebugLogger.warning('Swipe history failed', e.runtimeType);
      rethrow;
    }
  }
}
