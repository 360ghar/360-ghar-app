import 'package:flutter/widgets.dart';

import 'package:get/get.dart';

import 'package:ghar360/core/controllers/auth_controller.dart';
import 'package:ghar360/core/data/models/agent_model.dart';
import 'package:ghar360/core/data/models/property_model.dart';
import 'package:ghar360/core/data/models/visit_model.dart';
import 'package:ghar360/core/firebase/analytics_service.dart';
import 'package:ghar360/core/utils/app_exceptions.dart';
import 'package:ghar360/core/utils/app_toast.dart';
import 'package:ghar360/core/utils/debug_logger.dart';
import 'package:ghar360/features/dashboard/presentation/controllers/dashboard_controller.dart';
import 'package:ghar360/features/visits/data/visits_repository.dart';

class VisitsController extends GetxController {
  static const int _visitPageSize = 25;

  // Resolved lazily on access (not stored in late-final fields) so the
  // controller's lifecycle can never crash with a double-initialization if
  // GetX re-runs onInit() on a cached-but-uninitialized instance.
  VisitsRepository get _visitsRepository => Get.find<VisitsRepository>();
  AuthController get _authController => Get.find<AuthController>();

  final RxList<VisitModel> visits = <VisitModel>[].obs;
  final RxList<VisitModel> upcomingVisitsList = <VisitModel>[].obs;
  final RxList<VisitModel> pastVisitsList = <VisitModel>[].obs;
  final RxBool isLoading = false.obs;
  final RxBool isLoadingMore = false.obs;
  final RxBool isLoadingAgent = false.obs;
  final RxBool isBookingVisit = false.obs;

  /// Failure of the PRIMARY visits-list fetch. The view gates its full-screen
  /// error state on this, so it must never be written by a secondary call —
  /// otherwise a user with zero visits sees a server error instead of the
  /// empty state.
  final Rxn<AppException> error = Rxn<AppException>();

  /// Failure of the SECONDARY relationship-manager fetch. Kept separate from
  /// [error] so the agent card can degrade to "not shown" without masking the
  /// visits list's own state.
  final Rxn<AppException> agentError = Rxn<AppException>();
  final Rxn<AgentModel> relationshipManager = Rxn<AgentModel>();
  final Rxn<String> nextCursor = Rxn<String>();
  final RxBool hasMore = true.obs;
  bool _backgroundRefreshInFlight = false;
  final RxBool isBackgroundRefreshing = false.obs;
  Worker? _authStatusWorker;
  Worker? _tabActivationWorker;

  // Track if data has been loaded to prevent infinite loops
  final RxBool hasLoadedVisits = false.obs;
  final RxBool hasLoadedAgent = false.obs;

  // Track in-flight requests to prevent race conditions
  bool dataLoadInFlight = false;

  @override
  void onInit() {
    super.onInit();

    // Listen to authentication state changes (guarded so a re-entrant onInit
    // can never register duplicate workers).
    _authStatusWorker ??= ever(_authController.authStatus, (authStatus) {
      if (_authController.isAuthenticated) {
        // User is authenticated, safe to fetch data
        _initializeController();
      } else {
        // User logged out, clear all data
        _clearAllData();
      }
    });

    // If already authenticated, initialize immediately
    if (_authController.isAuthenticated) {
      _initializeController();
    }

    // Observe dashboard tab switches to refresh when Visits tab is active
    // (guarded so a re-entrant onInit can never register a duplicate worker).
    if (_tabActivationWorker == null && Get.isRegistered<DashboardController>()) {
      final dash = Get.find<DashboardController>();
      DateTime? lastRefresh;

      const cooldown = Duration(seconds: 30);

      _tabActivationWorker = ever<int>(dash.currentIndex, (idx) async {
        if (idx == 4) {
          final now = DateTime.now();
          // Throttle to avoid spamming refresh
          if (lastRefresh == null || now.difference(lastRefresh!) > cooldown) {
            DebugLogger.info('🔄 Visits tab activated — refreshing (background)');
            await loadVisits(isRefresh: true, silent: true);
            lastRefresh = now;
          } else {
            DebugLogger.info('⏳ Skipping visits refresh due to cooldown');
          }
        }
      });

      // If app starts on Visits tab, ensure data loads quickly
      if (dash.currentIndex.value == 4) {
        WidgetsBinding.instance.addPostFrameCallback((_) {
          if (!hasLoadedVisits.value && !isLoading.value) {
            loadVisitsLazy();
          }
        });
      }
    }
  }

