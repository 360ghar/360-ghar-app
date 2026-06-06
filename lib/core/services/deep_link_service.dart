import 'dart:async';

import 'package:app_links/app_links.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import 'package:flutter/widgets.dart';
import 'package:get/get.dart';
import 'package:ghar360/core/routes/app_routes.dart';
import 'package:ghar360/core/utils/debug_logger.dart';

class DeepLinkService extends GetxService {
  StreamSubscription? _sub;
  final AppLinks _appLinks = AppLinks();

  static const String _propertyBaseUrl = 'https://360ghar.com';

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
      (Uri? uri) {
        if (uri != null) {
          _handleDeepLink(uri);
        }
      },
      onError: (Object err) {
        DebugLogger.error('Deep link stream error: $err');
      },
    );
  }

  void _handleDeepLink(Uri uri) {
    DebugLogger.info('🔗 Received Deep Link: $uri');

    final segments = uri.pathSegments;

    if (segments.isEmpty) {
      DebugLogger.warning('🔗 Deep link has no path segments: $uri');
      return;
    }

    final firstSegment = segments[0];

    if ((firstSegment == 'p' || firstSegment == 'property') && segments.length >= 2) {
      final propertyId = segments[1];
      if (propertyId.isNotEmpty) {
        DebugLogger.info('🔗 Navigating to Property ID: $propertyId');
        _navigateToProperty(propertyId);
      }
    } else if (firstSegment == 'tour' && segments.length >= 2) {
      final tourId = segments[1];
      if (tourId.isNotEmpty) {
        DebugLogger.info('🔗 Navigating to Tour ID: $tourId');
        _navigateToTour(tourId);
      }
    } else {
      DebugLogger.warning('🔗 Could not parse deep link: $uri');
    }
  }

  void _navigateToProperty(String propertyId) {
    Future.delayed(const Duration(milliseconds: 500), () {
      Get.toNamed(AppRoutes.propertyShortLink, parameters: {'id': propertyId});
    });
  }

  void _navigateToTour(String tourId) {
    Future.delayed(const Duration(milliseconds: 500), () {
      final tourUrl = '$_propertyBaseUrl/view/$tourId';
      Get.toNamed(AppRoutes.tour, arguments: tourUrl);
    });
  }

  static String propertyUrl(String propertyId) =>
      '$_propertyBaseUrl/property/$propertyId';

  static String propertyShortUrl(String propertyId) =>
      'https://ghar.sale/p/$propertyId';

  static String tourUrl(String tourId) =>
      '$_propertyBaseUrl/tour/$tourId';
}
