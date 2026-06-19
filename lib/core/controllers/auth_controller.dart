// lib/core/controllers/auth_controller.dart

import 'dart:async';

import 'package:firebase_crashlytics/firebase_crashlytics.dart';
import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:ghar360/core/data/models/auth_status.dart';
import 'package:ghar360/core/data/models/user_model.dart';
import 'package:ghar360/core/firebase/analytics_service.dart';
import 'package:ghar360/core/firebase/push_notifications_service.dart';
import 'package:ghar360/core/network/api_client.dart';
import 'package:ghar360/core/utils/app_toast.dart';
import 'package:ghar360/core/utils/debug_logger.dart';
import 'package:ghar360/core/utils/error_handler.dart';
import 'package:ghar360/features/auth/data/auth_repository.dart';
import 'package:ghar360/features/notifications/data/datasources/notifications_remote_datasource.dart';
import 'package:ghar360/features/profile/data/profile_repository.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

class AuthController extends GetxController {
  // Dependencies are resolved lazily in onInit() (not via field initializers)
  // so that registration order in InitialBinding can change without throwing
  // a cryptic "X not found" error. onInit() runs after the binding completes.
  late final AuthRepository _authRepository;
  late final ProfileRepository _profileRepository;
  late final NotificationsRemoteDatasource _notificationsDatasource;

  // --- Reactive State ---
  final Rx<AuthStatus> authStatus = AuthStatus.initial.obs;
  final Rxn<UserModel> currentUser = Rxn<UserModel>();
  final RxnString authErrorMessage = RxnString();
  final RxBool isLoading = false.obs;
  final RxBool isDeleting = false.obs;
  final RxBool isAuthResolving = false.obs;
  final Rxn<RouteSettings> redirectRoute = Rxn<RouteSettings>();

  /// Set when an OTP login completes for an account without a password.
  /// Forces a mandatory set-password screen before entering the app
  /// (closes requirement 6). Cleared once the password is set.
  bool _requiresPasswordSetup = false;

  StreamSubscription<User?>? _authSubscription;
  Timer? _debounceTimer;
  String? _lastProcessedAuthFingerprint;
  Worker? _crashlyticsWorker;
  bool _profileRetryInFlight = false;
  DateTime? _lastProfileRetryAttemptAt;
  bool _isHandlingUnauthorized = false;
  DateTime? _lastUnauthorizedHandledAt;
  String? _lastRegisteredNotificationToken;
  String? _lastRegisteredNotificationUserId;
  int _authProcessingGeneration = 0;
  Timer? _authResolvingTimeoutTimer;
  static const Duration _authResolvingMaxDuration = Duration(seconds: 60);
  static const Duration _tokenWaitTimeout = Duration(seconds: 10);
  static const Duration _initialProfileLoadTimeout = Duration(seconds: 50);
  static const Duration _profileRetryCooldown = Duration(seconds: 2);
  static const Duration _unauthorizedHandleCooldown = Duration(seconds: 8);
  static const Duration _authStateDebounce = Duration(
    milliseconds: 300,
  ); // Increased from 100ms for Supabase propagation
  static const int _maxBootRetries = 3;
  static const Duration _initialRetryDelay = Duration(seconds: 2);

  void _setAuthResolving(bool value) {
    isAuthResolving.value = value;
    _authResolvingTimeoutTimer?.cancel();
    if (value) {
      _authResolvingTimeoutTimer = Timer(_authResolvingMaxDuration, () {
        if (isAuthResolving.value) {
          DebugLogger.error(
            '⏰ isAuthResolving stuck true for '
            '${_authResolvingMaxDuration.inSeconds}s. '
            'Forcing recovery.',
          );
          isAuthResolving.value = false;
          if (authStatus.value != AuthStatus.authenticated &&
              authStatus.value != AuthStatus.unauthenticated) {
            _handleProfileLoadFailure(userMessage: 'auth_resolving_timeout'.tr);
          }
        }
      });
    }
  }

  @override
  void onInit() {
    super.onInit();
    _resolveDependencies();
    _setupCrashlyticsWorker();
    _setupUnauthorizedHandler();
    _initialize();
  }

  /// Resolves dependencies with a clear error message identifying which
  /// dependency is missing, so registration-order issues are easy to debug.
  void _resolveDependencies() {
    _authRepository = _findOrThrow<AuthRepository>('AuthRepository');
    _profileRepository = _findOrThrow<ProfileRepository>('ProfileRepository');
    _notificationsDatasource = _findOrThrow<NotificationsRemoteDatasource>(
      'NotificationsRemoteDatasource',
    );
  }

