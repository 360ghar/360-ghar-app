import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';

import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_core_platform_interface/test.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';

import 'package:ghar360/core/controllers/auth_controller.dart';
import 'package:ghar360/core/data/models/auth_status.dart';
import 'package:ghar360/core/data/models/user_model.dart';
import 'package:ghar360/core/firebase/firebase_runtime_state.dart';
import 'package:ghar360/core/firebase/push_notifications_service.dart';
import 'package:ghar360/core/network/api_client.dart';
import 'package:ghar360/core/providers/network_providers.dart';
import 'package:ghar360/core/utils/app_exceptions.dart';
import '../../helpers/auth_test_harness.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  late AuthHarness h;
  setUp(() async {
    h = AuthHarness();
    await h.open();
  });
  tearDown(() async {
    await h.close();
  });
  UnauthorizedEvent unauthorized({String code = AppException.unauthorizedCode, int status = 401}) =>
      UnauthorizedEvent(
        // A failure raised on the device (no token yet) has no HTTP status.
        error: AuthenticationException(
          'Denied',
          code: code,
          statusCode: code == AppException.missingAuthHeaderCode ? null : status,
        ),
        method: 'GET',
        endpoint: '/anything',
        statusCode: status,
      );

  test('no SDK session starts unauthenticated with idle mutation', () {
    expect(h.state.status, AuthStatus.unauthenticated);
    expect(h.state.resolving, false);
    expect(h.state.user, isNull);
    expect(h.state.mutation.isLoading, false);
  });
  test('SDK user stream loads profile and becomes authenticated', () async {
    await h.authenticate();
    expect(h.state.status, AuthStatus.authenticated);
    expect(h.state.user?.supabaseUserId, 'account-a');
    expect(h.state.stale, false);
  });
  test('null SDK event removes authenticated state', () async {
    await h.authenticate();
    h.emit(null);
    expect(h.state.status, AuthStatus.unauthenticated);
    expect(h.state.user, isNull);
  });
  test('incomplete profile requires completion', () async {
    await h.authenticate(complete: false);
    expect(h.state.status, AuthStatus.requiresProfileCompletion);
  });
  test('profile request failure exposes typed recoverable error', () async {
    h.controller;
    when(() => h.profiles.getCurrentUserProfile()).thenThrow(NetworkException('offline'));
    h.emit(sdkUser());
    await h.settle();
    expect(h.state.status, AuthStatus.error);
    expect(h.state.error, isA<NetworkException>());
    expect(h.state.resolving, false);
  });
  test('signOut calls repository and exposes loading until completion', () async {
    await h.authenticate();
    final pending = Completer<void>();
    when(() => h.repository.signOut()).thenAnswer((_) => pending.future);
    final result = h.controller.signOut();
    expect(h.state.mutation.isLoading, true);
    await h.settle();
    pending.complete();
    expect(await result, true);
    expect(h.state.status, AuthStatus.unauthenticated);
  });
  test('failed explicit signOut retains profile and exposes retryable mutation', () async {
    await h.authenticate();
    when(() => h.repository.signOut()).thenThrow(NetworkException('offline'));
    expect(await h.controller.signOut(), false);
    expect(h.state.user, isNotNull);
    expect(h.state.mutation.error, isA<NetworkException>());
  });
  test('duplicate signOut performs one repository request', () async {
    await h.authenticate();
    final pending = Completer<void>();
    when(() => h.repository.signOut()).thenAnswer((_) => pending.future);
    final first = h.controller.signOut();
    expect(await h.controller.signOut(), false);
    await h.settle();
    pending.complete();
    await first;
    verify(() => h.repository.signOut()).called(1);
  });
  group('account change during device unregistration', () {
    const messagingChannel = MethodChannel('plugins.flutter.io/firebase_messaging');
    late bool previousEnabled;
    late bool previousReady;
    setUpAll(setupFirebaseCoreMocks);
    setUp(() async {
      previousEnabled = FirebaseRuntimeState.isEnabled;
      previousReady = FirebaseRuntimeState.isReady;
      debugDefaultTargetPlatformOverride = TargetPlatform.iOS;
      await Firebase.initializeApp(
        options: const FirebaseOptions(
          apiKey: '123',
          appId: '123',
          messagingSenderId: '123',
          projectId: '123',
        ),
      );
      FirebaseRuntimeState.isEnabled = true;
      FirebaseRuntimeState.isReady = true;
      TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger.setMockMethodCallHandler(
        messagingChannel,
        (call) async => switch (call.method) {
          'Messaging#getToken' => {'token': 'test-device-token'},
          'Messaging#getAPNSToken' => {'token': 'test-apns-token'},
          _ => null,
        },
      );
      await PushNotificationsService.getToken();
      when(
        () => h.notifications.registerDeviceToken(token: any(named: 'token')),
      ).thenAnswer((_) async => true);
    });
    tearDown(() async {
      await PushNotificationsService.dispose();
      TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger.setMockMethodCallHandler(
        messagingChannel,
        null,
      );
      FirebaseRuntimeState.isEnabled = previousEnabled;
      FirebaseRuntimeState.isReady = previousReady;
      debugDefaultTargetPlatformOverride = null;
    });
    for (final operation in ['signOut', 'deleteAccount', 'unauthorized']) {
      test('$operation does not mutate the replacement account', () async {
        await h.authenticate();
        final pending = Completer<bool>();
        when(
          () => h.notifications.unregisterDeviceToken('test-device-token'),
        ).thenAnswer((_) => pending.future);
        final controller = h.controller;
        final result = switch (operation) {
          'signOut' => controller.signOut(),
          'deleteAccount' => controller.deleteAccount(),
          _ => h.client.onUnauthorized!(unauthorized()),
        };
        verify(() => h.notifications.unregisterDeviceToken('test-device-token')).called(1);
        await h.authenticate(account: 'account-b');
        pending.complete(true);
        await result;
        verifyNever(() => h.repository.signOut());
        verifyNever(() => h.repository.deleteAccount());
        expect(h.state.status, AuthStatus.authenticated);
        expect(h.state.user?.supabaseUserId, 'account-b');
        expect(h.state.mutation.isLoading, false);
      });
    }
  });
  test('password gate can be marked and cleared', () {
    final c = h.controller;
    c.markRequiresPasswordSetup();
    expect(c.requiresPasswordSetup, true);
    c.clearRequiresPasswordSetup();
    expect(c.requiresPasswordSetup, false);
  });
  test('password gate is applied before verification publishes a session', () async {
    h.controller.markRequiresPasswordSetup();
    h.emit(sdkUser());
    await h.settle();
    expect(h.state.status, AuthStatus.requiresPasswordSetup);
  });
  test('profile update makes completed profile authenticated', () async {
    await h.authenticate(complete: false);
    expect(await h.controller.updateUserProfile({'full_name': 'Test User'}), true);
    expect(h.state.status, AuthStatus.authenticated);
  });
  test('profile update error is returned without losing profile', () async {
    await h.authenticate();
    when(() => h.profiles.updateUserProfile(any())).thenThrow(NetworkException('offline'));
    expect(await h.controller.updateUserProfile({}), false);
    expect(h.state.user, isNotNull);
    expect(h.state.mutation.hasError, true);
  });
  test('avatar success updates profile and durable offline snapshot', () async {
    await h.authenticate();
    final updated = profile().copyWith(profileImageUrl: 'https://example.com/new.jpg');
    when(() => h.profiles.updateProfileImage(any())).thenAnswer((_) async => updated);
    expect(await h.controller.updateProfileImage('/avatar.jpg'), true);
    expect(h.state.user?.profileImageUrl, updated.profileImageUrl);
    final cached = await h.database.readCache(
      scope: h.container.read(storageScopeProvider),
      key: 'auth-profile',
    );
    expect((cached!.value as Map)['profile_image_url'], updated.profileImageUrl);
  });
  test('avatar error keeps existing profile and typed retry state', () async {
    await h.authenticate();
    when(() => h.profiles.updateProfileImage(any())).thenThrow(NetworkException('offline'));
    expect(await h.controller.updateProfileImage('/avatar.jpg'), false);
    expect(h.state.user?.supabaseUserId, 'account-a');
    expect(h.state.mutation.error, isA<NetworkException>());
    expect(h.state.mutationKind, AuthMutation.updateAvatar);
  });
  test('late avatar cannot enter a replacement account', () async {
    await h.authenticate();
    final pending = Completer<UserModel>();
    when(() => h.profiles.updateProfileImage(any())).thenAnswer((_) => pending.future);
    final result = h.controller.updateProfileImage('/avatar.jpg');
    await h.authenticate(account: 'account-b');
    pending.complete(profile().copyWith(profileImageUrl: 'old-account'));
    expect(await result, false);
    expect(h.state.user?.supabaseUserId, 'account-b');
    expect(h.state.user?.profileImageUrl, isNot('old-account'));
  });
  test('confirmed 401 from any endpoint signs out', () async {
    await h.authenticate();
    await h.client.onUnauthorized!(unauthorized());
    expect(h.state.status, AuthStatus.unauthenticated);
    verify(() => h.repository.signOut()).called(1);
  });
  test('a 401 with a domain code such as TOKEN_INVALID signs out', () async {
    await h.authenticate();
    await h.client.onUnauthorized!(unauthorized(code: 'TOKEN_INVALID'));
    expect(h.state.status, AuthStatus.unauthenticated);
    verify(() => h.repository.signOut()).called(1);
  });
  test('a 403 USER_INACTIVE signs out', () async {
    await h.authenticate();
    await h.client.onUnauthorized!(unauthorized(code: AppException.userInactiveCode, status: 403));
    expect(h.state.status, AuthStatus.unauthenticated);
    verify(() => h.repository.signOut()).called(1);
  });
  test('a 403 for another reason keeps the session', () async {
    await h.authenticate();
    await h.client.onUnauthorized!(unauthorized(code: 'USER_ACCESS_DENIED', status: 403));
    expect(h.state.isAuthenticated, true);
    verifyNever(() => h.repository.signOut());
  });
  test('missing auth header during offline refresh preserves session', () async {
    await h.authenticate();
    await h.client.onUnauthorized!(unauthorized(code: 'MISSING_AUTH_HEADER'));
    expect(h.state.isAuthenticated, true);
    verifyNever(() => h.repository.signOut());
  });
  test('non-401 event does not sign out', () async {
    await h.authenticate();
    await h.client.onUnauthorized!(unauthorized(status: 503));
    expect(h.state.isAuthenticated, true);
  });
  test('concurrent unauthorized events trigger one signOut', () async {
    await h.authenticate();
    final pending = Completer<void>();
    when(() => h.repository.signOut()).thenAnswer((_) => pending.future);
    final first = h.client.onUnauthorized!(unauthorized());
    await h.client.onUnauthorized!(unauthorized());
    pending.complete();
    await first;
    verify(() => h.repository.signOut()).called(1);
  });
  test('confirmed unauthorized blocks protected UI even if SDK signOut fails', () async {
    await h.authenticate();
    when(() => h.repository.signOut()).thenThrow(NetworkException('offline'));
    await h.client.onUnauthorized!(unauthorized());
    expect(h.state.status, AuthStatus.unauthenticated);
  });
  test('unauthorized while logged out is ignored', () async {
    h.controller;
    await h.client.onUnauthorized!(unauthorized());
    verifyNever(() => h.repository.signOut());
  });
  test('user convenience getters read immutable state', () async {
    expect(h.controller.userEmail, isNull);
    expect(h.controller.userId, isNull);
    expect(h.controller.isAuthenticated, false);
    await h.authenticate();
    expect(h.controller.userEmail, 'account-a@example.com');
    expect(h.controller.userId, 'account-a');
    expect(h.controller.isAuthenticated, true);
  });
  test('delete account succeeds then signs out', () async {
    await h.authenticate();
    expect(await h.controller.deleteAccount(), true);
    expect(h.state.status, AuthStatus.unauthenticated);
    verify(() => h.repository.deleteAccount()).called(1);
  });
  test('delete account failure retains current account', () async {
    await h.authenticate();
    when(() => h.repository.deleteAccount()).thenThrow(ServerException('failed'));
    expect(await h.controller.deleteAccount(), false);
    expect(h.state.isAuthenticated, true);
    expect(h.state.mutation.hasError, true);
  });
  test('profile retry recovers after failure', () async {
    h.controller;
    when(() => h.profiles.getCurrentUserProfile()).thenThrow(NetworkException('offline'));
    h.emit(sdkUser());
    await h.settle();
    when(() => h.profiles.getCurrentUserProfile()).thenAnswer((_) async => profile());
    await h.controller.retryProfileLoad();
    expect(h.state.isAuthenticated, true);
  });
  test('rapid profile retries respect cooldown', () async {
    await h.authenticate();
    when(() => h.profiles.getCurrentUserProfile()).thenThrow(NetworkException('offline'));
    await h.controller.retryProfileLoad();
    await h.controller.retryProfileLoad();
    verify(() => h.profiles.getCurrentUserProfile()).called(2);
  });
  test('password setup succeeds and clears mandatory gate', () async {
    h.controller.markRequiresPasswordSetup();
    h.emit(sdkUser());
    await h.settle();
    expect(await h.controller.completePasswordSetup('Password123'), true);
    expect(h.controller.requiresPasswordSetup, false);
    expect(h.state.isAuthenticated, true);
  });
  test('password setup failure retains mandatory gate', () async {
    h.controller.markRequiresPasswordSetup();
    h.emit(sdkUser());
    await h.settle();
    when(() => h.repository.updateUserPassword(any())).thenThrow(NetworkException('offline'));
    expect(await h.controller.completePasswordSetup('Password123'), false);
    expect(h.state.status, AuthStatus.requiresPasswordSetup);
    expect(h.state.mutation.hasError, true);
  });
  test('transient profile refresh keeps prior data marked stale', () async {
    await h.authenticate();
    when(() => h.profiles.getCurrentUserProfile()).thenThrow(NetworkException('offline'));
    await h.controller.recheckAuthBootstrap();
    expect(h.state.isAuthenticated, true);
    expect(h.state.stale, true);
    expect(h.state.error, isA<NetworkException>());
  });
  test('same account refresh event does not refetch profile', () async {
    await h.authenticate();
    h.emit(sdkUser());
    await h.settle();
    verify(() => h.profiles.getCurrentUserProfile()).called(1);
  });
  test('empty token cannot publish a successful session', () async {
    h.controller;
    when(
      () => h.repository.waitForAccessToken(
        timeout: any(named: 'timeout'),
        minTtlSeconds: any(named: 'minTtlSeconds'),
      ),
    ).thenAnswer((_) async => '');
    h.emit(sdkUser());
    await h.settle();
    expect(h.state.status, AuthStatus.error);
    verifyNever(() => h.profiles.getCurrentUserProfile());
  });
  test('late profile success after logout is ignored', () async {
    final pending = Completer<UserModel>();
    h.controller;
    when(() => h.profiles.getCurrentUserProfile()).thenAnswer((_) => pending.future);
    h.emit(sdkUser());
    await h.settle();
    h.emit(null);
    pending.complete(profile());
    await h.settle();
    expect(h.state.user, isNull);
    expect(h.state.status, AuthStatus.unauthenticated);
  });
  test('late account A profile cannot replace account B', () async {
    final pending = Completer<UserModel>();
    h.controller;
    when(() => h.profiles.getCurrentUserProfile()).thenAnswer((_) => pending.future);
    h.emit(sdkUser());
    await h.settle();
    when(() => h.profiles.getCurrentUserProfile()).thenAnswer((_) async => profile('account-b'));
    h.emit(sdkUser('account-b'));
    await h.settle();
    pending.complete(profile());
    await h.settle();
    expect(h.state.user?.supabaseUserId, 'account-b');
  });
  test('account A to B to A rejects old generation response', () async {
    final old = Completer<UserModel>();
    h.controller;
    when(() => h.profiles.getCurrentUserProfile()).thenAnswer((_) => old.future);
    h.emit(sdkUser());
    await h.settle();
    when(
      () => h.profiles.getCurrentUserProfile(),
    ).thenAnswer((_) async => profile(h.currentUser!.id));
    h.emit(sdkUser('account-b'));
    await h.settle();
    h.emit(sdkUser());
    await h.settle();
    old.complete(profile('account-a', false));
    await h.settle();
    expect(h.state.isAuthenticated, true);
  });
  test('profile from mismatched account is rejected', () async {
    h.controller;
    when(
      () => h.profiles.getCurrentUserProfile(),
    ).thenAnswer((_) async => profile('other-account'));
    h.emit(sdkUser());
    await h.settle();
    expect(h.state.user, isNull);
    expect(h.state.error?.code, 'ACCOUNT_MISMATCH');
  });
  test('late profile mutation after account change is ignored', () async {
    await h.authenticate();
    final pending = Completer<UserModel>();
    when(() => h.profiles.updateUserProfile(any())).thenAnswer((_) => pending.future);
    final result = h.controller.updateUserProfile({});
    when(() => h.profiles.getCurrentUserProfile()).thenAnswer((_) async => profile('account-b'));
    h.emit(sdkUser('account-b'));
    await h.settle();
    pending.complete(profile());
    expect(await result, false);
    expect(h.state.user?.supabaseUserId, 'account-b');
  });
  test('cached profile permits offline access only for matching active account', () async {
    h.controller;
    h.currentUser = sdkUser();
    h.emit(h.currentUser);
    await h.settle();
    h.container.invalidate(authProvider);
    when(
      () => h.repository.waitForAccessToken(
        timeout: any(named: 'timeout'),
        minTtlSeconds: any(named: 'minTtlSeconds'),
      ),
    ).thenThrow(NetworkException('offline'));
    h.controller;
    await h.settle();
    expect(h.state.user?.supabaseUserId, 'account-a');
    expect(h.state.stale, true);
    expect(h.state.isAuthenticated, true);
  });
  test('signOut preserves durable pending actions for owning account', () async {
    await h.authenticate();
    final scope = h.container.read(storageScopeProvider);
    await h.database.createAction(scope: scope, kind: 'swipe', payload: {'property_id': 4});
    await h.controller.signOut();
    await h.authenticate();
    expect((await h.database.listActions(scope: h.container.read(storageScopeProvider))).length, 1);
  });
  test('profile Skip is scoped to this session and cannot bypass password gate', () async {
    await h.authenticate(complete: false);
    h.controller.deferProfileCompletion();
    expect(h.state.profileCompletionDeferred, true);
    expect(h.state.isAuthenticated, true);
    h.controller.markRequiresPasswordSetup();
    expect(h.state.status, AuthStatus.requiresPasswordSetup);
    h.controller.deferProfileCompletion();
    expect(h.state.status, AuthStatus.requiresPasswordSetup);
    h.emit(null);
    expect(h.state.profileCompletionDeferred, false);
  });
  test('account switch clears deferred completion and password gate', () async {
    await h.authenticate(complete: false);
    h.controller.deferProfileCompletion();
    h.controller.markRequiresPasswordSetup();
    when(
      () => h.profiles.getCurrentUserProfile(),
    ).thenAnswer((_) async => profile('account-b', false));
    h.emit(sdkUser('account-b'));
    await h.settle();
    expect(h.state.profileCompletionDeferred, false);
    expect(h.state.status, AuthStatus.requiresProfileCompletion);
  });
  test('disposing provider removes only its owned unauthorized handler', () async {
    h.controller;
    expect(h.client.onUnauthorized, isNotNull);
    h.container.invalidate(authProvider);
    await h.settle();
    expect(h.client.onUnauthorized, isNull);
  });
  test('disposed pending profile cannot republish state', () async {
    final pending = Completer<UserModel>();
    h.controller;
    when(() => h.profiles.getCurrentUserProfile()).thenAnswer((_) => pending.future);
    h.emit(sdkUser());
    await h.settle();
    h.container.invalidate(authProvider);
    pending.complete(profile());
    await h.settle();
    expect(h.client.onUnauthorized, isNull);
  });
}
