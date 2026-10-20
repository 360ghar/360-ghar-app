import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:ghar360/core/providers/app_database_provider.dart';
import 'package:ghar360/core/providers/network_providers.dart';
import 'package:ghar360/features/auth/data/auth_repository.dart';
import 'package:ghar360/features/notifications/data/datasources/notifications_remote_datasource.dart';
import 'package:ghar360/features/profile/data/profile_repository.dart';

final authRepositoryProvider = Provider<AuthRepository>(
  (ref) => AuthRepository(
    supabaseClient: ref.watch(supabaseClientProvider),
    apiClient: ref.watch(apiClientProvider),
    database: ref.watch(appDatabaseProvider),
    authHeaderProvider: ref.watch(authHeaderProviderProvider),
  ),
);

final profileRepositoryProvider = Provider<ProfileRepository>(
  (ref) => ProfileRepository(apiClient: ref.watch(apiClientProvider)),
);
final notificationsDatasourceProvider = Provider<NotificationsRemoteDatasource>(
  (ref) => NotificationsRemoteDatasource(ref.watch(apiClientProvider)),
);
