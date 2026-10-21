import 'dart:async';

import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:ghar360/core/controllers/offline_queue_service.dart';
import 'package:ghar360/core/data/models/agent_model.dart';
import 'package:ghar360/core/data/models/visit_model.dart';
import 'package:ghar360/core/providers/app_database_provider.dart';
import 'package:ghar360/core/providers/network_providers.dart';
import 'package:ghar360/core/utils/app_exceptions.dart';
import 'package:ghar360/features/visits/data/datasources/visits_remote_datasource.dart';
import 'package:ghar360/features/visits/data/visits_repository.dart';

final visitsRepositoryProvider = Provider<VisitsRepository>(
  (ref) => VisitsRepository(
    remoteDatasource: VisitsRemoteDatasource(ref.watch(apiClientProvider)),
    offlineQueue: ref.watch(offlineQueueServiceProvider),
  ),
);
final visitsProvider = NotifierProvider<VisitsController, VisitsState>(VisitsController.new);
final visitClockProvider = Provider<DateTime Function()>((ref) => DateTime.now);

enum VisitLoadPhase { initial, loading, content, refreshing, failed }

enum VisitPagePhase { idle, loading, failed }

class VisitAgentState {
  const VisitAgentState({this.value, this.phase = VisitLoadPhase.loading, this.error});
  final AgentModel? value;
  final VisitLoadPhase phase;
  final AppException? error;
  bool get isLoading => phase == VisitLoadPhase.loading || phase == VisitLoadPhase.refreshing;
  bool get hasValue => value != null;
  bool get hasError => error != null;
}

class VisitsState {
  VisitsState({
    List<VisitModel> visits = const [],
    this.phase = VisitLoadPhase.initial,
    this.failure,
    this.nextCursor,
    this.pagePhase = VisitPagePhase.idle,
    this.pageFailure,
    this.stale = false,
    this.agent = const VisitAgentState(),
    this.booking = const AsyncData(null),
    Map<int, AsyncValue<bool>> mutations = const {},
  }) : visits = List.unmodifiable(visits),
       mutations = Map.unmodifiable(mutations);
  final List<VisitModel> visits;
  final VisitLoadPhase phase;
  final AppException? failure;
  final String? nextCursor;
  final VisitPagePhase pagePhase;
  final AppException? pageFailure;
  final bool stale;
  final VisitAgentState agent;
  final AsyncValue<VisitRequestResult?> booking;
  final Map<int, AsyncValue<bool>> mutations;
  bool get hasMore => nextCursor != null;
  bool get isLoading => phase == VisitLoadPhase.loading || phase == VisitLoadPhase.initial;
  bool get isRefreshing => phase == VisitLoadPhase.refreshing;
  List<VisitModel> get upcoming => List.unmodifiable(
    visits.where((v) => v.isUpcoming).toList()
      ..sort((a, b) => a.scheduledDate.compareTo(b.scheduledDate)),
  );
  List<VisitModel> get past => List.unmodifiable(
    visits.where((v) => !v.isUpcoming).toList()
      ..sort((a, b) => b.scheduledDate.compareTo(a.scheduledDate)),
  );

  VisitsState copyWith({
    List<VisitModel>? visits,
    VisitLoadPhase? phase,
    AppException? failure,
    bool clearFailure = false,
    String? nextCursor,
    bool clearCursor = false,
    VisitPagePhase? pagePhase,
    AppException? pageFailure,
    bool clearPageFailure = false,
    bool? stale,
    VisitAgentState? agent,
    AsyncValue<VisitRequestResult?>? booking,
    Map<int, AsyncValue<bool>>? mutations,
  }) => VisitsState(
    visits: visits ?? this.visits,
    phase: phase ?? this.phase,
    failure: clearFailure ? null : failure ?? this.failure,
    nextCursor: clearCursor ? null : nextCursor ?? this.nextCursor,
    pagePhase: pagePhase ?? this.pagePhase,
    pageFailure: clearPageFailure ? null : pageFailure ?? this.pageFailure,
    stale: stale ?? this.stale,
    agent: agent ?? this.agent,
    booking: booking ?? this.booking,
    mutations: mutations ?? this.mutations,
  );
}

class VisitsController extends Notifier<VisitsState> {
  int _generation = 0;
  int _listRequest = 0;
  bool _listInFlight = false;
  bool _agentInFlight = false;
  final _seenCursors = <String>{};
  @override
  VisitsState build() {
    final scope = ref.watch(storageScopeProvider);
    ref.watch(visitsRepositoryProvider);
    final generation = ++_generation;
    _listInFlight = false;
    _agentInFlight = false;
    _seenCursors.clear();
    ref.onDispose(() {
      _generation++;
    });
    if (scope.accountId != null) {
      Future.microtask(() async {
        if (!_active(generation)) return;
        await Future.wait([_restoreAndLoad(generation, scope), loadRelationshipManager()]);
      });
      return VisitsState();
    }
    return VisitsState(
      phase: VisitLoadPhase.content,
      agent: const VisitAgentState(phase: VisitLoadPhase.content),
    );
  }

