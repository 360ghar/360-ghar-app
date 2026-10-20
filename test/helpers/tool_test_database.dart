import 'package:ghar360/core/storage/app_database.dart';
import 'package:mocktail/mocktail.dart';

/// Injected storage boundary: this fake does not replace checklist state logic.
class ToolTestDatabase extends Fake implements AppDatabase {
  final Map<String, Object?> preferences = {};
  final List<Map<String, Object?>> writes = [];
  Future<void> Function()? beforeWrite;
  bool failReads = false;
  bool failWrites = false;

  @override
  T? readPreference<T>(String key) {
    if (failReads) throw StateError('storage unavailable');
    return preferences[key] as T?;
  }

  @override
  Future<void> writePreference(String key, Object? value) async {
    await beforeWrite?.call();
    if (failWrites) throw StateError('storage full');
    writes.add({key: value});
    preferences[key] = value;
  }
}