  T _findOrThrow<T>(String name) {
    if (!Get.isRegistered<T>()) {
      throw StateError(
        'AuthController: $name is not registered. Ensure InitialBinding registers '
        'it before AuthController.onInit().',
      );
    }
    return Get.find<T>();
  }

  /// Initialize the controller and listen to auth state changes.
  void _initialize() {
    // Listen to the stream from the repository
    _authSubscription = _authRepository.onAuthStateChange.listen(_onAuthStateChanged);
    DebugLogger.auth('AuthController initialized and listening for auth changes.');

    // Perform an initial check in case the stream has already emitted a value
    final initialUser = _authRepository.currentUser;
    if (initialUser != null) {
      _onAuthStateChanged(initialUser);
    } else {
      authStatus.value = AuthStatus.unauthenticated;
    }
  }

  /// Keeps Crashlytics context in sync with auth status.
  void _setupCrashlyticsWorker() {
    _crashlyticsWorker = ever(authStatus, (AuthStatus status) {
      try {
        FirebaseCrashlytics.instance.setCustomKey('auth_status', status.name);
      } catch (_) {}
    });
  }

  void _setupUnauthorizedHandler() {
    ApiClient.onUnauthorized = _handleUnauthorizedFromApi;
  }

  Future<void> _handleUnauthorizedFromApi(UnauthorizedEvent event) async {
    final error = event.error;
    if (error.code != 'UNAUTHORIZED') {
      return;
    }

    if (!event.isSessionCritical) {
      DebugLogger.warning(
        '🔐 [AUTH] Ignoring non-critical unauthorized response from ${event.endpoint}',
      );
      return;
    }

    if (authStatus.value == AuthStatus.unauthenticated || _isHandlingUnauthorized) {
      return;
    }

    final now = DateTime.now();
    final lastHandledAt = _lastUnauthorizedHandledAt;
    if (lastHandledAt != null && now.difference(lastHandledAt) < _unauthorizedHandleCooldown) {
      return;
    }

    _isHandlingUnauthorized = true;
    _lastUnauthorizedHandledAt = now;

    try {
      DebugLogger.warning(
        '🔐 [AUTH] Critical unauthorized response detected from ${event.endpoint}.',
      );

      ErrorHandler.showInfo('session_expired_message'.tr);
      await _authRepository.signOut();
    } catch (e, st) {
      DebugLogger.error(
        '🔐 [AUTH] Failed to resolve critical '
        'unauthorized response',
        e,
        st,
      );
      currentUser.value = null;
      _setAuthResolving(false);
      // Delay to allow stream listener to handle state first
      Future.delayed(const Duration(milliseconds: 500), () {
        if (authStatus.value != AuthStatus.unauthenticated) {
          authStatus.value = AuthStatus.unauthenticated;
        }
      });
    } finally {
      _isHandlingUnauthorized = false;
    }
  }

  /// Callback triggered when Supabase auth state changes (sign-in, sign-out, token refresh).
  /// Uses debouncing to prevent duplicate processing.
  Future<void> _onAuthStateChanged(User? supabaseUser) async {
    // Cancel any existing debounce timer
    _debounceTimer?.cancel();

    // Debounce rapid auth state changes to prevent duplicate processing
    // Using 300ms to ensure Supabase session is fully propagated
    _debounceTimer = Timer(_authStateDebounce, () {
      _processAuthStateChange(supabaseUser).catchError((Object error, StackTrace stackTrace) {
        DebugLogger.error('Unhandled error while processing auth state change', error, stackTrace);
        authStatus.value = AuthStatus.error;
        _setAuthResolving(false);
      });
    });
  }

  String _buildSessionFingerprint(User? supabaseUser) {
    final session = _authRepository.currentSession;
    final token = session?.accessToken ?? '';
    final tokenSuffix = token.isEmpty
        ? ''
        : token.substring(token.length >= 8 ? token.length - 8 : 0);
    return '${supabaseUser?.id ?? 'signed_out'}|${session?.expiresAt ?? 0}|$tokenSuffix';
  }

