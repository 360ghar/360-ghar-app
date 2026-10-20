import 'dart:async';
import 'dart:convert';
import 'dart:math';

import 'package:crypto/crypto.dart';
import 'package:flutter/foundation.dart';
import 'package:ghar360/core/config/app_config.dart';
import 'package:ghar360/core/network/api_client.dart';
import 'package:ghar360/core/network/api_paths.dart';
import 'package:ghar360/core/network/auth_header_provider.dart';
import 'package:ghar360/core/storage/app_database.dart';
import 'package:ghar360/core/utils/debug_logger.dart';
import 'package:ghar360/features/auth/data/auth_method.dart';
import 'package:ghar360/features/auth/data/identifier_utils.dart';
import 'package:ghar360/features/auth/data/last_auth_method_store.dart';
import 'package:ghar360/features/auth/data/models/identifier_status.dart';
import 'package:google_sign_in/google_sign_in.dart';
import 'package:sign_in_with_apple/sign_in_with_apple.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

// lib/features/auth/data/auth_repository.dart

class AuthRepository {
  AuthRepository({
    required SupabaseClient supabaseClient,
    required ApiClient apiClient,
    required AppDatabase database,
    AuthHeaderProvider? authHeaderProvider,
    LastAuthMethodStore? lastAuthMethodStore,
  }) : _supabase = supabaseClient,
       _api = apiClient,
       _authHeaderProvider =
           authHeaderProvider ?? AuthHeaderProvider(supabaseClient: supabaseClient),
       _lastAuthMethodStore = lastAuthMethodStore ?? LastAuthMethodStore(database: database);

  final SupabaseClient _supabase;
  final ApiClient _api;
  final AuthHeaderProvider _authHeaderProvider;
  static const oauthRedirectUrl = 'ghar360://login-callback';
  static const oauthRedirectScheme = 'ghar360';
  static const oauthRedirectHost = 'login-callback';
  final LastAuthMethodStore _lastAuthMethodStore;
  bool _googleInitialized = false;

  static const int _defaultMinTokenTtlSeconds = 45;
  static const List<String> _googleScopes = <String>['email', 'profile'];

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
    DebugLogger.auth('Authentication request started');
    final response = await _api.post(
      ApiPaths.identifierStatus,
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
  /// `POST /api/v1/auth/last-method` (auth Bearer, answers 204 with no body) and mirrors it
  /// into local storage. Failures are swallowed (best-effort, non-blocking).
  Future<void> recordLastMethod(AuthMethod method, {String? identifier}) async {
    try {
      await _lastAuthMethodStore.save(method, identifier: identifier);
    } catch (error, stack) {
      DebugLogger.warning('Login preference could not be saved', error.runtimeType, stack);
    }
    try {
      await _api.post(ApiPaths.lastMethod, body: {'method': method.wire});
      DebugLogger.auth('Recorded last-method=${method.wire} on backend');
    } catch (e, st) {
      // Non-critical: local store already updated; backend mirror is best-effort.
      DebugLogger.warning('Failed to record last-method on backend', e.runtimeType, st);
    }
  }

  // --- GOOGLE SIGN-IN (native ID-token flow, google_sign_in v7) ---

  /// True when the native ID-token flow can be used: the platform-appropriate
  /// Google client ID is present. Android needs the WEB (server) client id;
  /// iOS needs the iOS client id. When false, we fall back to the Supabase
  /// OAuth redirect flow (the Google provider is enabled server-side).
  bool get isGoogleSignInConfigured {
    if (kIsWeb) return false;
    final config = AppConfig.instance;
    final hasWeb = config.googleWebClientId.isNotEmpty;
    final hasIos = config.googleIosClientId.isNotEmpty;
    if (defaultTargetPlatform == TargetPlatform.android) return hasWeb;
    if (defaultTargetPlatform == TargetPlatform.iOS) return hasIos;
    return false;
  }

  /// Prefer the native ID-token flow only when a WEB client id is configured;
  /// otherwise use the Supabase OAuth redirect flow (works with the enabled
  /// Google provider without any native client IDs).
  bool get _preferNativeGoogle =>
      isGoogleSignInConfigured && AppConfig.instance.googleWebClientId.isNotEmpty;

  Future<void> _ensureGoogleInitialized() async {
    if (_googleInitialized) return;
    final config = AppConfig.instance;
    final webClientId = config.googleWebClientId;
    final iosClientId = config.googleIosClientId;
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
      DebugLogger.warning('Native Google sign-in failed; using redirect flow', e.runtimeType, st);
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
      DebugLogger.error('Google sign-in failed', e.code);
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
      redirectTo: oauthRedirectUrl,
      authScreenLaunchMode: LaunchMode.externalApplication,
    );
    if (!started) {
      throw const AuthException('Could not start Google sign-in.');
    }
    // Session is completed later when the redirect deep link returns.
  }

  /// True when [uri] is the Google OAuth redirect callback.
  bool isOAuthRedirectUri(Uri uri) {
    return uri.scheme == oauthRedirectScheme &&
        (uri.host == oauthRedirectHost ||
            uri.path == '/$oauthRedirectHost' ||
            uri.path == oauthRedirectHost);
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
  bool get isAppleSignInSupported => !kIsWeb && defaultTargetPlatform == TargetPlatform.iOS;

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
      DebugLogger.error('Apple sign-in failed', e.code);
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
    DebugLogger.auth('Authentication request started');
    return _supabase.auth.signUp(phone: phone, password: password, data: data);
  }