  bool _active(int generation) => ref.mounted && generation == _generation;
  bool get _signedIn => ref.read(storageScopeProvider).accountId != null;
  AppException _failure(Object error) => error is AppException
      ? error
      : ServerException('The request could not be completed.', code: 'VISITS_FAILED');

  Future<void> _restoreAndLoad(int generation, StorageScope scope) async {
    final database = ref.read(appDatabaseProvider);
    try {
      final cache = await database.readCache(scope: scope, key: 'visits:first');
      if (_active(generation) && cache?.value is List) {
        final visits = (cache!.value! as List)
            .map((value) => VisitModel.fromJson(Map<String, dynamic>.from(value as Map)))
            .toList();
        state = state.copyWith(visits: visits, phase: VisitLoadPhase.content, stale: true);
      }
    } catch (_) {
      /* Optional cache failure does not hide network recovery. */
    }
    if (_active(generation)) await loadVisits();
  }

  Future<void> loadVisits() async {
    if (!_signedIn || _listInFlight) return;
    _listInFlight = true;
    final generation = _generation;
    final request = ++_listRequest;
    final scope = ref.read(storageScopeProvider);
    final repository = ref.read(visitsRepositoryProvider);
    final database = ref.read(appDatabaseProvider);
    state = state.copyWith(
      phase: state.visits.isEmpty ? VisitLoadPhase.loading : VisitLoadPhase.refreshing,
      clearFailure: true,
      pagePhase: VisitPagePhase.idle,
      clearPageFailure: true,
    );
    try {
      final page = await repository.fetchVisitsSummary(limit: 25);
      if (!_active(generation) || request != _listRequest) return;
      _seenCursors.clear();
      final cursor = page.hasMore && (page.nextCursor?.isNotEmpty ?? false)
          ? page.nextCursor
          : null;
      state = state.copyWith(
        visits: _deduplicate(page.visits),
        phase: VisitLoadPhase.content,
        nextCursor: cursor,
        clearCursor: cursor == null,
        stale: false,
      );
      _listInFlight = false;
      try {
        final now = ref.read(visitClockProvider)();
        await database.writeCache(
          scope: scope,
          key: 'visits:first',
          value: page.visits.map((visit) => visit.toJson()).toList(),
          freshUntil: now.add(const Duration(minutes: 5)),
          expiresAt: now.add(const Duration(days: 7)),
        );
      } catch (_) {
        /* Fresh server content remains usable if cache persistence fails. */
      }
    } catch (error) {
      if (_active(generation) && request == _listRequest) {
        state = state.copyWith(
          phase: state.visits.isEmpty ? VisitLoadPhase.failed : VisitLoadPhase.content,
          failure: _failure(error),
          stale: state.visits.isNotEmpty,
        );
      }
    } finally {
      if (_active(generation) && request == _listRequest) _listInFlight = false;
    }
  }

  Future<void> refreshVisits() => loadVisits();
  Future<void> loadMoreVisits() async {
    final cursor = state.nextCursor;
    if (!_signedIn ||
        _listInFlight ||
        state.pagePhase == VisitPagePhase.loading ||
        cursor == null) {
      return;
    }
    final generation = _generation;
    final request = _listRequest;
    state = state.copyWith(pagePhase: VisitPagePhase.loading, clearPageFailure: true);
    try {
      final page = await ref
          .read(visitsRepositoryProvider)
          .fetchVisitsSummary(cursor: cursor, limit: 25);
      if (!_active(generation) || request != _listRequest) return;
      _seenCursors.add(cursor);
      final next =
          page.hasMore &&
              (page.nextCursor?.isNotEmpty ?? false) &&
              !_seenCursors.contains(page.nextCursor)
          ? page.nextCursor
          : null;
      state = state.copyWith(
        visits: _deduplicate([...state.visits, ...page.visits]),
        pagePhase: VisitPagePhase.idle,
        nextCursor: next,
        clearCursor: next == null,
      );
    } catch (error) {
      if (_active(generation) && request == _listRequest) {
        state = state.copyWith(pagePhase: VisitPagePhase.failed, pageFailure: _failure(error));
      }
    }
  }

  List<VisitModel> _deduplicate(List<VisitModel> values) {
    final seen = <int>{};
    return values.where((visit) => seen.add(visit.id)).toList();
  }

