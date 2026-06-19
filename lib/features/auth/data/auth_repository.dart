// lib/features/auth/data/auth_repository.dart

import 'dart:convert';
import 'dart:io' show Platform;
import 'dart:math';

import 'package:crypto/crypto.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter_dotenv/flutter_dotenv.dart';
import 'package:get/get.dart';
import 'package:ghar360/core/network/api_client.dart';
import 'package:ghar360/core/routes/app_routes.dart';
import 'package:ghar360/core/utils/debug_logger.dart';
import 'package:ghar360/features/auth/data/auth_method.dart';
import 'package:ghar360/features/auth/data/identifier_utils.dart';
import 'package:ghar360/features/auth/data/last_auth_method_store.dart';
import 'package:ghar360/features/auth/data/models/identifier_status.dart';
import 'package:google_sign_in/google_sign_in.dart';
import 'package:sign_in_with_apple/sign_in_with_apple.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

class AuthRepository extends GetxService {
  AuthRepository({ApiClient? apiClient, LastAuthMethodStore? lastAuthMethodStore})
    : _apiClient = apiClient,
      _lastAuthMethodStore = lastAuthMethodStore ?? LastAuthMethodStore();

  final _supabase = Supabase.instance.client;
  ApiClient? _apiClient;
  final LastAuthMethodStore _lastAuthMethodStore;
  bool _googleInitialized = false;

  static const int _defaultMinTokenTtlSeconds = 45;
  static const List<String> _googleScopes = <String>['email', 'profile'];

  ApiClient get _api => _apiClient ??= Get.find<ApiClient>();

  /// Local last-used-method persistence (read by the entry controller onInit).
  LastAuthMethodStore get lastAuthMethodStore => _lastAuthMethodStore;

  // --- STREAMS & GETTERS ---

  /// Stream of user authentication state changes from Supabase.
  Stream<User?> get onAuthStateChange =>
      _supabase.auth.onAuthStateChange.map((data) => data.session?.user);

  /// The current logged-in Supabase user.
  User? get currentUser => _supabase.auth.currentUser;

  /// The current active session, containing the JWT access token.
  Session? get currentSession => _supabase.auth.currentSession;

  // --- LOGIN STATE-MACHINE ---

  /// Calls the public `POST /api/v1/auth/identifier-status` endpoint to drive
  /// the login state-machine. [identifier] may be an email or a phone number;
  /// it is normalized before being sent.
  Future<IdentifierStatus> checkIdentifierStatus(String identifier) async {
    final normalized = IdentifierUtils.normalize(identifier);
    DebugLogger.auth('Checking identifier-status for: ${IdentifierUtils.mask(normalized)}');
    final response = await _api.post(
      '/auth/identifier-status',
      body: {'identifier': normalized},
      requireAuth: false,
      notifyUnauthorized: false,
      idempotent: true,
    );
    final body = response.body;
    if (body is! Map<String, dynamic>) {
      throw const FormatException('Unexpected identifier-status response shape');
    }
    final status = IdentifierStatus.fromJson(body);
    DebugLogger.auth('identifier-status → $status');
    return status;
  }

  /// Records the last-used auth method on the backend via
  /// `POST /api/v1/auth/last-method` (auth Bearer, returns 204) and mirrors it
  /// into local storage. Failures are swallowed (best-effort, non-blocking).
  Future<void> recordLastMethod(AuthMethod method, {String? identifier}) async {
    _lastAuthMethodStore.save(method, identifier: identifier);
    try {
      await _api.post('/auth/last-method', body: {'method': method.wireValue});
      DebugLogger.auth('Recorded last-method=${method.wireValue} on backend');
    } catch (e, st) {
      // Non-critical: local store already updated; backend mirror is best-effort.
      DebugLogger.warning('Failed to record last-method on backend', e, st);
    }
  }

  // --- GOOGLE SIGN-IN (native ID-token flow, google_sign_in v7) ---

  /// True when the native ID-token flow can be used: the platform-appropriate
  /// Google client ID is present. Android needs the WEB (server) client id;
  /// iOS needs the iOS client id. When false, we fall back to the Supabase
  /// OAuth redirect flow (the Google provider is enabled server-side).
  bool get isGoogleSignInConfigured {
    if (kIsWeb) return false;
    final hasWeb = (dotenv.env['GOOGLE_WEB_CLIENT_ID'] ?? '').trim().isNotEmpty;
    final hasIos = (dotenv.env['GOOGLE_IOS_CLIENT_ID'] ?? '').trim().isNotEmpty;
    if (Platform.isAndroid) return hasWeb;
    if (Platform.isIOS) return hasIos;
    return false;
  }

