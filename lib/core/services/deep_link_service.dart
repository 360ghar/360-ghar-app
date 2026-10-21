import 'dart:async';
import 'dart:convert';

import 'package:crypto/crypto.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:ghar360/core/routes/app_routes.dart';
import 'package:ghar360/core/routes/route_policy.dart';
import 'package:ghar360/core/utils/debug_logger.dart';

/// Owns one native link subscription. Navigation does not depend on an elapsed
/// delay; go_router accepts destinations even while the session is resolving.
class DeepLinkService {
  DeepLinkService({
    required this.initialLink,
    required this.links,
    required this.completeOAuth,
    required this.navigate,
    required this.oauthState,
  });
  final Future<Uri?> Function() initialLink;
  final Stream<Uri> links;
  final Future<void> Function(Uri) completeOAuth;
  final void Function(String) navigate;
  final void Function(AsyncValue<void>) oauthState;
  final Set<String> _callbacks = {};
  StreamSubscription<Uri>? _subscription;
  Future<void> _oauthTail = Future.value();
  bool _started = false;
  bool _closed = false;
  int _receivedLinks = 0;

  Future<void> start() async {
    if (_started || _closed) return;
    _started = true;
    _subscription = links.listen(
      (uri) {
        if (isOAuthCallback(uri) || propertyPathForUri(uri) != null) _receivedLinks++;
        unawaited(handle(uri));
      },
      onError: (Object error, StackTrace stack) {
        DebugLogger.warning('Native link stream failed', error.runtimeType, stack);
      },
    );
    try {
      final initialGeneration = _receivedLinks;
      final uri = await initialLink();
      if (uri != null &&
          !_closed &&
          (initialGeneration == _receivedLinks || isOAuthCallback(uri))) {
        await handle(uri);
      }
    } catch (error, stack) {
      DebugLogger.warning('Initial native link failed', error.runtimeType, stack);
    }
  }

  Future<void> handle(Uri uri) async {
    if (_closed) return;
    if (isOAuthCallback(uri)) {
      // Store only a bounded digest, never callback tokens or query parameters.
      final digest = sha256.convert(utf8.encode(uri.toString())).toString();
      if (!_callbacks.add(digest)) return;
      if (_callbacks.length > 32) _callbacks.remove(_callbacks.first);
      _oauthTail = _oauthTail.then((_) async {
        if (_closed) return;
        oauthState(const AsyncLoading());
        try {
          await completeOAuth(uri);
          if (!_closed) oauthState(const AsyncData(null));
        } catch (error, stack) {
          DebugLogger.warning('OAuth callback failed', error.runtimeType, stack);
          if (!_closed) oauthState(AsyncError(error, stack));
        }
      });
      await _oauthTail;
      return;
    }
    final path = propertyPathForUri(uri);
    if (path != null) navigate(path);
  }

  static bool isOAuthCallback(Uri uri) =>
      uri.scheme.toLowerCase() == AppRoutes.oauthRedirectScheme &&
      (uri.host == AppRoutes.oauthRedirectHost ||
          (uri.host.isEmpty && uri.path == '/${AppRoutes.oauthRedirectHost}'));

  /// The in-app property route of a public property link, or null for any other link. A
  /// `ghar360` link reads like an https link: `ghar360://property/42` and `ghar360://p/42`
  /// (the first path segment is the host of a custom scheme), or the https form with the scheme
  /// swapped (`ghar360://360ghar.com/p/42`). `ghar360` is also the OAuth callback scheme; the
  /// callback host (`login-callback`) is never a property path.
  static String? propertyPathForUri(Uri uri) {
    final scheme = uri.scheme.toLowerCase();
    final host = uri.host.toLowerCase();
    if (uri.userInfo.isNotEmpty) return null;
    final String path;
    if (scheme == AppRoutes.oauthRedirectScheme) {
      if (uri.hasPort) return null;
      path = switch (host) {
        '360ghar.com' || 'www.360ghar.com' || '' => uri.path,
        _ => '/$host${uri.path}',
      };
    } else if (scheme == 'https' || scheme == 'http') {
      if (host != '360ghar.com' && host != 'www.360ghar.com') return null;
      if (uri.hasPort && uri.port != 443 && uri.port != 80) return null;
      path = uri.path;
    } else {
      return null;
    }
    final id = propertyIdFromPath(path);
    return id == null ? null : '/property/$id';
  }

  void close() {
    if (_closed) return;
    _closed = true;
    unawaited(_subscription?.cancel());
    _callbacks.clear();
  }
}
