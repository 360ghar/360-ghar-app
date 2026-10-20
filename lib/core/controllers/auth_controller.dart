import 'dart:async';

import 'package:firebase_crashlytics/firebase_crashlytics.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:ghar360/core/data/models/auth_status.dart';
import 'package:ghar360/core/data/models/user_model.dart';
import 'package:ghar360/core/firebase/analytics_service.dart';
import 'package:ghar360/core/firebase/push_notifications_service.dart';
import 'package:ghar360/core/network/api_client.dart';
import 'package:ghar360/core/providers/app_database_provider.dart';
import 'package:ghar360/core/providers/auth_providers.dart';
import 'package:ghar360/core/providers/network_providers.dart';
import 'package:ghar360/core/storage/app_database.dart';
import 'package:ghar360/core/utils/app_exceptions.dart';
import 'package:ghar360/core/utils/debug_logger.dart';
import 'package:ghar360/features/auth/data/auth_failure.dart';
import 'package:ghar360/features/auth/data/auth_repository.dart';
import 'package:ghar360/features/notifications/data/datasources/notifications_remote_datasource.dart';
import 'package:ghar360/features/profile/data/profile_repository.dart';
import 'package:supabase_flutter/supabase_flutter.dart' show User;

const _unchanged = Object();

enum AuthMutation { none, signOut, deleteAccount, updateProfile, updateAvatar, setPassword }

@immutable
class AuthState {
  const AuthState({
    this.status = AuthStatus.initial,
    this.user,
    this.error,
    this.resolving = false,
    this.stale = false,
    this.profileCompletionDeferred = false,
    this.mutation = const AsyncData(null),
    this.mutationKind = AuthMutation.none,
  });
  final AuthStatus status;
  final UserModel? user;
  final AppException? error;
  final bool resolving;
  final bool stale;
  final bool profileCompletionDeferred;
  final AsyncValue<void> mutation;
  final AuthMutation mutationKind;
  bool get isAuthenticated => status == AuthStatus.authenticated;

  AuthState copyWith({
    AuthStatus? status,
    Object? user = _unchanged,
    Object? error = _unchanged,
    bool? resolving,
    bool? stale,
    bool? profileCompletionDeferred,
    AsyncValue<void>? mutation,
    AuthMutation? mutationKind,
  }) => AuthState(
    status: status ?? this.status,
    user: identical(user, _unchanged) ? this.user : user as UserModel?,
    error: identical(error, _unchanged) ? this.error : error as AppException?,
    resolving: resolving ?? this.resolving,
    stale: stale ?? this.stale,
    profileCompletionDeferred: profileCompletionDeferred ?? this.profileCompletionDeferred,
    mutation: mutation ?? this.mutation,
    mutationKind: mutationKind ?? this.mutationKind,
  );
}

final authProvider = NotifierProvider<AuthController, AuthState>(AuthController.new);

/// Session state has no navigation or presentation controllers.
class AuthController extends Notifier<AuthState> {
  late AuthRepository _auth;
  late ProfileRepository _profiles;
  late NotificationsRemoteDatasource _notifications;
  late AppDatabase _database;
  late ApiClient _client;
  String? _accountId;
  String? _registeredToken;
  int _generation = 0;
  bool _passwordRequired = false;
  bool _handlingUnauthorized = false;
  DateTime? _lastRetry;

  @override
  AuthState build() {
    _auth = ref.watch(authRepositoryProvider);
    _profiles = ref.watch(profileRepositoryProvider);
    _notifications = ref.watch(notificationsDatasourceProvider);
    _database = ref.watch(appDatabaseProvider);
    _client = ref.watch(apiClientProvider);
    // Establish account scope subscription before accepting profile responses.
    ref.read(storageScopeProvider);
    final generation = ++_generation;
    _accountId = _auth.currentUser?.id;
    final handler = _handleUnauthorized;
    _client.onUnauthorized = handler;
    final subscription = _auth.onAuthStateChange.listen(
      _acceptSession,
      onError: (Object error, StackTrace stack) {
        if (!ref.mounted) return;
        state = state.copyWith(
          error: authFailure(error),
          resolving: false,
          status: state.user == null ? AuthStatus.error : state.status,
          stale: state.user != null,
        );
        DebugLogger.warning('Session stream failed', error.runtimeType, stack);
      },
    );
    ref.onDispose(() {
      _generation++;
      unawaited(subscription.cancel());
      if (identical(_client.onUnauthorized, handler)) _client.onUnauthorized = null;
    });
    if (_accountId == null) return const AuthState(status: AuthStatus.unauthenticated);
    Future.microtask(() {
      if (_isCurrent(generation)) unawaited(_loadProfile(generation));
    });
    return const AuthState(resolving: true);
  }