  /// Prefer the native ID-token flow only when a WEB client id is configured;
  /// otherwise use the Supabase OAuth redirect flow (works with the enabled
  /// Google provider without any native client IDs).
  bool get _preferNativeGoogle =>
      isGoogleSignInConfigured && (dotenv.env['GOOGLE_WEB_CLIENT_ID'] ?? '').trim().isNotEmpty;

  Future<void> _ensureGoogleInitialized() async {
    if (_googleInitialized) return;
    final webClientId = (dotenv.env['GOOGLE_WEB_CLIENT_ID'] ?? '').trim();
    final iosClientId = (dotenv.env['GOOGLE_IOS_CLIENT_ID'] ?? '').trim();
    await GoogleSignIn.instance.initialize(
      // Android serverClientId / token audience is the WEB client id.
      serverClientId: webClientId.isEmpty ? null : webClientId,
      // iOS uses its own OAuth client id.
      clientId: iosClientId.isEmpty ? null : iosClientId,
    );
    _googleInitialized = true;
  }

  /// Starts Google sign-in. Prefers the native ID-token flow when a WEB client
  /// id is configured, otherwise uses the Supabase OAuth redirect flow against
  /// the enabled Google provider.
  ///
  /// Resilience: if the native path fails for any reason OTHER than user
  /// cancellation (e.g. the per-app iOS/Android OAuth clients or SHA
  /// fingerprints aren't provisioned yet → DEVELOPER_ERROR / PlatformException),
  /// it automatically falls back to the redirect flow, which works with the
  /// already-enabled provider. User cancellation aborts quietly (no fallback).
  /// In both paths the `onAuthStateChange` listener in [AuthController] drives
  /// routing (and the post-Google add-phone prompt).
  ///
  /// Throws [AuthException] on failure/cancellation.
  Future<void> signInWithGoogle() async {
    if (!_preferNativeGoogle) {
      await _signInWithGoogleRedirect();
      return;
    }

    try {
      await _signInWithGoogleNative();
    } on _GoogleSignInCancelled {
      // User dismissed the native picker: abort quietly, do NOT fall back.
      throw const AuthException('Google sign-in was cancelled.');
    } catch (e, st) {
      // Any non-cancellation native failure (e.g. missing native OAuth client /
      // wrong SHA → DEVELOPER_ERROR) → fall back to the redirect flow.
      DebugLogger.warning('Native Google sign-in failed; falling back to redirect flow', e, st);
      await _signInWithGoogleRedirect();
    }
  }

  /// Native ID-token flow (google_sign_in v7) → `signInWithIdToken`.
  /// Throws [_GoogleSignInCancelled] on user cancellation so the dispatcher can
  /// distinguish it from real errors (which trigger the redirect fallback).
  Future<void> _signInWithGoogleNative() async {
    await _ensureGoogleInitialized();

    if (!GoogleSignIn.instance.supportsAuthenticate()) {
      // Fall back to the redirect flow if native isn't supported here.
      await _signInWithGoogleRedirect();
      return;
    }

    DebugLogger.auth('Starting native Google sign-in');
    final GoogleSignInAccount account;
    try {
      account = await GoogleSignIn.instance.authenticate(scopeHint: _googleScopes);
    } on GoogleSignInException catch (e) {
      if (e.code == GoogleSignInExceptionCode.canceled) {
        throw const _GoogleSignInCancelled();
      }
      DebugLogger.error('Google sign-in failed (${e.code})', e);
      throw AuthException('Google sign-in failed: ${e.description ?? e.code.name}');
    }

    final idToken = account.authentication.idToken;
    if (idToken == null || idToken.isEmpty) {
      throw const AuthException('Google did not return an ID token.');
    }

    // The access token is obtained via the authorization client in v7.
    String? accessToken;
    try {
      final authorization = await account.authorizationClient.authorizeScopes(_googleScopes);
      accessToken = authorization.accessToken;
    } on GoogleSignInException catch (e) {
      // Supabase only strictly requires the ID token; proceed without the
      // access token if scope authorization is unavailable.
      DebugLogger.warning('Google scope authorization unavailable: ${e.code.name}');
    }

    final response = await _supabase.auth.signInWithIdToken(
      provider: OAuthProvider.google,
      idToken: idToken,
      accessToken: accessToken,
    );

    await recordLastMethod(AuthMethod.google, identifier: response.user?.email);
    DebugLogger.success('Google sign-in successful (native)');
  }