  Future<void> _initializeController() async {
    // Load visits and agent data lazily (guards prevent duplicate requests).
    // Kept sequential: running these concurrently races the per-controller
    // load-guard flags in a way the lazy-loader unit tests rely on, and the
    // single saved round-trip on sign-in is not worth that coupling.
    await loadVisitsLazy();
    await loadRelationshipManagerLazy();
  }

  void _clearAllData() {
    visits.clear();
    upcomingVisitsList.clear();
    pastVisitsList.clear();
    relationshipManager.value = null;
    error.value = null;
    agentError.value = null;
    hasLoadedVisits.value = false;
    hasLoadedAgent.value = false;
  }

  // Lazy loading methods - only fetch when actually needed
  Future<void> loadVisitsLazy() async {
    if (hasLoadedVisits.value || isLoading.value) {
      return; // Prevent duplicate requests.
    }
    hasLoadedVisits.value = true;
    await loadVisits();
    // A failed first load must remain retryable (for pull-to-refresh, tab
    // activation, or a later network recovery).
    if (error.value != null) {
      hasLoadedVisits.value = false;
    }
  }

  Future<void> loadRelationshipManagerLazy() async {
    if (hasLoadedAgent.value || isLoadingAgent.value) {
      return; // Prevent duplicate requests.
    }
    hasLoadedAgent.value = true;
    await loadRelationshipManager();
    if (agentError.value != null) {
      hasLoadedAgent.value = false;
    }
  }

  Future<void> loadVisits({bool isRefresh = false, bool silent = false}) async {
    if (!_authController.isAuthenticated) {
      error.value = AuthenticationException('User not authenticated', code: 'NOT_AUTHENTICATED');
      return;
    }

    // Race condition protection
    if (dataLoadInFlight && !isRefresh) {
      DebugLogger.info('🔁 Visit data load already in flight, skipping duplicate request');
      return;
    }

    try {
      if (isRefresh && !silent) {
        // For pull-to-refresh, clear existing data
        visits.clear();
        upcomingVisitsList.clear();
        pastVisitsList.clear();
      }
      if (silent) {
        if (_backgroundRefreshInFlight) {
          DebugLogger.info('🔁 Background refresh already running, skipping');
          return;
        }
        _backgroundRefreshInFlight = true;
        isBackgroundRefreshing.value = true;
      } else {
        dataLoadInFlight = true;
        isLoading.value = true;
      }
      error.value = null;

      // Reset pagination cursor on initial load / explicit refresh so the
      // cursor loop restarts at page 1.
      nextCursor.value = null;
      hasMore.value = true;

      // Fetch the first page only. Subsequent pages are fetched lazily by
      // [loadMoreVisits] (driven by the scroll listener in VisitsView).
      DebugLogger.info('🔄 Fetching visits page (cursor=first, limit=$_visitPageSize)...');
      final page = await _visitsRepository.fetchVisitsSummary(cursor: null, limit: _visitPageSize);
      nextCursor.value = page.nextCursor;
      hasMore.value = page.hasMore;

      final fetched = page.visits;
      DebugLogger.info(
        '📥 Visits fetched: total=${fetched.length} | '
        'hasMore=${page.hasMore} | nextCursor=${page.nextCursor != null} | '
        'example=${fetched.isNotEmpty ? '{id: ${fetched.first.id}, status: ${fetched.first.status}, date: ${fetched.first.scheduledDate.toIso8601String()}}' : 'none'}',
      );

      _replaceWithPageVisits(fetched);

      // Detailed per-item logs for diagnostics
      if (upcomingVisitsList.isEmpty) {
        DebugLogger.warning('🟡 No upcoming visits after compute');
      } else {
        DebugLogger.info('🟢 Upcoming visits (${upcomingVisitsList.length}):');
        for (final v in upcomingVisitsList) {
          DebugLogger.info(
            '  • id=${v.id} status=${v.status} date=${v.scheduledDate.toIso8601String()}',
          );
        }
      }
      if (pastVisitsList.isEmpty) {
        DebugLogger.warning('🟠 No past visits after compute');
      } else {
        DebugLogger.info('🔵 Past visits (${pastVisitsList.length}):');
        for (final v in pastVisitsList) {
          DebugLogger.info(
            '  • id=${v.id} status=${v.status} date=${v.scheduledDate.toIso8601String()}',
          );
        }
      }

      DebugLogger.success(
        '✅ Visits loaded: ${fetched.length} on first page '
        '(${upcomingVisitsList.length} upcoming, ${pastVisitsList.length} past, '
        'hasMore=${page.hasMore})',
      );
    } catch (e, stackTrace) {
      final appException = e is AppException
          ? e
          : ServerException('Failed to load visits: ${e.toString()}', code: 'LOAD_ERROR');
      error.value = appException;
      DebugLogger.error('❌ Error loading visits: $e', e, stackTrace);
    } finally {
      if (silent) {
        _backgroundRefreshInFlight = false;
        isBackgroundRefreshing.value = false;
      } else {
        dataLoadInFlight = false;
        isLoading.value = false;
      }
    }
  }