  /// Process the actual auth state change after debouncing
  Future<void> _processAuthStateChange(User? supabaseUser) async {
    final fingerprint = _buildSessionFingerprint(supabaseUser);
    if (_lastProcessedAuthFingerprint == fingerprint) {
      DebugLogger.debug('Skipping duplicate auth state change: $fingerprint');
      return;
    }

    _lastProcessedAuthFingerprint = fingerprint;
    final generation = ++_authProcessingGeneration;

    if (supabaseUser == null) {
      // --- USER IS SIGNED OUT ---
      DebugLogger.auth('Auth state changed: User is signed out.');
      authErrorMessage.value = null;
      currentUser.value = null;
      authStatus.value = AuthStatus.unauthenticated;
      _setAuthResolving(false);
      _profileRetryInFlight = false;
      _lastRegisteredNotificationToken = null;
      _lastRegisteredNotificationUserId = null;
      // Clear analytics/Crashlytics user context
      try {
        await AnalyticsService.setUserId(null);
        await FirebaseCrashlytics.instance.setUserIdentifier('');
      } catch (_) {}
    } else {
      // --- USER IS SIGNED IN ---
      DebugLogger.auth(
        'Auth state changed: User is signed in. '
        'UID: ${supabaseUser.id}',
      );
      authErrorMessage.value = null;
      _setAuthResolving(true);
      try {
        // Set analytics/Crashlytics user context
        if (_authProcessingGeneration != generation) return;
        try {
          await AnalyticsService.setUserId(supabaseUser.id);
          await FirebaseCrashlytics.instance.setUserIdentifier(supabaseUser.id);
        } catch (_) {}

        // Ensure access token is available before backend call
        if (_authProcessingGeneration != generation) return;
        await _ensureTokenThenLoadProfile();
      } finally {
        _setAuthResolving(false);
        DebugLogger.debug('🔐 [AUTH_BOOT] Auth bootstrap flow finished.');
      }
    }
  }

  Future<void> _ensureTokenThenLoadProfile() async {
    int attempt = 0;
    while (true) {
      try {
        DebugLogger.auth(
          '🔐 [AUTH_BOOT] Waiting for access token '
          '(attempt ${attempt + 1}/$_maxBootRetries)',
        );
        final token = await _authRepository.waitForAccessToken(
          timeout: _tokenWaitTimeout,
          minTtlSeconds: 45,
        );
        if (token.isEmpty) {
          throw Exception('Access token is empty after wait');
        }
        DebugLogger.auth(
          '🔐 [AUTH_BOOT] Access token ready '
          '(length: ${token.length}). '
          'Loading user profile...',
        );
        await _loadUserProfile();
        return; // Success
      } catch (e, st) {
        attempt++;
        if (attempt >= _maxBootRetries || !_isTransientError(e)) {
          DebugLogger.error('🔐 [AUTH_BOOT] Failed after $attempt attempt(s)', e, st);
          _handleProfileLoadFailure(userMessage: 'profile_load_error_user'.tr);
          return;
        }
        final delay = _initialRetryDelay * (1 << (attempt - 1));
        DebugLogger.warning(
          '🔐 [AUTH_BOOT] Attempt $attempt failed, '
          'retrying in ${delay.inSeconds}s...',
        );
        await Future.delayed(delay);
      }
    }
  }

  bool _isTransientError(Object error) {
    if (error is TimeoutException) return true;
    final msg = error.toString().toLowerCase();
    return msg.contains('timeout') ||
        msg.contains('network') ||
        msg.contains('socket') ||
        msg.contains('connection');
  }

  /// Fetches the user profile from our backend and updates the app's auth status.
  Future<void> _loadUserProfile() async {
    final profileLoadStartedAt = DateTime.now();
    try {
      DebugLogger.auth(
        '👤 [AUTH_BOOT] Fetching current user profile '
        '(timeout: ${_initialProfileLoadTimeout.inSeconds}s)',
      );

      final userProfile = await _profileRepository.getCurrentUserProfile().timeout(
        _initialProfileLoadTimeout,
      );

      final durationMs = DateTime.now().difference(profileLoadStartedAt).inMilliseconds;
      currentUser.value = userProfile;
      authErrorMessage.value = null;
      DebugLogger.success(
        '👤 [AUTH_BOOT] User profile loaded in ${durationMs}ms: ${userProfile.fullName}',
      );
      unawaited(_registerNotificationTokenIfAvailable(userProfile));

      // Determine the final auth status based on profile completeness.
      // A pending password-setup requirement (OTP login without a password)
      // takes precedence and gates entry into the app until resolved.
      final AuthStatus newStatus;
      if (_requiresPasswordSetup) {
        newStatus = AuthStatus.requiresPasswordSetup;
      } else if (userProfile.isProfileComplete) {
        newStatus = AuthStatus.authenticated;
      } else {
        newStatus = AuthStatus.requiresProfileCompletion;
      }

      // Only update if status actually changed to prevent unnecessary rebuilds
      if (authStatus.value != newStatus) {
        DebugLogger.auth('Changing auth status from ${authStatus.value} to $newStatus');
        authStatus.value = newStatus;

        if (newStatus == AuthStatus.authenticated) {
          DebugLogger.auth('User is fully authenticated and profile is complete.');
        } else {
          DebugLogger.auth('User authenticated, but $newStatus is required.');
          // Force a UI rebuild to ensure navigation happens
          Future.delayed(const Duration(milliseconds: 50), () {
            authStatus.refresh();
          });
        }
      }
    } on TimeoutException catch (e, stackTrace) {
      DebugLogger.error('👤 [AUTH_BOOT] Timed out while loading user profile.', e, stackTrace);
      _handleProfileLoadFailure(userMessage: 'profile_load_timeout'.tr);
    } catch (e, stackTrace) {
      DebugLogger.error('Failed to load user profile after sign-in.', e, stackTrace);
      _handleProfileLoadFailure(userMessage: 'profile_load_error_user'.tr);
    }
  }