  /// Supabase OAuth redirect flow. Opens the system browser; the redirect
  /// `ghar360://login-callback` is handled by the deep-link service, which
  /// calls [completeOAuthFromUri] to exchange the URI for a session.
  Future<void> _signInWithGoogleRedirect() async {
    DebugLogger.auth('Starting Google sign-in via Supabase OAuth redirect');
    final started = await _supabase.auth.signInWithOAuth(
      OAuthProvider.google,
      redirectTo: AppRoutes.oauthRedirectUrl,
      authScreenLaunchMode: LaunchMode.externalApplication,
    );
    if (!started) {
      throw const AuthException('Could not start Google sign-in.');
    }
    // Session is completed later when the redirect deep link returns.
  }

  /// True when [uri] is the Google OAuth redirect callback.
  bool isOAuthRedirectUri(Uri uri) {
    return uri.scheme == AppRoutes.oauthRedirectScheme &&
        (uri.host == AppRoutes.oauthRedirectHost ||
            uri.path == '/${AppRoutes.oauthRedirectHost}' ||
            uri.path == AppRoutes.oauthRedirectHost);
  }

  /// Exchanges the OAuth redirect [uri] for a Supabase session. Called from the
  /// deep-link handler because the SDK is initialized with
  /// `detectSessionInUri: false`. Records last-method=google on success.
  Future<void> completeOAuthFromUri(Uri uri) async {
    DebugLogger.auth('Completing OAuth from redirect URI');
    final response = await _supabase.auth.getSessionFromUrl(uri);
    await recordLastMethod(AuthMethod.google, identifier: response.session.user.email);
    DebugLogger.success('Google sign-in successful (redirect)');
  }

  // --- SIGN IN WITH APPLE (iOS; native ID-token flow) ---

  /// True when Sign in with Apple is available (iOS only, non-web).
  bool get isAppleSignInSupported => !kIsWeb && Platform.isIOS;

  /// Performs Sign in with Apple and exchanges the identity token with Supabase
  /// via `signInWithIdToken`. A raw nonce is hashed (SHA-256) and sent to Apple,
  /// while the raw nonce is passed to Supabase to bind the token. The
  /// `onAuthStateChange` listener in [AuthController] then drives routing.
  /// Records last-method=apple on success.
  Future<AuthResponse> signInWithApple() async {
    if (!isAppleSignInSupported) {
      throw const AuthException('Apple sign-in is not supported on this platform.');
    }

    final rawNonce = generateRawNonce();
    final hashedNonce = sha256OfString(rawNonce);

    DebugLogger.auth('Starting Sign in with Apple');
    final AuthorizationCredentialAppleID credential;
    try {
      credential = await SignInWithApple.getAppleIDCredential(
        scopes: const [AppleIDAuthorizationScopes.email, AppleIDAuthorizationScopes.fullName],
        nonce: hashedNonce,
      );
    } on SignInWithAppleAuthorizationException catch (e) {
      if (e.code == AuthorizationErrorCode.canceled) {
        throw const AuthException('Apple sign-in was cancelled.');
      }
      DebugLogger.error('Apple sign-in failed (${e.code})', e);
      throw AuthException('Apple sign-in failed: ${e.message}');
    }

    final idToken = credential.identityToken;
    if (idToken == null || idToken.isEmpty) {
      throw const AuthException('Apple did not return an identity token.');
    }

    final response = await _supabase.auth.signInWithIdToken(
      provider: OAuthProvider.apple,
      idToken: idToken,
      nonce: rawNonce,
    );

    await recordLastMethod(AuthMethod.apple, identifier: response.user?.email);
    DebugLogger.success('Apple sign-in successful');
    return response;
  }

  // --- PHONE AUTHENTICATION ---

  /// Signs up a new user with a phone number and password.
  /// Supabase will automatically send an OTP for verification.
  Future<AuthResponse> signUpWithPhonePassword(
    String phone,
    String password, {
    Map<String, dynamic>? data,
  }) {
    DebugLogger.auth('Attempting to sign up with phone: $phone');
    return _supabase.auth.signUp(phone: phone, password: password, data: data);
  }

  /// Signs in an existing user with their phone number and password.
  Future<AuthResponse> signInWithPhonePassword(String phone, String password) {
    DebugLogger.auth('Attempting to sign in with phone: $phone');
    return _supabase.auth.signInWithPassword(phone: phone, password: password);
  }