  bool _isCurrent(int generation) =>
      ref.mounted && generation == _generation && _auth.currentUser?.id == _accountId;

  void _acceptSession(User? user) {
    if (!ref.mounted) return;
    if (user?.id == _accountId && (state.user != null || state.resolving)) return;
    final generation = ++_generation;
    if (_accountId != null && _accountId != user?.id) _passwordRequired = false;
    _accountId = user?.id;
    _registeredToken = null;
    _client.cancelPendingRequests();
    if (user == null) {
      _passwordRequired = false;
      state = const AuthState(status: AuthStatus.unauthenticated);
      AnalyticsService.clearSessionState();
      unawaited(_telemetry(null));
      return;
    }
    state = const AuthState(resolving: true);
    unawaited(_telemetry(user.id));
    unawaited(_loadProfile(generation));
  }

  AuthStatus _statusFor(UserModel user) => _passwordRequired
      ? AuthStatus.requiresPasswordSetup
      : user.isProfileComplete || state.profileCompletionDeferred
      ? AuthStatus.authenticated
      : AuthStatus.requiresProfileCompletion;

  Future<void> _loadProfile(int generation) async {
    if (!_isCurrent(generation) || _accountId == null) return;
    final scope = ref.read(storageScopeProvider);
    // A cached profile is only useful for the active authenticated SDK account.
    if (scope.accountId != _accountId) {
      state = state.copyWith(
        resolving: false,
        status: AuthStatus.error,
        error: AuthenticationException('Account scope is not ready.', code: 'SESSION_NOT_READY'),
      );
      return;
    }
    if (state.user == null) {
      try {
        final cached = await _database.readCache(scope: scope, key: 'auth-profile');
        if (!_isCurrent(generation)) return;
        if (cached?.value case final Map raw) {
          final user = UserModel.fromJson(Map<String, dynamic>.from(raw));
          if (user.supabaseUserId == _accountId) {
            state = state.copyWith(
              user: user,
              status: _statusFor(user),
              stale: true,
              resolving: true,
            );
          }
        }
      } catch (error, stack) {
        DebugLogger.warning('Cached profile unavailable', error.runtimeType, stack);
      }
    }
    try {
      final token = await _auth.waitForAccessToken(
        timeout: const Duration(seconds: 10),
        minTtlSeconds: 45,
      );
      if (token.isEmpty) {
        throw AuthenticationException('Session is not ready.', code: 'SESSION_NOT_READY');
      }
      if (!_isCurrent(generation)) return;
      final user = await _profiles.getCurrentUserProfile().timeout(const Duration(seconds: 30));
      if (!_isCurrent(generation)) return;
      if (user.supabaseUserId != _accountId) {
        throw AuthenticationException('Profile account did not match.', code: 'ACCOUNT_MISMATCH');
      }
      state = state.copyWith(
        user: user,
        status: _statusFor(user),
        error: null,
        stale: false,
        resolving: false,
      );
      unawaited(_registerPush(generation));
      await _cacheProfile(user, scope, generation);
    } catch (error, stack) {
      if (!_isCurrent(generation)) return;
      state = state.copyWith(
        error: authFailure(error),
        resolving: false,
        stale: state.user != null,
        status: state.user == null ? AuthStatus.error : _statusFor(state.user!),
      );
      DebugLogger.warning('Profile request failed', error.runtimeType, stack);
    }
  }

  Future<void> _cacheProfile(UserModel user, StorageScope scope, int generation) async {
    try {
      final now = DateTime.now().toUtc();
      await _database.writeCache(
        scope: scope,
        key: 'auth-profile',
        value: user.toJson(),
        freshUntil: now.add(const Duration(minutes: 5)),
        expiresAt: now.add(const Duration(hours: 24)),
      );
    } catch (error, stack) {
      if (_isCurrent(generation)) state = state.copyWith(error: authFailure(error));
      DebugLogger.warning('Profile cache write failed', error.runtimeType, stack);
    }
  }

