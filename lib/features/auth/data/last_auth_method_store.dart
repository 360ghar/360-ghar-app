import 'package:ghar360/core/storage/app_database.dart';
import 'package:ghar360/core/utils/storage_keys.dart';
import 'package:ghar360/features/auth/data/auth_method.dart';
import 'package:ghar360/features/auth/data/identifier_utils.dart';

/// Login hints only. Supabase owns session and credential persistence.
class LastAuthMethodStore {
  LastAuthMethodStore({required this._database});
  final AppDatabase _database;

  Future<void> save(AuthMethod method, {String? identifier}) => _database.writePreferences({
    StorageKeys.lastAuthMethod: method.wire,
    StorageKeys.lastAuthMethodAt: DateTime.now().toUtc().toIso8601String(),
    StorageKeys.lastAuthIdentifierHint: identifier == null || identifier.trim().isEmpty
        ? null
        : IdentifierUtils.mask(identifier),
  });

  AuthMethod? get lastMethod =>
      AuthMethod.fromJson(_database.readPreference<String>(StorageKeys.lastAuthMethod));
  String? get lastIdentifierHint {
    final hint = _database.readPreference<String>(StorageKeys.lastAuthIdentifierHint);
    return hint == null || hint.isEmpty ? null : hint;
  }

  Future<void> clear() => _database.writePreferences({
    StorageKeys.lastAuthMethod: null,
    StorageKeys.lastAuthMethodAt: null,
    StorageKeys.lastAuthIdentifierHint: null,
  });
}