  /// Verifies the OTP sent to the user's phone to complete sign-up or sign-in.
  Future<AuthResponse> verifyPhoneOtp({required String phone, required String token}) {
    DebugLogger.auth('Verifying OTP for phone: $phone');
    return _supabase.auth.verifyOTP(phone: phone, token: token, type: OtpType.sms);
  }

  /// Sends a one-time password (OTP) to a phone for password reset or login.
  /// Login/reset only: never creates a new account (`shouldCreateUser: false`),
  /// so a mistyped/unknown number can't silently register. Signup uses
  /// [signUpWithPhonePassword] instead.
  Future<void> sendPhoneOtp(String phone) {
    DebugLogger.auth('Sending OTP to phone: $phone');
    return _supabase.auth.signInWithOtp(phone: phone, shouldCreateUser: false);
  }

  // --- EMAIL AUTHENTICATION ---

  /// Sends a 6-digit email OTP for signup (creates user with metadata).
  /// User sets their password after OTP verification via [updateUserPassword].
  Future<void> signUpWithEmailOtp(String email, {Map<String, dynamic>? data}) {
    DebugLogger.auth('Sending signup email OTP to: ${IdentifierUtils.mask(email)}');
    return _supabase.auth.signInWithOtp(
      email: email,
      data: data,
      shouldCreateUser: true,
      emailRedirectTo: AppRoutes.oauthRedirectUrl,
    );
  }

  /// Signs in an existing user with their email and password.
  Future<AuthResponse> signInWithEmailPassword(String email, String password) {
    DebugLogger.auth('Attempting to sign in with email: ${IdentifierUtils.mask(email)}');
    return _supabase.auth.signInWithPassword(email: email, password: password);
  }

  /// Sends a 6-digit email OTP for login or password reset.
  /// Login/reset only: never creates a new account (`shouldCreateUser: false`),
  /// so a mistyped/unknown email can't silently register. Signup uses
  /// [signUpWithEmailOtp] instead.
  Future<void> sendEmailOtp(String email) {
    DebugLogger.auth('Sending email OTP to: ${IdentifierUtils.mask(email)}');
    return _supabase.auth.signInWithOtp(
      email: email,
      shouldCreateUser: false,
      emailRedirectTo: AppRoutes.oauthRedirectUrl,
    );
  }

  /// Verifies the 6-digit email OTP (Supabase OtpType.email).
  Future<AuthResponse> verifyEmailOtp({required String email, required String token}) {
    DebugLogger.auth('Verifying email OTP for: ${IdentifierUtils.mask(email)}');
    return _supabase.auth.verifyOTP(email: email, token: token, type: OtpType.email);
  }

  // --- ADD-VERIFIED-PHONE (for passwordless Google users) ---

  /// Starts the add-verified-phone flow for an already-authenticated user by
  /// requesting a phone change; Supabase sends an SMS OTP to [phone].
  Future<void> startAddPhone(String phone) async {
    DebugLogger.auth('Requesting phone change to: $phone');
    await _supabase.auth.updateUser(UserAttributes(phone: phone));
  }

  /// Completes the add-verified-phone flow by verifying the phoneChange OTP.
  Future<AuthResponse> addAndVerifyPhone({required String phone, required String token}) {
    DebugLogger.auth('Verifying phoneChange OTP for: $phone');
    return _supabase.auth.verifyOTP(phone: phone, token: token, type: OtpType.phoneChange);
  }

  // --- PASSWORD MANAGEMENT ---

  /// Updates the current user's password. Requires the user to be logged in.
  Future<User> updateUserPassword(String newPassword) async {
    DebugLogger.auth('Updating user password.');
    final response = await _supabase.auth.updateUser(UserAttributes(password: newPassword));
    if (response.user == null) {
      throw const AuthException('Failed to update password. User not found.');
    }
    return response.user!;
  }

  /// Signs out the current user and invalidates their session.
  Future<void> signOut() async {
    DebugLogger.auth('Signing out user.');
    if (_googleInitialized) {
      try {
        await GoogleSignIn.instance.signOut();
      } catch (e) {
        DebugLogger.debug('Google signOut skipped/failed: $e');
      }
    }
    await _supabase.auth.signOut();
  }