  /// Signs in an existing user with their phone number and password.
  Future<AuthResponse> signInWithPhonePassword(String phone, String password) {
    DebugLogger.auth('Authentication request started');
    return _supabase.auth.signInWithPassword(phone: phone, password: password);
  }

  /// Verifies the OTP sent to the user's phone to complete sign-up or sign-in.
  Future<AuthResponse> verifyPhoneOtp({required String phone, required String token}) {
    DebugLogger.auth('Authentication request started');
    return _supabase.auth.verifyOTP(phone: phone, token: token, type: OtpType.sms);
  }

  /// Sends a one-time password (OTP) to a phone for password reset or login.
  /// Login/reset only: never creates a new account (`shouldCreateUser: false`),
  /// so a mistyped/unknown number can't silently register. Signup uses
  /// [signUpWithPhonePassword] instead.
  Future<void> sendPhoneOtp(String phone) {
    DebugLogger.auth('Authentication request started');
    return _supabase.auth.signInWithOtp(phone: phone, shouldCreateUser: false);
  }

  // --- EMAIL AUTHENTICATION ---

  /// Sends a 6-digit email OTP for signup (creates user with metadata).
  /// User sets their password after OTP verification via [updateUserPassword].
  Future<void> signUpWithEmailOtp(String email, {Map<String, dynamic>? data}) {
    DebugLogger.auth('Authentication request started');
    return _supabase.auth.signInWithOtp(
      email: email,
      data: data,
      shouldCreateUser: true,
      emailRedirectTo: oauthRedirectUrl,
    );
  }

  /// Signs in an existing user with their email and password.
  Future<AuthResponse> signInWithEmailPassword(String email, String password) {
    DebugLogger.auth('Authentication request started');
    return _supabase.auth.signInWithPassword(email: email, password: password);
  }

  /// Sends a 6-digit email OTP for login or password reset.
  /// Login/reset only: never creates a new account (`shouldCreateUser: false`),
  /// so a mistyped/unknown email can't silently register. Signup uses
  /// [signUpWithEmailOtp] instead.
  Future<void> sendEmailOtp(String email) {
    DebugLogger.auth('Authentication request started');
    return _supabase.auth.signInWithOtp(
      email: email,
      shouldCreateUser: false,
      emailRedirectTo: oauthRedirectUrl,
    );
  }

  /// Verifies the 6-digit email OTP (Supabase OtpType.email).
  Future<AuthResponse> verifyEmailOtp({required String email, required String token}) {
    DebugLogger.auth('Authentication request started');
    return _supabase.auth.verifyOTP(email: email, token: token, type: OtpType.email);
  }

  // --- ADD-VERIFIED-PHONE (for passwordless Google users) ---

  /// Starts the add-verified-phone flow for an already-authenticated user by
  /// requesting a phone change; Supabase sends an SMS OTP to [phone].
  Future<void> startAddPhone(String phone) async {
    DebugLogger.auth('Authentication request started');
    await _supabase.auth.updateUser(UserAttributes(phone: phone));
  }

  /// Completes the add-verified-phone flow by verifying the phoneChange OTP.
  Future<AuthResponse> addAndVerifyPhone({required String phone, required String token}) {
    DebugLogger.auth('Authentication request started');
    return _supabase.auth.verifyOTP(phone: phone, token: token, type: OtpType.phoneChange);
  }

  /// Asks Supabase to change the sign-in email to [email]. Supabase mails a confirmation link
  /// to the new address, and the account keeps the old one until it is opened. A no-op when
  /// [email] is already the address or is already waiting for confirmation. The profile route
  /// takes no email: this is the only way an email changes.
  Future<void> requestEmailChange(String email) async {
    final address = email.trim();
    final user = _supabase.auth.currentUser;
    bool same(String? other) => other != null && other.toLowerCase() == address.toLowerCase();
    if (address.isEmpty || same(user?.email) || same(user?.newEmail)) return;
    DebugLogger.auth('Requesting an email change.');
    await _supabase.auth.updateUser(UserAttributes(email: address));
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
        DebugLogger.debug('Native Google sign-out unavailable');
      }
    }
    await _supabase.auth.signOut();
  }

  /// Deletes the account through `DELETE /api/v1/users/me` (auth Bearer, answers 204 with no
  /// body). The backend erases the user's profile and personal data. Call [signOut] afterwards
  /// to clear the local session; the auth-state listener routes to login.
  Future<void> deleteAccount() async {
    DebugLogger.auth('Deleting user account.');
    await _api.delete(ApiPaths.usersMe);
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
    final session = _supabase.auth.currentSession;
    final minimum = minTtlSeconds < 0 ? 0 : minTtlSeconds;
    if (_hasUsableAccessToken(session, minTtlSeconds: minimum)) return session!.accessToken;
    // The shared header provider owns one coalesced refresh; do not add another
    // retry loop here. Offline refresh preserves the typed NetworkException.
    final header = await _authHeaderProvider.getAuthHeader().timeout(timeout);
    final refreshed = _supabase.auth.currentSession;
    if (header == null || !_hasUsableAccessToken(refreshed, minTtlSeconds: minimum)) {
      throw TimeoutException('The session is not ready.', timeout);
    }
    return refreshed!.accessToken;
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
