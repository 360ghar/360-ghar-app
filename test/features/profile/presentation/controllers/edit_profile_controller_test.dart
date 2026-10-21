import 'dart:async';

import 'package:flutter_test/flutter_test.dart';

import 'package:ghar360/core/controllers/auth_controller.dart';
import 'package:ghar360/core/data/models/user_model.dart';
import 'package:ghar360/core/utils/app_exceptions.dart';
import 'package:ghar360/features/profile/presentation/controllers/edit_profile_controller.dart';
import '../../../../helpers/profile_test_harness.dart';

void main() {
  late ProfileHarness h;
  late EditProfileController controller;
  setUp(() {
    h = ProfileHarness();
    h.listen(editProfileProvider);
    controller = h.container.read(editProfileProvider.notifier);
  });
  tearDown(() => h.close());
  test('starts idle without widget-owned text or form state', () {
    expect(h.container.read(editProfileProvider).busy, isFalse);
  });
  test('saves the profile keys and sends the place through the preferences writer', () async {
    h.session.set(
      h.container.read(authProvider).copyWith(user: profile().copyWith(profileImageUrl: 'avatar')),
    );
    await h.container.pump();
    expect(
      await controller.saveProfile(
        name: ' Updated ',
        location: ' Delhi ',
        dateOfBirth: DateTime(1990, 5, 20),
      ),
      isTrue,
    );
    // The profile body holds only keys of UserUpdate: no email, avatar or preferences.
    expect(h.session.lastProfile, {'full_name': 'Updated', 'date_of_birth': '1990-05-20'});
    expect(h.session.lastPreferences, {
      'location_preference': ['Delhi'],
    });
  });
  test('an unchanged place sends no preferences', () async {
    h.session.set(
      h.container
          .read(authProvider)
          .copyWith(
            user: profile().copyWith(
              preferences: const UserPreferences(locationPreference: ['Delhi']),
            ),
          ),
    );
    await h.container.pump();
    await controller.saveProfile(name: 'Name', location: ' Delhi ');
    expect(h.session.lastPreferences, isNull);
  });
  test('a cleared place removes the key with null', () async {
    h.session.set(
      h.container
          .read(authProvider)
          .copyWith(
            user: profile().copyWith(
              preferences: const UserPreferences(locationPreference: ['Delhi']),
            ),
          ),
    );
    await h.container.pump();
    await controller.saveProfile(name: 'Name', location: '  ');
    expect(h.session.lastPreferences, {'location_preference': null});
  });
  test('a failed preferences write stops before the profile write', () async {
    h.session.savePreferences = () async => false;
    final saved = await controller.saveProfile(name: 'Name', location: 'Mumbai');
    expect(saved, isFalse);
    expect(h.session.lastProfile, isNull);
  });
  test('cleared date is sent as null', () async {
    await controller.saveProfile(name: 'Name', location: '');
    expect(h.session.lastProfile!['date_of_birth'], isNull);
  });
  test('missing user does not send a write', () async {
    h.session.set(h.container.read(authProvider).copyWith(user: null));
    await h.container.pump();
    expect(await controller.saveProfile(name: 'Name', location: ''), isFalse);
    expect(h.session.lastProfile, isNull);
  });
  test('duplicate saves are blocked while first write is pending', () async {
    final completer = Completer<bool>();
    h.session.save = () => completer.future;
    final first = controller.saveProfile(name: 'First', location: '');
    expect(h.container.read(editProfileProvider).saving, isTrue);
    expect(await controller.saveProfile(name: 'Second', location: ''), isFalse);
    expect(h.session.lastProfile!['full_name'], 'First');
    completer.complete(true);
    expect(await first, isTrue);
    expect(h.container.read(editProfileProvider).busy, isFalse);
  });
  test('network failure is visible and preserves retry', () async {
    h.session.save = () async => throw NetworkException('offline');
    expect(await controller.saveProfile(name: 'Draft', location: ''), isFalse);
    expect(h.container.read(editProfileProvider).error, isA<NetworkException>());
    h.session.save = null;
    expect(await controller.saveProfile(name: 'Draft', location: ''), isTrue);
  });
  test('avatar upload owns only mutation state and delegates once', () async {
    final completer = Completer<bool>();
    h.session.upload = () => completer.future;
    final first = controller.uploadImage('/avatar.jpg');
    expect(h.container.read(editProfileProvider).uploading, isTrue);
    expect(await controller.uploadImage('/other.jpg'), isFalse);
    expect(h.session.lastImage, '/avatar.jpg');
    completer.complete(true);
    expect(await first, isTrue);
    expect(h.container.read(editProfileProvider).busy, isFalse);
  });
  test('avatar failure is visible and resets progress', () async {
    h.session.upload = () async => throw NetworkException('offline');
    expect(await controller.uploadImage('/avatar.jpg'), isFalse);
    expect(h.container.read(editProfileProvider).error, isA<NetworkException>());
    expect(h.container.read(editProfileProvider).busy, isFalse);
  });
  test('late save cannot complete for a replacement account', () async {
    final completer = Completer<bool>();
    h.session.save = () => completer.future;
    final first = controller.saveProfile(name: 'Old', location: '');
    h.session.set(h.container.read(authProvider).copyWith(user: profile('account-b')));
    await h.container.pump();
    completer.complete(true);
    expect(await first, isFalse);
    expect(h.container.read(editProfileProvider).busy, isFalse);
  });
  test('disposing the form ignores late avatar completion', () async {
    final sub = h.listen(editProfileProvider);
    final completer = Completer<bool>();
    h.session.upload = () => completer.future;
    final first = controller.uploadImage('/old.jpg');
    sub.close();
    h.container.invalidate(editProfileProvider);
    await h.container.pump();
    completer.complete(true);
    expect(await first, isFalse);
  });
}