  Future<void> loadRelationshipManager() async {
    if (!_signedIn || _agentInFlight) return;
    _agentInFlight = true;
    final generation = _generation;
    state = state.copyWith(
      agent: VisitAgentState(value: state.agent.value, phase: VisitLoadPhase.refreshing),
    );
    try {
      final agent = await ref.read(visitsRepositoryProvider).fetchRelationshipManager();
      if (_active(generation)) {
        state = state.copyWith(
          agent: VisitAgentState(value: agent, phase: VisitLoadPhase.content),
        );
      }
    } catch (error) {
      if (_active(generation)) {
        state = state.copyWith(
          agent: VisitAgentState(
            value: state.agent.value,
            phase: VisitLoadPhase.failed,
            error: _failure(error),
          ),
        );
      }
    } finally {
      if (_active(generation)) _agentInFlight = false;
    }
  }

  Future<VisitRequestResult> bookVisit(int propertyId, DateTime date, {String? notes}) async {
    if (!_signedIn) {
      return VisitFailed(
        AuthenticationException('Sign in to continue.', code: 'NOT_AUTHENTICATED'),
      );
    }
    if (state.booking.isLoading) {
      return VisitFailed(
        ValidationException('Request already in progress.', code: 'DUPLICATE_REQUEST'),
      );
    }
    if (propertyId <= 0 || !date.isAfter(ref.read(visitClockProvider)())) {
      final result = VisitFailed(
        ValidationException('Select a future date and time.', code: 'INVALID_VISIT_DATE'),
      );
      state = state.copyWith(booking: AsyncData(result));
      return result;
    }
    final generation = _generation;
    state = state.copyWith(booking: const AsyncLoading());
    VisitRequestResult result;
    try {
      result = await ref
          .read(visitsRepositoryProvider)
          .scheduleVisit(
            propertyId: propertyId,
            scheduledDate: date.toUtc().toIso8601String(),
            specialRequirements: notes,
          );
    } catch (error) {
      result = VisitFailed(_failure(error));
    }
    if (!_active(generation)) {
      return VisitFailed(NetworkException('Account changed.', code: 'CANCELLED'));
    }
    state = state.copyWith(booking: AsyncData(result));
    if (result is VisitConfirmed) {
      state = state.copyWith(visits: _deduplicate([result.visit, ...state.visits]));
      unawaited(loadVisits());
    }
    return result;
  }

  /// The cancel reason is required: 1 to 1000 characters after trimming.
  Future<bool> cancelVisit(int visitId, {required String reason}) => _mutate(
    visitId,
    allowed: (visit) =>
        visit.canCancel && reason.trim().isNotEmpty && reason.trim().length <= _maxReasonLength,
    action: (repository) => repository.cancelVisit(visitId, reason: reason.trim()),
  );
  Future<bool> rescheduleVisit(int visitId, DateTime date, {String? reason}) => _mutate(
    visitId,
    allowed: (visit) => visit.canReschedule && date.isAfter(ref.read(visitClockProvider)()),
    action: (repository) => repository.rescheduleVisit(
      visitId,
      newDate: date.toUtc().toIso8601String(),
      reason: reason,
    ),
  );
  static const _maxReasonLength = 1000;
  Future<bool> _mutate(
    int id, {
    required bool Function(VisitModel) allowed,
    required Future<VisitModel> Function(VisitsRepository) action,
  }) async {
    if (!_signedIn || state.mutations[id]?.isLoading == true) return false;
    final matches = state.visits.where((visit) => visit.id == id);
    if (matches.isEmpty || !allowed(matches.first)) {
      state = state.copyWith(
        mutations: {
          ...state.mutations,
          id: AsyncError(
            ValidationException('Check the visit details.', code: 'INVALID_VISIT_CHANGE'),
            StackTrace.current,
          ),
        },
      );
      return false;
    }
    final generation = _generation;
    state = state.copyWith(mutations: {...state.mutations, id: const AsyncLoading()});
    try {
      // Both routes answer with the updated Visit: show it now, then reload the list.
      final updated = await action(ref.read(visitsRepositoryProvider));
      if (!_active(generation)) return false;
      state = state.copyWith(
        visits: [
          for (final visit in state.visits)
            if (visit.id == updated.id)
              updated.copyWith(property: updated.property ?? visit.property)
            else
              visit,
        ],
        mutations: {...state.mutations, id: const AsyncData(true)},
      );
      unawaited(loadVisits());
      return true;
    } catch (error, stack) {
      if (_active(generation)) {
        state = state.copyWith(
          mutations: {...state.mutations, id: AsyncError(_failure(error), stack)},
        );
      }
      return false;
    }
  }

  Future<bool> reconcile(PendingAction action) async {
    final generation = _generation;
    final visit = await ref.read(visitsRepositoryProvider).reconcile(action);
    if (!_active(generation)) return false;
    if (visit != null) state = state.copyWith(visits: _deduplicate([visit, ...state.visits]));
    return visit != null;
  }
}
