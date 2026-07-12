import 'package:flutter_test/flutter_test.dart';
import 'package:get/get.dart';

import 'package:ghar360/core/data/ports/properties_port.dart';
import 'package:ghar360/core/data/ports/swipes_port.dart';
import 'package:ghar360/core/network/api_client.dart';
import 'package:ghar360/core/utils/repository_registration.dart';
import 'package:ghar360/features/properties/data/datasources/properties_remote_datasource.dart';
import 'package:ghar360/features/properties/data/properties_repository.dart';
import 'package:ghar360/features/swipes/data/swipes_repository.dart';
import 'package:ghar360/features/visits/data/datasources/visits_remote_datasource.dart';
import 'package:ghar360/features/visits/data/visits_repository.dart';

import '../../helpers/getx_test_binding.dart';
import '../../helpers/mocks.dart';

void main() {
  setUp(() {
    GetxTestBinding.init();
    // RepositoryRegistration resolves ApiClient via Get.find<ApiClient>().
    GetxTestBinding.bind().register<ApiClient>(MockApiClient());
  });

  tearDown(() {
    GetxTestBinding.reset();
  });

  group('RepositoryRegistration.ensurePropertiesRepository', () {
    test('registers PropertiesRepository in the GetX container', () {
      RepositoryRegistration.ensurePropertiesRepository();

      expect(Get.isRegistered<PropertiesRepository>(), isTrue);
    });

    test('registers PropertiesPort in the GetX container', () {
      RepositoryRegistration.ensurePropertiesRepository();

      expect(Get.isRegistered<PropertiesPort>(), isTrue);
    });

    test('registers PropertiesRemoteDatasource in the GetX container', () {
      RepositoryRegistration.ensurePropertiesRepository();

      expect(Get.isRegistered<PropertiesRemoteDatasource>(), isTrue);
    });

    test('the registered PropertiesPort is the same instance as PropertiesRepository', () {
      RepositoryRegistration.ensurePropertiesRepository();

      final repo = Get.find<PropertiesRepository>();
      final port = Get.find<PropertiesPort>();

      expect(identical(repo, port), isTrue);
    });

    test('is idempotent — calling twice does not throw', () {
      RepositoryRegistration.ensurePropertiesRepository();

      expect(
        () => RepositoryRegistration.ensurePropertiesRepository(),
        returnsNormally,
      );
    });

    test('is idempotent — PropertiesRepository remains registered after second call', () {
      RepositoryRegistration.ensurePropertiesRepository();
      RepositoryRegistration.ensurePropertiesRepository();

      expect(Get.isRegistered<PropertiesRepository>(), isTrue);
      expect(Get.isRegistered<PropertiesPort>(), isTrue);
    });
  });

  group('RepositoryRegistration.ensureSwipesRepository', () {
    test('registers SwipesRepository in the GetX container', () {
      RepositoryRegistration.ensureSwipesRepository();

      expect(Get.isRegistered<SwipesRepository>(), isTrue);
    });

    test('registers SwipesPort in the GetX container', () {
      RepositoryRegistration.ensureSwipesRepository();

      expect(Get.isRegistered<SwipesPort>(), isTrue);
    });

    test('the registered SwipesPort is the same instance as SwipesRepository', () {
      RepositoryRegistration.ensureSwipesRepository();

      final repo = Get.find<SwipesRepository>();
      final port = Get.find<SwipesPort>();

      expect(identical(repo, port), isTrue);
    });

    test('is idempotent — calling twice does not throw', () {
      RepositoryRegistration.ensureSwipesRepository();

      expect(
        () => RepositoryRegistration.ensureSwipesRepository(),
        returnsNormally,
      );
    });

    test('is idempotent — SwipesRepository remains registered after second call', () {
      RepositoryRegistration.ensureSwipesRepository();
      RepositoryRegistration.ensureSwipesRepository();

      expect(Get.isRegistered<SwipesRepository>(), isTrue);
      expect(Get.isRegistered<SwipesPort>(), isTrue);
    });
  });

  group('RepositoryRegistration.ensureVisitsRepository', () {
    test('registers VisitsRepository and VisitsRemoteDatasource', () {
      RepositoryRegistration.ensureVisitsRepository();

      expect(Get.isRegistered<VisitsRepository>(), isTrue);
      expect(Get.isRegistered<VisitsRemoteDatasource>(), isTrue);
    });

    test('is idempotent — calling twice does not throw', () {
      RepositoryRegistration.ensureVisitsRepository();

      expect(
        () => RepositoryRegistration.ensureVisitsRepository(),
        returnsNormally,
      );
      expect(Get.isRegistered<VisitsRepository>(), isTrue);
    });
  });

  group('RepositoryRegistration — both repositories together', () {
    test('registers both PropertiesRepository and SwipesRepository', () {
      RepositoryRegistration.ensurePropertiesRepository();
      RepositoryRegistration.ensureSwipesRepository();

      expect(Get.isRegistered<PropertiesRepository>(), isTrue);
      expect(Get.isRegistered<SwipesRepository>(), isTrue);
      expect(Get.isRegistered<PropertiesPort>(), isTrue);
      expect(Get.isRegistered<SwipesPort>(), isTrue);
    });

    test('registers ports in any order', () {
      RepositoryRegistration.ensureSwipesRepository();
      RepositoryRegistration.ensurePropertiesRepository();

      expect(Get.isRegistered<PropertiesPort>(), isTrue);
      expect(Get.isRegistered<SwipesPort>(), isTrue);
    });
  });
}
