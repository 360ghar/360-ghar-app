import 'dart:convert';

import 'package:flutter/foundation.dart';

import 'package:ghar360/core/data/models/auth_status.dart';
import 'package:ghar360/core/routes/app_routes.dart';
import 'package:ghar360/core/utils/tour_url.dart';

const authEntryPaths = {
  AppRoutes.phoneEntry,
  AppRoutes.login,
  AppRoutes.signup,
  AppRoutes.forgotPassword,
};
const authGatePaths = {AppRoutes.setPassword, AppRoutes.profileCompletion};
const _knownDestinations = {
  AppRoutes.dashboard,
  AppRoutes.discover,
  AppRoutes.explore,
  AppRoutes.likes,
  AppRoutes.visits,
  AppRoutes.profile,
  AppRoutes.propertyDetails,
  AppRoutes.editProfile,
  AppRoutes.tour,
  AppRoutes.preferences,
  AppRoutes.privacy,
  AppRoutes.help,
  AppRoutes.feedback,
  AppRoutes.about,
  AppRoutes.tools,
  AppRoutes.areaConverter,
  AppRoutes.loanEligibility,
  AppRoutes.emiCalculator,
  AppRoutes.carpetArea,
  AppRoutes.documentChecklist,
  AppRoutes.capitalGains,
  AppRoutes.assistant,
};

int? propertyIdFromPath(String path) {
  final match = RegExp(r'^/(?:p|property)/([0-9]+)$').firstMatch(path);
  return positivePropertyId(match?.group(1));
}

/// The largest id every platform holds exactly (2^53 - 1: JavaScript numbers).
const _maxPropertyId = 9007199254740991;

int? positivePropertyId(Object? value) {
  final id = int.tryParse(value?.toString() ?? '');
  return id != null && id > 0 && id <= _maxPropertyId ? id : null;
}

bool isPublicPropertyPath(String path) => propertyIdFromPath(path) != null;

/// Store only validated public media input in the route, so a redirect or cold
/// reconstruction cannot discard an in-memory `extra` payload.
String? tourRouteLocation(String? url, {String? title}) {
  final validated = TourUrl.validate(url);
  if (validated == null || validated.length > 4096) return null;
  final label = title?.trim();
  return Uri(
    path: AppRoutes.tour,
    queryParameters: {
      'url': validated,
      if (label != null && label.isNotEmpty && label.length <= 160) 'title': label,
    },
  ).toString();
}

/// Accept only known internal destinations. Never echo OAuth callback values,
/// auth form identifiers, arbitrary hosts, fragments, or nested return URLs.
String? safeReturnLocation(String? value) {
  if (value == null || !value.startsWith('/') || value.startsWith('//') || value.contains('\\')) {
    return null;
  }
  final uri = Uri.tryParse(value);
  if (uri == null || uri.hasScheme || uri.hasAuthority || uri.fragment.isNotEmpty) return null;
  if (!_knownDestinations.contains(uri.path) &&
      !isPublicPropertyPath(uri.path) &&
      !RegExp(r'^/policy/[a-z-]+$').hasMatch(uri.path)) {
    return null;
  }
  if (uri.path == AppRoutes.tour) {
    return tourRouteLocation(uri.queryParameters['url'], title: uri.queryParameters['title']);
  }
  final query = <String, String>{};
  if (uri.path == AppRoutes.propertyDetails) {
    final id = positivePropertyId(uri.queryParameters['id']);
    if (id == null) return null;
    query['id'] = '$id';
  }
  if (uri.path == AppRoutes.assistant) {
    final conversation = uri.queryParameters['conversation'];
    if (conversation != null && RegExp(r'^[a-zA-Z0-9_-]{1,128}$').hasMatch(conversation)) {
      query['conversation'] = conversation;
    }
  }
  return Uri(path: uri.path, queryParameters: query.isEmpty ? null : query).toString();
}

