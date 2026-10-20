import 'package:ghar360/core/data/models/user_model.dart';
import 'package:ghar360/core/network/api_client.dart';
import 'package:ghar360/core/network/api_paths.dart';
import 'package:ghar360/core/network/response_parser.dart';

/// The account's notification settings on the backend (`NotificationSettings`): four booleans.
///
/// `PUT /users/notification-settings` takes `NotificationSettingsWrite` and merges it: a key that
/// is not sent keeps its value. A switch therefore sends only its own key. There is no read
/// before the write, so two sessions cannot overwrite each other's other switches.
class NotificationSettingsRepository {
  NotificationSettingsRepository({required this._apiClient});

  final ApiClient _apiClient;

  /// Keys this app shows as switches. `promotional_emails` is the one marketing consent: the
  /// backend sends home recommendations and offers only when it is true, and a missing value
  /// means opt-out.
  static const toggles = ['push_notifications', 'email_notifications', 'promotional_emails'];

  Future<UserNotificationSettings> fetch() async {
    final response = await _apiClient.get(
      ApiPaths.usersNotificationSettings,
      useCache: false,
      dedupe: false,
    );
    return UserNotificationSettings.fromJson(ResponseParser.object(response.body));
  }

  /// Writes one switch and returns the settings the backend now holds. Idempotent: the body is
  /// the full intent for that key, so a transport retry writes the same value.
  Future<UserNotificationSettings> set(String key, bool value) async {
    assert(UserNotificationSettings.keys.contains(key), 'Not a notification setting: $key');
    final response = await _apiClient.put(
      ApiPaths.usersNotificationSettings,
      body: {key: value},
      idempotent: true,
    );
    return UserNotificationSettings.fromJson(ResponseParser.object(response.body));
  }
}