  /// Submits an account-deletion request to the backend via
  /// `POST /api/v1/auth/delete-account` (auth Bearer). The backend schedules the
  /// erasure of the user's profile and personal data. Call [signOut] afterwards
  /// to clear the local session; the auth-state listener routes to login.
  Future<void> deleteAccount() async {
    DebugLogger.auth('Deleting user account.');
    await _api.post('/auth/delete-account');
    DebugLogger.success('Account deletion acknowledged by backend.');
  }

  // --- NONCE HELPERS (available for providers that require a hashed nonce) ---

  /// Generates a cryptographically-random raw nonce.
  static String generateRawNonce([int length = 32]) {
    const charset = 'ABCDEFGHIJKLMNOPQRSTUVWXYZabcdefghijklmnopqrstuvwxyz0123456789-._';
    final random = Random.secure();
    return List.generate(length, (_) => charset[random.nextInt(charset.length)]).join();
  }

  /// SHA-256 hash of [rawNonce] (sent to the provider; raw nonce to Supabase).
  static String sha256OfString(String rawNonce) {
    final bytes = utf8.encode(rawNonce);
    return sha256.convert(bytes).toString();
  }

  // --- TOKEN READINESS ---

  /// Waits for a valid access token to become available with robust retries.
  /// Useful immediately after signup/OTP verification where the session may lag.
  Future<String> waitForAccessToken({
    Duration timeout = const Duration(seconds: 8),
    int minTtlSeconds = _defaultMinTokenTtlSeconds,
  }) async {
    final effectiveMinTtlSeconds = minTtlSeconds < 0 ? 0 : minTtlSeconds;
    final deadline = DateTime.now().add(timeout);

    // Check immediately first
    Session? session = _supabase.auth.currentSession;
    if (_hasUsableAccessToken(session, minTtlSeconds: effectiveMinTtlSeconds)) {
      DebugLogger.auth(
        'Access token available immediately (length: ${session!.accessToken.length}, '
        'expiresIn: ${_sessionExpiresInSeconds(session)}s)',
      );
      return session.accessToken;
    }
    final immediateTtl = _sessionExpiresInSeconds(session);
    if (session?.accessToken.isNotEmpty == true) {
      DebugLogger.warning(
        'Access token present but stale/near expiry '
        '(expiresIn: ${immediateTtl ?? 'unknown'}s, '
        'minTtlRequired: ${effectiveMinTtlSeconds}s). Refreshing...',
      );
    }

    int refreshAttempts = 0;
    int pollCount = 0;
    const maxRefreshAttempts = 6;
    while (DateTime.now().isBefore(deadline)) {
      // Attempt periodic refreshes (throttled) to ensure token is ready
      if (refreshAttempts < maxRefreshAttempts) {
        try {
          DebugLogger.auth(
            'Attempting session refresh while waiting for access token (attempt ${refreshAttempts + 1})',
          );
          await _supabase.auth.refreshSession();
        } catch (e) {
          DebugLogger.debug('Session refresh attempt failed: $e');
        }
        refreshAttempts++;
      }
      await Future.delayed(const Duration(milliseconds: 200));
      pollCount++;

      session = _supabase.auth.currentSession;
      if (_hasUsableAccessToken(session, minTtlSeconds: effectiveMinTtlSeconds)) {
        DebugLogger.auth(
          'Access token obtained after $pollCount polls (length: ${session!.accessToken.length}, '
          'expiresIn: ${_sessionExpiresInSeconds(session)}s)',
        );
        return session.accessToken;
      }
    }

    DebugLogger.error(
      'Access token not available or still stale after ${timeout.inSeconds}s '
      'and $pollCount polls',
    );
    throw const AuthException('Access token not available in time');
  }

  bool _hasUsableAccessToken(Session? session, {required int minTtlSeconds}) {
    final token = session?.accessToken;
    if (token == null || token.isEmpty) return false;

    final expiresIn = _sessionExpiresInSeconds(session);
    if (expiresIn == null) {
      // If SDK doesn't expose expiry, treat token as usable and rely on server checks.
      return true;
    }
    return expiresIn > minTtlSeconds;
  }

  int? _sessionExpiresInSeconds(Session? session) {
    final expiresAt = session?.expiresAt;
    if (expiresAt == null) return null;
    final now = DateTime.now().millisecondsSinceEpoch ~/ 1000;
    return expiresAt - now;
  }
}

/// Internal signal: the user cancelled the native Google picker. Used to skip
/// the redirect fallback (cancellation should abort quietly).
class _GoogleSignInCancelled implements Exception {
  const _GoogleSignInCancelled();
}