String routeWithReturn(String path, String? destination) {
  final safe = safeReturnLocation(destination);
  return Uri(path: path, queryParameters: safe == null ? null : {'from': safe}).toString();
}

/// Deterministic redirect policy, independent of navigator timing.
String? authRedirect({
  required AuthStatus status,
  required bool onboardingComplete,
  required Uri location,
}) {
  final path = location.path;
  final public =
      isPublicPropertyPath(path) ||
      (path == AppRoutes.tour && safeReturnLocation(location.toString()) != null);
  final entry = authEntryPaths.contains(path);
  final gate = authGatePaths.contains(path);
  final returnTo = safeReturnLocation(location.queryParameters['from']);
  final destination =
      returnTo ??
      (entry || gate || path == '/' || path == AppRoutes.splash
          ? null
          : safeReturnLocation(location.toString()));
  if (public &&
      (status == AuthStatus.initial ||
          status == AuthStatus.error ||
          status == AuthStatus.unauthenticated)) {
    return null;
  }
  switch (status) {
    case AuthStatus.initial:
    case AuthStatus.error:
      return path == '/' ? null : routeWithReturn('/', destination);
    case AuthStatus.unauthenticated:
      if (!onboardingComplete) {
        return path == AppRoutes.splash ? null : routeWithReturn(AppRoutes.splash, destination);
      }
      return entry ? null : routeWithReturn(AppRoutes.phoneEntry, destination);
    case AuthStatus.requiresPasswordSetup:
      return path == AppRoutes.setPassword
          ? null
          : routeWithReturn(AppRoutes.setPassword, destination);
    case AuthStatus.requiresProfileCompletion:
      return path == AppRoutes.profileCompletion
          ? null
          : routeWithReturn(AppRoutes.profileCompletion, destination);
    case AuthStatus.authenticated:
      if (entry || gate || path == '/' || path == AppRoutes.splash) {
        return returnTo ?? AppRoutes.discover;
      }
      return path == AppRoutes.dashboard ? AppRoutes.discover : null;
  }
}

/// The FCM `data` map of a push from this backend. Every value is a string. `route` is the
/// in-app path to open, `type_key` names the notification type, `_meta` is JSON text
/// (`{type_key, channel, priority}`), and the other keys are data for that type (`property_id`).
@immutable
class PushPayload {
  const PushPayload({this.route, this.typeKey, this.propertyId, this.meta = const {}});

  factory PushPayload.fromData(Map<String, dynamic> data) {
    String? text(String key) {
      final value = data[key];
      return value is String && value.trim().isNotEmpty ? value.trim() : null;
    }

    Map<String, dynamic> meta = const {};
    final rawMeta = data['_meta'];
    if (rawMeta is String) {
      try {
        final decoded = jsonDecode(rawMeta);
        if (decoded is Map) meta = Map<String, dynamic>.from(decoded);
      } on FormatException {
        // `_meta` is context only. A broken one never blocks opening the route.
      }
    }
    return PushPayload(
      route: text('route'),
      typeKey: text('type_key'),
      propertyId: positivePropertyId(data['property_id']),
      meta: Map.unmodifiable(meta),
    );
  }

  final String? route;
  final String? typeKey;
  final int? propertyId;
  final Map<String, dynamic> meta;
}

/// Where a push of a known type opens when it carries no route.
const _typeDestinations = {
  'visit_reminder': AppRoutes.visits,
  'property_recommendation': AppRoutes.discover,
  'daily_digest': AppRoutes.discover,
};

/// Notification payloads can request only known internal routes. The public
/// property route works before sign-in; mutation buttons still require auth.
String? notificationDestination(Map<String, dynamic> payload) {
  final push = PushPayload.fromData(payload);
  final raw = push.route;
  final id = push.propertyId;
  if (raw != null) {
    if (raw == AppRoutes.propertyDetails && id != null) return '/property/$id';
    final route = safeReturnLocation(raw);
    if (route != null) return route;
  }
  if (id != null) return '/property/$id';
  return _typeDestinations[push.typeKey];
}
