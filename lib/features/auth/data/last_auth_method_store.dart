// lib/features/auth/data/last_auth_method_store.dart

import 'package:get_storage/get_storage.dart';

import 'package:ghar360/core/utils/debug_logger.dart';
import 'package:ghar360/features/auth/data/auth_method.dart';
import 'package:ghar360/features/auth/data/identifier_utils.dart';

/// Persists the last-used auth method + a masked identifier hint in GetStorage
/// so the auth-entry screen can pre-select / highlight it on return.
class LastAuthMethodStore {
  LastAuthMethodStore({GetStorage? storage}) : _storage = storage ?? GetStorage();

  final GetStorage _storage;

  static const String _methodKey = 'last_auth_method';
  static const String _hintKey = 'last_auth_identifier_hint';
  static const String _atKey = 'last_auth_method_at';

  /// Records the last-used method and an optional masked identifier hint.
  /// [identifier] is masked before persisting; never store the raw value.
  void save(AuthMethod method, {String? identifier}) {
    try {
      _storage.write(_methodKey, method.wireValue);
      _storage.write(_atKey, DateTime.now().toIso8601String());
      if (identifier != null && identifier.trim().isNotEmpty) {
        _storage.write(_hintKey, IdentifierUtils.mask(identifier));
      } else {
        // Do not leave a previous account hint visible after a provider-only
        // sign-in or any auth flow that has no identifier to persist.
        _storage.remove(_hintKey);
      }
      DebugLogger.auth('💾 Saved last_auth_method=${method.wireValue}');
    } catch (e, st) {
      DebugLogger.warning('Failed to persist last auth method', e, st);
    }
  }

  AuthMethod? get lastMethod => AuthMethod.fromWire(_storage.read<String>(_methodKey));

  String? get lastIdentifierHint {
    final hint = _storage.read<String>(_hintKey);
    return (hint != null && hint.isNotEmpty) ? hint : null;
  }

  void clear() {
    try {
      _storage.remove(_methodKey);
      _storage.remove(_hintKey);
      _storage.remove(_atKey);
    } catch (_) {}
  }
}