  Future<void> _registerNotificationTokenIfAvailable(UserModel userProfile) async {
    final token = PushNotificationsService.currentToken;
    if (token == null || token.isEmpty) {
      return;
    }

    final authUserId = _authRepository.currentUser?.id;
    final resolvedUserId = authUserId != null && authUserId.isNotEmpty
        ? authUserId
        : userProfile.supabaseUserId;

    if (resolvedUserId.isEmpty) {
      DebugLogger.warning('🔔 Skipping device token registration: no authenticated user id');
      return;
    }

    if (_lastRegisteredNotificationToken == token &&
        _lastRegisteredNotificationUserId == resolvedUserId) {
      return;
    }

    for (var attempt = 0; attempt < 2; attempt++) {
      try {
        final registered = await _notificationsDatasource.registerDeviceToken(
          token: token,
          userId: resolvedUserId,
        );
        if (registered) {
          _lastRegisteredNotificationToken = token;
          _lastRegisteredNotificationUserId = resolvedUserId;
        }
        return; // Success
      } catch (e, st) {
        DebugLogger.warning(
          '🔔 Notification token registration '
          'attempt ${attempt + 1} failed',
          e,
          st,
        );
        if (attempt == 0) {
          await Future.delayed(const Duration(seconds: 5));
        }
      }
    }
  }

  void _handleProfileLoadFailure({required String userMessage}) {
    // If we already have a user and were authenticated, treat this as a transient refresh failure.
    // Do not knock the app into an error state; keep current auth status.
    if (currentUser.value != null && authStatus.value == AuthStatus.authenticated) {
      DebugLogger.warning('Transient profile refresh failure; preserving authenticated state.');
      try {
        if (Get.context != null) {
          ErrorHandler.showInfo('profile_refresh_failed'.tr);
        }
      } catch (_) {}
      return;
    }

    // Otherwise, this is initial load failure; set error state so user can retry or sign out.
    authErrorMessage.value = userMessage;
    authStatus.value = AuthStatus.error;
    DebugLogger.warning('👤 [AUTH_BOOT] Profile load failure surfaced to user: $userMessage');
  }

  /// Unregisters the push-notification device token (best-effort). Shared by
  /// [signOut] and [deleteAccount] so the device stops receiving notifications
  /// once the session ends.
  Future<void> _unregisterPushToken() async {
    final token = PushNotificationsService.currentToken;
    if (token != null && token.isNotEmpty) {
      try {
        await _notificationsDatasource.unregisterDeviceToken(token);
      } catch (e, st) {
        DebugLogger.warning('🔔 Failed to unregister device token during sign-out', e, st);
      }
    }
  }

  /// Signs out the user from Supabase. The `_onAuthStateChanged` listener will handle the rest.
  Future<void> signOut() async {
    try {
      isLoading.value = true;
      await _unregisterPushToken();
      await _authRepository.signOut();
      // The listener will automatically set the state to unauthenticated and navigation worker will handle routing
    } catch (e) {
      ErrorHandler.handleAuthError(e);
    } finally {
      isLoading.value = false;
    }
  }

  /// Permanently deletes the user's account. Unregisters the push token,
  /// submits the deletion request to the backend, then clears the local
  /// session; the auth-state listener routes to login.
  ///
  /// Returns `true` on success, `false` on failure so callers (e.g.
  /// `PrivacyView`) can branch on the outcome instead of always closing
  /// the confirmation dialog.
  Future<bool> deleteAccount() async {
    isDeleting.value = true;
    try {
      await _unregisterPushToken();
      await _authRepository.deleteAccount();
      await _authRepository.signOut(); // clears session; listener routes to login
      AppToast.success('success'.tr, 'account_deleted_success'.tr);
      return true;
    } catch (e, st) {
      ErrorHandler.handleAuthError(e, stackTrace: st);
      DebugLogger.error('Account deletion failed', e, st);
      return false;
    } finally {
      isDeleting.value = false;
    }
  }

