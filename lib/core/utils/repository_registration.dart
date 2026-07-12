import 'package:get/get.dart';
import 'package:ghar360/core/data/ports/properties_port.dart';
import 'package:ghar360/core/data/ports/swipes_port.dart';
import 'package:ghar360/core/network/api_client.dart';
import 'package:ghar360/core/utils/debug_logger.dart';
import 'package:ghar360/features/properties/data/datasources/properties_remote_datasource.dart';
import 'package:ghar360/features/properties/data/properties_repository.dart';
import 'package:ghar360/features/swipes/data/swipes_repository.dart';
import 'package:ghar360/features/visits/data/datasources/visits_remote_datasource.dart';
import 'package:ghar360/features/visits/data/visits_repository.dart';

/// Registers feature repositories as both concrete types and core ports so
/// core controllers can depend on [PropertiesPort]/[SwipesPort] only.
class RepositoryRegistration {
  RepositoryRegistration._();

  static void ensurePropertiesRepository() {
    if (Get.isRegistered<PropertiesRepository>()) {
      _ensurePort<PropertiesPort, PropertiesRepository>();
      return;
    }

    final apiClient = Get.find<ApiClient>();
    final remote = Get.isRegistered<PropertiesRemoteDatasource>()
        ? Get.find<PropertiesRemoteDatasource>()
        : PropertiesRemoteDatasource(apiClient);

    if (!Get.isRegistered<PropertiesRemoteDatasource>()) {
      Get.put<PropertiesRemoteDatasource>(remote, permanent: true);
    }

    final repo = PropertiesRepository(remoteDatasource: remote, apiClient: apiClient);
    Get.put<PropertiesRepository>(repo, permanent: true);
    Get.put<PropertiesPort>(repo, permanent: true);
    DebugLogger.info('✅ PropertiesRepository (+PropertiesPort) registered');
  }

  static void ensureSwipesRepository() {
    if (Get.isRegistered<SwipesRepository>()) {
      _ensurePort<SwipesPort, SwipesRepository>();
      return;
    }

    final apiClient = Get.find<ApiClient>();
    final repo = SwipesRepository(apiClient: apiClient);
    Get.put<SwipesRepository>(repo, permanent: true);
    Get.put<SwipesPort>(repo, permanent: true);
    DebugLogger.info('✅ SwipesRepository (+SwipesPort) registered');
  }

  /// Ensures [VisitsRepository] (and its remote datasource) are registered.
  /// Safe to call from property-details / visits bindings before deferred
  /// [InitialBinding] work finishes.
  static void ensureVisitsRepository() {
    if (Get.isRegistered<VisitsRepository>()) {
      return;
    }

    final apiClient = Get.find<ApiClient>();
    final remote = Get.isRegistered<VisitsRemoteDatasource>()
        ? Get.find<VisitsRemoteDatasource>()
        : VisitsRemoteDatasource(apiClient);

    if (!Get.isRegistered<VisitsRemoteDatasource>()) {
      Get.put<VisitsRemoteDatasource>(remote, permanent: true);
    }

    Get.put<VisitsRepository>(VisitsRepository(remoteDatasource: remote), permanent: true);
    DebugLogger.info('✅ VisitsRepository registered');
  }

  static void _ensurePort<P, R extends P>() {
    if (!Get.isRegistered<P>() && Get.isRegistered<R>()) {
      Get.put<P>(Get.find<R>(), permanent: true);
    }
  }
}