  Future<void> _handleUnauthorized(UnauthorizedEvent event) async {
    // A 401 that survived the token refresh, or a 403 USER_INACTIVE, ends the session. A refresh
    // that could not reach Supabase is not proof of an expired session, and a failure raised on
    // the device carries no status, so neither ends it.
    if (!event.error.endsSession || _handlingUnauthorized || _accountId == null) return;
    _handlingUnauthorized = true;
    final scope = ref.read(storageScopeProvider);
    try {
      final signedOut = await signOut();
      if (!signedOut && ref.mounted && identical(ref.read(storageScopeProvider), scope)) {
        // A confirmed backend rejection must never leave protected UI active.
        _client.cancelPendingRequests();
        _acceptSession(null);
      }
    } finally {
      _handlingUnauthorized = false;
    }
  }

  Future<void> recheckAuthBootstrap() async {
    if (state.resolving) return;
    if (_auth.currentUser == null) {
      _acceptSession(null);
      return;
    }
    _accountId = _auth.currentUser!.id;
    final generation = ++_generation;
    state = state.copyWith(resolving: true, error: null);
    await _loadProfile(generation);
  }

  Future<void> retryProfileLoad() async {
    if (state.resolving) return;
    final now = DateTime.now();
    if (_lastRetry != null && now.difference(_lastRetry!) < const Duration(seconds: 2)) return;
    _lastRetry = now;
    await recheckAuthBootstrap();
  }

  Future<bool> signOut() async {
    if (state.mutation.isLoading) return false;
    final generation = ++_generation;
    _client.cancelPendingRequests();
    state = state.copyWith(
      resolving: false,
      mutationKind: AuthMutation.signOut,
      mutation: const AsyncLoading(),
    );
    try {
      await _unregisterPush();
      if (!_isCurrent(generation)) return false;
      await _auth.signOut();
      if (ref.mounted && generation == _generation) _acceptSession(null);
      return true;
    } catch (error, stack) {
      if (ref.mounted && generation == _generation) {
        state = state.copyWith(mutation: AsyncError(authFailure(error), stack));
      }
      return false;
    }
  }

  Future<bool> deleteAccount() async {
    if (state.mutation.isLoading) return false;
    final generation = _generation;
    state = state.copyWith(
      mutationKind: AuthMutation.deleteAccount,
      mutation: const AsyncLoading(),
    );
    try {
      await _unregisterPush();
      if (!_isCurrent(generation)) return false;
      await _auth.deleteAccount();
      if (!_isCurrent(generation)) return false;
      await _auth.signOut();
      if (_isCurrent(generation)) _acceptSession(null);
      return true;
    } catch (error, stack) {
      if (_isCurrent(generation)) {
        state = state.copyWith(mutation: AsyncError(authFailure(error), stack));
      }
      return false;
    }
  }

  Future<bool> updateUserProfile(Map<String, dynamic> profileData) async {
    if (state.mutation.isLoading) return false;
    final generation = _generation;
    final scope = ref.read(storageScopeProvider);
    state = state.copyWith(
      mutationKind: AuthMutation.updateProfile,
      mutation: const AsyncLoading(),
    );
    try {
      final user = await _profiles.updateUserProfile(profileData);
      if (!_isCurrent(generation)) return false;
      if (user.supabaseUserId != _accountId) {
        throw AuthenticationException('Profile account did not match.', code: 'ACCOUNT_MISMATCH');
      }
      state = state.copyWith(
        user: user,
        status: _statusFor(user),
        stale: false,
        error: null,
        mutation: const AsyncData(null),
      );
      await _cacheProfile(user, scope, generation);
      return _isCurrent(generation);
    } catch (error, stack) {
      if (_isCurrent(generation)) {
        state = state.copyWith(mutation: AsyncError(authFailure(error), stack));
      }
      return false;
    }
  }