  /// Allows the UI to retry loading the profile if it fails.
  Future<void> retryProfileLoad() async {
    if (authStatus.value == AuthStatus.error) {
      if (_profileRetryInFlight) {
        DebugLogger.debug('Retry profile load ignored: retry already in flight.');
        return;
      }

      final now = DateTime.now();
      final lastRetryAttemptAt = _lastProfileRetryAttemptAt;
      if (lastRetryAttemptAt != null &&
          now.difference(lastRetryAttemptAt) < _profileRetryCooldown) {
        DebugLogger.debug('Retry profile load ignored: cooldown active.');
        AppToast.info('retry_cooldown_title'.tr, 'retry_cooldown_message'.tr);
        return;
      }

      _profileRetryInFlight = true;
      _lastProfileRetryAttemptAt = now;
      DebugLogger.info('Retrying user profile load...');
      _setAuthResolving(true);
      try {
        await _ensureTokenThenLoadProfile();
      } finally {
        _profileRetryInFlight = false;
        _setAuthResolving(false);
      }
    }
  }

  /// Updates the user profile and refreshes the auth state.
  Future<bool> updateUserProfile(Map<String, dynamic> profileData) async {
    try {
      isLoading.value = true;
      final updatedUser = await _profileRepository.updateUserProfile(profileData);
      currentUser.value = updatedUser;

      DebugLogger.info(
        'Profile update: isComplete=${updatedUser.isProfileComplete}, '
        'authStatus=${authStatus.value}',
      );

      // After updating, re-evaluate the auth status.
      if (updatedUser.isProfileComplete &&
          authStatus.value == AuthStatus.requiresProfileCompletion) {
        authStatus.value = AuthStatus.authenticated;
      }

      AppToast.success('success'.tr, 'profile_updated_successfully'.tr);
      return true;
    } catch (e) {
      ErrorHandler.handleNetworkError(e);
      return false;
    } finally {
      isLoading.value = false;
    }
  }

  /// Updates the user's location using ProfileRepository
  Future<bool> updateUserLocation(Map<String, dynamic> locationData) async {
    try {
      await _profileRepository.updateUserLocation(locationData);
      return true;
    } catch (e) {
      DebugLogger.error('Failed to update user location', e);
      return false;
    }
  }

  /// Updates the user's preferences using ProfileRepository
  Future<bool> updateUserPreferences(Map<String, dynamic> preferences) async {
    try {
      final updatedUser = await _profileRepository.updateUserPreferences(preferences);
      currentUser.value = updatedUser;
      return true;
    } catch (e) {
      DebugLogger.error('Failed to update user preferences', e);
      return false;
    }
  }

  /// Marks that the just-authenticated OTP session has no password and must
  /// set one before entering the app. Call this BEFORE verifying the OTP so
  /// the [_loadUserProfile] status decision routes to the set-password screen.
  void markRequiresPasswordSetup() {
    _requiresPasswordSetup = true;
  }

  /// Clears a pending set-password requirement. Call this if the OTP verify
  /// that would have established the session fails, so a failed verify can't
  /// leave a stale set-password gate.
  void clearRequiresPasswordSetup() {
    _requiresPasswordSetup = false;
  }

  bool get requiresPasswordSetup => _requiresPasswordSetup;

  /// Completes the mandatory set-password step: sets the Supabase password,
  /// clears the pending flag, and re-evaluates the post-auth status so the
  /// user proceeds into profile completion / home.
  Future<bool> completePasswordSetup(String newPassword) async {
    try {
      isLoading.value = true;
      await _authRepository.updateUserPassword(newPassword);
      _requiresPasswordSetup = false;
      _setAuthResolving(true);
      await _loadUserProfile();
      return true;
    } catch (e, st) {
      DebugLogger.error('Failed to set password after OTP', e, st);
      ErrorHandler.handleAuthError(e);
      return false;
    } finally {
      _setAuthResolving(false);
      isLoading.value = false;
    }
  }

  @override
  void onClose() {
    _authSubscription?.cancel();
    _debounceTimer?.cancel();
    _authResolvingTimeoutTimer?.cancel();
    _crashlyticsWorker?.dispose();
    ApiClient.onUnauthorized = null;
    super.onClose();
  }

  // Convenience Getters
  bool get isAuthenticated => authStatus.value == AuthStatus.authenticated;
  String? get userEmail => currentUser.value?.email;
  String? get userId => _authRepository.currentUser?.id;
}
