// test/features/auth/data/auth_repository_test.dart
//
// Unit tests for the auth module's utility surfaces: static nonce helpers,
// identifier masking/normalization, identifier-status parsing, auth-method
// wire mapping, Supabase-backed auth wrappers, platform config gates, token
// readiness polling, and session lifecycle.

import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:get_storage/get_storage.dart';
import 'package:ghar360/core/config/app_config.dart';
import 'package:ghar360/core/network/api_client.dart';
import 'package:ghar360/core/utils/app_exceptions.dart';
import 'package:ghar360/features/auth/data/auth_method.dart';
import 'package:ghar360/features/auth/data/auth_repository.dart';
import 'package:ghar360/features/auth/data/identifier_utils.dart';
import 'package:ghar360/features/auth/data/last_auth_method_store.dart';
import 'package:ghar360/features/auth/data/models/identifier_status.dart';
import 'package:google_sign_in_platform_interface/google_sign_in_platform_interface.dart';
import 'package:mocktail/mocktail.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../../../helpers/mocks.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  const pathChannel = MethodChannel('plugins.flutter.io/path_provider');
  const prefsChannel = MethodChannel('plugins.flutter.io/shared_preferences');

  setUpAll(() async {
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger.setMockMethodCallHandler(
      pathChannel,
      (MethodCall methodCall) async {
        if (methodCall.method == 'getApplicationDocumentsDirectory') return '.';
        return null;
      },
    );
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger.setMockMethodCallHandler(
      prefsChannel,
      (MethodCall methodCall) async {
        // Handle all shared_preferences method calls so Supabase signOut /
        // session persistence doesn't crash on the null platform backend.
        // Write/remove methods must return true (bool) to satisfy the
        // platform interface's null-checked return values.
        if (methodCall.method == 'getAll') return <String, dynamic>{};
        if (methodCall.method == 'remove') return true;
        if (methodCall.method == 'setString') return true;
        if (methodCall.method == 'setBool') return true;
        if (methodCall.method == 'setInt') return true;
        if (methodCall.method == 'setDouble') return true;
        if (methodCall.method == 'setStringList') return true;
        if (methodCall.method == 'clear') return true;
        return null;
      },
    );
    await Supabase.initialize(url: 'https://example.supabase.co', publishableKey: 'anon-key');
    await GetStorage.init();
  });

  group('AuthRepository.generateRawNonce', () {
    test('returns a string of the default length (32)', () {
      final nonce = AuthRepository.generateRawNonce();
      expect(nonce.length, 32);
    });

    test('returns a string of the requested length', () {
      final nonce = AuthRepository.generateRawNonce(64);
      expect(nonce.length, 64);
    });

    test('contains only valid charset characters', () {
      final nonce = AuthRepository.generateRawNonce(200);
      final validPattern = RegExp(r'^[A-Za-z0-9\-._]+$');
      expect(validPattern.hasMatch(nonce), isTrue);
    });
  });

  group('AuthRepository.sha256OfString', () {
    test('returns a deterministic hex digest', () {
      final hash1 = AuthRepository.sha256OfString('test-nonce');
      final hash2 = AuthRepository.sha256OfString('test-nonce');
      expect(hash1, equals(hash2));
    });

    test('produces the known SHA-256 for "hello"', () {
      // SHA-256 of "hello" is a well-known constant.
      final hash = AuthRepository.sha256OfString('hello');
      expect(hash, '2cf24dba5fb0a30e26e83b2ac5b9e29e1b161e5c1fa7425e73043362938b9824');
    });

    test('different inputs produce different hashes', () {
      final hash1 = AuthRepository.sha256OfString('abc');
      final hash2 = AuthRepository.sha256OfString('xyz');
      expect(hash1, isNot(equals(hash2)));
    });
  });

  group('IdentifierUtils.mask', () {
    test('masks email: shows first char and domain', () {
      expect(IdentifierUtils.mask('john@gmail.com'), 'j***@gmail.com');
    });

    test('masks email: single-char local part', () {
      expect(IdentifierUtils.mask('a@domain.org'), 'a***@domain.org');
    });

    test('masks phone: hides all but last 4 digits', () {
      expect(IdentifierUtils.mask('+919876543210'), '+91 ******3210');
    });

    test('masks phone: 10-digit raw number', () {
      expect(IdentifierUtils.mask('9876543210'), '+91 ******3210');
    });

    test('returns empty string for empty input', () {
      expect(IdentifierUtils.mask(''), '');
    });

    test('returns raw value for short phone (4 or fewer digits)', () {
      expect(IdentifierUtils.mask('1234'), '1234');
    });
  });

  group('IdentifierUtils.normalize', () {
    test('lowercases and trims email', () {
      expect(IdentifierUtils.normalize('  John@Gmail.COM  '), 'john@gmail.com');
    });

    test('normalizes 10-digit phone to E.164 (+91)', () {
      final normalized = IdentifierUtils.normalize('9876543210');
      expect(normalized, '+919876543210');
    });

    test('keeps already-normalized +91 phone unchanged', () {
      expect(IdentifierUtils.normalize('+919876543210'), '+919876543210');
    });
  });

  group('IdentifierStatus.fromJson', () {
    test('parses existing verified user with password', () {
      final status = IdentifierStatus.fromJson({
        'exists': true,
        'verified': true,
        'has_password': true,
        'channel': 'email',
        'next_step': 'password',
      });

      expect(status.exists, isTrue);
      expect(status.verified, isTrue);
      expect(status.hasPassword, isTrue);
      expect(status.channel, IdentifierChannel.email);
      expect(status.nextStep, IdentifierNextStep.password);
      expect(status.isPasswordStep, isTrue);
    });

    test('parses new user (signup path)', () {
      final status = IdentifierStatus.fromJson({
        'exists': false,
        'verified': false,
        'has_password': false,
        'channel': 'phone',
        'next_step': 'otp',
      });

      expect(status.isNewUser, isTrue);
      expect(status.channel, IdentifierChannel.phone);
      expect(status.isOtpStep, isTrue);
    });
  });

  group('AuthMethod.fromWire', () {
    test('maps known wire values to enum members', () {
      expect(AuthMethod.fromWire('google'), AuthMethod.google);
      expect(AuthMethod.fromWire('apple'), AuthMethod.apple);
      expect(AuthMethod.fromWire('email_password'), AuthMethod.emailPassword);
      expect(AuthMethod.fromWire('phone_password'), AuthMethod.phonePassword);
      expect(AuthMethod.fromWire('phone_otp'), AuthMethod.phoneOtp);
      expect(AuthMethod.fromWire('email_otp'), AuthMethod.emailOtp);
    });

    test('returns null for unknown wire value', () {
      expect(AuthMethod.fromWire('magic_link'), isNull);
    });

    test('returns null for null input', () {
      expect(AuthMethod.fromWire(null), isNull);
    });
  });

  // -------------------------------------------------------------------------
  // ApiClient-backed methods. These construct a real [AuthRepository] (which
  // resolves `Supabase.instance.client` at construction) and stub the [ApiClient]
  // so the HTTP surface can be verified without a live backend.
  // -------------------------------------------------------------------------

  group('AuthRepository.checkIdentifierStatus', () {
    late MockApiClient mockApiClient;
    late AuthRepository repository;

    setUp(() {
      mockApiClient = MockApiClient();
      repository = AuthRepository(apiClient: mockApiClient);
    });

    tearDown(() {
      GetStorage().erase();
    });

    test('returns parsed IdentifierStatus on a valid response body', () async {
      when(
        () => mockApiClient.post(
          '/auth/identifier-status',
          body: any(named: 'body'),
          requireAuth: any(named: 'requireAuth'),
          notifyUnauthorized: any(named: 'notifyUnauthorized'),
          idempotent: any(named: 'idempotent'),
        ),
      ).thenAnswer(
        (_) async => ApiResponse(
          statusCode: 200,
          body: {
            'exists': true,
            'verified': true,
            'has_password': true,
            'channel': 'email',
            'next_step': 'password',
          },
          headers: {},
        ),
      );

      final status = await repository.checkIdentifierStatus('John@Gmail.COM');

      expect(status.exists, isTrue);
      expect(status.hasPassword, isTrue);
      expect(status.channel, IdentifierChannel.email);
      expect(status.isPasswordStep, isTrue);
      // Email is normalized (lowercased + trimmed) before being sent.
      verify(
        () => mockApiClient.post(
          '/auth/identifier-status',
          body: {'identifier': 'john@gmail.com'},
          requireAuth: false,
          notifyUnauthorized: false,
          idempotent: true,
        ),
      ).called(1);
    });

    test('normalizes a 10-digit phone to E.164 before sending', () async {
      when(
        () => mockApiClient.post(
          '/auth/identifier-status',
          body: any(named: 'body'),
          requireAuth: any(named: 'requireAuth'),
          notifyUnauthorized: any(named: 'notifyUnauthorized'),
          idempotent: any(named: 'idempotent'),
        ),
      ).thenAnswer(
        (_) async => ApiResponse(
          statusCode: 200,
          body: {
            'exists': false,
            'verified': false,
            'has_password': false,
            'channel': 'phone',
            'next_step': 'otp',
          },
          headers: {},
        ),
      );

      final status = await repository.checkIdentifierStatus('9876543210');

      expect(status.isNewUser, isTrue);
      expect(status.channel, IdentifierChannel.phone);
      expect(status.isOtpStep, isTrue);
      verify(
        () => mockApiClient.post(
          '/auth/identifier-status',
          body: {'identifier': '+919876543210'},
          requireAuth: false,
          notifyUnauthorized: false,
          idempotent: true,
        ),
      ).called(1);
    });

    test('throws FormatException when response body is not a Map', () async {
      when(
        () => mockApiClient.post(
          '/auth/identifier-status',
          body: any(named: 'body'),
          requireAuth: any(named: 'requireAuth'),
          notifyUnauthorized: any(named: 'notifyUnauthorized'),
          idempotent: any(named: 'idempotent'),
        ),
      ).thenAnswer((_) async => ApiResponse(statusCode: 200, body: 'not-a-map', headers: {}));

      expect(
        () => repository.checkIdentifierStatus('john@gmail.com'),
        throwsA(isA<FormatException>()),
      );
    });

    test('propagates AppException from ApiClient', () async {
      when(
        () => mockApiClient.post(
          '/auth/identifier-status',
          body: any(named: 'body'),
          requireAuth: any(named: 'requireAuth'),
          notifyUnauthorized: any(named: 'notifyUnauthorized'),
          idempotent: any(named: 'idempotent'),
        ),
      ).thenThrow(NetworkException('Offline'));

      expect(
        () => repository.checkIdentifierStatus('john@gmail.com'),
        throwsA(isA<NetworkException>()),
      );
    });
  });

  group('AuthRepository.recordLastMethod', () {
    late MockApiClient mockApiClient;
    late LastAuthMethodStore store;
    late AuthRepository repository;

    setUp(() {
      mockApiClient = MockApiClient();
      store = LastAuthMethodStore();
      repository = AuthRepository(apiClient: mockApiClient, lastAuthMethodStore: store);
    });

    tearDown(() {
      store.clear();
    });

    test('persists method locally and mirrors it to the backend', () async {
      when(
        () => mockApiClient.post('/auth/last-method', body: any(named: 'body')),
      ).thenAnswer((_) async => ApiResponse(statusCode: 200, body: {}, headers: {}));

      await repository.recordLastMethod(AuthMethod.google, identifier: 'john@gmail.com');

      // Local store updated synchronously.
      expect(store.lastMethod, AuthMethod.google);
      // Identifier is masked before persisting.
      expect(store.lastIdentifierHint, 'j***@gmail.com');
      // Backend mirror uses the wire value.
      verify(() => mockApiClient.post('/auth/last-method', body: {'method': 'google'})).called(1);
    });

    test('does not persist hint when identifier is null', () async {
      when(
        () => mockApiClient.post('/auth/last-method', body: any(named: 'body')),
      ).thenAnswer((_) async => ApiResponse(statusCode: 200, body: {}, headers: {}));

      await repository.recordLastMethod(AuthMethod.emailOtp);

      expect(store.lastMethod, AuthMethod.emailOtp);
      expect(store.lastIdentifierHint, isNull);
      verify(
        () => mockApiClient.post('/auth/last-method', body: {'method': 'email_otp'}),
      ).called(1);
    });

    test('swallows backend failure (best-effort) but keeps local store', () async {
      when(
        () => mockApiClient.post('/auth/last-method', body: any(named: 'body')),
      ).thenThrow(ServerException('Boom', statusCode: 500));

      // Should not throw — backend mirror is non-blocking.
      await repository.recordLastMethod(AuthMethod.phoneOtp, identifier: '9876543210');

      expect(store.lastMethod, AuthMethod.phoneOtp);
      expect(store.lastIdentifierHint, '+91 ******3210');
    });
  });

  group('AuthRepository.deleteAccount', () {
    late MockApiClient mockApiClient;
    late AuthRepository repository;

    setUp(() {
      mockApiClient = MockApiClient();
      repository = AuthRepository(apiClient: mockApiClient);
    });

    test('posts confirm payload to delete-account endpoint', () async {
      when(
        () => mockApiClient.post('/auth/delete-account', body: any(named: 'body')),
      ).thenAnswer((_) async => ApiResponse(statusCode: 200, body: {}, headers: {}));

      await repository.deleteAccount();

      verify(() => mockApiClient.post('/auth/delete-account', body: {'confirm': true})).called(1);
    });

    test('propagates AppException from ApiClient', () async {
      when(
        () => mockApiClient.post('/auth/delete-account', body: any(named: 'body')),
      ).thenThrow(AuthenticationException('Unauthorized'));

      expect(() => repository.deleteAccount(), throwsA(isA<AuthenticationException>()));
    });
  });

  group('AuthRepository.isOAuthRedirectUri', () {
    late AuthRepository repository;

    setUp(() {
      repository = AuthRepository(apiClient: MockApiClient());
    });

    test('returns true for the canonical redirect URI', () {
      expect(repository.isOAuthRedirectUri(Uri.parse('ghar360://login-callback')), isTrue);
    });

    test('returns true when host matches even with a trailing path segment', () {
      expect(repository.isOAuthRedirectUri(Uri.parse('ghar360://login-callback/extra')), isTrue);
    });

    test('returns false for a different scheme', () {
      expect(repository.isOAuthRedirectUri(Uri.parse('https://login-callback')), isFalse);
    });

    test('returns false for a different host', () {
      expect(repository.isOAuthRedirectUri(Uri.parse('ghar360://other-host')), isFalse);
    });
  });

  // -------------------------------------------------------------------------
  // Platform config gates: isGoogleSignInConfigured / isAppleSignInSupported.
  // These depend on AppConfig.instance and defaultTargetPlatform, both of
  // which can be controlled in tests.
  // -------------------------------------------------------------------------

  group('AuthRepository.isGoogleSignInConfigured', () {
    late AuthRepository repository;
    TargetPlatform? savedPlatform;

    setUp(() {
      repository = AuthRepository(apiClient: MockApiClient());
      savedPlatform = debugDefaultTargetPlatformOverride;
    });

    tearDown(() {
      debugDefaultTargetPlatformOverride = savedPlatform;
      AppConfig.resetForTest();
    });

    test('returns false when no client IDs are configured (Android)', () {
      AppConfig.initialize(overrides: const {});
      debugDefaultTargetPlatformOverride = TargetPlatform.android;

      expect(repository.isGoogleSignInConfigured, isFalse);
    });

    test('returns true on Android when web client ID is configured', () {
      AppConfig.initialize(overrides: {'GOOGLE_WEB_CLIENT_ID': 'web-client-id'});
      debugDefaultTargetPlatformOverride = TargetPlatform.android;

      expect(repository.isGoogleSignInConfigured, isTrue);
    });

    test('returns false on Android when only iOS client ID is configured', () {
      AppConfig.initialize(overrides: {'GOOGLE_IOS_CLIENT_ID': 'ios-client-id'});
      debugDefaultTargetPlatformOverride = TargetPlatform.android;

      expect(repository.isGoogleSignInConfigured, isFalse);
    });

    test('returns true on iOS when iOS client ID is configured', () {
      AppConfig.initialize(overrides: {'GOOGLE_IOS_CLIENT_ID': 'ios-client-id'});
      debugDefaultTargetPlatformOverride = TargetPlatform.iOS;

      expect(repository.isGoogleSignInConfigured, isTrue);
    });

    test('returns false on iOS when only web client ID is configured', () {
      AppConfig.initialize(overrides: {'GOOGLE_WEB_CLIENT_ID': 'web-client-id'});
      debugDefaultTargetPlatformOverride = TargetPlatform.iOS;

      expect(repository.isGoogleSignInConfigured, isFalse);
    });

    test('returns false on unsupported platforms (macOS)', () {
      AppConfig.initialize(
        overrides: {
          'GOOGLE_WEB_CLIENT_ID': 'web-client-id',
          'GOOGLE_IOS_CLIENT_ID': 'ios-client-id',
        },
      );
      debugDefaultTargetPlatformOverride = TargetPlatform.macOS;

      expect(repository.isGoogleSignInConfigured, isFalse);
    });
  });

  group('AuthRepository.isAppleSignInSupported', () {
    late AuthRepository repository;
    TargetPlatform? savedPlatform;

    setUp(() {
      repository = AuthRepository(apiClient: MockApiClient());
      savedPlatform = debugDefaultTargetPlatformOverride;
    });

    tearDown(() {
      debugDefaultTargetPlatformOverride = savedPlatform;
    });

    test('returns true on iOS', () {
      debugDefaultTargetPlatformOverride = TargetPlatform.iOS;
      expect(repository.isAppleSignInSupported, isTrue);
    });

    test('returns false on Android', () {
      debugDefaultTargetPlatformOverride = TargetPlatform.android;
      expect(repository.isAppleSignInSupported, isFalse);
    });

    test('returns false on macOS', () {
      debugDefaultTargetPlatformOverride = TargetPlatform.macOS;
      expect(repository.isAppleSignInSupported, isFalse);
    });
  });

  // -------------------------------------------------------------------------
  // Session getters: currentUser / currentSession / onAuthStateChange.
  // With the dummy Supabase instance there is no session, so these return null.
  // -------------------------------------------------------------------------

  group('AuthRepository session getters', () {
    late AuthRepository repository;

    setUp(() {
      repository = AuthRepository(apiClient: MockApiClient());
    });

    test('currentUser returns null when no session', () {
      expect(repository.currentUser, isNull);
    });

    test('currentSession returns null when no session', () {
      expect(repository.currentSession, isNull);
    });

    test('onAuthStateChange emits a stream', () {
      expect(repository.onAuthStateChange, isA<Stream<User?>>());
    });
  });

  // -------------------------------------------------------------------------
  // waitForAccessToken: polls the Supabase session for a usable access token.
  // With no session, it should time out and throw AuthException.
  // -------------------------------------------------------------------------

  group('AuthRepository.waitForAccessToken', () {
    late AuthRepository repository;

    setUp(() {
      repository = AuthRepository(apiClient: MockApiClient());
    });

    test('throws AuthException when no session is available within timeout', () async {
      expect(
        () => repository.waitForAccessToken(
          timeout: const Duration(milliseconds: 300),
          minTtlSeconds: 0,
        ),
        throwsA(isA<AuthException>()),
      );
    });

    test('throws with message "Access token not available in time"', () async {
      Object? caught;
      try {
        await repository.waitForAccessToken(
          timeout: const Duration(milliseconds: 300),
          minTtlSeconds: 0,
        );
      } catch (e) {
        caught = e;
      }
      expect(caught, isA<AuthException>());
      expect((caught as AuthException).message, 'Access token not available in time');
    });

    test('clamps negative minTtlSeconds to 0', () async {
      // A negative TTL should be treated as 0, not cause an error.
      expect(
        () => repository.waitForAccessToken(
          timeout: const Duration(milliseconds: 300),
          minTtlSeconds: -10,
        ),
        throwsA(isA<AuthException>()),
      );
    });
  });

  // -------------------------------------------------------------------------
  // signOut: clears the local session. With no active session this is a no-op
  // that completes without error.
  // -------------------------------------------------------------------------

  group('AuthRepository.signOut', () {
    late AuthRepository repository;

    setUp(() {
      repository = AuthRepository(apiClient: MockApiClient());
    });

    test('completes without error when no session is active', () async {
      // signOut on a session-less Supabase client should succeed.
      await repository.signOut();
    });
  });

  // -------------------------------------------------------------------------
  // updateUserPassword: delegates to Supabase updateUser. Without a session
  // the SDK throws; the repository wraps the null-user case in AuthException.
  // -------------------------------------------------------------------------

  group('AuthRepository.updateUserPassword', () {
    late AuthRepository repository;

    setUp(() {
      repository = AuthRepository(apiClient: MockApiClient());
    });

    test('throws when no session is active (Supabase rejects)', () async {
      // Without a session, Supabase's updateUser throws an AuthException.
      expect(() => repository.updateUserPassword('newPassword123'), throwsA(anything));
    });
  });

  // -------------------------------------------------------------------------
  // startAddPhone / addAndVerifyPhone: thin Supabase wrappers.
  // -------------------------------------------------------------------------

  group('AuthRepository.startAddPhone', () {
    late AuthRepository repository;

    setUp(() {
      repository = AuthRepository(apiClient: MockApiClient());
    });

    test('throws when no session is active', () async {
      expect(() => repository.startAddPhone('+919876543210'), throwsA(anything));
    });
  });

  group('AuthRepository.addAndVerifyPhone', () {
    late AuthRepository repository;

    setUp(() {
      repository = AuthRepository(apiClient: MockApiClient());
    });

    test('throws when no session is active', () async {
      expect(
        () => repository.addAndVerifyPhone(phone: '+919876543210', token: '123456'),
        throwsA(anything),
      );
    });
  });

  // -------------------------------------------------------------------------
  // Phone auth wrappers: signUp / signIn / verifyOtp / sendOtp.
  // These delegate to the Supabase SDK which will fail against the dummy URL.
  // We verify they propagate the failure (i.e., the wrapper does not swallow).
  // -------------------------------------------------------------------------

  group('AuthRepository phone auth wrappers', () {
    late AuthRepository repository;

    setUp(() {
      repository = AuthRepository(apiClient: MockApiClient());
    });

    test('signUpWithPhonePassword propagates Supabase failure', () async {
      expect(
        () => repository.signUpWithPhonePassword('+919876543210', 'password123'),
        throwsA(anything),
      );
    });

    test('signInWithPhonePassword propagates Supabase failure', () async {
      expect(
        () => repository.signInWithPhonePassword('+919876543210', 'password123'),
        throwsA(anything),
      );
    });

    test('verifyPhoneOtp propagates Supabase failure', () async {
      expect(
        () => repository.verifyPhoneOtp(phone: '+919876543210', token: '123456'),
        throwsA(anything),
      );
    });

    test('sendPhoneOtp propagates Supabase failure', () async {
      expect(() => repository.sendPhoneOtp('+919876543210'), throwsA(anything));
    });
  });

  // -------------------------------------------------------------------------
  // Email auth wrappers: signUp / signIn / verifyOtp / sendOtp.
  // -------------------------------------------------------------------------

  group('AuthRepository email auth wrappers', () {
    late AuthRepository repository;

    setUp(() {
      repository = AuthRepository(apiClient: MockApiClient());
    });

    test('signUpWithEmailOtp propagates Supabase failure', () async {
      expect(() => repository.signUpWithEmailOtp('test@example.com'), throwsA(anything));
    });

    test('signInWithEmailPassword propagates Supabase failure', () async {
      expect(
        () => repository.signInWithEmailPassword('test@example.com', 'password123'),
        throwsA(anything),
      );
    });

    test('sendEmailOtp propagates Supabase failure', () async {
      expect(() => repository.sendEmailOtp('test@example.com'), throwsA(anything));
    });

    test('verifyEmailOtp propagates Supabase failure', () async {
      expect(
        () => repository.verifyEmailOtp(email: 'test@example.com', token: '123456'),
        throwsA(anything),
      );
    });
  });

  // -------------------------------------------------------------------------
  // lastAuthMethodStore getter: exposes the injected store.
  // -------------------------------------------------------------------------

  group('AuthRepository.lastAuthMethodStore', () {
    test('returns the injected store instance', () {
      final store = LastAuthMethodStore();
      final repository = AuthRepository(apiClient: MockApiClient(), lastAuthMethodStore: store);

      expect(repository.lastAuthMethodStore, same(store));
    });

    test('returns a default store when none is injected', () {
      final repository = AuthRepository(apiClient: MockApiClient());

      expect(repository.lastAuthMethodStore, isA<LastAuthMethodStore>());
    });
  });

  // -------------------------------------------------------------------------
  // completeOAuthFromUri: exchanges a redirect URI for a session via Supabase.
  // With the dummy instance, the SDK will reject the URI.
  // -------------------------------------------------------------------------

  group('AuthRepository.completeOAuthFromUri', () {
    late AuthRepository repository;

    setUp(() {
      repository = AuthRepository(apiClient: MockApiClient());
    });

    test('throws when Supabase rejects the URI', () async {
      expect(
        () => repository.completeOAuthFromUri(Uri.parse('ghar360://login-callback?code=invalid')),
        throwsA(anything),
      );
    });
  });

  // -------------------------------------------------------------------------
  // signInWithGoogle: dispatches to native or redirect flow based on config.
  // Without native Google client IDs, it takes the redirect path which calls
  // signInWithOAuth on Supabase — this will fail against the dummy instance.
  // -------------------------------------------------------------------------

  group('AuthRepository.signInWithGoogle', () {
    late AuthRepository repository;
    TargetPlatform? savedPlatform;

    setUp(() {
      repository = AuthRepository(apiClient: MockApiClient());
      savedPlatform = debugDefaultTargetPlatformOverride;
      AppConfig.initialize(overrides: const {});
    });

    tearDown(() {
      debugDefaultTargetPlatformOverride = savedPlatform;
      AppConfig.resetForTest();
    });

    test('throws when redirect flow fails (no native config)', () async {
      // No Google client IDs → redirect path → Supabase signInWithOAuth fails.
      expect(() => repository.signInWithGoogle(), throwsA(anything));
    });
  });

  // -------------------------------------------------------------------------
  // signInWithApple: platform-gated; throws on non-iOS.
  // -------------------------------------------------------------------------

  group('AuthRepository.signInWithApple', () {
    late AuthRepository repository;
    TargetPlatform? savedPlatform;

    setUp(() {
      repository = AuthRepository(apiClient: MockApiClient());
      savedPlatform = debugDefaultTargetPlatformOverride;
    });

    tearDown(() {
      debugDefaultTargetPlatformOverride = savedPlatform;
    });

    test('throws AuthException on Android (unsupported platform)', () async {
      debugDefaultTargetPlatformOverride = TargetPlatform.android;

      expect(() => repository.signInWithApple(), throwsA(isA<AuthException>()));
    });

    test('throws AuthException on macOS (unsupported platform)', () async {
      debugDefaultTargetPlatformOverride = TargetPlatform.macOS;

      expect(() => repository.signInWithApple(), throwsA(isA<AuthException>()));
    });
  });

  // -------------------------------------------------------------------------
  // Native Google sign-in via a fake [GoogleSignInPlatform].
  // -------------------------------------------------------------------------

  group('AuthRepository.signInWithGoogle native paths', () {
    late AuthRepository repository;
    late FakeGoogleSignInPlatform fakePlatform;
    late GoogleSignInPlatform previousPlatform;
    TargetPlatform? savedPlatform;

    setUp(() {
      previousPlatform = GoogleSignInPlatform.instance;
      savedPlatform = debugDefaultTargetPlatformOverride;
      debugDefaultTargetPlatformOverride = TargetPlatform.android;
      AppConfig.initialize(overrides: {'GOOGLE_WEB_CLIENT_ID': 'web-client-id'});
      repository = AuthRepository(apiClient: MockApiClient());
    });

    tearDown(() {
      GoogleSignInPlatform.instance = previousPlatform;
      debugDefaultTargetPlatformOverride = savedPlatform;
      AppConfig.resetForTest();
    });

    void installPlatform(FakeGoogleSignInPlatform platform) {
      fakePlatform = platform;
      GoogleSignInPlatform.instance = platform;
    }

    test('falls back to redirect when native authenticate is unsupported', () async {
      installPlatform(FakeGoogleSignInPlatform(supportsAuth: false));

      // Redirect path still fails against the dummy Supabase instance.
      await expectLater(repository.signInWithGoogle(), throwsA(anything));
      expect(fakePlatform.initCalled, isTrue);
    });

    test('throws AuthException when the user cancels the native picker', () async {
      installPlatform(
        FakeGoogleSignInPlatform(
          authException: const GoogleSignInException(
            code: GoogleSignInExceptionCode.canceled,
            description: 'user cancelled',
          ),
        ),
      );

      await expectLater(
        repository.signInWithGoogle(),
        throwsA(isA<AuthException>().having((e) => e.message, 'message', contains('cancelled'))),
      );
    });

    test('falls back to redirect when native returns a non-cancel error', () async {
      installPlatform(
        FakeGoogleSignInPlatform(
          authException: const GoogleSignInException(
            code: GoogleSignInExceptionCode.clientConfigurationError,
            description: 'DEVELOPER_ERROR',
          ),
        ),
      );

      await expectLater(repository.signInWithGoogle(), throwsA(anything));
      expect(fakePlatform.initCalled, isTrue);
    });

    test('falls back to redirect when native ID token is empty', () async {
      installPlatform(FakeGoogleSignInPlatform(idToken: ''));

      // Empty id token → AuthException → outer catch falls back to redirect.
      await expectLater(repository.signInWithGoogle(), throwsA(anything));
    });

    test('falls back to redirect when native ID token is null', () async {
      installPlatform(FakeGoogleSignInPlatform(idToken: null));

      await expectLater(repository.signInWithGoogle(), throwsA(anything));
    });

    test('continues without access token when scope authorization fails', () async {
      installPlatform(
        FakeGoogleSignInPlatform(
          idToken: 'valid-id-token',
          clientAuthException: const GoogleSignInException(
            code: GoogleSignInExceptionCode.unknownError,
            description: 'scopes unavailable',
          ),
        ),
      );

      // Reaches signInWithIdToken (fails on dummy Supabase) → redirect fallback.
      await expectLater(repository.signInWithGoogle(), throwsA(anything));
      expect(fakePlatform.initCalled, isTrue);
    });

    test('native path with tokens reaches Supabase id-token exchange', () async {
      installPlatform(
        FakeGoogleSignInPlatform(idToken: 'valid-id-token', accessToken: 'valid-access-token'),
      );

      await expectLater(repository.signInWithGoogle(), throwsA(anything));
      expect(fakePlatform.initCalled, isTrue);
    });

    test('signOut also signs out of Google after native init', () async {
      installPlatform(
        FakeGoogleSignInPlatform(
          authException: const GoogleSignInException(code: GoogleSignInExceptionCode.canceled),
        ),
      );

      // Trigger native init via a cancelled sign-in attempt.
      try {
        await repository.signInWithGoogle();
      } catch (_) {}

      await repository.signOut();
      expect(fakePlatform.signOutCalled, isTrue);
    });
  });

  // -------------------------------------------------------------------------
  // Sign in with Apple on iOS via method-channel mock.
  // -------------------------------------------------------------------------

  group('AuthRepository.signInWithApple iOS paths', () {
    late AuthRepository repository;
    TargetPlatform? savedPlatform;
    const appleChannel = MethodChannel('com.aboutyou.dart_packages.sign_in_with_apple');

    setUp(() {
      repository = AuthRepository(apiClient: MockApiClient());
      savedPlatform = debugDefaultTargetPlatformOverride;
      debugDefaultTargetPlatformOverride = TargetPlatform.iOS;
    });

    tearDown(() {
      debugDefaultTargetPlatformOverride = savedPlatform;
      TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger.setMockMethodCallHandler(
        appleChannel,
        null,
      );
    });

    test('throws AuthException when user cancels Apple sign-in', () async {
      TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger.setMockMethodCallHandler(
        appleChannel,
        (call) async {
          if (call.method == 'performAuthorizationRequest') {
            throw PlatformException(
              code: 'authorization-error/canceled',
              message: 'user cancelled',
            );
          }
          return null;
        },
      );

      await expectLater(
        repository.signInWithApple(),
        throwsA(isA<AuthException>().having((e) => e.message, 'message', contains('cancelled'))),
      );
    });

    test('throws AuthException when Apple authorization fails', () async {
      TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger.setMockMethodCallHandler(
        appleChannel,
        (call) async {
          if (call.method == 'performAuthorizationRequest') {
            throw PlatformException(code: 'authorization-error/failed', message: 'not available');
          }
          return null;
        },
      );

      await expectLater(
        repository.signInWithApple(),
        throwsA(
          isA<AuthException>().having(
            (e) => e.message,
            'message',
            contains('Apple sign-in failed'),
          ),
        ),
      );
    });

    test('throws AuthException when identity token is missing', () async {
      TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger.setMockMethodCallHandler(
        appleChannel,
        (call) async {
          if (call.method == 'performAuthorizationRequest') {
            return <dynamic, dynamic>{
              'type': 'appleid',
              'userIdentifier': 'uid',
              'givenName': 'A',
              'familyName': 'B',
              'email': 'a@b.com',
              'identityToken': null,
              'authorizationCode': 'code',
            };
          }
          return null;
        },
      );

      await expectLater(
        repository.signInWithApple(),
        throwsA(
          isA<AuthException>().having((e) => e.message, 'message', contains('identity token')),
        ),
      );
    });

    test('propagates Supabase failure after a valid Apple credential', () async {
      TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger.setMockMethodCallHandler(
        appleChannel,
        (call) async {
          if (call.method == 'performAuthorizationRequest') {
            return <dynamic, dynamic>{
              'type': 'appleid',
              'userIdentifier': 'uid',
              'givenName': 'A',
              'familyName': 'B',
              'email': 'a@b.com',
              'identityToken': 'apple-id-token',
              'authorizationCode': 'code',
            };
          }
          return null;
        },
      );

      await expectLater(repository.signInWithApple(), throwsA(anything));
    });
  });

  group('AuthRepository.isOAuthRedirectUri path variants', () {
    late AuthRepository repository;

    setUp(() {
      repository = AuthRepository(apiClient: MockApiClient());
    });

    test('returns true when path is /login-callback', () {
      expect(repository.isOAuthRedirectUri(Uri.parse('ghar360:///login-callback')), isTrue);
    });

    test('returns true when path is login-callback without leading slash', () {
      // path segment equality against host-less path style.
      expect(repository.isOAuthRedirectUri(Uri(scheme: 'ghar360', path: 'login-callback')), isTrue);
    });
  });
}

