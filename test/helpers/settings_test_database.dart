import 'package:mocktail/mocktail.dart';

import 'package:ghar360/core/storage/app_database.dart';

/// State tests control writes; real SQLite guarantees are tested separately.
class SettingsTestDatabase extends Fake implements AppDatabase {
  final Map<String, Object?> values = {};
  Object? writeFailure;
  Future<void> Function()? beforeWrite;
  int closeCount = 0;
  int writeCount = 0;

  @override
  T? readPreference<T>(String key) => values[key] is T ? values[key] as T : null;

  @override
  Future<void> writePreference(String key, Object? value) => writePreferences({key: value});

  @override
  Future<void> writePreferences(Map<String, Object?> updates) async {
    writeCount++;
    await beforeWrite?.call();
    if (writeFailure case final failure?) throw failure;
    values.addAll(updates);
  }

  @override
  Future<void> close() async {
    closeCount++;
  }
}