  /// Loads the next page of visits using the stored [nextCursor].
  ///
  /// Driven by the scroll listener in [VisitsView]. Idempotent: returns
  /// immediately when a load is already in flight, when there are no more
  /// pages, or when the backend has signalled the terminal page
  /// (`nextCursor == null`).
  Future<void> loadMoreVisits() async {
    if (!_authController.isAuthenticated) return;

    if (isLoading.value || isLoadingMore.value) {
      DebugLogger.info('🔁 Visit load already in flight, skipping loadMoreVisits');
      return;
    }

    if (!hasMore.value) {
      DebugLogger.info('🔚 No more visits pages (hasMore=false)');
      return;
    }

    final cursor = nextCursor.value;
    if (cursor == null || cursor.isEmpty) {
      // Backend signalled terminal page; mark hasMore=false so subsequent
      // scroll events short-circuit without making a network call.
      hasMore.value = false;
      DebugLogger.info('🔚 nextCursor is null while hasMore=true; marking terminal page');
      return;
    }

    try {
      isLoadingMore.value = true;
      error.value = null;

      DebugLogger.info('🔄 Fetching next visits page (cursor=set, limit=$_visitPageSize)...');
      final page = await _visitsRepository.fetchVisitsSummary(
        cursor: cursor,
        limit: _visitPageSize,
      );
      nextCursor.value = page.nextCursor;
      hasMore.value = page.hasMore;

      final fetched = page.visits;
      DebugLogger.info(
        '📥 Visits fetched (loadMore): total=${fetched.length} | '
        'hasMore=${page.hasMore} | nextCursor=${page.nextCursor != null}',
      );

      _mergePageVisits(fetched);

      DebugLogger.success(
        '✅ Loaded more visits: +${fetched.length} '
        '(${upcomingVisitsList.length} upcoming, ${pastVisitsList.length} past, '
        'hasMore=${page.hasMore})',
      );
    } catch (e, stackTrace) {
      final appException = e is AppException
          ? e
          : ServerException('Failed to load more visits: ${e.toString()}', code: 'LOAD_MORE_ERROR');
      error.value = appException;
      DebugLogger.error('❌ Error loading more visits: $e', e, stackTrace);
    } finally {
      isLoadingMore.value = false;
    }
  }

  /// Upcoming visits, soonest first. The single bucket predicate is
  /// [VisitModel.isUpcoming]; "past" is its exact complement, so a visit
  /// always lands in exactly one bucket.
  List<VisitModel> _computeUpcomingVisits(List<VisitModel> source) =>
      source.where((v) => v.isUpcoming).toList()
        ..sort((a, b) => a.scheduledDate.compareTo(b.scheduledDate));

  /// Past visits, most recent first — exact complement of
  /// [_computeUpcomingVisits].
  List<VisitModel> _computePastVisits(List<VisitModel> source) =>
      source.where((v) => !v.isUpcoming).toList()
        ..sort((a, b) => b.scheduledDate.compareTo(a.scheduledDate));

