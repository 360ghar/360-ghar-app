import 'package:flutter_test/flutter_test.dart';

import 'package:ghar360/features/auth/data/auth_method.dart';
import 'package:ghar360/features/auth/data/last_auth_method_store.dart';
import '../../../helpers/settings_test_database.dart';

void main() {
  late LastAuthMethodStore store;
  late SettingsTestDatabase database;
  setUp(() {
    database = SettingsTestDatabase();
    store = LastAuthMethodStore(database: database);
  });
  group('LastAuthMethodStore.save / lastMethod', () {
    test('stores and retrieves the last method', () async {
      await store.save(AuthMethod.google);
      expect(store.lastMethod, AuthMethod.google);
    });

    test('overwrites the previous method on subsequent save', () async {
      await store.save(AuthMethod.emailOtp);
      await store.save(AuthMethod.phonePassword);
      expect(store.lastMethod, AuthMethod.phonePassword);
    });

    test('returns null when no method has been saved', () async {
      expect(store.lastMethod, isNull);
    });
  });

  group('LastAuthMethodStore.lastIdentifierHint', () {
    test('stores a masked email hint', () async {
      await store.save(AuthMethod.emailPassword, identifier: 'john@gmail.com');
      expect(store.lastIdentifierHint, 'j***@gmail.com');
    });

    test('stores a masked phone hint', () async {
      await store.save(AuthMethod.phoneOtp, identifier: '9876543210');
      expect(store.lastIdentifierHint, '+91 ******3210');
    });

    test('clears a previous hint when identifier is null', () async {
      await store.save(AuthMethod.emailPassword, identifier: 'john@gmail.com');
      await store.save(AuthMethod.google);
      expect(store.lastIdentifierHint, isNull);
    });

    test('does not store a hint when identifier is empty/whitespace', () async {
      await store.save(AuthMethod.apple, identifier: '   ');
      expect(store.lastIdentifierHint, isNull);
    });

    test('returns null when no hint has been saved', () async {
      expect(store.lastIdentifierHint, isNull);
    });
  });

  group('LastAuthMethodStore.clear', () {
    test('removes the method and hint', () async {
      await store.save(AuthMethod.google, identifier: 'john@gmail.com');
      expect(store.lastMethod, AuthMethod.google);
      expect(store.lastIdentifierHint, isNotNull);

      await store.clear();

      expect(store.lastMethod, isNull);
      expect(store.lastIdentifierHint, isNull);
    });

    test('is a no-op when nothing was saved', () async {
      await store.clear();
      expect(store.lastMethod, isNull);
      expect(store.lastIdentifierHint, isNull);
    });
  });

  group('LastAuthMethodStore masking', () {
    test('never persists the raw identifier (email)', () async {
      await store.save(AuthMethod.emailPassword, identifier: 'rawemail@example.com');
      // The stored hint must be masked, not the raw value.
      expect(store.lastIdentifierHint, isNot('rawemail@example.com'));
      expect(store.lastIdentifierHint, 'r***@example.com');
    });

    test('never persists the raw identifier (phone)', () async {
      await store.save(AuthMethod.phoneOtp, identifier: '+919876543210');
      expect(store.lastIdentifierHint, isNot('+919876543210'));
      expect(store.lastIdentifierHint, '+91 ******3210');
    });
  });
}
