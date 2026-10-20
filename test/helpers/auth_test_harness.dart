import 'dart:async';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:ghar360/core/controllers/auth_controller.dart';
import 'package:ghar360/core/data/models/user_model.dart';
import 'package:ghar360/core/network/api_client.dart';
import 'package:ghar360/core/providers/app_database_provider.dart';
import 'package:ghar360/core/providers/auth_providers.dart';
import 'package:ghar360/core/providers/network_providers.dart';
import 'package:ghar360/core/storage/app_database.dart';
import 'package:ghar360/features/auth/data/auth_method.dart';
import 'package:ghar360/features/auth/data/auth_repository.dart';
import 'package:ghar360/features/auth/data/last_auth_method_store.dart';
import 'package:ghar360/features/notifications/data/datasources/notifications_remote_datasource.dart';
import 'package:ghar360/features/profile/data/profile_repository.dart';
import 'package:mocktail/mocktail.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';
import 'package:supabase_flutter/supabase_flutter.dart' show User;

class MockAuthRepository extends Mock implements AuthRepository {}

class MockProfileRepository extends Mock implements ProfileRepository {}

class MockNotificationsRemoteDatasource extends Mock implements NotificationsRemoteDatasource {}

class TestAuthClient extends Fake implements ApiClient {
  @override
  UnauthorizedHandler? onUnauthorized;
  int cancellations = 0;
  @override
  void cancelPendingRequests() {
    cancellations++;
  }
}

class TestScopeNotifier extends StorageScopeNotifier {
  TestScopeNotifier(this.harness);
  final AuthHarness harness;
  @override
  StorageScope build() {
    final subscription = harness.events.stream.listen((user) {
      state = harness.database.activateScope(environment: 'test', accountId: user?.id);
    }, onError: (Object _) {});
    ref.onDispose(() => unawaited(subscription.cancel()));
    return harness.database.activateScope(environment: 'test', accountId: harness.currentUser?.id);
  }
}

User sdkUser([String id = 'account-a', String? provider]) => User(
  id: id,
  appMetadata: provider == null ? {} : {'provider': provider},
  userMetadata: {},
  aud: 'authenticated',
  createdAt: '2024-01-01T00:00:00Z',
  email: '$id@example.com',
);
UserModel profile([String account = 'account-a', bool complete = true]) => UserModel(
  id: 1,
  supabaseUserId: account,
  email: '$account@example.com',
  fullName: complete ? 'Test User' : null,
  dateOfBirth: complete ? '1990-01-01' : null,
  isActive: true,
  isVerified: true,
  createdAt: DateTime(2024),
);

class AuthHarness {
  final repository = MockAuthRepository();
  final profiles = MockProfileRepository();
  final notifications = MockNotificationsRemoteDatasource();
  final client = TestAuthClient();
  final events = StreamController<User?>.broadcast(sync: true);
  User? currentUser;
  late AppDatabase database;
  late ProviderContainer container;
  Future<void> open({User? initialUser}) async {
    currentUser = initialUser;
    sqfliteFfiInit();
    database = await AppDatabase.open(
      factory: databaseFactoryFfi,
      databasePath: inMemoryDatabasePath,
      legacyReader: () async => {},
    );
    registerFallbackValue(const Duration(seconds: 10));
    registerFallbackValue(AuthMethod.google);
    when(() => repository.currentUser).thenAnswer((_) => currentUser);
    when(() => repository.currentSession).thenReturn(null);
    when(() => repository.onAuthStateChange).thenAnswer((_) => events.stream);
    when(() => repository.lastAuthMethodStore).thenReturn(LastAuthMethodStore(database: database));
    when(() => repository.isAppleSignInSupported).thenReturn(false);
    when(
      () => repository.waitForAccessToken(
        timeout: any(named: 'timeout'),
        minTtlSeconds: any(named: 'minTtlSeconds'),
      ),
    ).thenAnswer((_) async => 'token');
    when(
      () => repository.recordLastMethod(any(), identifier: any(named: 'identifier')),
    ).thenAnswer((_) async {});
    when(() => repository.signOut()).thenAnswer((_) async => emit(null));
    when(() => repository.deleteAccount()).thenAnswer((_) async {});
    when(() => repository.updateUserPassword(any())).thenAnswer((_) async => sdkUser());
    when(
      () => profiles.getCurrentUserProfile(),
    ).thenAnswer((_) async => profile(currentUser?.id ?? 'account-a'));
    when(
      () => profiles.updateUserPreferences(any()),
    ).thenAnswer((_) async => const UserPreferences());
    when(
      () => profiles.updateUserProfile(any()),
    ).thenAnswer((_) async => profile(currentUser?.id ?? 'account-a'));
    container = ProviderContainer(
      overrides: [
        appDatabaseProvider.overrideWithValue(database),
        authRepositoryProvider.overrideWithValue(repository),
        profileRepositoryProvider.overrideWithValue(profiles),
        notificationsDatasourceProvider.overrideWithValue(notifications),
        apiClientProvider.overrideWithValue(client),
        storageScopeProvider.overrideWith(() => TestScopeNotifier(this)),
      ],
    );
  }

  void emit(User? user) {
    currentUser = user;
    events.add(user);
  }

  AuthState get state => container.read(authProvider);
  AuthController get controller => container.read(authProvider.notifier);
  Future<void> settle() async {
    for (var i = 0; i < 5; i++) {
      await Future<void>.delayed(const Duration(milliseconds: 5));
    }
  }

  Future<void> authenticate({String account = 'account-a', bool complete = true}) async {
    container.read(authProvider);
    when(
      () => profiles.getCurrentUserProfile(),
    ).thenAnswer((_) async => profile(account, complete));
    emit(sdkUser(account));
    await settle();
  }

  Future<void> close() async {
    container.dispose();
    await events.close();
    await database.close();
  }
}