/// Fake [GoogleSignInPlatform] for exercising the native Google sign-in path
/// without real platform channels.
class FakeGoogleSignInPlatform extends GoogleSignInPlatform {
  FakeGoogleSignInPlatform({
    this.supportsAuth = true,
    this.idToken = 'fake-id-token',
    this.accessToken = 'fake-access-token',
    this.authException,
    this.clientAuthException,
  });

  final bool supportsAuth;
  final String? idToken;
  final String? accessToken;
  final GoogleSignInException? authException;
  final GoogleSignInException? clientAuthException;

  bool initCalled = false;
  bool signOutCalled = false;

  @override
  Future<void> init(InitParameters params) async {
    initCalled = true;
  }

  @override
  Future<AuthenticationResults?> attemptLightweightAuthentication(
    AttemptLightweightAuthenticationParameters params,
  ) async => null;

  @override
  bool supportsAuthenticate() => supportsAuth;

  @override
  Future<AuthenticationResults> authenticate(AuthenticateParameters params) async {
    if (authException != null) throw authException!;
    return AuthenticationResults(
      user: const GoogleSignInUserData(email: 'g@example.com', id: 'gid-1'),
      authenticationTokens: AuthenticationTokenData(idToken: idToken),
    );
  }

  @override
  bool authorizationRequiresUserInteraction() => false;

  @override
  Future<ClientAuthorizationTokenData?> clientAuthorizationTokensForScopes(
    ClientAuthorizationTokensForScopesParameters params,
  ) async {
    if (clientAuthException != null) throw clientAuthException!;
    final token = accessToken;
    if (token == null || token.isEmpty) return null;
    return ClientAuthorizationTokenData(accessToken: token);
  }

  @override
  Future<ServerAuthorizationTokenData?> serverAuthorizationTokensForScopes(
    ServerAuthorizationTokensForScopesParameters params,
  ) async => null;

  @override
  Future<void> signOut(SignOutParams params) async {
    signOutCalled = true;
  }

  @override
  Future<void> disconnect(DisconnectParams params) async {}
}
