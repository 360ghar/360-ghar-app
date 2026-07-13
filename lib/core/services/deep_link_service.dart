import 'dart:async';

import 'package:app_links/app_links.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import 'package:flutter/widgets.dart';
import 'package:get/get.dart';
import 'package:ghar360/core/routes/app_routes.dart';
import 'package:ghar360/core/utils/debug_logger.dart';
import 'package:ghar360/core/utils/error_handler.dart';
import 'package:ghar360/features/auth/data/auth_repository.dart';

class DeepLinkService extends GetxService {
  StreamSubscription? _sub;
  final AppLinks _appLinks = AppLinks();

  @override
  void onInit() {
    super.onInit();
    _initDeepLinks();
  }

  @override
  void onClose() {
    _sub?.cancel();
    super.onClose();
  }

  Future<void> _initDeepLinks() async {
    if (kIsWeb) return;

    try {
      final initialUri = await _appLinks.getInitialLink();
      if (initialUri != null) {
        WidgetsBinding.instance.addPostFrameCallback((_) {
          _handleDeepLink(initialUri);
        });
      }
    } on PlatformException catch (e) {
      DebugLogger.warning('Failed to get initial deep link: $e');
    }

    _sub = _appLinks.uriLinkStream.listen(
      _handleDeepLink,
      onError: (Object err) {
        DebugLogger.error('Deep link stream error: $err');
      },
    );
  }

  void _handleDeepLink(Uri uri) {
    DebugLogger.info('🔗 Received Deep Link: $uri');

    // OAuth redirect (Supabase Google redirect flow): exchange for a session.
    // Supabase is initialized with detectSessionInUri: false, so we do this
    // explicitly here. The onAuthStateChange listener then drives routing.
    if (Get.isRegistered<AuthRepository>()) {
      final authRepository = Get.find<AuthRepository>();
      if (authRepository.isOAuthRedirectUri(uri)) {
        _handleOAuthRedirect(authRepository, uri);
        return;
      }
    }

    // Parse path segments to find property ID
    // Supports:
    // 1. https://the360ghar.com/p/123 (short link from _redirects)
    // 2. https://the360ghar.com/property/123

    String? propertyId;

    if (uri.pathSegments.length >= 2) {
      final firstSegment = uri.pathSegments[0];
      if (firstSegment == 'p' || firstSegment == 'property') {
        propertyId = uri.pathSegments[1];
      }
    }

    if (propertyId != null && propertyId.isNotEmpty) {
      DebugLogger.info('🔗 Navigating to Property ID: $propertyId');
      _navigateToProperty(propertyId);
    } else {
      DebugLogger.warning('🔗 Could not parse Property ID from: $uri');
    }
  }

  Future<void> _handleOAuthRedirect(AuthRepository authRepository, Uri uri) async {
    DebugLogger.info('🔗 Handling OAuth redirect callback');
    try {
      await authRepository.completeOAuthFromUri(uri);
      // Session established; AuthController.onAuthStateChange drives routing.
    } catch (e, st) {
      DebugLogger.error('Failed to complete OAuth redirect', e, st);
      ErrorHandler.handleAuthError(e);
    }
  }

  void _navigateToProperty(String propertyId) {
    // Small delay to ensure UI is ready/transition has settled if coming from cold start
    Future.delayed(const Duration(milliseconds: 500), () {
      // Shared property URLs are deliberately public routes. Navigating to the
      // authenticated details route here caused a cold-start link for a signed
      // out user to be redirected to phone entry, even though
      // `propertyDeepLink` is explicitly available without AuthMiddleware.
      Get.toNamed(propertyDeepLinkPath(propertyId));
    });
  }

  @visibleForTesting
  static String propertyDeepLinkPath(String propertyId) =>
      AppRoutes.propertyDeepLink.replaceFirst(':id', propertyId);

  /// Test-only entry point for URI routing without app_links streams.
  @visibleForTesting
  void handleDeepLinkForTest(Uri uri) => _handleDeepLink(uri);
}
