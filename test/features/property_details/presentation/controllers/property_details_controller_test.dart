import 'dart:async';

import 'package:flutter_test/flutter_test.dart';
import 'package:get/get.dart';
import 'package:ghar360/core/data/models/property_model.dart';
import 'package:ghar360/features/properties/data/properties_repository.dart';
import 'package:ghar360/features/property_details/presentation/controllers/property_details_controller.dart';
import 'package:mocktail/mocktail.dart';

import '../../../../helpers/getx_test_binding.dart';
import '../../../../helpers/mocks.dart';

void main() {
  late MockPropertiesRepository mockPropertiesRepository;

  setUp(() {
    GetxTestBinding.init();
    mockPropertiesRepository = MockPropertiesRepository();
    GetxTestBinding.bind().register<PropertiesRepository>(mockPropertiesRepository);
  });

  tearDown(() {
    GetxTestBinding.reset();
  });

  /// Set Get.arguments by manipulating the routing state directly.
  /// In GetX 4.x, `Get.arguments` delegates to `Get.routing.args`.
  void setArguments(dynamic args) {
    // Routing is mutable — update its args field.
    Get.routing.update((r) => r.args = args);
  }

  /// Helper: set arguments then construct and initialise the controller.
  PropertyDetailsController createControllerWithArgs(dynamic args) {
    setArguments(args);
    final c = PropertyDetailsController();
    c.onInit();
    return c;
  }

  /// Helper: create controller with no arguments set (args = null).
  PropertyDetailsController createController() {
    setArguments(null);
    final c = PropertyDetailsController();
    c.onInit();
    return c;
  }

  group('PropertyDetailsController', () {
    test('resolves property directly from Get.arguments when PropertyModel', () async {
      final prop = testPropertyModel(id: 42);

      final controller = createControllerWithArgs(prop);
      await Future<void>.value();

      expect(controller.property.value, isNotNull);
      expect(controller.property.value!.id, 42);
      expect(controller.isLoading.value, isFalse);
      expect(controller.errorKey.value, isNull);
    });

    test('resolves property from Get.arguments["property"] embedded PropertyModel', () async {
      final prop = testPropertyModel(id: 77);

      final controller = createControllerWithArgs({'property': prop});
      await Future<void>.value();

      expect(controller.property.value, isNotNull);
      expect(controller.property.value!.id, 77);
      expect(controller.isLoading.value, isFalse);
    });

    test('fetches property by string id from Get.arguments', () async {
      when(
        () => mockPropertiesRepository.getPropertyDetail(101),
      ).thenAnswer((_) async => testPropertyModel(id: 101));

      final controller = createControllerWithArgs('101');
      await Future<void>.value();

      expect(controller.property.value, isNotNull);
      expect(controller.property.value!.id, 101);
      expect(controller.isLoading.value, isFalse);
      expect(controller.errorKey.value, isNull);
    });

    test('fetches property by id from Get.arguments map with "id" key', () async {
      when(
        () => mockPropertiesRepository.getPropertyDetail(401),
      ).thenAnswer((_) async => testPropertyModel(id: 401));

      final controller = createControllerWithArgs({'id': '401'});
      await Future<void>.value();

      expect(controller.property.value, isNotNull);
      expect(controller.property.value!.id, 401);
      verify(() => mockPropertiesRepository.getPropertyDetail(401)).called(1);
    });

    test('fetches property by id from Get.arguments map with "property_id" key', () async {
      when(
        () => mockPropertiesRepository.getPropertyDetail(402),
      ).thenAnswer((_) async => testPropertyModel(id: 402));

      final controller = createControllerWithArgs({'property_id': '402'});
      await Future<void>.value();

      expect(controller.property.value, isNotNull);
      expect(controller.property.value!.id, 402);
    });

    test('sets error when Get.arguments is null and no URL parameters', () async {
      final controller = createController();
      await Future<void>.value();

      expect(controller.isLoading.value, isFalse);
      expect(controller.errorKey.value, 'property_not_found');
      expect(controller.property.value, isNull);
    });

    test('sets error for non-numeric string id', () async {
      final controller = createControllerWithArgs({'id': 'abc'});
      await Future<void>.value();

      expect(controller.isLoading.value, isFalse);
      expect(controller.errorKey.value, 'invalid_property_id');
      expect(controller.property.value, isNull);
    });

    test('sets error when repository throws an exception', () async {
      when(
        () => mockPropertiesRepository.getPropertyDetail(500),
      ).thenThrow(Exception('Network timeout'));

      final controller = createControllerWithArgs('500');
      await Future<void>.value();

      expect(controller.isLoading.value, isFalse);
      expect(controller.errorKey.value, 'property_load_failed');
      expect(controller.errorDetail.value, isNotNull);
      expect(controller.property.value, isNull);
    });

    test('retry reloads property after an error', () async {
      when(
        () => mockPropertiesRepository.getPropertyDetail(300),
      ).thenThrow(Exception('Server down'));

      final controller = createControllerWithArgs('300');
      await Future<void>.value();

      // First load fails.
      expect(controller.errorKey.value, 'property_load_failed');

      // Set up success for retry.
      when(
        () => mockPropertiesRepository.getPropertyDetail(300),
      ).thenAnswer((_) async => testPropertyModel(id: 300));

      controller.retry();
      await Future<void>.value();

      expect(controller.property.value, isNotNull);
      expect(controller.property.value!.id, 300);
      expect(controller.isLoading.value, isFalse);
      expect(controller.errorKey.value, isNull);
    });

    test('errorMessage returns mapped message for property_load_failed', () async {
      when(
        () => mockPropertiesRepository.getPropertyDetail(600),
      ).thenThrow(Exception('Internal error'));

      final controller = createControllerWithArgs('600');
      await Future<void>.value();

      expect(controller.errorKey.value, 'property_load_failed');
      expect(controller.errorMessage, isNotNull);
    });

    test('errorMessage returns null when no error is set', () async {
      final controller = createControllerWithArgs(testPropertyModel(id: 1));
      await Future<void>.value();

      expect(controller.errorMessage, isNull);
    });

    test('resolves int argument as direct property id', () async {
      when(
        () => mockPropertiesRepository.getPropertyDetail(250),
      ).thenAnswer((_) async => testPropertyModel(id: 250));

      final controller = createControllerWithArgs(250);
      await Future<void>.value();

      expect(controller.property.value, isNotNull);
      expect(controller.property.value!.id, 250);
      verify(() => mockPropertiesRepository.getPropertyDetail(250)).called(1);
    });

    // ── Resolves property from map with "property_id" snake_case key ──────

    test('fetches property by id from map with "property_id" snake_case key', () async {
      when(
        () => mockPropertiesRepository.getPropertyDetail(403),
      ).thenAnswer((_) async => testPropertyModel(id: 403));

      final controller = createControllerWithArgs({'property_id': '403'});
      await Future<void>.value();

      expect(controller.property.value, isNotNull);
      expect(controller.property.value!.id, 403);
    });

    // ── Resolves int id from map ──────────────────────────────────────────

    test('fetches property by int id from Get.arguments map', () async {
      when(
        () => mockPropertiesRepository.getPropertyDetail(404),
      ).thenAnswer((_) async => testPropertyModel(id: 404));

      final controller = createControllerWithArgs({'id': 404});
      await Future<void>.value();

      expect(controller.property.value, isNotNull);
      expect(controller.property.value!.id, 404);
    });

    // ── PropertyModel in map takes priority over id ───────────────────────

    test('PropertyModel in map takes priority over id field', () async {
      final prop = testPropertyModel(id: 99);

      final controller = createControllerWithArgs({'property': prop, 'id': '123'});
      await Future<void>.value();

      expect(controller.property.value!.id, 99);
      verifyNever(() => mockPropertiesRepository.getPropertyDetail(any()));
    });

    // ── Direct int argument ───────────────────────────────────────────────

    test('direct int argument resolves without map wrapper', () async {
      when(
        () => mockPropertiesRepository.getPropertyDetail(500),
      ).thenAnswer((_) async => testPropertyModel(id: 500));

      final controller = createControllerWithArgs(500);
      await Future<void>.value();

      expect(controller.property.value!.id, 500);
    });

    // ── Direct String argument ────────────────────────────────────────────

    test('direct String argument resolves as property id', () async {
      when(
        () => mockPropertiesRepository.getPropertyDetail(600),
      ).thenAnswer((_) async => testPropertyModel(id: 600));

      final controller = createControllerWithArgs('600');
      await Future<void>.value();

      expect(controller.property.value!.id, 600);
    });

    // ── Non-numeric string id in map ──────────────────────────────────────

    test('non-numeric string id in map sets invalid_property_id error', () async {
      final controller = createControllerWithArgs({'property_id': 'not_a_number'});
      await Future<void>.value();

      expect(controller.errorKey.value, 'invalid_property_id');
      expect(controller.property.value, isNull);
    });

    // ── errorMessage for property_not_found ───────────────────────────────

    test('errorMessage returns translated key for property_not_found', () async {
      final controller = createController();
      await Future<void>.value();

      expect(controller.errorKey.value, 'property_not_found');
      expect(controller.errorMessage, isNotNull);
    });

    // ── errorMessage for invalid_property_id ──────────────────────────────

    test('errorMessage returns translated key for invalid_property_id', () async {
      final controller = createControllerWithArgs({'id': 'abc'});
      await Future<void>.value();

      expect(controller.errorKey.value, 'invalid_property_id');
      expect(controller.errorMessage, isNotNull);
    });

    // ── retry clears previous error ───────────────────────────────────────

    test('retry clears error and loads property successfully', () async {
      final controller = createController();
      await Future<void>.value();
      expect(controller.errorKey.value, 'property_not_found');

      when(
        () => mockPropertiesRepository.getPropertyDetail(700),
      ).thenAnswer((_) async => testPropertyModel(id: 700));
      setArguments('700');

      controller.retry();
      await Future<void>.value();

      expect(controller.property.value, isNotNull);
      expect(controller.property.value!.id, 700);
      expect(controller.errorKey.value, isNull);
    });

    // ── isLoading is true initially ───────────────────────────────────────

    test('isLoading is true before async resolution completes', () {
      final completer = Completer<PropertyModel>();
      when(
        () => mockPropertiesRepository.getPropertyDetail(800),
      ).thenAnswer((_) => completer.future);

      final controller = createControllerWithArgs('800');
      // Before the future completes, isLoading should be true
      expect(controller.isLoading.value, isTrue);

      completer.complete(testPropertyModel(id: 800));
    });

    // ── Map with no recognized keys falls through to property_not_found ───

    test('map with no recognized keys sets property_not_found', () async {
      final controller = createControllerWithArgs({'unknown_key': 'value'});
      await Future<void>.value();

      expect(controller.errorKey.value, 'property_not_found');
    });

    // ── Unrecognized argument type falls through ──────────────────────────

    test('unrecognized argument type sets property_not_found', () async {
      final controller = createControllerWithArgs(3.14); // double, not int/String/PropertyModel
      await Future<void>.value();

      expect(controller.errorKey.value, 'property_not_found');
    });

    // ── errorDetail is set on repository failure ──────────────────────────

    test('errorDetail contains mapped error message on failure', () async {
      when(
        () => mockPropertiesRepository.getPropertyDetail(900),
      ).thenThrow(Exception('Custom error message'));

      final controller = createControllerWithArgs('900');
      await Future<void>.value();

      expect(controller.errorKey.value, 'property_load_failed');
      expect(controller.errorDetail.value, isNotNull);
      expect(controller.errorDetail.value, isNotEmpty);
    });
  });
}