  /// Rebuilds the upcoming/past buckets and re-orders [visits] so the flat
  /// list matches the two derived lists.
  void _rebuildBuckets() {
    final upcoming = _computeUpcomingVisits(visits);
    final past = _computePastVisits(visits);

    upcomingVisitsList.assignAll(upcoming);
    pastVisitsList.assignAll(past);
    visits.assignAll([...upcoming, ...past]);
  }

  /// Replaces the entire visit list with the supplied page. Used by the
  /// initial / refresh path which always starts from the first cursor.
  void _replaceWithPageVisits(List<VisitModel> pageVisits) {
    visits.assignAll(pageVisits);
    _rebuildBuckets();
  }

  /// Merges a paginated page into the existing visit lists, deduplicating by
  /// visit id so cursor rewinds or backend overlaps never produce duplicates.
  void _mergePageVisits(List<VisitModel> pageVisits) {
    if (pageVisits.isEmpty) return;

    final existingIds = visits.map((v) => v.id).toSet();
    final fresh = pageVisits.where((v) => !existingIds.contains(v.id)).toList();
    // Nothing new: the buckets already reflect `visits`, so skipping the
    // rebuild is a no-op, not a missed update.
    if (fresh.isEmpty) return;

    visits.addAll(fresh);
    _rebuildBuckets();
  }

  // Pull-to-refresh method
  Future<void> refreshVisits() async {
    await loadVisits(isRefresh: true);
  }

  Future<void> loadRelationshipManager() async {
    if (!_authController.isAuthenticated) return;

    try {
      isLoadingAgent.value = true;
      agentError.value = null;
      final agentData = await _visitsRepository.fetchRelationshipManager();

      // Use updated AgentModel with simplified fields
      relationshipManager.value = AgentModel(
        id: agentData.id,
        name: agentData.name,
        description: agentData.description,
        avatarUrl: agentData.avatarUrl,
        contactNumber: agentData.contactNumber,
        languages: agentData.languages,
        agentType: agentData.agentType,
        experienceLevel: agentData.experienceLevel,
        isActive: agentData.isActive,
        isAvailable: agentData.isAvailable,
        workingHours: agentData.workingHours,
        totalUsersAssigned: agentData.totalUsersAssigned,
        userSatisfactionRating: agentData.userSatisfactionRating,
        createdAt: agentData.createdAt,
        updatedAt: agentData.updatedAt,
      );

      DebugLogger.success('✅ Agent loaded successfully: ${agentData.name}');
    } catch (e) {
      DebugLogger.error('❌ Error loading agent: $e');
      // Secondary call: never write [error] — the agent card simply stays
      // hidden (relationshipManager remains null) and the visits list keeps
      // its own empty/error state.
      relationshipManager.value = null;
      agentError.value = ServerException('Failed to load agent', code: 'AGENT_LOAD_ERROR');
    } finally {
      isLoadingAgent.value = false;
    }
  }

