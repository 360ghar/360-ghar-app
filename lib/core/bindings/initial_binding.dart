import 'package:flutter/foundation.dart';
import 'package:flutter/widgets.dart';

import 'package:get/get.dart';

import 'package:ghar360/core/controllers/app_update_controller.dart';
import 'package:ghar360/core/controllers/auth_controller.dart';
import 'package:ghar360/core/controllers/localization_controller.dart';
import 'package:ghar360/core/controllers/location_controller.dart';
import 'package:ghar360/core/controllers/offline_queue_service.dart';
import 'package:ghar360/core/controllers/theme_controller.dart';
import 'package:ghar360/core/network/api_client.dart';
import 'package:ghar360/core/network/auth_header_provider.dart';
import 'package:ghar360/core/network/etag_cache.dart';
import 'package:ghar360/core/network/sse_client.dart';
import 'package:ghar360/core/services/auth_navigation_service.dart';
import 'package:ghar360/core/services/deep_link_service.dart';
import 'package:ghar360/core/services/google_places_service.dart';
import 'package:ghar360/core/utils/debug_logger.dart';
import 'package:ghar360/features/auth/data/auth_repository.dart';
import 'package:ghar360/features/notifications/data/datasources/notifications_remote_datasource.dart';
import 'package:ghar360/features/profile/data/profile_repository.dart';
import 'package:ghar360/features/profile/data/static_page_repository.dart';
import 'package:ghar360/features/properties/data/datasources/properties_remote_datasource.dart';
import 'package:ghar360/features/splash/data/app_update_repository.dart';
import 'package:ghar360/features/swipes/data/datasources/swipes_remote_datasource.dart';
import 'package:ghar360/features/visits/data/datasources/visits_remote_datasource.dart';
import 'package:ghar360/features/visits/data/visits_repository.dart';

class InitialBinding extends Bindings {
  @override
  void dependencies() {
    // ── CRITICAL: Network layer (needed immediately for auth) ──
    Get.put<AuthHeaderProvider>(AuthHeaderProvider(), permanent: true);
    Get.put<ETagCache>(ETagCache(), permanent: true);
    Get.put<ApiClient>(
      ApiClient(authProvider: Get.find<AuthHeaderProvider>(), etagCache: Get.find<ETagCache>()),
      permanent: true,
    );

    // ── SSE client (uses same auth provider) ──
    Get.put<SseClient>(SseClient(authProvider: Get.find<AuthHeaderProvider>()), permanent: true);

    // ── CRITICAL: Auth repository (needed for login) ──
    Get.put<AuthRepository>(AuthRepository(apiClient: Get.find<ApiClient>()), permanent: true);

    // ── CRITICAL: Core controllers only ──
    _initializeCoreControllers();

    // ── DEFER NON-CRITICAL INIT TO POST-FRAME ──
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _initializeDeferredServices();
    });
  }

  void _initializeCoreControllers() {
    // ── CRITICAL: These must be registered BEFORE AuthController ──
    // AuthController has field initializers that synchronously access these
    final apiClient = Get.find<ApiClient>();
    Get.put<ProfileRepository>(ProfileRepository(apiClient: apiClient), permanent: true);
    Get.put<NotificationsRemoteDatasource>(
      NotificationsRemoteDatasource(apiClient),
      permanent: true,
    );

    // ── CRITICAL: GooglePlacesService must be registered BEFORE LocationController ──
    // LocationController accesses it in onInit()
    Get.put<GooglePlacesService>(GooglePlacesService(), permanent: true);

    // ── CRITICAL: AppUpdateRepository must be registered BEFORE AppUpdateController ──
    // AppUpdateController has a field initializer that synchronously accesses it
    Get.put<AppUpdateRepository>(AppUpdateRepository(), permanent: true);

    // Register only essential controllers that don't make API calls on init
    Get.put<AuthController>(AuthController(), permanent: true);
    Get.put<AuthNavigationService>(AuthNavigationService(), permanent: true);
    Get.put<LocationController>(LocationController(), permanent: true);
    Get.put<LocalizationController>(LocalizationController(), permanent: true);
    Get.put<ThemeController>(ThemeController(), permanent: true);
    Get.put<AppUpdateController>(AppUpdateController(), permanent: true);
  }

  void _initializeDeferredServices() {
    DebugLogger.info('🔧 InitialBinding: Initializing deferred services...');

    // ── Datasources (only needed after auth) ──
    final apiClient = Get.find<ApiClient>();
    Get.put<PropertiesRemoteDatasource>(PropertiesRemoteDatasource(apiClient), permanent: true);
    Get.put<VisitsRemoteDatasource>(VisitsRemoteDatasource(apiClient), permanent: true);
    Get.put<SwipesRemoteDatasource>(SwipesRemoteDatasource(apiClient), permanent: true);
    // NotificationsRemoteDatasource is registered in _initializeCoreControllers (before AuthController)

    // ── Other repositories ──
    // AppUpdateRepository is registered in _initializeCoreControllers (before AppUpdateController)
    // ProfileRepository is registered in _initializeCoreControllers (before AuthController)
    Get.put<StaticPageRepository>(StaticPageRepository(apiClient: apiClient), permanent: true);
    Get.put<VisitsRepository>(
      VisitsRepository(remoteDatasource: Get.find<VisitsRemoteDatasource>()),
      permanent: true,
    );

    // ── Services ──
    // GooglePlacesService is registered in _initializeCoreControllers (before LocationController)

    // ── Offline queue (after datasources it depends on) ──
    try {
      Get.put<OfflineQueueService>(
        OfflineQueueService(
          swipesRemoteDatasource: Get.find<SwipesRemoteDatasource>(),
          visitsRemoteDatasource: Get.find<VisitsRemoteDatasource>(),
        ),
        permanent: true,
      ).init();
      DebugLogger.success('✅ OfflineQueueService registered');
    } catch (e) {
      DebugLogger.error('💥 Failed to initialize OfflineQueueService: $e');
    }

    // ── Deep link service ──
    Get.put<DeepLinkService>(DeepLinkService());

    DebugLogger.success('✅ InitialBinding: Deferred services registered');

    // Backend health check only in debug — avoids noisy production probes and
    // accidental /api/v1 prefix mismatches on bare /health URLs.
    if (kDebugMode) {
      Future.delayed(const Duration(seconds: 2), _testBackendConnection);
    }
  }

  void _testBackendConnection() async {
    try {
      if (!Get.isRegistered<ApiClient>()) return;

      final apiClient = Get.find<ApiClient>();
      // Relative path is normalized to /api/v1/health by ApiPaths.
      await apiClient.get(
        '/health',
        useCache: false,
        requireAuth: false,
        notifyUnauthorized: false,
      );
      DebugLogger.success('🎉 Backend connection test successful!');
    } catch (e) {
      DebugLogger.warning('💥 Backend connection test failed: $e');
    }
  }
}
