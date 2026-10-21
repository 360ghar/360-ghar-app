import 'package:flutter/foundation.dart';

import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:ghar360/core/data/models/user_model.dart';
import 'package:ghar360/core/providers/network_providers.dart';
import 'package:ghar360/core/utils/app_exceptions.dart';
import 'package:ghar360/features/profile/data/notification_settings_repository.dart';

final notificationSettingsRepositoryProvider = Provider<NotificationSettingsRepository>(
  (ref) => NotificationSettingsRepository(apiClient: ref.watch(apiClientProvider)),
);

@immutable
class NotificationSettingsState {
  const NotificationSettingsState({
    this.settings,
    this.loading = true,
    this.loadError,
    this.savingKey,
    this.saveError,
  });

  /// The settings the backend last returned, with an in-flight change applied.
  final UserNotificationSettings? settings;
  final bool loading;
  final AppException? loadError;

  /// The switch being written. Other switches wait until it finishes.
  final String? savingKey;
  final AppException? saveError;

  /// The switches to show once the backend has answered.
  List<String> get toggles => settings == null ? const [] : NotificationSettingsRepository.toggles;

  bool valueOf(String key) => settings?[key] == true;
}

final notificationSettingsProvider =
    NotifierProvider.autoDispose<NotificationSettingsController, NotificationSettingsState>(
      NotificationSettingsController.new,
    );

class NotificationSettingsController extends Notifier<NotificationSettingsState> {
  int _generation = 0;

  @override
  NotificationSettingsState build() {
    ref.watch(storageScopeProvider);
    ref.watch(notificationSettingsRepositoryProvider);
    final generation = ++_generation;
    ref.onDispose(() => _generation++);
    Future.microtask(() {
      if (_active(generation)) return load();
    });
    return const NotificationSettingsState();
  }

  bool _active(int generation) => ref.mounted && generation == _generation;

  AppException _failure(Object error) => error is AppException
      ? error
      : ServerException('Notification settings failed.', code: 'NOTIFICATION_SETTINGS_FAILED');

  Future<void> load() async {
    final generation = _generation;
    state = NotificationSettingsState(settings: state.settings);
    try {
      final settings = await ref.read(notificationSettingsRepositoryProvider).fetch();
      if (_active(generation)) {
        state = NotificationSettingsState(settings: settings, loading: false);
      }
    } catch (error) {
      if (_active(generation)) {
        state = NotificationSettingsState(
          settings: state.settings,
          loading: false,
          loadError: _failure(error),
        );
      }
    }
  }

  /// Writes one switch. Only that key goes to the backend, which merges it. On failure the
  /// switch returns to the last known server value.
  Future<bool> toggle(String key, bool value) async {
    final shown = state.settings;
    if (shown == null ||
        state.savingKey != null ||
        !NotificationSettingsRepository.toggles.contains(key)) {
      return false;
    }
    final generation = _generation;
    final repository = ref.read(notificationSettingsRepositoryProvider);
    state = NotificationSettingsState(
      settings: shown.withSwitch(key, value),
      loading: false,
      savingKey: key,
    );
    try {
      final saved = await repository.set(key, value);
      if (!_active(generation)) return false;
      state = NotificationSettingsState(settings: saved, loading: false);
      return true;
    } catch (error) {
      if (_active(generation)) {
        state = NotificationSettingsState(
          settings: shown,
          loading: false,
          saveError: _failure(error),
        );
      }
      return false;
    }
  }
}