  Future<bool> bookVisit(
    dynamic property, // Can be PropertyModel or PropertyCardModel
    DateTime visitDateTime, {
    String visitType = 'physical',
    String? notes,
    String contactPreference = 'phone',
    int guestsCount = 1,
  }) async {
    if (!_authController.isAuthenticated) {
      AppToast.warning('auth_required'.tr, 'login_to_book_visit'.tr);
      return false;
    }
    if (isBookingVisit.value) {
      return false;
    }
    if (!visitDateTime.isAfter(DateTime.now())) {
      AppToast.warning('invalid_time'.tr, 'select_future_datetime'.tr);
      return false;
    }

    try {
      isBookingVisit.value = true;
      error.value = null;

      // Reject malformed dynamic input instead of sending property_id=0 or
      // throwing a cast error (int.tryParse never throws).
      final int? propertyId = int.tryParse(property.id.toString());
      if (propertyId == null || propertyId <= 0) {
        AppToast.error('booking_failed'.tr, 'booking_failed_message'.tr);
        return false;
      }
      final String propertyTitle = property is PropertyModel
          ? property.title
          : property.title?.toString() ?? 'Property';

      final visitModel = await _visitsRepository.scheduleVisit(
        propertyId: propertyId,
        scheduledDate: visitDateTime.toUtc().toIso8601String(),
        specialRequirements: notes ?? 'Property visit scheduled through 360ghar app',
      );

      DebugLogger.success('✅ Visit scheduled successfully: ${visitModel.id}');

      // The API returns the complete visit model, no need to reconstruct
      // Just reload visits to get the updated list
      await loadVisits(isRefresh: true, silent: true);

      AppToast.success(
        'visit_scheduled'.tr,
        '${'visit_scheduled_message_prefix'.tr} $propertyTitle ${'visit_scheduled_message_infix'.tr} ${formatVisitDate(visitDateTime)} at ${formatVisitTime(visitDateTime)}',
      );
      await _safeAnalytics(
        'visit_schedule',
        () => AnalyticsService.scheduleVisit(propertyId.toString()),
      );

      return true;
    } catch (e) {
      final appException = e is AppException
          ? e
          : ServerException('Failed to book visit: ${e.toString()}', code: 'BOOKING_ERROR');
      error.value = appException;
      DebugLogger.error('Error booking visit: $e');

      // Repository queues all retryable offline failures, including a missing
      // auth header while the device is offline.
      if (e is AppException && e.isRetryableOffline) {
        AppToast.info('queued_offline'.tr, 'queued_offline_message'.tr);
        return false;
      }

      AppToast.error(
        'booking_failed'.tr,
        'booking_failed_message'.trParams({'error': e.toString()}),
      );

      return false;
    } finally {
      isBookingVisit.value = false;
    }
  }

  // Fallback method for non-authenticated users removed.
  // Previously this fabricated a local VisitModel with userId: 1 and showed
  // a success toast with no server backing, which was lost on refresh.
  // Unauthenticated users are now routed to the real bookVisit() flow,
  // which surfaces an "auth required" toast if not signed in.

  Future<bool> cancelVisit(dynamic visitId, {required String reason}) async {
    if (!_authController.isAuthenticated) {
      AppToast.warning('auth_required'.tr, 'login_to_cancel_visit'.tr);
      return false;
    }

    final visitIdInt = visitId is int ? visitId : int.tryParse(visitId.toString()) ?? 0;
    final visitIndex = visits.indexWhere((visit) => visit.id == visitIdInt);
    if (visitIndex == -1) {
      DebugLogger.warning('Cancel requested for unknown visit id=$visitIdInt');
      AppToast.error('error'.tr, 'could_not_cancel_visit'.tr);
      return false;
    }

    final visit = visits[visitIndex];
    if (!visit.canCancel) {
      DebugLogger.warning('Cancel rejected for visit id=$visitIdInt status=${visit.status}');
      AppToast.error('error'.tr, 'could_not_cancel_visit'.tr);
      return false;
    }

    if (reason.trim().isEmpty) {
      AppToast.warning('reason_required_label'.tr, 'reason_required_hint'.tr);
      return false;
    }

    try {
      if (_authController.isAuthenticated) {
        final ok = await _visitsRepository.cancelVisit(visitIdInt, reason: reason);
        if (!ok) {
          throw Exception('Failed to cancel visit');
        }
      }

      // Reload visits to get updated state from server
      await loadVisits(isRefresh: true, silent: true);

      AppToast.success('visit_cancelled'.tr, 'your_visit_has_been_cancelled'.tr);
      await _safeAnalytics(
        'visit_cancel',
        () => AnalyticsService.logVital('visit_cancel', params: {'id': visitIdInt.toString()}),
      );

      return true;
    } catch (e) {
      DebugLogger.error('Error cancelling visit: $e');
      AppToast.error('error'.tr, 'could_not_cancel_visit'.tr);
      return false;
    }
  }

