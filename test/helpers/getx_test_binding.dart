// test/helpers/getx_test_binding.dart
//
// Reusable GetX test harness. The app's controllers resolve dependencies via
// `Get.find<T>()` (service-locator), so tests must register mock instances into
// the GetX container before constructing the controller under test. This helper
// guarantees a FRESH, ISOLATED container per test and full teardown afterward,
// preventing the permanent-registration pollution that otherwise leaks state
// across tests in the same process.
//
// Usage:
//
//   setUp(() {
//     GetxTestBinding.init();          // Get.testMode = true + clean slate
//   });
//
//   tearDown(() {
//     GetxTestBinding.reset();         // Get.reset() clears every registration
//   });
//
//   test('...', () {
//     final authRepo = MockAuthRepository();
//     final profileRepo = MockProfileRepository();
//     GetxTestBinding.bind()
//       ..register<AuthRepository>(authRepo)
//       ..register<ProfileRepository>(profileRepo);
//     // ... construct controller, assert behaviour
//   });
//
// Why register() returns a fluent binder: each test declares exactly which
// dependencies it needs, keeping test intent explicit and avoiding a giant
// one-size-fits-all registration that masks missing wiring.

import 'package:flutter/foundation.dart';

import 'package:get/get.dart';

/// A scoped GetX test container. Call [init] in `setUp`, [reset] in `tearDown`,
/// and chain [bind]..register() inside each test to seed the dependencies that
/// specific test requires.
class GetxTestBinding {
  GetxTestBinding._();

  /// Puts GetX into test mode and ensures the container starts empty.
  ///
  /// `Get.testMode = true` makes GetX throw (instead of silently returning null)
  /// when an unregistered dependency is looked up, which surfaces missing wiring
  /// immediately rather than producing confusing null-pointer failures deeper in
  /// the test.
  static void init() {
    Get.testMode = true;
    _hardReset();
  }

  /// Fully tears down the GetX container: disposes registered controllers/
  /// services where possible, then clears the registry. Safe to call even when
  /// nothing is registered.
  static void reset() {
    _hardReset();
  }

  /// Starts a fluent registration chain. Each [register] call puts an instance
  /// into the container, mirroring `Get.put` but scoped to test intent.
  static TestBinder bind() => TestBinder();

  static void _hardReset() {
    try {
      Get.reset();
    } catch (e, st) {
      // In test mode Get.reset can throw if a disposed dependency is touched
      // concurrently; surface it loudly instead of masking registration leaks.
      debugPrint('GetxTestBinding: Get.reset() failed: $e\n$st');
      rethrow;
    }
  }
}

/// Fluent registrar returned by [GetxTestBinding.bind]. Each method returns
/// `this` so registrations chain readably.
class TestBinder {
  TestBinder();

  /// Registers [instance] as type [T] in the GetX container (permanent, so it
  /// survives for the lifetime of the test and is cleaned up by [Get.reset]).
  TestBinder register<T>(T instance, {String? tag}) {
    Get.put<T>(instance, tag: tag, permanent: true);
    return this;
  }

  /// Registers [instance] lazily: it is only constructed on first `Get.find`.
  /// Useful for heavyweight mocks whose construction should be deferred.
  TestBinder registerLazy<T>(T Function() factory, {String? tag}) {
    Get.lazyPut<T>(factory, tag: tag, fenix: true);
    return this;
  }
}