  /// Merges [patch] into the stored preferences (`PUT /users/preferences`) and shows the
  /// preferences the backend now holds.
  Future<bool> updateUserPreferences(Map<String, dynamic> patch) async {
    if (state.mutation.isLoading || state.user == null) return false;
    final generation = _generation;
    final scope = ref.read(storageScopeProvider);
    state = state.copyWith(
      mutationKind: AuthMutation.updateProfile,
      mutation: const AsyncLoading(),
    );
    try {
      final preferences = await _profiles.updateUserPreferences(patch);
      final current = state.user;
      if (!_isCurrent(generation) || current == null) return false;
      final user = current.copyWith(preferences: preferences);
      state = state.copyWith(user: user, error: null, mutation: const AsyncData(null));
      await _cacheProfile(user, scope, generation);
      return _isCurrent(generation);
    } catch (error, stack) {
      if (_isCurrent(generation)) {
        state = state.copyWith(mutation: AsyncError(authFailure(error), stack));
      }
      return false;
    }
  }

  Future<bool> updateProfileImage(String imagePath) async {
    if (state.mutation.isLoading || _accountId == null) return false;
    final generation = _generation;
    final scope = ref.read(storageScopeProvider);
    state = state.copyWith(mutationKind: AuthMutation.updateAvatar, mutation: const AsyncLoading());
    try {
      final user = await _profiles.updateProfileImage(imagePath);
      if (!_isCurrent(generation)) return false;
      if (user.supabaseUserId != _accountId) {
        throw AuthenticationException('Profile account did not match.', code: 'ACCOUNT_MISMATCH');
      }
      state = state.copyWith(
        user: user,
        status: _statusFor(user),
        stale: false,
        error: null,
        mutation: const AsyncData(null),
      );
      await _cacheProfile(user, scope, generation);
      return _isCurrent(generation);
    } catch (error, stack) {
      if (_isCurrent(generation)) {
        state = state.copyWith(mutation: AsyncError(authFailure(error), stack));
      }
      return false;
    }
  }

  /// Called only after the required purpose preference has been saved.
  void deferProfileCompletion() {
    if (_accountId == null || state.user == null || _passwordRequired) return;
    state = state.copyWith(profileCompletionDeferred: true, status: AuthStatus.authenticated);
  }

  void markRequiresPasswordSetup() {
    _passwordRequired = true;
    if (state.user != null) state = state.copyWith(status: AuthStatus.requiresPasswordSetup);
  }

  void clearRequiresPasswordSetup() {
    _passwordRequired = false;
    if (state.user != null) state = state.copyWith(status: _statusFor(state.user!));
  }

  bool get requiresPasswordSetup => _passwordRequired;

  Future<bool> completePasswordSetup(String password) async {
    if (state.mutation.isLoading) return false;
    final generation = _generation;
    state = state.copyWith(mutationKind: AuthMutation.setPassword, mutation: const AsyncLoading());
    try {
      await _auth.updateUserPassword(password);
      if (!_isCurrent(generation)) return false;
      _passwordRequired = false;
      state = state.copyWith(mutation: const AsyncData(null), resolving: true);
      await _loadProfile(generation);
      return true;
    } catch (error, stack) {
      if (_isCurrent(generation)) {
        state = state.copyWith(mutation: AsyncError(authFailure(error), stack));
      }
      return false;
    }
  }

  Future<void> _registerPush(int generation) async {
    final token = PushNotificationsService.currentToken;
    if (token == null || token.isEmpty || token == _registeredToken || _accountId == null) return;
    try {
      if (!_isCurrent(generation)) return;
      final registered = await _notifications.registerDeviceToken(token: token);
      if (registered && _isCurrent(generation)) _registeredToken = token;
    } catch (error, stack) {
      DebugLogger.warning('Device token registration failed', error.runtimeType, stack);
    }
  }

  Future<void> _unregisterPush() async {
    final token = PushNotificationsService.currentToken;
    if (token == null || token.isEmpty) return;
    try {
      await _notifications.unregisterDeviceToken(token).timeout(const Duration(seconds: 5));
    } catch (error, stack) {
      DebugLogger.warning('Device token removal failed', error.runtimeType, stack);
    }
  }

  Future<void> _telemetry(String? id) async {
    try {
      await AnalyticsService.setUserId(id);
      await FirebaseCrashlytics.instance.setUserIdentifier(id ?? '');
    } catch (error, stack) {
      DebugLogger.debug('Session diagnostics unavailable', error.runtimeType, stack);
    }
  }

  bool get isAuthenticated => state.isAuthenticated;
  String? get userEmail => state.user?.email;
  String? get userId => _accountId;
}