  Future<bool> rescheduleVisit(dynamic visitId, DateTime newDateTime, {String? reason}) async {
    if (!_authController.isAuthenticated) {
      AppToast.warning('auth_required'.tr, 'login_to_cancel_visit'.tr);
      return false;
    }

    final visitIdInt = visitId is int ? visitId : int.tryParse(visitId.toString()) ?? 0;
    final visitIndex = visits.indexWhere((visit) => visit.id == visitIdInt);
    if (visitIndex == -1) {
      DebugLogger.warning('Reschedule requested for unknown visit id=$visitIdInt');
      AppToast.error('error'.tr, 'could_not_reschedule_visit'.tr);
      return false;
    }

    final visit = visits[visitIndex];
    if (!visit.canReschedule) {
      DebugLogger.warning('Reschedule rejected for visit id=$visitIdInt status=${visit.status}');
      AppToast.error('error'.tr, 'could_not_reschedule_visit'.tr);
      return false;
    }
    if (!newDateTime.isAfter(DateTime.now())) {
      AppToast.warning('invalid_time'.tr, 'select_future_datetime'.tr);
      return false;
    }

    try {
      if (_authController.isAuthenticated) {
        final ok = await _visitsRepository.rescheduleVisit(
          visitIdInt,
          newDate: newDateTime.toUtc().toIso8601String(),
          reason: reason,
        );
        if (!ok) {
          throw Exception('Failed to reschedule visit');
        }
      }

      // Reload visits to get updated state from server
      await loadVisits(isRefresh: true, silent: true);

      AppToast.success(
        'visit_rescheduled'.tr,
        '${'visit_rescheduled_to'.tr} ${formatVisitDate(newDateTime)} ${'at'.tr} ${formatVisitTime(newDateTime)}',
      );
      await _safeAnalytics(
        'visit_reschedule',
        () => AnalyticsService.logVital('visit_reschedule', params: {'id': visitIdInt.toString()}),
      );

      return true;
    } catch (e) {
      DebugLogger.error('Error rescheduling visit: $e');
      AppToast.error('error'.tr, 'could_not_reschedule_visit'.tr);
      return false;
    }
  }

  void markVisitCompleted(dynamic visitId) {
    final visitIdInt = visitId is int ? visitId : int.tryParse(visitId.toString()) ?? 0;
    final visitIndex = visits.indexWhere((visit) => visit.id == visitIdInt);
    if (visitIndex != -1) {
      visits[visitIndex] = visits[visitIndex].copyWith(status: VisitStatus.completed);
      // The status change moves the visit across the upcoming/past boundary.
      _rebuildBuckets();
    }
  }

  Future<void> _safeAnalytics(String event, Future<void> Function() action) async {
    try {
      await action();
    } catch (e, stackTrace) {
      DebugLogger.warning('Analytics call failed for $event', e, stackTrace);
    }
  }

  @override
  void onClose() {
    _authStatusWorker?.dispose();
    _tabActivationWorker?.dispose();
    super.onClose();
  }

  List<VisitModel> get upcomingVisits {
    if (upcomingVisitsList.isNotEmpty || hasLoadedVisits.value) {
      return upcomingVisitsList;
    }
    // Fallback compute — same predicate as _rebuildBuckets().
    return _computeUpcomingVisits(visits);
  }

  List<VisitModel> get pastVisits {
    if (pastVisitsList.isNotEmpty || hasLoadedVisits.value) {
      return pastVisitsList;
    }
    // Fallback compute — exact complement of the upcoming predicate.
    return _computePastVisits(visits);
  }

  String formatVisitDate(DateTime dateTime) {
    final now = DateTime.now();
    final today = DateTime(now.year, now.month, now.day);
    final visitDay = DateTime(dateTime.year, dateTime.month, dateTime.day);
    final difference = visitDay.difference(today).inDays;

    if (difference == 0) {
      return 'today'.tr;
    } else if (difference == 1) {
      return 'tomorrow'.tr;
    } else if (difference == -1) {
      return 'yesterday'.tr;
    } else if (difference > 1) {
      return 'in_n_days'.trParams({'days': '$difference'});
    } else {
      return 'n_days_ago'.trParams({'days': '${difference.abs()}'});
    }
  }

  String formatVisitTime(DateTime dateTime) {
    final hour = dateTime.hour;
    final minute = dateTime.minute;
    final period = hour >= 12 ? 'PM' : 'AM';
    final displayHour = hour > 12 ? hour - 12 : (hour == 0 ? 12 : hour);
    final displayMinute = minute.toString().padLeft(2, '0');

    return '$displayHour:$displayMinute $period';
  }
}
