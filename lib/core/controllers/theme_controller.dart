import 'package:flutter/material.dart';

import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:ghar360/core/providers/app_database_provider.dart';
import 'package:ghar360/core/storage/app_database.dart';
import 'package:ghar360/core/utils/storage_keys.dart';

enum AppThemeMode { light, dark, system }

@immutable
class ThemeSettings {
  const ThemeSettings({required this.mode, this.persistence = const AsyncData(null)});
  final AppThemeMode mode;
  final AsyncValue<void> persistence;
  ThemeMode get flutterMode => switch (mode) {
    AppThemeMode.light => ThemeMode.light,
    AppThemeMode.dark => ThemeMode.dark,
    AppThemeMode.system => ThemeMode.system,
  };
  String get nameKey => '${mode.name}_mode';
}

final themeProvider = NotifierProvider<ThemeController, ThemeSettings>(ThemeController.new);

class ThemeController extends Notifier<ThemeSettings> {
  late AppDatabase _database;
  AppThemeMode? _requestedMode;

  @override
  ThemeSettings build() {
    _database = ref.watch(appDatabaseProvider);
    return ThemeSettings(
      mode: parseStoredThemeMode(_database.readPreference<Object>(StorageKeys.themeMode)),
    );
  }

  static AppThemeMode parseStoredThemeMode(Object? stored) {
    if (stored is int && stored >= 0 && stored < AppThemeMode.values.length) {
      return AppThemeMode.values[stored];
    }
    return AppThemeMode.values.firstWhere(
      (mode) => mode.name == stored,
      orElse: () => AppThemeMode.system,
    );
  }

  Future<bool> setThemeMode(AppThemeMode mode) async {
    if (state.persistence.isLoading) return false;
    _requestedMode = mode;
    state = ThemeSettings(mode: state.mode, persistence: const AsyncLoading());
    try {
      await _database.writePreference(StorageKeys.themeMode, mode.name);
      if (!ref.mounted) return false;
      state = ThemeSettings(mode: mode);
      return true;
    } catch (error, stack) {
      if (ref.mounted) {
        state = ThemeSettings(mode: state.mode, persistence: AsyncError(error, stack));
      }
      return false;
    }
  }

  Future<bool> retry() => setThemeMode(_requestedMode ?? state.mode);
  Future<bool> toggleTheme() =>
      setThemeMode(AppThemeMode.values[(state.mode.index + 1) % AppThemeMode.values.length]);
  Future<bool> setTheme(bool dark) => setThemeMode(dark ? AppThemeMode.dark : AppThemeMode.light);
}
