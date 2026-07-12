import 'package:firebase_analytics/firebase_analytics.dart';

import 'package:ghar360/core/firebase/firebase_initializer.dart';
import 'package:ghar360/core/firebase/remote_config_service.dart';
import 'package:ghar360/core/utils/debug_logger.dart';

class AnalyticsService {
  static final Set<String> _seenProperties = <String>{};
  static const int _maxSeenProperties = 1000;

  static bool get _enabled =>
      FirebaseInitializer.isFirebaseReady && RemoteConfigService.analyticsEnabled;

  static FirebaseAnalytics? get _analytics {
    if (!FirebaseInitializer.isFirebaseReady) return null;
    try {
      return FirebaseAnalytics.instance;
    } catch (e, st) {
      DebugLogger.warning('Analytics instance unavailable', e, st);
      return null;
    }
  }

  static Future<void> setUserId(String? userId) async {
    final analytics = _analytics;
    if (!_enabled || analytics == null) return;
    try {
      await analytics.setUserId(id: userId);
    } catch (e, st) {
      DebugLogger.warning('Analytics setUserId failed', e, st);
    }
  }

  static Future<void> setUserProperty(String name, String value) async {
    final analytics = _analytics;
    if (!_enabled || analytics == null) return;
    try {
      await analytics.setUserProperty(name: name, value: value);
    } catch (e, st) {
      DebugLogger.warning('Analytics setUserProperty failed', e, st);
    }
  }

  static Future<void> logVital(String name, {Map<String, Object>? params}) async {
    final analytics = _analytics;
    if (!_enabled || analytics == null) return;
    try {
      await analytics.logEvent(name: name, parameters: params);
      DebugLogger.debug('📊 Analytics event: $name ${params ?? {}}');
    } catch (e, st) {
      DebugLogger.warning('Analytics logEvent failed', e, st);
    }
  }

  // Suggested canonical events for vital flows
  static Future<void> login({String? method}) =>
      logVital('login', params: method != null ? {'method': method} : null);
  static Future<void> signUp({String? method}) =>
      logVital('sign_up', params: method != null ? {'method': method} : null);
  static Future<void> viewProperty(String propertyId) =>
      logVital('property_view', params: {'id': propertyId});
  static Future<void> viewPropertyOnce(String propertyId) async {
    if (_seenProperties.contains(propertyId)) return;
    if (_seenProperties.length >= _maxSeenProperties && _seenProperties.isNotEmpty) {
      // Maintain a bounded set to avoid unbounded memory growth
      _seenProperties.remove(_seenProperties.first);
    }
    _seenProperties.add(propertyId);
    await viewProperty(propertyId);
  }

  /// Clears session-local de-dupe state (call on logout).
  static void clearSessionState() {
    _seenProperties.clear();
  }

  static Future<void> likeProperty(String propertyId) =>
      logVital('property_like', params: {'id': propertyId});
  static Future<void> scheduleVisit(String propertyId) =>
      logVital('visit_schedule', params: {'id': propertyId});
  static Future<void> applyFilter(Map<String, Object> snapshot) =>
      logVital('filters_apply', params: snapshot);

  // App lifecycle events
  static Future<void> appLaunchComplete({required int durationMs}) =>
      logVital('app_launch_complete', params: {'duration_ms': durationMs});

  static Future<void> firstPropertyLoaded({required int latencyMs}) =>
      logVital('first_property_loaded', params: {'latency_ms': latencyMs});

  // Discover deck events
  static Future<void> deckExhausted({int totalSwiped = 0}) =>
      logVital('deck_exhausted', params: {'total_swiped': totalSwiped});

  // Filter events
  static Future<void> filterApplied({required int activeCount, required String pageType}) =>
      logVital('filter_applied', params: {'active_count': activeCount, 'page_type': pageType});

  // Location events
  static Future<void> locationChanged({required String source}) =>
      logVital('location_changed', params: {'source': source});

  // Auth funnel events
  static Future<void> authPhoneEntered() => logVital('auth_phone_entered');

  static Future<void> authOtpVerified() => logVital('auth_otp_verified');

  static Future<void> authProfileCompleted() => logVital('auth_profile_completed');

  // Deep link analytics
  static Future<void> deepLinkOpenProperty(String propertyId) =>
      logVital('deep_link_open_property', params: {'id': propertyId});
  static Future<void> deepLinkOpenTour({String? propertyId, String? url}) async {
    final params = <String, Object>{};
    if (propertyId != null) params['property_id'] = propertyId;
    if (url != null) params['url'] = url;
    await logVital('deep_link_open_tour', params: params.isEmpty ? null : params);
  }
}
