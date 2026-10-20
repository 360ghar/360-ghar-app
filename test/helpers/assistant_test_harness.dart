import 'dart:async';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_riverpod/misc.dart';
import 'package:ghar360/core/bootstrap/provider_policy.dart';
import 'package:ghar360/core/providers/app_database_provider.dart';
import 'package:ghar360/core/providers/network_providers.dart';
import 'package:ghar360/core/storage/app_database.dart';
import 'package:ghar360/features/assistant/data/assistant_repository.dart';
import 'package:ghar360/features/assistant/presentation/controllers/assistant_controller.dart';
import 'package:ghar360/features/assistant/presentation/controllers/assistant_history_controller.dart';
import 'package:mocktail/mocktail.dart';

class MockAssistantRepository extends Mock implements AssistantRepository {}

class TestAssistantScope extends Fake implements StorageScope {
  TestAssistantScope(this.accountId);
  @override
  final String? accountId;
  @override
  String get key => 'test:$accountId';
}

class TestAssistantDatabase extends Fake implements AppDatabase {
  StorageScope activeScope = TestAssistantScope('account-a');
  final drafts = <String, Map<String, Object?>>{};
  Object? readFailure;
  Object? writeFailure;
  Future<void> Function()? beforeWrite;
  String _key(StorageScope scope, String key) => '${scope.key}:$key';
  void _check(StorageScope scope) {
    if (!identical(scope, activeScope)) throw StorageFailure('obsolete lease');
  }

  @override
  Future<Map<String, dynamic>?> readDraft({
    required StorageScope scope,
    required String key,
  }) async {
    _check(scope);
    if (readFailure != null) throw readFailure!;
    final value = drafts[_key(scope, key)];
    return value == null ? null : Map<String, dynamic>.from(value);
  }

  @override
  Future<void> removeDraft({required StorageScope scope, required String key}) async {
    _check(scope);
    if (writeFailure != null) throw writeFailure!;
    drafts.remove(_key(scope, key));
  }

  @override
  Future<void> writeDraft({
    required StorageScope scope,
    required String key,
    required Map<String, Object?> value,
  }) async {
    await beforeWrite?.call();
    _check(scope);
    if (writeFailure != null) throw writeFailure!;
    drafts[_key(scope, key)] = Map.of(value);
  }
}

class TestScopeNotifier extends StorageScopeNotifier {
  TestScopeNotifier(this.database);
  final TestAssistantDatabase database;
  @override
  StorageScope build() => database.activeScope;
  void switchAccount(String id) {
    database.activeScope = TestAssistantScope(id);
    state = database.activeScope;
  }
}

class TestAssistantController extends AssistantController {
  TestAssistantController(super.id, {this.initial});
  final AssistantState? initial;
  @override
  AssistantState build() {
    final value = super.build();
    return initial ?? value;
  }

  void seed(AssistantState value) => state = value;
  AssistantState get snapshot => state;
}

class TestAssistantHistoryController extends AssistantHistoryController {
  void seed(AssistantHistoryState value) => state = value;
  AssistantHistoryState get snapshot => state;
}

class AssistantTestHarness {
  AssistantTestHarness({AssistantState? initial}) {
    overrides = [
      assistantRepositoryProvider.overrideWithValue(repository),
      appDatabaseProvider.overrideWithValue(database),
      storageScopeProvider.overrideWith(() => TestScopeNotifier(database)),
      assistantControllerProvider.overrideWith2(
        (id) => TestAssistantController(id, initial: initial),
      ),
      assistantHistoryProvider.overrideWith(TestAssistantHistoryController.new),
    ];
    container = ProviderContainer(overrides: overrides, retry: noProviderRetry);
  }
  final repository = MockAssistantRepository();
  final database = TestAssistantDatabase();
  late final List<Override> overrides;
  late final ProviderContainer container;
  TestAssistantController conversation([int? id]) {
    container.listen(assistantControllerProvider(id), (_, _) {});
    return container.read(assistantControllerProvider(id).notifier) as TestAssistantController;
  }

  TestAssistantHistoryController history() {
    container.listen(assistantHistoryProvider, (_, _) {});
    return container.read(assistantHistoryProvider.notifier) as TestAssistantHistoryController;
  }

  void dispose() => container.dispose();
}
