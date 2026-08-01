// test/features/auth/data/last_auth_method_store_test.dart
//
// Unit tests for [LastAuthMethodStore], which persists the last-used auth
// method and a masked identifier hint to GetStorage. Requires GetStorage.init()
// backed by a mocked path_provider platform channel.

import 'package:flutter/services.dart';

import 'package:flutter_test/flutter_test.dart';
import 'package:get_storage/get_storage.dart';

import 'package:ghar360/features/auth/data/auth_method.dart';
import 'package:ghar360/features/auth/data/last_auth_method_store.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  const pathChannel = MethodChannel('plugins.flutter.io/path_provider');

  setUpAll(() async {
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger.setMockMethodCallHandler(
      pathChannel,
      (MethodCall methodCall) async {
        if (methodCall.method == 'getApplicationDocumentsDirectory') return '.';
        return null;
      },
    );
    await GetStorage.init();
  });

  late LastAuthMethodStore store;
  late GetStorage testStorage;

  setUp(() async {
    // Use a dedicated GetStorage container to avoid state leaking from other
    // test files that write to the default GetStorage instance.
    testStorage = GetStorage('TestLastAuth');
    await testStorage.initStorage;
    testStorage.erase();
    store = LastAuthMethodStore(storage: testStorage);
    store.clear();
  });

  tearDown(() {
    testStorage.erase();
  });

  group('LastAuthMethodStore.save / lastMethod', () {
    test('stores and retrieves the last method', () {
      store.save(AuthMethod.google);
      expect(store.lastMethod, AuthMethod.google);
    });

    test('overwrites the previous method on subsequent save', () {
      store.save(AuthMethod.emailOtp);
      store.save(AuthMethod.phonePassword);
      expect(store.lastMethod, AuthMethod.phonePassword);
    });

    test('returns null when no method has been saved', () {
      expect(store.lastMethod, isNull);
    });
  });

  group('LastAuthMethodStore.lastIdentifierHint', () {
    test('stores a masked email hint', () {
      store.save(AuthMethod.emailPassword, identifier: 'john@gmail.com');
      expect(store.lastIdentifierHint, 'j***@gmail.com');
    });

    test('stores a masked phone hint', () {
      store.save(AuthMethod.phoneOtp, identifier: '9876543210');
      expect(store.lastIdentifierHint, '+91 ******3210');
    });

    test('clears a previous hint when identifier is null', () {
      store.save(AuthMethod.emailPassword, identifier: 'john@gmail.com');
      store.save(AuthMethod.google);
      expect(store.lastIdentifierHint, isNull);
    });

    test('does not store a hint when identifier is empty/whitespace', () {
      store.save(AuthMethod.apple, identifier: '   ');
      expect(store.lastIdentifierHint, isNull);
    });

    test('returns null when no hint has been saved', () {
      expect(store.lastIdentifierHint, isNull);
    });
  });

  group('LastAuthMethodStore.clear', () {
    test('removes the method and hint', () {
      store.save(AuthMethod.google, identifier: 'john@gmail.com');
      expect(store.lastMethod, AuthMethod.google);
      expect(store.lastIdentifierHint, isNotNull);

      store.clear();

      expect(store.lastMethod, isNull);
      expect(store.lastIdentifierHint, isNull);
    });

    test('is a no-op when nothing was saved', () {
      store.clear();
      expect(store.lastMethod, isNull);
      expect(store.lastIdentifierHint, isNull);
    });
  });

  group('LastAuthMethodStore masking', () {
    test('never persists the raw identifier (email)', () {
      store.save(AuthMethod.emailPassword, identifier: 'rawemail@example.com');
      // The stored hint must be masked, not the raw value.
      expect(store.lastIdentifierHint, isNot('rawemail@example.com'));
      expect(store.lastIdentifierHint, 'r***@example.com');
    });

    test('never persists the raw identifier (phone)', () {
      store.save(AuthMethod.phoneOtp, identifier: '+919876543210');
      expect(store.lastIdentifierHint, isNot('+919876543210'));
      expect(store.lastIdentifierHint, '+91 ******3210');
    });
  });
}
