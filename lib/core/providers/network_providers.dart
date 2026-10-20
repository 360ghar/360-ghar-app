import 'dart:async';

import 'package:connectivity_plus/connectivity_plus.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:ghar360/core/config/app_config.dart';
import 'package:ghar360/core/network/api_client.dart';
import 'package:ghar360/core/network/auth_header_provider.dart';
import 'package:ghar360/core/network/etag_cache.dart';
import 'package:ghar360/core/network/sse_client.dart';
import 'package:ghar360/core/providers/app_database_provider.dart';
import 'package:ghar360/core/storage/app_database.dart';
import 'package:ghar360/core/utils/debug_logger.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

/// Bootstrap owns Supabase; tests override this composition dependency.
final supabaseClientProvider = Provider<SupabaseClient>((ref) => Supabase.instance.client);

final apiBaseUrlProvider = Provider<String>((ref) => AppConfig.instance.apiBaseUrl);

/// Per-attempt HTTP timeout from `API_TIMEOUT_SECONDS`; 15 s before config is loaded (tests).
final apiTimeoutSecondsProvider = Provider<int>(
  (ref) => AppConfig.isInitialized ? AppConfig.instance.apiTimeoutSeconds : 15,
);

final storageScopeProvider = NotifierProvider<StorageScopeNotifier, StorageScope>(
  StorageScopeNotifier.new,
);

/// Token refreshes keep the same lease. User changes invalidate old leases even
/// if that user later signs in again (A -> B -> A).
class StorageScopeNotifier extends Notifier<StorageScope> {
  @override
  StorageScope build() {
    final database = ref.watch(appDatabaseProvider);
    final client = ref.watch(supabaseClientProvider);
    final environment = ref.watch(apiBaseUrlProvider);
    var accountId = client.auth.currentUser?.id;
    final initial = database.activateScope(environment: environment, accountId: accountId);
    final subscription = client.auth.onAuthStateChange.listen(
      (event) {
        final nextAccountId = event.session?.user.id;
        if (nextAccountId == accountId) return;
        final previous = state;
        accountId = nextAccountId;
        state = database.activateScope(environment: environment, accountId: accountId);
        // The account that left keeps nothing of its own on the device: no cached listings or
        // profile and no unsent text. Pending actions stay with their account.
        if (previous.accountId != null && previous.key != state.key) {
          unawaited(
            database.purgeScope(previous.key).catchError((Object error, StackTrace stack) {
              DebugLogger.warning(
                'Signed-out account data was not purged.',
                error.runtimeType,
                stack,
              );
            }),
          );
        }
      },
      onError: (Object error, StackTrace stack) {
        DebugLogger.warning('Authentication state stream failed.', error.runtimeType, stack);
      },
    );
    ref.onDispose(() => unawaited(subscription.cancel()));
    return initial;
  }
}

final authHeaderProviderProvider = Provider<AuthHeaderProvider>((ref) {
  final provider = AuthHeaderProvider(supabaseClient: ref.watch(supabaseClientProvider));
  ref.listen(storageScopeProvider, (previous, next) => provider.invalidateSession());
  ref.onDispose(provider.invalidateSession);
  return provider;
});

final etagCacheProvider = Provider<ETagCache>((ref) {
  return ETagCache(
    database: ref.watch(appDatabaseProvider),
    scope: () => ref.read(storageScopeProvider),
  );
});

final apiClientProvider = Provider<ApiClient>((ref) {
  final client = ApiClient(
    baseUrl: ref.watch(apiBaseUrlProvider),
    authProvider: ref.watch(authHeaderProviderProvider),
    etagCache: ref.watch(etagCacheProvider),
    timeoutSeconds: ref.watch(apiTimeoutSecondsProvider),
  );
  // Keep the client stable and cancel in-flight work on account transitions.
  // Riverpod owns and closes the client when this provider is disposed.
  ref.listen(storageScopeProvider, (previous, next) => client.cancelPendingRequests());
  ref.onDispose(client.close);
  return client;
});

final sseClientProvider = Provider<SseClient>((ref) {
  // A 401 that survives the refresh on the assistant stream ends the session through the same
  // handler as every other request.
  final client = SseClient(
    authProvider: ref.watch(authHeaderProviderProvider),
    baseUrl: ref.watch(apiBaseUrlProvider),
    onUnauthorized: ref.watch(apiClientProvider).reportUnauthorized,
  );
  ref.listen(storageScopeProvider, (previous, next) => client.cancelPendingRequests());
  ref.onDispose(client.close);
  return client;
});

final connectivityProvider = Provider<Connectivity>((ref) => Connectivity());

/// False while the device has no network link. It reports links, not reach:
/// a request can still fail while this is true.
final isOnlineProvider = StreamProvider<bool>((ref) async* {
  final connectivity = ref.watch(connectivityProvider);
  bool online(List<ConnectivityResult> links) =>
      links.any((link) => link != ConnectivityResult.none);
  yield online(await connectivity.checkConnectivity());
  yield* connectivity.onConnectivityChanged.map(online);
});
